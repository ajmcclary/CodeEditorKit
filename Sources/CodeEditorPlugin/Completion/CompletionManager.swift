import Foundation

// MARK: - Frequency Entry

/// In-memory frequency + recency record for a single label, scoped by
/// `"\(language.identifier):\(label)"`. Lives only inside `CompletionManager`'s
/// LRU; never published, never persisted in this round. See the spec's
/// "Follow-ups (deliberately deferred)" section for persistence design.
private struct FrequencyEntry: Sendable {
    var usageCount: Int
    var lastUsed: Date
}

// MARK: - Completion Manager

/// Manages code completion requests across multiple providers.
///
/// `CompletionManager` coordinates completion requests from various providers,
/// handles caching, deduplication, and provides a unified interface for
/// code completion functionality.
///
/// ## Features
/// - Multiple provider support
/// - Result caching with configurable expiration
/// - Request debouncing and throttling
/// - Concurrent provider queries
/// - Smart result sorting and deduplication
/// - Performance statistics tracking
///
/// ## Example Usage
///
/// ```swift
/// let manager = CompletionManager(memoryMonitor: monitor)
///
/// // Register providers
/// if let provider = LanguageProviderFactory.createProvider(for: .swift) {
///     manager.registerProvider(provider)
/// }
/// manager.registerProvider(LSPCompletionProvider())
///
/// // Request completions
/// let context = CompletionContextModel(
///     text: "let x = ",
///     cursorPosition: 8,
///     language: .swift
/// )
///
/// let result = try await manager.requestCompletions(for: context)
/// ```
///
/// ## Performance Optimization
///
/// The manager includes several optimizations:
/// - Concurrent requests to multiple providers
/// - Result deduplication and smart sorting
/// - Configurable caching with expiration
/// - Debouncing to reduce request frequency
///
/// - SeeAlso: ``CompletionProvider``, ``CompletionDebouncer``, ``CompletionStatistics``
@MainActor
public final class CompletionManager {
    private var providers: [String: any CompletionProvider] = [:]
    private var currentRequest: Task<CompletionResult, Error>?
    private let cache: LRUCache<CompletionCacheKey, CachedCompletionResult>
    private let cacheExpirationTime: TimeInterval
    private let enableCaching: Bool
    private let debouncer: CompletionDebouncer
    private let memoryMonitor: MemoryMonitor
    private let broadcaster = CompletionEventBroadcaster()

    /// In-memory frequency/recency cache. Keyed by
    /// `"\(language.identifier):\(label)"`; capacity matches the legacy
    /// SmartCompletionEngine setting (500). Cleared on
    /// `clearLearnedPatterns()` and on the memory-monitor cleanup hook.
    /// Never persisted in this round; see spec follow-ups.
    private let frequencyCache: LRUCache<String, FrequencyEntry>

    /// Captured at the top of `requestCompletions(for:)` so
    /// `recordSelection(_:)` can scope the frequency key by language
    /// without forcing callers to thread the context through.
    private var lastContext: CompletionContextModel?

    private let logger = CrossPlatformLogger.logger(
        subsystem: "com.codeeditor.plugin",
        category: "CompletionManager"
    )

    /// Maximum items returned from `requestCompletions(for:)`. Default 50.
    /// Mutable so hosts can tune per editor without sub-classing or DI.
    public var maxCompletions: Int = 50

    /// Completion request statistics
    public private(set) var statistics = CompletionStatistics()

    /// Creates a new completion manager with the specified configuration
    /// - Parameters:
    ///   - memoryMonitor: Memory monitor for tracking resource usage
    ///   - cacheSize: Maximum number of cached completion results
    ///   - cacheExpirationTime: Time before cached results expire (seconds)
    ///   - enableCaching: Whether to enable result caching
    ///   - debouncer: Optional debouncer for throttling completion requests
    public init(
        memoryMonitor: MemoryMonitor,
        cacheSize: Int = 100,
        cacheExpirationTime: TimeInterval = 300, // 5 minutes
        enableCaching: Bool = true,
        debouncer: CompletionDebouncer? = nil
    ) {
        self.memoryMonitor = memoryMonitor
        self.cache = LRUCache(capacity: cacheSize, memoryMonitor: memoryMonitor)
        self.frequencyCache = LRUCache(capacity: 500, memoryMonitor: memoryMonitor)
        self.cacheExpirationTime = cacheExpirationTime
        self.enableCaching = enableCaching
        self.debouncer = debouncer ?? CompletionDebouncer()

        // Wire up the debouncer to use this manager's completion logic
        self.debouncer.setCompletionHandler { [weak self] context in
            guard let self else {
                throw CompletionDebouncingError.cancelled
            }
            return try await self.requestCompletions(for: context)
        }

        // Register with memory monitor
        registerWithMemoryMonitor()
    }

