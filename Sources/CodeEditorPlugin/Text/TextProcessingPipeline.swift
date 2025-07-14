import Foundation

// MARK: - Text Processing Pipeline Framework

/// Framework for chaining text processing operations efficiently
/// Provides consistent error handling, caching, and performance optimizations
public struct TextProcessingPipeline {
    // MARK: - Supporting Types
    
    public struct ProcessingResult: Sendable {
        public let processedText: String
        public let metadata: ProcessingMetadata
        public let operations: [OperationResult]
        public let duration: TimeInterval
        
        public var isSuccess: Bool {
            operations.allSatisfy { $0.isSuccess }
        }
        
        public var errors: [ProcessingError] {
            operations.compactMap { $0.error }
        }
    }
    
    public struct ProcessingMetadata: Sendable {
        public let originalLength: Int
        public let processedLength: Int
        public let operationCount: Int
        public let cacheHits: Int
        public let estimatedCost: TextProcessingUtilities.ProcessingCost
        
        public var compressionRatio: Double {
            guard originalLength > 0 else { return 1.0 }
            return Double(processedLength) / Double(originalLength)
        }
    }
    
    public struct OperationResult: Sendable {
        public let operation: TextProcessingOperation
        public let duration: TimeInterval
        public let inputLength: Int
        public let outputLength: Int
        public let wasFromCache: Bool
        public let error: ProcessingError?
        
        public var isSuccess: Bool {
            error == nil
        }
    }
    
    public enum ProcessingError: Error, LocalizedError {
        case operationFailed(operation: String, reason: String)
        case validationFailed(validator: String, issues: [String])
        case transformationFailed(transformer: String, reason: String)
        case cachingFailed(reason: String)
        case timeoutExceeded(operation: String, timeout: TimeInterval)
        case memoryLimitExceeded(limit: Int, actual: Int)
        
        public var errorDescription: String? {
            switch self {
            case let .operationFailed(operation, reason):
                return "Operation '\(operation)' failed: \(reason)"

            case let .validationFailed(validator, issues):
                return "Validation '\(validator)' failed: \(issues.joined(separator: ", "))"

            case let .transformationFailed(transformer, reason):
                return "Transformation '\(transformer)' failed: \(reason)"

            case let .cachingFailed(reason):
                return "Caching failed: \(reason)"

            case let .timeoutExceeded(operation, timeout):
                return "Operation '\(operation)' exceeded timeout of \(timeout)s"

            case let .memoryLimitExceeded(limit, actual):
                return "Memory limit exceeded: \(actual)MB > \(limit)MB limit"
            }
        }
    }
    
    // MARK: - Properties
    
    private var operations: [TextProcessingOperation] = []
    private var validators: [TextValidator] = []
    private var transformers: [TextTransformer] = []
    private var configuration: PipelineConfiguration
    
    // MARK: - Configuration
    
    public struct PipelineConfiguration {
        public var enableCaching: Bool = true
        public var maxCacheSize: Int = 100
        public var operationTimeout: TimeInterval = 30.0
        public var memoryLimit: Int = 100 // MB
        public var enableParallelProcessing: Bool = true
        public var batchSize: Int = 10_000
        public var logVerbose: Bool = false
        
        public init() {}
    }
    
    // MARK: - Initialization
    
    public init(configuration: PipelineConfiguration = PipelineConfiguration()) {
        self.configuration = configuration
    }
    
    // MARK: - Pipeline Construction
    
    /// Adds a processing operation to the pipeline
    @discardableResult
    public func addOperation(_ operation: TextProcessingOperation) -> Self {
        var pipeline = self
        pipeline.operations.append(operation)
        return pipeline
    }
    
    /// Adds a validation step to the pipeline
    @discardableResult
    public func addValidation(_ validator: TextValidator) -> Self {
        var pipeline = self
        pipeline.validators.append(validator)
        return pipeline
    }
    
    /// Adds a transformation step to the pipeline
    @discardableResult
    public func addTransformation(_ transformer: TextTransformer) -> Self {
        var pipeline = self
        pipeline.transformers.append(transformer)
        return pipeline
    }
    
    /// Configures the pipeline with custom settings
    @discardableResult
    public func configure(_ configurationBuilder: (inout PipelineConfiguration) -> Void) -> Self {
        var pipeline = self
        configurationBuilder(&pipeline.configuration)
        return pipeline
    }
    
