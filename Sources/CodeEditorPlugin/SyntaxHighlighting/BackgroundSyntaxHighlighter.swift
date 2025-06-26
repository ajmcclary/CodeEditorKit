import Foundation
import os.log

/// Performs syntax highlighting in background threads to improve UI responsiveness
@MainActor
public final class BackgroundSyntaxHighlighter: ObservableObject {
    // MARK: - Configuration
    
    /// Maximum number of concurrent highlighting operations
    public var maxConcurrentOperations: Int = 3
    
    /// Time delay before starting highlighting after text changes (in seconds)
    public var highlightingDelay: TimeInterval = 0.1
    
    /// Maximum text length for background highlighting (larger texts use chunked processing)
    public var maxBackgroundTextLength: Int = 500_000
    
    /// Chunk size for processing very large texts
    public var chunkSize: Int = 10_000
    
    /// Enable priority-based highlighting (visible content first)
    public var enablePriorityHighlighting: Bool = true
    
    // MARK: - State
    
    /// Current highlighting statistics
    @Published public private(set) var statistics = BackgroundHighlightingStatistics()
    
    /// Background operation queue
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.codeeditor.background-highlighting"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 3
        return queue
    }()
    
    /// Pending highlighting requests
    private var pendingRequests: [String: HighlightingRequest] = [:]
    
    /// Completed highlighting results cache
    private var resultCache: [String: CachedHighlightResult] = [:]
    
    /// Current visible range for priority highlighting
    private var visibleRange = NSRange(location: 0, length: 0)
    
    /// Debounce timer for text changes
    private var debounceTimer: Timer?
    
    /// Logger for debugging
    private let logger = Logger(subsystem: "com.codeeditor.highlighting", category: "BackgroundSyntaxHighlighter")
    
    // MARK: - Completion Handlers
    
    /// Completion handler for highlighting results
    public typealias HighlightingCompletion = @Sendable (Result<[HighlightedToken], Error>) -> Void
    
    // MARK: - Initialization
    
    public init() {
        configureOperationQueue()
        
        // Register with memory monitor
        registerWithMemoryMonitor()
    }
    
    deinit {
        // Note: Cannot access MainActor isolated properties from deinit
        // Timer and OperationQueue will be cleaned up automatically
        // The operation queue will cancel all operations when deallocated
        operationQueue.cancelAllOperations()
    }
    
    // MARK: - Public Methods
    
    /// Request background syntax highlighting for text
    /// - Parameters:
    ///   - text: Text to highlight
    ///   - language: Programming language
    ///   - requestId: Unique identifier for the request
    ///   - priority: Request priority
    ///   - completion: Completion handler
    public func requestHighlighting(
        text: String,
        language: Language,
        requestId: String = UUID().uuidString,
        priority: HighlightingPriority = .normal,
        completion: @escaping HighlightingCompletion
    ) {
        // Cancel any existing request with the same ID
        cancelRequest(requestId)
        
        // Check cache first
        let cacheKey = createCacheKey(text: text, language: language)
        if let cachedResult = resultCache[cacheKey], !cachedResult.isExpired {
            statistics.recordCacheHit()
            completion(.success(cachedResult.tokens))
            return
        }
        
        // Create new request
        let request = HighlightingRequest(
            id: requestId,
            text: text,
            language: language,
            priority: priority,
            visibleRange: enablePriorityHighlighting ? visibleRange : nil,
            completion: completion
        )
        
        pendingRequests[requestId] = request
        
        // Debounce the highlighting to avoid excessive operations
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: highlightingDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.processRequest(request)
            }
        }
        
        statistics.recordRequest()
    }
    
    /// Update visible range for priority highlighting
    /// - Parameter range: Currently visible text range
    public func updateVisibleRange(_ range: NSRange) {
        visibleRange = range
        
        // Re-prioritize pending requests if priority highlighting is enabled
        if enablePriorityHighlighting {
            reprioritizePendingRequests()
        }
    }
    
    /// Cancel a specific highlighting request
    /// - Parameter requestId: ID of the request to cancel
    public func cancelRequest(_ requestId: String) {
        if let request = pendingRequests.removeValue(forKey: requestId) {
            request.operation?.cancel()
            statistics.recordCancellation()
        }
    }
    
    /// Cancel all pending highlighting requests
    public func cancelAllRequests() {
        for (_, request) in pendingRequests {
            request.operation?.cancel()
        }
        pendingRequests.removeAll()
        operationQueue.cancelAllOperations()
        
        statistics.recordBulkCancellation(count: pendingRequests.count)
    }
    
    /// Clear the highlighting cache
    public func clearCache() {
        resultCache.removeAll()
        statistics.recordCacheClear()
    }
    
    /// Configure operation queue settings
    /// - Parameters:
    ///   - maxConcurrentOperations: Maximum concurrent operations
    ///   - qualityOfService: Quality of service for operations
    public func configureQueue(
        maxConcurrentOperations: Int,
        qualityOfService: QualityOfService = .userInitiated
    ) {
        self.maxConcurrentOperations = maxConcurrentOperations
        operationQueue.maxConcurrentOperationCount = maxConcurrentOperations
        operationQueue.qualityOfService = qualityOfService
    }
    
    // MARK: - Private Methods
    
    private func configureOperationQueue() {
        operationQueue.maxConcurrentOperationCount = maxConcurrentOperations
        operationQueue.qualityOfService = .userInitiated
    }
    
    private func processRequest(_ request: HighlightingRequest) async {
        let startTime = Date()
        
        do {
            let tokens: [HighlightedToken]
            
            // Choose highlighting strategy based on text size
            if request.text.count > maxBackgroundTextLength {
                tokens = try await processLargeText(request)
            } else {
                tokens = try await processNormalText(request)
            }
            
            // Cache the result
            let cacheKey = createCacheKey(text: request.text, language: request.language)
            let cachedResult = CachedHighlightResult(
                tokens: tokens,
                timestamp: Date(),
                expirationTime: 300 // 5 minutes
            )
            resultCache[cacheKey] = cachedResult
            
            // Complete the request
            let processingTime = Date().timeIntervalSince(startTime)
            statistics.recordCompletion(processingTime: processingTime, tokenCount: tokens.count)
            
            // Call completion on main thread
            await MainActor.run {
                request.completion(.success(tokens))
                pendingRequests.removeValue(forKey: request.id)
            }
        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            statistics.recordError(processingTime: processingTime)
            
            await MainActor.run {
                request.completion(.failure(error))
                pendingRequests.removeValue(forKey: request.id)
            }
        }
    }
    
    private func processNormalText(_ request: HighlightingRequest) async throws -> [HighlightedToken] {
        // Create highlighting operation
        let operation = HighlightingOperation(
            text: request.text,
            language: request.language,
            priority: request.priority
        )
        
        // Store operation reference for cancellation
        await MainActor.run {
            if var storedRequest = pendingRequests[request.id] {
                storedRequest.operation = operation
                pendingRequests[request.id] = storedRequest
            }
        }
        
        // Add to operation queue
        operationQueue.addOperation(operation)
        
        // Wait for completion
        while !operation.isFinished && !operation.isCancelled {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        if operation.isCancelled {
            throw HighlightingError.cancelled
        }
        
        return operation.result
    }
    
    private func processLargeText(_ request: HighlightingRequest) async throws -> [HighlightedToken] {
        // Split large text into chunks for processing
        let chunks = splitTextIntoChunks(request.text, chunkSize: chunkSize)
        var allTokens: [HighlightedToken] = []
        
        for (index, chunk) in chunks.enumerated() {
            // Process each chunk
            let chunkRequest = HighlightingRequest(
                id: "\(request.id)-chunk-\(index)",
                text: chunk.text,
                language: request.language,
                priority: request.priority,
                visibleRange: request.visibleRange
            ) { _ in } // Empty completion for chunks
            
            let chunkTokens = try await processNormalText(chunkRequest)
            
            // Adjust token ranges to match original text positions
            let adjustedTokens = chunkTokens.map { token in
                HighlightedToken(
                    range: NSRange(
                        location: token.range.location + chunk.offset,
                        length: token.range.length
                    ),
                    type: token.type,
                    text: token.text
                )
            }
            
            allTokens.append(contentsOf: adjustedTokens)
        }
        
        return allTokens
    }
    
    private func splitTextIntoChunks(_ text: String, chunkSize: Int) -> [(text: String, offset: Int)] {
        var chunks: [(text: String, offset: Int)] = []
        // swiftlint:disable:next legacy_objc_type
        let nsString = NSString(string: text)
        var currentOffset = 0
        
        while currentOffset < nsString.length {
            let remainingLength = nsString.length - currentOffset
            let currentChunkSize = min(chunkSize, remainingLength)
            
            let chunkRange = NSRange(location: currentOffset, length: currentChunkSize)
            let chunkText = nsString.substring(with: chunkRange)
            
            chunks.append((text: chunkText, offset: currentOffset))
            currentOffset += currentChunkSize
        }
        
        return chunks
    }
    
    private func reprioritizePendingRequests() {
        // Sort requests by priority and visible range overlap
        for (_, request) in pendingRequests {
            if let visibleRange = request.visibleRange,
               let textRange = request.textRange {
                // Calculate overlap with current visible range
                let overlap = calculateRangeOverlap(visibleRange, textRange)
                
                // Boost priority for visible content
                if overlap > 0 {
                    request.operation?.queuePriority = .high
                } else {
                    request.operation?.queuePriority = .normal
                }
            }
        }
    }
    
    private func calculateRangeOverlap(_ range1: NSRange, _ range2: NSRange) -> Int {
        let start = max(range1.location, range2.location)
        let end = min(range1.location + range1.length, range2.location + range2.length)
        return max(0, end - start)
    }
    
    private func createCacheKey(text: String, language: Language) -> String {
        // Create a cache key that's efficient but reasonably unique
        let textHash = text.prefix(100).hashValue // Use first 100 chars for hash
        return "\(language.identifier)-\(textHash)-\(text.count)"
    }
    
    /// Register with memory monitor for cleanup
    private func registerWithMemoryMonitor() {
        Task { @MainActor in
            MemoryMonitor.shared.registerCleanupHandler(
                identifier: "background-syntax-highlighter",
                priority: .normal
            ) { @MainActor [weak self] in
                guard let self else {
                    return CleanupResult(memoryFreedMB: 0, description: "BackgroundSyntaxHighlighter deallocated")
                }
                
                // Cancel all operations
                self.operationQueue.cancelAllOperations()
                
                // Clear cache
                let beforeCacheSize = self.resultCache.count
                self.resultCache.removeAll()
                
                // Clear pending requests
                let beforePendingCount = self.pendingRequests.count
                self.pendingRequests.removeAll()
                
                // Reset statistics
                self.statistics.reset()
                
                // Estimate memory freed
                let estimatedMemoryMB = Double(beforeCacheSize + beforePendingCount) * 0.01 // 10KB per item estimate
                
                return CleanupResult(
                    memoryFreedMB: estimatedMemoryMB,
                    description: "Cleared \(beforeCacheSize) cached results and \(beforePendingCount) pending requests"
                )
            }
        }
    }
}