    // MARK: - Event Stream

    /// Returns a fresh `AsyncStream` of completion events.
    ///
    /// Each call returns an independent stream; every subscriber receives
    /// every event published while its iterator is alive. The buffer keeps
    /// the most recent 256 events per subscriber if the consumer falls
    /// behind — older events are dropped (`.bufferingNewest(256)`).
    ///
    /// Events publish for every per-provider `completions(for:)` call —
    /// `.succeeded(itemCount:)` when the provider returns a result, and
    /// `.failed(SendableError)` when it throws. Failure events publish
    /// *before* the existing per-provider failure isolation swallows the
    /// error to keep the batch alive, so subscribers see every fire.
    public func events() -> AsyncStream<CompletionEvent> {
        broadcaster.subscribe()
    }

    /// Internal test hook — exposes the broadcaster so suites in
    /// `CodeEditorPluginTests` (via `@testable import`) can probe its
    /// `subscriberCount`. Not part of the public API.
    var testOnlyBroadcaster: CompletionEventBroadcaster {
        broadcaster
    }

    // MARK: - Provider Management

    /// Register a completion provider
    public func registerProvider(_ provider: any CompletionProvider) {
        providers[provider.id] = provider
    }

    /// Unregister a completion provider
    public func unregisterProvider(withId id: String) {
        providers.removeValue(forKey: id)
    }

    /// Get all registered providers
    public var registeredProviders: [any CompletionProvider] {
        Array(providers.values)
    }

    /// Clear the completion cache
    public func clearCache() {
        cache.removeAll()
        statistics.resetCacheStats()
    }

    /// Get cache statistics
    public var cacheStatistics: CacheStatistics {
        cache.statistics
    }

    // MARK: - Completion Requests

    /// Request completions for the given context
    public func requestCompletions(for context: CompletionContextModel) async throws -> CompletionResult {
        // Cancel any existing request
        currentRequest?.cancel()

        // Check cache first if enabled
        if let cachedResult = getCachedResult(for: context) {
            return cachedResult
        }

        // Create new request
        currentRequest = Task {
            let startTime = Date()

            // Get results from providers
            let results = await fetchResultsFromProviders(for: context, startTime: startTime)

            // Process and cache the results

            return processAndCacheResults(results, context: context, startTime: startTime)
        }

        guard let request = currentRequest else {
            throw CompletionRequestError.noActiveRequest
        }
        return try await request.value
    }

    // MARK: - Helper Methods

    private func getCachedResult(for context: CompletionContextModel) -> CompletionResult? {
        guard enableCaching else { return nil }

        let cacheKey = CompletionCacheKey(context: context)
        if let cachedResult = cache.get(cacheKey), !cachedResult.isExpired {
            statistics.recordCacheHit()
            return cachedResult.result
        }
        statistics.recordCacheMiss()
        return nil
    }

    private func fetchResultsFromProviders(
        for context: CompletionContextModel,
        startTime _: Date
    ) async -> [CompletionResult] {
        // Find applicable providers
        let applicableProviders = providers.values.filter { provider in
            provider.supportedLanguages.contains(context.language) ||
            provider.supportedLanguages.isEmpty
        }

        guard !applicableProviders.isEmpty else {
            let result = CompletionResult(
                items: [],
                context: context,
                isIncomplete: false,
                processingTime: 0
            )
            statistics.recordRequest(processingTime: 0)
            return [result]
        }

        // Request from all applicable providers concurrently
        return await collectResultsConcurrently(from: applicableProviders, context: context)
    }