    // MARK: - Execution
    
    /// Processes text through the entire pipeline
    public func process(_ text: String) async throws -> ProcessingResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var currentText = text
        var operationResults: [OperationResult] = []
        var cacheHits = 0
        
        // Estimate total cost
        let estimatedCost = TextProcessingUtilities.estimateProcessingCost(
            for: text,
            operation: .parsing // Use parsing as baseline
        )
        
        // Check memory requirements
        let estimatedMemoryMB = Int(estimatedCost.memoryRequirementMB)
        if estimatedMemoryMB > configuration.memoryLimit {
            throw ProcessingError.memoryLimitExceeded(
                limit: configuration.memoryLimit,
                actual: estimatedMemoryMB
            )
        }
        
        // Run validators first
        for validator in validators {
            try await runValidator(validator, on: currentText)
        }
        
        // Process through operations
        for operation in operations {
            let operationStart = CFAbsoluteTimeGetCurrent()
            
            do {
                let result = try await executeOperation(operation, on: currentText)
                currentText = result.processedText
                
                let operationDuration = CFAbsoluteTimeGetCurrent() - operationStart
                operationResults.append(OperationResult(
                    operation: operation,
                    duration: operationDuration,
                    inputLength: text.count,
                    outputLength: currentText.count,
                    wasFromCache: result.wasFromCache,
                    error: nil
                ))
                
                if result.wasFromCache {
                    cacheHits += 1
                }
            } catch {
                let operationDuration = CFAbsoluteTimeGetCurrent() - operationStart
                operationResults.append(OperationResult(
                    operation: operation,
                    duration: operationDuration,
                    inputLength: text.count,
                    outputLength: currentText.count,
                    wasFromCache: false,
                    error: error as? ProcessingError ?? .operationFailed(
                        operation: operation.name,
                        reason: error.localizedDescription
                    )
                ))
                throw error
            }
        }
        
        // Apply transformers
        for transformer in transformers {
            currentText = try await runTransformer(transformer, on: currentText)
        }
        
        let totalDuration = CFAbsoluteTimeGetCurrent() - startTime
        
        let metadata = ProcessingMetadata(
            originalLength: text.count,
            processedLength: currentText.count,
            operationCount: operations.count,
            cacheHits: cacheHits,
            estimatedCost: estimatedCost
        )
        
        return ProcessingResult(
            processedText: currentText,
            metadata: metadata,
            operations: operationResults,
            duration: totalDuration
        )
    }
    
    /// Processes text in batches for better memory management
    public func processInBatches(_ text: String, batchSize: Int? = nil) async throws -> ProcessingResult {
        let actualBatchSize = batchSize ?? configuration.batchSize
        let chunks = TextProcessingUtilities.splitIntoChunks(text, chunkSize: actualBatchSize)
        
        var processedChunks: [String] = []
        var allOperationResults: [OperationResult] = []
        var totalCacheHits = 0
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for (chunkText, _) in chunks {
            let chunkResult = try await process(chunkText)
            processedChunks.append(chunkResult.processedText)
            allOperationResults.append(contentsOf: chunkResult.operations)
            totalCacheHits += chunkResult.metadata.cacheHits
        }
        
        let processedText = processedChunks.joined()
        let totalDuration = CFAbsoluteTimeGetCurrent() - startTime
        
        let estimatedCost = TextProcessingUtilities.estimateProcessingCost(for: text, operation: .parsing)
        let metadata = ProcessingMetadata(
            originalLength: text.count,
            processedLength: processedText.count,
            operationCount: operations.count * chunks.count,
            cacheHits: totalCacheHits,
            estimatedCost: estimatedCost
        )
        
        return ProcessingResult(
            processedText: processedText,
            metadata: metadata,
            operations: allOperationResults,
            duration: totalDuration
        )
    }
    
    /// Processes text with caching for repeated operations
    public func processWithCaching(_ text: String, cacheKey: String) async throws -> ProcessingResult {
        if configuration.enableCaching {
            if let cachedResult = PipelineCache.shared.get(key: cacheKey) {
                return cachedResult
            }
        }
        
        let result = try await process(text)
        
        if configuration.enableCaching {
            PipelineCache.shared.set(key: cacheKey, value: result)
        }
        
        return result
    }
}