// MARK: - Supporting Types

/// Priority levels for highlighting requests
public enum HighlightingPriority: Int, CaseIterable, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}

/// Highlighting request data
public struct HighlightingRequest: Sendable {
    let id: String
    let text: String
    let language: Language
    let priority: HighlightingPriority
    let visibleRange: NSRange?
    let completion: BackgroundSyntaxHighlighter.HighlightingCompletion
    var operation: HighlightingOperation?
    
    var textRange: NSRange? {
        NSRange(location: 0, length: text.count)
    }
}

/// Cached highlighting result
public struct CachedHighlightResult: Sendable {
    let tokens: [HighlightedToken]
    let timestamp: Date
    let expirationTime: TimeInterval
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > expirationTime
    }
}

/// Background highlighting operation
public class HighlightingOperation: Operation, @unchecked Sendable {
    let text: String
    let language: Language
    let priority: HighlightingPriority
    
    private(set) var result: [HighlightedToken] = []
    
    init(text: String, language: Language, priority: HighlightingPriority) {
        self.text = text
        self.language = language
        self.priority = priority
        super.init()
        
        // Set operation priority
        switch priority {
        case .low:
            queuePriority = .low

        case .normal:
            queuePriority = .normal

        case .high:
            queuePriority = .high

        case .critical:
            queuePriority = .veryHigh
        }
    }
    