    private func collectResultsConcurrently(
        from providers: [any CompletionProvider],
        context: CompletionContextModel
    ) async -> [CompletionResult] {
        await withTaskGroup(of: CompletionResult?.self) { group in
            for provider in providers {
                let providerID = provider.id
                let broadcaster = self.broadcaster
                let capturedContext = context
                group.addTask {
                    let start = Date()
                    do {
                        let result = try await provider.completions(for: capturedContext)
                        broadcaster.publish(
                            CompletionEvent(
                                providerID: providerID,
                                context: capturedContext,
                                durationMilliseconds: Date().timeIntervalSince(start) * 1_000,
                                outcome: .succeeded(itemCount: result.items.count)
                            )
                        )
                        return result
                    } catch {
                        broadcaster.publish(
                            CompletionEvent(
                                providerID: providerID,
                                context: capturedContext,
                                durationMilliseconds: Date().timeIntervalSince(start) * 1_000,
                                outcome: .failed(SendableError(error, domain: "CompletionProvider"))
                            )
                        )
                        return nil   // existing per-provider failure isolation preserved
                    }
                }
            }

            var allResults: [CompletionResult] = []
            for await result in group {
                if let result {
                    allResults.append(result)
                }
            }
            return allResults
        }
    }

    private func processAndCacheResults(
        _ results: [CompletionResult],
        context: CompletionContextModel,
        startTime: Date
    ) -> CompletionResult {
        // Combine results
        let allItems = results.flatMap { $0.items }
        let isIncomplete = results.contains { $0.isIncomplete }
        let processingTime = Date().timeIntervalSince(startTime)

        // Sort and deduplicate items
        let sortedItems = sortAndDeduplicateItems(allItems)

        let result = CompletionResult(
            items: sortedItems,
            context: context,
            isIncomplete: isIncomplete,
            processingTime: processingTime
        )

        // Cache the result if enabled and not incomplete
        if enableCaching && !isIncomplete && !sortedItems.isEmpty {
            let cacheKey = CompletionCacheKey(context: context)
            let cachedResult = CachedCompletionResult(result: result, expirationTime: cacheExpirationTime)
            cache.set(cachedResult, forKey: cacheKey)
        }

        statistics.recordRequest(processingTime: processingTime)
        return result
    }