// MARK: - Processing Operation Protocol

public protocol TextProcessingOperation: Sendable {
    var name: String { get }
    var priority: OperationPriority { get }
    var canBeParallelized: Bool { get }
    
    func execute(on text: String) async throws -> String
    func estimateComplexity(for text: String) -> ProcessingComplexity
}

public enum OperationPriority: Sendable {
    case low, medium, high, critical
    
    var numericValue: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

public enum ProcessingComplexity: Sendable {
    case constant
    case linear
    case quadratic
    case exponential
    
    func estimateTime(for textLength: Int) -> TimeInterval {
        let lengthDouble = Double(textLength)
        switch self {
        case .constant:
            return 0.001
            
        case .linear:
            return lengthDouble * 0.00001
            
        case .quadratic:
            return lengthDouble * lengthDouble * 0.000001
            
        case .exponential:
            return pow(2, lengthDouble / 1_000) * 0.001
        }
    }
}

// MARK: - Validator Protocol

public protocol TextValidator: Sendable {
    var name: String { get }

    func validate(_ text: String) throws
}

// MARK: - Transformer Protocol

public protocol TextTransformer: Sendable {
    var name: String { get }

    func transform(_ text: String) async throws -> String
}

// MARK: - Caching System

private final class PipelineCache: @unchecked Sendable {
    static let shared = PipelineCache()
    
    private var cache: [String: TextProcessingPipeline.ProcessingResult] = [:]
    private var accessTimes: [String: Date] = [:]
    private let maxSize = 100
    private let queue = DispatchQueue(label: "pipeline.cache", attributes: .concurrent)
    
    private init() {}
    
    func get(key: String) -> TextProcessingPipeline.ProcessingResult? {
        queue.sync {
            accessTimes[key] = Date()
            return cache[key]
        }
    }
    
    func set(key: String, value: TextProcessingPipeline.ProcessingResult) {
        queue.async(flags: .barrier) {
            self.cache[key] = value
            self.accessTimes[key] = Date()
            
            if self.cache.count > self.maxSize {
                self.evictOldestEntry()
            }
        }
    }
    
    private func evictOldestEntry() {
        guard let oldestKey = accessTimes.min(by: { $0.value < $1.value })?.key else { return }
        cache.removeValue(forKey: oldestKey)
        accessTimes.removeValue(forKey: oldestKey)
    }
}

// MARK: - Built-in Operations

public struct SyntaxHighlightingOperation: TextProcessingOperation {
    public let name = "SyntaxHighlighting"
    public let priority = OperationPriority.high
    public let canBeParallelized = true
    
    private let language: Language
    
    public init(language: Language) {
        self.language = language
    }
    
    public func execute(on text: String) async throws -> String {
        // This would integrate with the existing syntax highlighting system
        // For now, returning the original text
        text
    }
    
    public func estimateComplexity(for _: String) -> ProcessingComplexity {
        .linear
    }
}

public struct WhitespaceNormalizationOperation: TextProcessingOperation {
    public let name = "WhitespaceNormalization"
    public let priority = OperationPriority.low
    public let canBeParallelized = true
    
    public func execute(on text: String) async throws -> String {
        TextProcessingUtilities.normalizeWhitespace(in: text)
    }
    
    public func estimateComplexity(for _: String) -> ProcessingComplexity {
        .linear
    }
}

public struct LineEndingNormalizationOperation: TextProcessingOperation {
    public let name = "LineEndingNormalization"
    public let priority = OperationPriority.medium
    public let canBeParallelized = true
    
    private let format: TextParsingUtilities.LineEndingType
    
    public init(format: TextParsingUtilities.LineEndingType) {
        self.format = format
    }
    
    public func execute(on text: String) async throws -> String {
        TextParsingUtilities.normalizeLineEndings(in: text, to: format)
    }
    
    public func estimateComplexity(for _: String) -> ProcessingComplexity {
        .linear
    }
}

// MARK: - Built-in Validators

public struct TextLengthValidator: TextValidator {
    public let name = "TextLengthValidator"
    private let maxLength: Int
    
    public init(maxLength: Int) {
        self.maxLength = maxLength
    }
    