    override public func main() {
        guard !isCancelled else { return }
        
        // For now, create a simple highlighting result
        // In a full implementation, this would use a background-compatible highlighter
        result = createBasicHighlighting(for: text, language: language)
    }
    
    private func createBasicHighlighting(for text: String, language: Language) -> [HighlightedToken] {
        // Simple keyword-based highlighting that doesn't require MainActor
        var tokens: [HighlightedToken] = []
        
        let keywords: [String]
        switch language {
        case .swift:
            keywords = ["func", "var", "let", "class", "struct", "enum", "import", "if", "else", "for", "while", "return", "public", "private", "internal"]

        case .regex:
            keywords = ["function", "var", "const", "let", "if", "else", "for", "while", "return"]

        default:
            keywords = ["function", "var", "if", "else", "for", "while", "return"]
        }
        
        // swiftlint:disable:next legacy_objc_type
        let nsString = NSString(string: text)
        
        for keyword in keywords {
            var searchRange = NSRange(location: 0, length: nsString.length)
            
            while searchRange.location < nsString.length {
                let foundRange = nsString.range(of: keyword, options: [.caseInsensitive], range: searchRange)
                
                if foundRange.location == NSNotFound {
                    break
                }
                
                // Create a token for the keyword
                let token = HighlightedToken(
                    range: foundRange,
                    type: .keyword,
                    text: nsString.substring(with: foundRange)
                )
                tokens.append(token)
                
                // Update search range to continue after this match
                searchRange.location = foundRange.location + foundRange.length
                searchRange.length = nsString.length - searchRange.location
            }
        }
        
        return tokens
    }
    