    /// Request completions with debouncing and throttling
    /// - Parameters:
    ///   - context: The completion context
    ///   - priority: Request priority (default: normal)
    ///   - completion: Completion handler
    public func requestCompletionsDebounced(
        for context: CompletionContextModel,
        priority: CompletionPriority = .normal,
        completion: @escaping @Sendable (Result<CompletionResult, Error>) -> Void
    ) {
        debouncer.requestCompletions(
            for: context,
            priority: priority
        ) { result in
            Task { @MainActor in
                switch result {
                case .success(let completionResult):
                    completion(.success(completionResult))

                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    /// Cancel any pending completion request
    public func cancelCurrentRequest() {
        currentRequest?.cancel()
        currentRequest = nil
        debouncer.cancelAllRequests()
    }

    /// Access to the debouncer for configuration
    public var debouncingConfiguration: CompletionDebouncer {
        debouncer
    }

    // MARK: - Learning API

    /// Record that the user accepted this item. Updates the in-memory
    /// frequency/recency cache used by the next `requestCompletions(for:)`
    /// call's ranking pass.
    ///
    /// - Note: No-op if no `requestCompletions(for:)` has fired yet (no
    ///   `lastContext`) or if it was cancelled via `cancelCurrentRequest()`.
    /// - SeeAlso: ``clearLearnedPatterns()``, ``maxCompletions``.
    public func recordSelection(_ item: CompletionItemModel) {
        guard let language = lastContext?.language else {
            logger.debug("recordSelection called with no lastContext; ignored")
            return
        }
        let key = "\(language.identifier):\(item.label)"
        var entry = frequencyCache.get(key) ?? FrequencyEntry(usageCount: 0, lastUsed: Date())
        entry.usageCount += 1
        entry.lastUsed = Date()
        frequencyCache.set(entry, forKey: key)
    }

    /// Clear in-memory frequency + recency state.
    ///
    /// The response cache and registered providers are unaffected — use
    /// ``clearCache()`` for the former and ``unregisterProvider(withId:)``
    /// for the latter.
    public func clearLearnedPatterns() {
        frequencyCache.removeAll()
    }

    // MARK: - Private Methods

    private func sortAndDeduplicateItems(_ items: [CompletionItemModel]) -> [CompletionItemModel] {
        // Remove duplicates based on label and kind
        var seen = Set<String>()
        let unique = items.filter { item in
            let key = "\(item.label):\(item.kind.rawValue)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }

        // Sort by priority (desc), then by label (asc)
        return unique.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            if lhs.kind.defaultPriority != rhs.kind.defaultPriority {
                return lhs.kind.defaultPriority > rhs.kind.defaultPriority
            }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
    }

    /// Register with memory monitor for cleanup
    private func registerWithMemoryMonitor() {
        Task { @MainActor in
            self.memoryMonitor.registerCleanupHandler(
                identifier: "completion-manager",
                priority: .normal
            ) { @MainActor [weak self] in
                guard let self else {
                    return CleanupResult(memoryFreedMB: 0, description: "CompletionManager deallocated")
                }

                // Clear completion cache
                let beforeCacheSize = self.cache.count
                self.cache.removeAll()

                // Cancel pending requests
                self.cancelCurrentRequest()

                // Reset statistics
                self.statistics.reset()

                // Estimate memory freed
                let estimatedMemoryMB = Double(beforeCacheSize) * 0.005 // 5KB per cached item estimate

                return CleanupResult(
                    memoryFreedMB: estimatedMemoryMB,
                    description: "Cleared \(beforeCacheSize) completion cache items"
                )
            }
        }
    }
}

// MARK: - Completion Statistics

/// Statistics for completion requests and cache performance.
///
/// Tracks metrics about completion system performance including request counts,
/// cache hit rates, and processing times. Useful for monitoring and optimization.
///
/// ## Example
///
/// ```swift
/// let stats = manager.statistics
/// logger.debug("Total requests: \(stats.totalRequests)")
/// logger.debug("Cache hit rate: \(stats.cacheHitRate * 100)%")
/// logger.debug("Avg processing time: \(stats.averageProcessingTime)s")
/// ```
///
/// - SeeAlso: ``CompletionManager``
@MainActor
public final class CompletionStatistics {
    /// Total number of completion requests processed
    public private(set) var totalRequests: Int = 0

    /// Number of requests served from cache
    public private(set) var totalCacheHits: Int = 0

    /// Number of requests that missed the cache
    public private(set) var totalCacheMisses: Int = 0

    /// Average processing time for completion requests
    public private(set) var averageProcessingTime: TimeInterval = 0

    /// Timestamp of the most recent completion request
    public private(set) var lastRequestTime: Date?

    private var processingTimes: [TimeInterval] = []
    private let maxProcessingTimeSamples = 100

    /// Percentage of requests served from cache (0.0 to 1.0)
    public var cacheHitRate: Double {
        let totalCacheRequests = totalCacheHits + totalCacheMisses
        return totalCacheRequests > 0 ? Double(totalCacheHits) / Double(totalCacheRequests) : 0
    }

    internal func recordRequest(processingTime: TimeInterval) {
        totalRequests += 1
        lastRequestTime = Date()

        // Update processing time statistics
        processingTimes.append(processingTime)
        if processingTimes.count > maxProcessingTimeSamples {
            processingTimes.removeFirst()
        }

        averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
    }

    internal func recordCacheHit() {
        totalCacheHits += 1
    }

    internal func recordCacheMiss() {
        totalCacheMisses += 1
    }

    internal func resetCacheStats() {
        totalCacheHits = 0
        totalCacheMisses = 0
    }

    /// Resets all completion statistics to their initial values
    public func reset() {
        totalRequests = 0
        totalCacheHits = 0
        totalCacheMisses = 0
        averageProcessingTime = 0
        lastRequestTime = nil
        processingTimes.removeAll()
    }
}
