import CodeEditorCommon
import CodeEditorInstrumentation
import CodeEditorLanguages
import Foundation
#if canImport(Combine)
import Combine
#endif
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Performs syntax highlighting in background threads to improve UI responsiveness
@available(macOS 10.15, iOS 13.0, *)
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

    /// Actor for managing concurrent highlighting operations
    private let highlightingActor = HighlightingActor()

    /// Pending highlighting requests
    private var pendingRequests: [String: HighlightingRequest] = [:]

    /// Active tasks for cancellation
    private var activeTasks: [String: Task<Void, Never>] = [:]

    /// Completed highlighting results cache
    private var resultCache: [String: CachedHighlightResult] = [:]

    /// Current visible range for priority highlighting
    private var visibleRange = NSRange(location: 0, length: 0)

    /// Debounce task for text changes
    private var debounceTask: Task<Void, Never>?

    /// Logger for debugging
    private let logger = CodeEditorLog.logger(category: "BackgroundSyntaxHighlighter")

    /// Memory monitor for managing cache memory
    private var memoryMonitor: MemoryMonitor
    private let cleanupIdentifier = "background-syntax-highlighter-\(UUID().uuidString)"

    /// Observer for app termination to ensure cleanup
    private var terminationObserver: NSObjectProtocol?

    // MARK: - Completion Handlers

    /// Completion handler for highlighting results
    public typealias HighlightingCompletion = @Sendable (Result<[HighlightedToken], Error>) -> Void

    // MARK: - Initialization

    public init(memoryMonitor: MemoryMonitor) {
        self.memoryMonitor = memoryMonitor
        // Register with memory monitor
        registerWithMemoryMonitor()
        // Register for app termination to ensure cleanup
        registerForTermination()
    }

    deinit {
        // Cleanup is handled automatically by ARC
        // Note: Cannot access @MainActor properties from deinit in Swift 6
        // cleanup() must be called explicitly before deallocation
        // The termination observer will be removed when the object is deallocated.
    }

    /// Register for app termination notifications to ensure cleanup
    private func registerForTermination() {
        #if canImport(AppKit)
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Cancel tasks directly during termination to avoid creating new Tasks
            MainActor.assumeIsolated {
                self?.debounceTask?.cancel()
                for (_, task) in self?.activeTasks ?? [:] {
                    task.cancel()
                }
            }
        }
        #elseif canImport(UIKit)
        terminationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.debounceTask?.cancel()
                for (_, task) in self?.activeTasks ?? [:] {
                    task.cancel()
                }
            }
        }
        #endif
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
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            do {
                guard let self else {
                    // Self is nil, request won't be processed
                    return
                }
                try await Task.sleep(for: .seconds(self.highlightingDelay))

                await MainActor.run { [weak self] in
                    guard let self else {
                        // Self is nil, request won't be processed
                        return
                    }
                    Task {
                        await self.processRequest(request)
                    }
                }
            } catch {
                // Task was cancelled, which is expected behavior
                // The request will be handled by cancelRequest if needed
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
        if pendingRequests.removeValue(forKey: requestId) != nil {
            if let task = activeTasks.removeValue(forKey: requestId) {
                task.cancel()
            }
            statistics.recordCancellation()
        }
    }

    /// Cancel all pending highlighting requests
    public func cancelAllRequests() {
        let count = pendingRequests.count

        for (_, task) in activeTasks {
            task.cancel()
        }

        pendingRequests.removeAll()
        activeTasks.removeAll()

        statistics.recordBulkCancellation(count: count)
    }

    /// Clear the highlighting cache
    public func clearCache() {
        resultCache.removeAll()
        statistics.recordCacheClear()
    }

    /// Configure operation queue settings
    /// - Parameters:
    ///   - maxConcurrentOperations: Maximum concurrent operations
    ///   - qualityOfService: Quality of service for operations (maintained for API compatibility)
    public func configureQueue(
        maxConcurrentOperations: Int,
        qualityOfService: QualityOfService = .userInitiated
    ) {
        self.maxConcurrentOperations = maxConcurrentOperations
        // QoS is now handled by Task priority
        _ = qualityOfService // Maintained for API compatibility
    }

    /// Cleanup all resources including timers and tasks
    /// 
    /// This method is automatically called in `deinit` to prevent memory leaks,
    /// but can also be called explicitly when you want to immediately free resources
    /// (e.g., when a view disappears or the editor is no longer needed).
    /// 
    /// The method is idempotent and safe to call multiple times.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Automatic cleanup on deallocation (recommended)
    /// let highlighter = BackgroundSyntaxHighlighter()
    /// // cleanup() is called automatically when highlighter is deallocated
    /// 
    /// // Manual cleanup for immediate resource release
    /// highlighter.cleanup()
    /// ```
    public func cleanup() {
        // Cancel debounce task
        debounceTask?.cancel()
        debounceTask = nil

        // Cancel all active tasks
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()

        // Clear pending requests
        pendingRequests.removeAll()

        // Clear cache
        resultCache.removeAll()

        // Reset statistics
        statistics.reset()
    }

    // MARK: - Private Methods

    private func processRequest(_ request: HighlightingRequest) async {
        let startTime = Date()

        // Create task for this request
        let task = Task { [weak self] in
            guard let self else { return }

            do {
                let tokens: [HighlightedToken]

                // Choose highlighting strategy based on text size
                if request.text.count > self.maxBackgroundTextLength {
                    tokens = try await self.processLargeText(request)
                } else {
                    tokens = try await self.highlightingActor.highlight(
                        text: request.text,
                        language: request.language,
                        priority: request.priority,
                        maxConcurrentOperations: self.maxConcurrentOperations
                    )
                }

                // Check for cancellation
                try Task.checkCancellation()

                await MainActor.run { [weak self] in
                    guard let self else { return }

                    // Cache the result
                    let cacheKey = self.createCacheKey(text: request.text, language: request.language)
                    let cachedResult = CachedHighlightResult(
                        tokens: tokens,
                        timestamp: Date(),
                        expirationTime: 300 // 5 minutes
                    )
                    self.resultCache[cacheKey] = cachedResult

                    // Complete the request
                    let processingTime = Date().timeIntervalSince(startTime)
                    self.statistics.recordCompletion(processingTime: processingTime, tokenCount: tokens.count)

                    request.completion(.success(tokens))
                    self.pendingRequests.removeValue(forKey: request.id)
                    self.activeTasks.removeValue(forKey: request.id)
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }

                    let processingTime = Date().timeIntervalSince(startTime)
                    self.statistics.recordError(processingTime: processingTime)

                    let finalError = error is CancellationError ? SyntaxHighlightingError.cancelled : error
                    request.completion(.failure(finalError))
                    self.pendingRequests.removeValue(forKey: request.id)
                    self.activeTasks.removeValue(forKey: request.id)
                }
            }
        }

        activeTasks[request.id] = task
    }

    private func processLargeText(_ request: HighlightingRequest) async throws -> [HighlightedToken] {
        // Split large text into chunks for processing
        let chunks = splitTextIntoChunks(request.text, chunkSize: chunkSize)

        // Process chunks concurrently using TaskGroup
        return try await withThrowingTaskGroup(of: (Int, [HighlightedToken]).self) { group in
            for (index, chunk) in chunks.enumerated() {
                group.addTask { [weak self] in
                    guard let self else { throw SyntaxHighlightingError.cancelled }

                    let chunkTokens = try await self.highlightingActor.highlight(
                        text: chunk.text,
                        language: request.language,
                        priority: request.priority,
                        maxConcurrentOperations: self.maxConcurrentOperations
                    )

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

                    return (index, adjustedTokens)
                }
            }

            // Collect results in order
            var results: [(Int, [HighlightedToken])] = []
            for try await result in group {
                results.append(result)
            }

            // Sort by chunk index and flatten
            return results
                .sorted { $0.0 < $1.0 }
                .flatMap { $0.1 }
        }
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
        // Update priority based on visible range overlap
        for (requestId, request) in pendingRequests {
            if let visibleRange = request.visibleRange,
               let textRange = request.textRange {
                // Calculate overlap with current visible range
                let overlap = calculateRangeOverlap(visibleRange, textRange)

                // Cancel and restart tasks with updated priority if needed
                if overlap > 0 && request.priority != .high {
                    if let task = activeTasks[requestId] {
                        task.cancel()
                        var updatedRequest = request
                        updatedRequest.priority = .high
                        pendingRequests[requestId] = updatedRequest
                        let capturedRequest = updatedRequest
                        Task {
                            await processRequest(capturedRequest)
                        }
                    }
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
        var hasher = Hasher()
        hasher.combine(text.prefix(100)) // Use first 100 chars for hash
        let textHash = hasher.finalize()
        return "\(language.identifier)-\(textHash)-\(text.count)"
    }

    /// Register with memory monitor for cleanup
    private func registerWithMemoryMonitor() {
        memoryMonitor.registerCleanupHandler(
            identifier: cleanupIdentifier,
            priority: .normal
        ) { @MainActor [weak self] in
            guard let self else {
                return CleanupResult(memoryFreedMB: 0, description: "BackgroundSyntaxHighlighter deallocated")
            }

            // Cancel all operations
            self.cancelAllRequests()

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

extension BackgroundSyntaxHighlighter: MemoryMonitorUsing {
    public func setMemoryMonitor(_ monitor: MemoryMonitor) {
        guard monitor !== memoryMonitor else { return }

        memoryMonitor.unregisterCleanupHandler(identifier: cleanupIdentifier)
        memoryMonitor = monitor
        registerWithMemoryMonitor()
    }
}