    deinit {
        // Cleanup if needed
    }
}

/// Background highlighting statistics
@MainActor
public final class BackgroundHighlightingStatistics: ObservableObject {
    @Published public private(set) var totalRequests: Int = 0
    @Published public private(set) var completedRequests: Int = 0
    @Published public private(set) var cancelledRequests: Int = 0
    @Published public private(set) var errorRequests: Int = 0
    @Published public private(set) var cacheHits: Int = 0
    @Published public private(set) var cacheMisses: Int = 0
    @Published public private(set) var averageProcessingTime: TimeInterval = 0
    @Published public private(set) var averageTokensPerRequest: Double = 0
    @Published public private(set) var lastRequestTime: Date?
    @Published public private(set) var lastCompletionTime: Date?
    
    private var processingTimes: [TimeInterval] = []
    private var tokenCounts: [Int] = []
    private let maxSamples = 100
    
    public var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(completedRequests) / Double(totalRequests)
    }
    
    public var cacheHitRate: Double {
        let totalCacheRequests = cacheHits + cacheMisses
        guard totalCacheRequests > 0 else { return 0 }
        return Double(cacheHits) / Double(totalCacheRequests)
    }
    
    internal func recordRequest() {
        totalRequests += 1
        lastRequestTime = Date()
    }
    
    internal func recordCompletion(processingTime: TimeInterval, tokenCount: Int) {
        completedRequests += 1
        lastCompletionTime = Date()
        
        // Update processing time statistics
        processingTimes.append(processingTime)
        if processingTimes.count > maxSamples {
            processingTimes.removeFirst()
        }
        averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
        
        // Update token count statistics
        tokenCounts.append(tokenCount)
        if tokenCounts.count > maxSamples {
            tokenCounts.removeFirst()
        }
        averageTokensPerRequest = Double(tokenCounts.reduce(0, +)) / Double(tokenCounts.count)
    }
    
    internal func recordCancellation() {
        cancelledRequests += 1
    }
    
    internal func recordBulkCancellation(count: Int) {
        cancelledRequests += count
    }
    
    internal func recordError(processingTime: TimeInterval) {
        errorRequests += 1
        
        // Still record processing time for errors
        processingTimes.append(processingTime)
        if processingTimes.count > maxSamples {
            processingTimes.removeFirst()
        }
        averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
    }
    
    internal func recordCacheHit() {
        cacheHits += 1
    }
    
    internal func recordCacheMiss() {
        cacheMisses += 1
    }
    
    internal func recordCacheClear() {
        // Reset cache-related stats when cache is cleared
        cacheHits = 0
        cacheMisses = 0
    }
    
    public func reset() {
        totalRequests = 0
        completedRequests = 0
        cancelledRequests = 0
        errorRequests = 0
        cacheHits = 0
        cacheMisses = 0
        averageProcessingTime = 0
        averageTokensPerRequest = 0
        lastRequestTime = nil
        lastCompletionTime = nil
        processingTimes.removeAll()
        tokenCounts.removeAll()
    }
    
    deinit {
        // Cleanup if needed
    }
}

/// Background highlighting errors
public enum HighlightingError: Error, LocalizedError {
    case cancelled
    case timeout
    case invalidInput
    case processingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Highlighting operation was cancelled"

        case .timeout:
            return "Highlighting operation timed out"

        case .invalidInput:
            return "Invalid input provided for highlighting"

        case .processingFailed(let reason):
            return "Highlighting processing failed: \(reason)"
        }
    }
}
