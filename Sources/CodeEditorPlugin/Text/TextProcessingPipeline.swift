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
    private let resultCache: PipelineCache
    private let operationCache: OperationCache

    // MARK: - Configuration

    /// Configuration options for customizing pipeline behavior and performance characteristics.
    public struct PipelineConfiguration {
        /// Whether to enable caching of operation results to improve performance.
        public var enableCaching: Bool = true
        /// Maximum number of cached results to maintain in memory.
        public var maxCacheSize: Int = 100
        /// Timeout in seconds for individual operations before they are cancelled.
        public var operationTimeout: TimeInterval = 30.0
        /// Memory limit in megabytes for pipeline operations.
        public var memoryLimit: Int = 100
        /// Whether to enable parallel processing of operations when possible.
        public var enableParallelProcessing: Bool = true
        /// Default batch size for processing large text inputs.
        public var batchSize: Int = 10_000
        /// Whether to enable verbose logging for debugging purposes.
        public var logVerbose: Bool = false

        /// Creates a new pipeline configuration with default settings.
        public init() {}
    }

    // MARK: - Initialization

    /// Creates a new text processing pipeline with the specified configuration.
    /// - Parameter configuration: Configuration options for the pipeline (uses defaults if not specified)
    public init(configuration: PipelineConfiguration = PipelineConfiguration()) {
        self.configuration = configuration
        self.resultCache = PipelineCache()
        self.operationCache = OperationCache()
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
            if let cachedResult = await resultCache.get(key: cacheKey) {
                return cachedResult
            }
        }

        let result = try await process(text)

        if configuration.enableCaching {
            await resultCache.set(key: cacheKey, value: result, maxSize: configuration.maxCacheSize)
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

private actor PipelineCache {
    private var cache: [String: TextProcessingPipeline.ProcessingResult] = [:]
    private var accessOrder: [String] = []

    init() {}

    func get(key: String) -> TextProcessingPipeline.ProcessingResult? {
        guard let value = cache[key] else { return nil }
        markAccessed(key)
        return value
    }

    func set(key: String, value: TextProcessingPipeline.ProcessingResult, maxSize: Int) {
        cache[key] = value
        markAccessed(key)
        evictIfNeeded(maxSize: maxSize)
    }

    private func markAccessed(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func evictIfNeeded(maxSize: Int) {
        let boundedSize = max(0, maxSize)
        while cache.count > boundedSize, let oldestKey = accessOrder.first {
            accessOrder.removeFirst()
            cache.removeValue(forKey: oldestKey)
        }
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
        let cacheKey = OperationCacheKey(operationName: operation.name, text: text)
        if configuration.enableCaching, let cachedText = await operationCache.get(key: cacheKey, originalText: text) {
            return OperationExecutionResult(processedText: cachedText, wasFromCache: true)
        }

        // Execute operation with timeout
        let processedText = try await withTimeout(configuration.operationTimeout) {
            try await operation.execute(on: text)
        }

        // Cache result
        if configuration.enableCaching {
            await operationCache.set(key: cacheKey, originalText: text, value: processedText, maxSize: configuration.maxCacheSize)
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

private struct OperationCacheKey: Hashable, Sendable {
    let operationName: String
    let text: String
}

private actor OperationCache {
    private struct Entry: Sendable {
        let originalText: String
        let processedText: String
    }

    private var cache: [OperationCacheKey: Entry] = [:]
    private var accessOrder: [OperationCacheKey] = []

    init() {}

    func get(key: OperationCacheKey, originalText: String) -> String? {
        guard let entry = cache[key], entry.originalText == originalText else { return nil }
        markAccessed(key)
        return entry.processedText
    }

    func set(key: OperationCacheKey, originalText: String, value: String, maxSize: Int) {
        cache[key] = Entry(originalText: originalText, processedText: value)
        markAccessed(key)
        evictIfNeeded(maxSize: maxSize)
    }

    private func markAccessed(_ key: OperationCacheKey) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func evictIfNeeded(maxSize: Int) {
        let boundedSize = max(0, maxSize)
        while cache.count > boundedSize, let oldestKey = accessOrder.first {
            accessOrder.removeFirst()
            cache.removeValue(forKey: oldestKey)
        }
    }
}