    public func validate(_ text: String) throws {
        if text.count > maxLength {
            throw TextProcessingPipeline.ProcessingError.validationFailed(
                validator: name,
                issues: ["Text length \(text.count) exceeds maximum \(maxLength)"]
            )
        }
    }
}

public struct EncodingValidator: TextValidator {
    public let name = "EncodingValidator"
    private let requiredEncoding: String.Encoding
    
    public init(requiredEncoding: String.Encoding = .utf8) {
        self.requiredEncoding = requiredEncoding
    }
    
    public func validate(_ text: String) throws {
        guard text.data(using: requiredEncoding) != nil else {
            throw TextProcessingPipeline.ProcessingError.validationFailed(
                validator: name,
                issues: ["Text cannot be encoded with required encoding"]
            )
        }
    }
}

// MARK: - Built-in Transformers

public struct TrimWhitespaceTransformer: TextTransformer {
    public let name = "TrimWhitespaceTransformer"
    private let mode: TextProcessingUtilities.TrimmingMode
    
    public init(mode: TextProcessingUtilities.TrimmingMode = .leadingAndTrailing) {
        self.mode = mode
    }
    
    public func transform(_ text: String) async throws -> String {
        TextProcessingUtilities.trimWhitespace(from: text, mode: mode)
    }
}

// MARK: - Pipeline Extensions

extension TextProcessingPipeline {
    /// Convenience method for common text cleanup pipeline
    public static func textCleanupPipeline() -> TextProcessingPipeline {
        TextProcessingPipeline()
            .addValidation(EncodingValidator())
            .addOperation(WhitespaceNormalizationOperation())
            .addOperation(LineEndingNormalizationOperation(format: .unix))
            .addTransformation(TrimWhitespaceTransformer())
    }
    
    /// Convenience method for syntax highlighting pipeline
    public static func syntaxHighlightingPipeline(language: Language) -> TextProcessingPipeline {
        TextProcessingPipeline()
            .addValidation(TextLengthValidator(maxLength: 1_000_000))
            .addOperation(SyntaxHighlightingOperation(language: language))
    }
}

// MARK: - Private Helpers

extension TextProcessingPipeline {
    struct OperationExecutionResult {
        let processedText: String
        let wasFromCache: Bool
    }
    
    func executeOperation(_ operation: TextProcessingOperation, on text: String) async throws -> OperationExecutionResult {
        // Check cache first
        let cacheKey = "\(operation.name)_\(text.hashValue)"
        if configuration.enableCaching, let cachedText = OperationCache.shared.get(key: cacheKey) {
            return OperationExecutionResult(processedText: cachedText, wasFromCache: true)
        }
        
        // Execute operation with timeout
        let processedText = try await withTimeout(configuration.operationTimeout) {
            try await operation.execute(on: text)
        }
        
        // Cache result
        if configuration.enableCaching {
            OperationCache.shared.set(key: cacheKey, value: processedText)
        }
        
        return OperationExecutionResult(processedText: processedText, wasFromCache: false)
    }
    
    func runValidator(_ validator: TextValidator, on text: String) async throws {
        try await withTimeout(configuration.operationTimeout) {
            try validator.validate(text)
        }
    }
    
    func runTransformer(_ transformer: TextTransformer, on text: String) async throws -> String {
        try await withTimeout(configuration.operationTimeout) {
            try await transformer.transform(text)
        }
    }
    
    func withTimeout<T: Sendable>(_ timeout: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw ProcessingError.timeoutExceeded(operation: "unknown", timeout: timeout)
            }
            
            guard let result = try await group.next() else {
                throw ProcessingError.operationFailed(operation: "withTimeout", reason: "No task completed successfully")
            }
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Operation Cache

private final class OperationCache: @unchecked Sendable {
    static let shared = OperationCache()
    
    private var cache: [String: String] = [:]
    private let maxSize = 1_000
    private let queue = DispatchQueue(label: "operation.cache", attributes: .concurrent)
    
    private init() {}
    
    func get(key: String) -> String? {
        queue.sync {
            cache[key]
        }
    }
    
    func set(key: String, value: String) {
        queue.async(flags: .barrier) {
            self.cache[key] = value
            
            if self.cache.count > self.maxSize {
                // Simple eviction: remove random entries
                let keysToRemove = Array(self.cache.keys.prefix(self.maxSize / 4))
                for key in keysToRemove {
                    self.cache.removeValue(forKey: key)
                }
            }
        }
    }
}
