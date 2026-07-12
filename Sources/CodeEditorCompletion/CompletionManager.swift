import CodeEditorCommon
import CodeEditorDiagnostics
import CodeEditorLanguages
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
    private let providerRegistry = CompletionProviderRegistry()
    private let requestCoordinator: CompletionRequestCoordinator
    private let cache: LRUCache<CompletionCacheKey, CachedCompletionResult>
    private let cacheExpirationTime: TimeInterval
    private let enableCaching: Bool
    private var memoryMonitor: MemoryMonitor
    private let cleanupIdentifier = "completion-manager-\(UUID().uuidString)"
    private let broadcaster: CompletionEventBroadcaster

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
        let broadcaster = CompletionEventBroadcaster()
        self.broadcaster = broadcaster
        self.requestCoordinator = CompletionRequestCoordinator(
            debouncer: debouncer ?? CompletionDebouncer(),
            eventSink: broadcaster
        )

        requestCoordinator.setDebouncedRequestHandler { [weak self] context in
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
        providerRegistry.register(provider)
    }

    /// Unregister a completion provider
    public func unregisterProvider(withId id: String) {
        providerRegistry.unregister(withId: id)
    }

    /// Ensures a `LanguageKeywordCompletionProvider` is registered for
    /// the given language. Idempotent. Sweeps any prior built-in for a
    /// different language, then registers the new one. Host-supplied
    /// providers at the canonical id win (collision check). Called by
    /// `CodeEditorView` on language change; safe to call from hosts
    /// using `CompletionManager` standalone.
    public func ensureBuiltInProvider(for language: Language) {
        providerRegistry.ensureBuiltInProvider(for: language)
    }

    /// Get all registered providers
    public var registeredProviders: [any CompletionProvider] {
        providerRegistry.registeredProviders
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
        // Capture for recordSelection scoping; cleared on cancel.
        lastContext = context

        // Check cache first if enabled
        if let cachedResult = getCachedResult(for: context) {
            return cachedResult
        }

        let providers = providerRegistry.applicableProviders(for: context.language)
        return try await requestCoordinator.request(
            providers: providers,
            context: context
        ) { [weak self] results, capturedContext, startTime in
            guard let self else {
                return CompletionResult(
                    items: [],
                    context: capturedContext,
                    isIncomplete: false,
                    processingTime: 0
                )
            }
            return self.processAndCacheResults(
                results,
                context: capturedContext,
                startTime: startTime
            )
        }
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

    private func processAndCacheResults(
        _ results: [CompletionResult],
        context: CompletionContextModel,
        startTime: Date
    ) -> CompletionResult {
        // Combine results
        let allItems = results.flatMap { $0.items }
        let isIncomplete = results.contains { $0.isIncomplete }
        let processingTime = Date().timeIntervalSince(startTime)

        // Apply the canonical six-tier rank (dedup + sort + maxCompletions cap).
        let sortedItems = rankCombined(allItems, context: context)

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
        requestCoordinator.requestDebounced(
            for: context,
            priority: priority
        ) { result in completion(result) }
    }

    /// Cancel any pending completion request
    public func cancelCurrentRequest() {
        requestCoordinator.cancelCurrentRequest()
        lastContext = nil
    }

    /// Access to the debouncer for configuration
    public var debouncingConfiguration: CompletionDebouncer {
        requestCoordinator.debouncingConfiguration
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

    // MARK: - Ranking

    /// Canonical six-tier sort applied to combined provider results.
    ///
    /// Tier order (each tier is a tiebreaker for the previous):
    /// 1. `sortText` ascending when both items have it; item-with-sortText
    ///    wins in mixed pairs; both-nil falls through.
    /// 2. `priority` descending.
    /// 3a. session-frequency descending (`usageCount`).
    /// 3b. recency descending (`lastUsed`) when frequencies tie.
    /// 4. `relevance(item:context:)` descending.
    /// 5. `kind.defaultPriority` descending.
    /// 6. `label.localizedCaseInsensitiveCompare` ascending.
    ///
    /// Dedup key is `"\(label):\(kind.rawValue)"` — kind-aware so
    /// `Float` (type) and `Float()` (initializer) both survive.
    private func rankCombined(
        _ items: [CompletionItemModel],
        context: CompletionContextModel
    ) -> [CompletionItemModel] {
        // Stage 1: dedup
        var seen = Set<String>()
        let unique = items.filter { item in
            let key = "\(item.label):\(item.kind.rawValue)"
            return seen.insert(key).inserted
        }

        // Stage 2: pre-compute the per-language frequency snapshot once.
        // Build both maps in a single walk — `usageCount` for tier 3a and
        // `lastUsed` for tier 3b (recency tiebreaker).
        //
        // Note: `LRUCache.get` promotes keys to MRU as a side effect. That's
        // fine here because we never use LRU position for ordering — `lastUsed`
        // captures recency explicitly. The promotion is harmless: it only
        // affects which key gets evicted next when the cache hits capacity.
        let prefix = "\(context.language.identifier):"
        var freq: [String: Int] = [:]
        var lastUsed: [String: Date] = [:]
        for key in frequencyCache.allKeys where key.hasPrefix(prefix) {
            guard let entry = frequencyCache.get(key) else { continue }
            let label = String(key.dropFirst(prefix.count))
            freq[label] = entry.usageCount
            lastUsed[label] = entry.lastUsed
        }

        // Stage 3: sort
        let sorted = unique.sorted { lhs, rhs in
            // 1. sortText asc — mixed pair: item with sortText wins.
            switch (lhs.sortText, rhs.sortText) {
            case let (lhsText?, rhsText?) where lhsText != rhsText:
                return lhsText < rhsText

            case (.some, .none):
                return true

            case (.none, .some):
                return false

            default:
                break
            }

            // 2. priority desc
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }

            // 3a. frequency desc
            let lhsFreq = freq[lhs.label] ?? 0
            let rhsFreq = freq[rhs.label] ?? 0
            if lhsFreq != rhsFreq {
                return lhsFreq > rhsFreq
            }

            // 3b. recency desc when frequencies tie (and at least one item
            // has been selected before). Items that have never been selected
            // are equal at this sub-tier and fall through to relevance.
            if let lhsDate = lastUsed[lhs.label], let rhsDate = lastUsed[rhs.label], lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            if lastUsed[lhs.label] != nil && lastUsed[rhs.label] == nil {
                return true
            }
            if lastUsed[lhs.label] == nil && lastUsed[rhs.label] != nil {
                return false
            }

            // 4. relevance desc — single source of truth in CompletionRankingModel.
            let lhsRelevance = CompletionRankingModel.calculateRelevance(item: lhs, context: context)
            let rhsRelevance = CompletionRankingModel.calculateRelevance(item: rhs, context: context)
            if lhsRelevance != rhsRelevance {
                return lhsRelevance > rhsRelevance
            }

            // 5. kind.defaultPriority desc
            if lhs.kind.defaultPriority != rhs.kind.defaultPriority {
                return lhs.kind.defaultPriority > rhs.kind.defaultPriority
            }

            // 6. label asc
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }

        // Stage 4: cap
        return Array(sorted.prefix(maxCompletions))
    }

    // MARK: - Test Hooks

    /// Internal test hook — exposes `rankCombined` so unit tests can
    /// exercise the sort key in isolation from the request pipeline.
    /// Not part of the public API.
    internal func testOnly_rankCombined(
        _ items: [CompletionItemModel],
        context: CompletionContextModel
    ) -> [CompletionItemModel] {
        rankCombined(items, context: context)
    }

    /// Internal test hook — seeds `lastContext` without going through
    /// `requestCompletions(for:)`. Lets learning tests drive the frequency
    /// cache deterministically.
    internal func testOnly_setLastContext(_ context: CompletionContextModel) {
        lastContext = context
    }

    // MARK: - Private Methods

    /// Register with memory monitor for cleanup
    private func registerWithMemoryMonitor() {
        memoryMonitor.registerCleanupHandler(
            identifier: cleanupIdentifier,
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

extension CompletionManager: MemoryMonitorUsing {
    public func setMemoryMonitor(_ monitor: MemoryMonitor) {
        guard monitor !== memoryMonitor else { return }

        memoryMonitor.unregisterCleanupHandler(identifier: cleanupIdentifier)
        memoryMonitor = monitor
        cache.setMemoryMonitor(monitor)
        frequencyCache.setMemoryMonitor(monitor)
        registerWithMemoryMonitor()
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

    /// Creates a fresh statistics tracker with all counters zeroed.
    public init() {}

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
