import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Asynchronous syntax highlighter with debouncing and cancellation support
@MainActor
public final class AsyncSyntaxHighlighter {
    // MARK: - Properties
    
    private let coordinator: SyntaxHighlightingCoordinator
    private let backgroundHighlighter: BackgroundSyntaxHighlighter
    private var highlightingTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var periodicOptimizationTask: Task<Void, Never>?
    private let debounceInterval: Duration
    private let performanceMonitor = SyntaxHighlightingPerformanceMonitor()
    
    // Smart cache for highlight results
    private var tokenCache = SmartTokenCache()
    
    // Enable background highlighting for large files
    public var enableBackgroundHighlighting: Bool = true
    
    // File size threshold for background highlighting
    public var backgroundHighlightingThreshold: Int = 10_000
    
    // Memory monitor for managing cache memory
    private let memoryMonitor: MemoryMonitor
    
    // MARK: - Initialization
    
    public init(memoryMonitor: MemoryMonitor, debounceInterval: Duration = .milliseconds(300)) {
        self.coordinator = SyntaxHighlightingCoordinator()
        self.backgroundHighlighter = BackgroundSyntaxHighlighter(memoryMonitor: memoryMonitor)
        self.debounceInterval = debounceInterval
        self.memoryMonitor = memoryMonitor
        
        // Set up periodic cache optimization
        setupPeriodicCacheOptimization()
        
        // Register cache with memory monitor
        registerCacheWithMemoryMonitor()
    }
    
    // MARK: - Public Methods
    
    /// Schedule highlighting with debouncing
    public func scheduleHighlighting(
        for textView: CodeEditorView,
        language: Language,
        visibleRange: NSRange? = nil
    ) {
        // Cancel any pending debounce task
        debounceTask?.cancel()
        
        // Schedule new highlighting
        debounceTask = Task { [weak self] in
            do {
                guard let self else { return }
                try await Task.sleep(for: self.debounceInterval)
                
                // Perform highlighting directly without nested tasks
                await self.performHighlighting(for: textView, language: language, visibleRange: visibleRange)
            } catch {
                // Task was cancelled, which is expected behavior
            }
        }
    }
    
    /// Perform highlighting immediately (cancels any pending operations)
    public func highlightImmediately(
        for textView: CodeEditorView,
        language: Language,
        visibleRange: NSRange? = nil
    ) async {
        // Cancel debounce task
        debounceTask?.cancel()
        debounceTask = nil
        
        await performHighlighting(for: textView, language: language, visibleRange: visibleRange)
    }
    
    /// Cancel all pending highlighting operations
    public func cancelAllHighlighting() {
        debounceTask?.cancel()
        debounceTask = nil
        highlightingTask?.cancel()
        highlightingTask = nil
        backgroundHighlighter.cancelAllRequests()
    }
    
    /// Update visible range for priority highlighting
    public func updateVisibleRange(_ range: NSRange) {
        backgroundHighlighter.updateVisibleRange(range)
    }
    
    /// Get background highlighting statistics
    public var backgroundStatistics: BackgroundHighlightingStatistics {
        backgroundHighlighter.statistics
    }
    
    /// Get cache statistics
    public func getCacheStatistics() async -> TokenCacheStatistics {
        await tokenCache.getStatistics()
    }
    
    /// Optimize cache performance by removing stale entries
    public func optimizeCache() async {
        await tokenCache.optimizeCache()
    }
    
    /// Configure cache settings
    public func configureCacheSettings(
        maxCacheSize: Int? = nil,
        maxMemoryUsageMB: Double? = nil,
        staleThreshold: Duration? = nil
    ) async {
        await tokenCache.configureCacheSettings(
            maxCacheSize: maxCacheSize,
            maxMemoryUsageMB: maxMemoryUsageMB,
            staleThreshold: staleThreshold
        )
    }
    
    // MARK: - Private Methods
    
    private func performHighlighting(
        for textView: CodeEditorView,
        language: Language,
        visibleRange: NSRange? = nil
    ) async {
        // Cancel any existing highlighting task
        highlightingTask?.cancel()
        
        // Get the text content
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            let text = textView.string
        #else
            let text = textView.text ?? ""
        #endif
        let textLength = text.count
        
        // Check performance limits
        guard textLength <= textView.configuration.performance.maxSyntaxHighlightingLength else {
            // File too large for syntax highlighting
            clearHighlighting(for: textView)
            return
        }
        
        // Create cache key
        let cacheKey = SmartTokenCache.CacheKey(
            text: text,
            language: language,
            version: 0 // Version tracking for future use
        )
        
        // Check cache first
        let cachedTokens = await tokenCache.getCachedTokens(for: cacheKey)
        if !cachedTokens.isEmpty {
            applyTokens(cachedTokens, to: textView, visibleRange: visibleRange)
            return
        }
        
        // Start new highlighting task
        highlightingTask = Task { [weak self] in
            guard let self else { return }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            await performanceMonitor.measure(category: .syntaxHighlighting) {
                // Choose highlighting strategy based on text size and settings
                var tokens: [HighlightedToken]
                
                if self.enableBackgroundHighlighting && textLength > self.backgroundHighlightingThreshold {
                    // Use background highlighter for large files
                    tokens = await self.highlightWithBackgroundHighlighter(
                        text: text, 
                        language: language, 
                        visibleRange: visibleRange
                    )
                    
                    // If background highlighting failed (returned empty), fall back to synchronous
                    if tokens.isEmpty {
                        tokens = await self.highlightInBackground(text: text, language: language)
                    }
                } else {
                    // Use synchronous highlighting for small files
                    tokens = await self.highlightInBackground(text: text, language: language)
                }
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                // Cache the results with performance metrics
                let endTime = CFAbsoluteTimeGetCurrent()
                let computationTime = Duration.seconds(endTime - startTime)
                await self.tokenCache.setCachedTokens(tokens, for: cacheKey, computationTime: computationTime)
                
                // Apply tokens on main thread
                await MainActor.run {
                    self.applyTokens(tokens, to: textView, visibleRange: visibleRange)
                }
            }
        }
    }
    
    @MainActor
    private func highlightInBackground(text: String, language: Language) async -> [HighlightedToken] {
        coordinator.highlight(source: text, language: language)
    }
    
    private func highlightWithBackgroundHighlighter(
        text: String,
        language: Language,
        visibleRange: NSRange?
    ) async -> [HighlightedToken] {
        let requestId = UUID().uuidString
        
        // Update visible range for priority highlighting
        if let visibleRange {
            backgroundHighlighter.updateVisibleRange(visibleRange)
        }
        
        // Request background highlighting with high priority for visible content
        let priority: HighlightingPriority = visibleRange != nil ? .high : .normal
        
        // Use withTaskCancellationHandler and withCheckedContinuation together properly
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                backgroundHighlighter.requestHighlighting(
                    text: text,
                    language: language,
                    requestId: requestId,
                    priority: priority
                ) { result in
                    switch result {
                    case .success(let tokens):
                        continuation.resume(returning: tokens)
                        
                    case .failure:
                        // For any error, return empty array instead of throwing
                        continuation.resume(returning: [])
                    }
                }
            }
        } onCancel: {
            // Cancel the background highlighting request if the task is cancelled
            Task { @MainActor in
                backgroundHighlighter.cancelRequest(requestId)
            }
        }
    }
    
    private func applyTokens(
        _ tokens: [HighlightedToken],
        to textView: CodeEditorView,
        visibleRange: NSRange? = nil
    ) {
        // Get text storage - works for both TextKit1 and TextKit2
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let textStorage = textView.textStorage else { return }
        #else
        let textStorage = textView.textStorage
        #endif
        
        // Determine range to apply
        let rangeToHighlight = visibleRange ?? NSRange(location: 0, length: textStorage.length)
        
        // Validate range
        guard rangeToHighlight.location >= 0,
              rangeToHighlight.location + rangeToHighlight.length <= textStorage.length else {
            CrossPlatformLogger.logger().warning("Invalid range for highlighting: \(rangeToHighlight) with text length: \(textStorage.length)")
            return
        }
        
        // Update text storage efficiently with both TextKit1 and TextKit2 support
        textStorage.beginEditing()
        
        // First, apply base text color to the entire range
        let baseTextColor = textView.textColor ?? PlatformColors.label
        textStorage.addAttribute(.foregroundColor, value: baseTextColor, range: rangeToHighlight)
        
        // Apply new highlighting - batch tokens by color for performance
        var tokensByColor: [PlatformColor: [NSRange]] = [:]
        
        for token in tokens {
            // Prevent out-of-bounds NSRange crashes, required for stability:
            // Validate that token.range.location and length are within textStorage bounds
            guard
                token.range.location >= 0,
                token.range.length > 0,
                token.range.location < textStorage.length,
                token.range.location + token.range.length <= textStorage.length
            else {
                continue
            }
            
            // Group tokens by color
            let tokenColor = token.type.adaptiveColor
            tokensByColor[tokenColor, default: []].append(token.range)
        }
        
        // Apply each color group in a single operation for better performance
        for (color, ranges) in tokensByColor {
            // Merge adjacent or overlapping ranges for even better performance
            let mergedRanges = mergeAdjacentRanges(ranges)
            for range in mergedRanges {
                textStorage.addAttribute(.foregroundColor, value: color, range: range)
            }
        }
        
        textStorage.endEditing()
    }
    
    private func clearHighlighting(for textView: CodeEditorView) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let textStorage = textView.textStorage else { return }
        #else
        let textStorage = textView.textStorage
        #endif
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            let range = NSRange(location: 0, length: textView.string.count)
        #else
            let range = NSRange(location: 0, length: textView.text?.count ?? 0)
        #endif
        
        textStorage.beginEditing()
        
        // Instead of removing the color, reset to the base text color
        let baseTextColor = textView.textColor ?? PlatformColors.label
        textStorage.addAttribute(.foregroundColor, value: baseTextColor, range: range)
        
        textStorage.endEditing()
    }
    
    /// Merge adjacent or overlapping ranges for more efficient attribute application
    private func mergeAdjacentRanges(_ ranges: [NSRange]) -> [NSRange] {
        guard !ranges.isEmpty else { return [] }
        
        // Sort ranges by location
        let sorted = ranges.sorted { $0.location < $1.location }
        var merged: [NSRange] = []
        var current = sorted[0]
        
        for index in 1..<sorted.count {
            let next = sorted[index]
            
            // Check if ranges are adjacent or overlapping
            if current.location + current.length >= next.location {
                // Merge ranges
                let endLocation = max(current.location + current.length, next.location + next.length)
                current = NSRange(location: current.location, length: endLocation - current.location)
            } else {
                // Ranges are not adjacent, add current to result
                merged.append(current)
                current = next
            }
        }
        
        // Don't forget the last range
        merged.append(current)
        return merged
    }
    
    /// Clean up resources before deinitialization
    public func cleanup() {
        debounceTask?.cancel()
        debounceTask = nil
        periodicOptimizationTask?.cancel()
        periodicOptimizationTask = nil
        highlightingTask?.cancel()
        highlightingTask = nil
    }
    
    deinit {
        // Timer cleanup is handled in the cleanup() method which should be called before deallocation
        // The @MainActor isolated properties can't be accessed directly in deinit
    }
    
    // MARK: - Cache Management
    
    private func setupPeriodicCacheOptimization() {
        // Set up task to periodically optimize cache (every 5 minutes)
        periodicOptimizationTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(300)) // 5 minutes
                    
                    // Optimize cache directly without nested tasks
                    await self?.optimizeCache()
                } catch {
                    // Task was cancelled
                    break
                }
            }
        }
    }
    
    private func registerCacheWithMemoryMonitor() {
        Task { @MainActor in
            self.memoryMonitor.registerCleanupHandler(
                identifier: "async-syntax-highlighter-cache",
                priority: .normal
            ) { @MainActor [weak self] in
                guard let self else {
                    return CleanupResult(memoryFreedMB: 0, description: "AsyncSyntaxHighlighter deallocated")
                }
                
                // Get cache stats before cleanup
                let stats = await self.tokenCache.getStatistics()
                let beforeMemoryMB = stats.estimatedMemoryMB
                
                // Clear the cache
                await self.tokenCache.clearCache()
                
                return CleanupResult(
                    memoryFreedMB: beforeMemoryMB,
                    description: "Cleared syntax highlighting cache: \\(stats.cacheSize) entries"
                )
            }
        }
    }
}

// MARK: - Token Cache

/// Smart cache for syntax highlighting tokens with intelligent eviction strategies
actor SmartTokenCache {
    struct CacheKey: Hashable {
        let textHash: Int
        let textLength: Int
        let language: Language
        let version: Int
        
        init(text: String, language: Language, version: Int) {
            // Create efficient hash without storing full text
            var hasher = Hasher()
            hasher.combine(text.count)
            hasher.combine(language)
            hasher.combine(version)
            
            // Hash strategic characters for better distribution
            if let first = text.first {
                hasher.combine(first)
                if text.count > 1, let last = text.last {
                    hasher.combine(last)
                }
                
                // Hash middle character for longer texts
                if text.count > 100 {
                    let midIndex = text.index(text.startIndex, offsetBy: text.count / 2)
                    hasher.combine(text[midIndex])
                }
                
                // For very large files, hash a few more strategic points
                if text.count > 10_000 {
                    let quarterIndex = text.index(text.startIndex, offsetBy: text.count / 4)
                    let threeQuarterIndex = text.index(text.startIndex, offsetBy: (text.count * 3) / 4)
                    hasher.combine(text[quarterIndex])
                    hasher.combine(text[threeQuarterIndex])
                }
            }
            
            self.textHash = hasher.finalize()
            self.textLength = text.count
            self.language = language
            self.version = version
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(textHash)
            hasher.combine(textLength)
            hasher.combine(language)
            hasher.combine(version)
        }
    }
    
    struct CacheEntry {
        let tokens: [HighlightedToken]
        let timestamp: Date
        let accessCount: Int
        let computationTime: Duration
        let textLength: Int
        
        var score: Double {
            // Calculate cache value score based on multiple factors
            let ageInSeconds = Date.now.timeIntervalSince(timestamp)
            let ageFactor = 1.0 / (ageInSeconds + 1.0)
            let accessFactor = Double(accessCount)
            let sizeFactor = Double(textLength) / 10_000.0 // Favor larger files
            let computationFactor = computationTime.timeInterval * 10.0 // Favor expensive computations
            
            return ageFactor * 0.3 + accessFactor * 0.3 + sizeFactor * 0.2 + computationFactor * 0.2
        }
    }
    
    // MARK: - Configuration
    
    /// Maximum number of cache entries
    var maxCacheSize: Int = 50
    
    /// Maximum memory usage in MB (approximate)
    var maxMemoryUsageMB: Double = 100.0
    
    /// Time threshold for considering entries stale (in seconds)
    var staleThreshold: Duration = .seconds(3_600) // 1 hour
    
    /// Minimum computation time to cache (avoid caching trivial computations)
    var minComputationTimeToCache: Duration = .milliseconds(10)
    
    // MARK: - State
    
    private var cache: [CacheKey: CacheEntry] = [:]
    private var accessOrder: [CacheKey] = []
    private var hitCount: Int = 0
    private var missCount: Int = 0
    private var evictionCount: Int = 0
    
    // MARK: - Public Methods
    
    func getCachedTokens(for key: CacheKey) -> [HighlightedToken] {
        if var entry = cache[key] {
            // Check if entry is stale
            let age = Duration.seconds(Date.now.timeIntervalSince(entry.timestamp))
            if age > staleThreshold {
                // Remove stale entry
                cache.removeValue(forKey: key)
                accessOrder.removeAll { $0 == key }
                missCount += 1
                return []
            }
            
            // Update access count and order
            entry = CacheEntry(
                tokens: entry.tokens,
                timestamp: entry.timestamp,
                accessCount: entry.accessCount + 1,
                computationTime: entry.computationTime,
                textLength: entry.textLength
            )
            cache[key] = entry
            
            // Move to end of access order
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
            
            hitCount += 1
            return entry.tokens
        }
        
        missCount += 1
        return []
    }
    
    func setCachedTokens(
        _ tokens: [HighlightedToken], 
        for key: CacheKey, 
        computationTime: Duration
    ) {
        // Don't cache trivial computations
        guard computationTime >= minComputationTimeToCache else { return }
        
        let entry = CacheEntry(
            tokens: tokens,
            timestamp: Date(),
            accessCount: 1,
            computationTime: computationTime,
            textLength: key.textLength
        )
        
        cache[key] = entry
        accessOrder.append(key)
        
        // Evict if necessary
        evictIfNeeded()
    }
    
    func clearCache() {
        cache.removeAll()
        accessOrder.removeAll()
        hitCount = 0
        missCount = 0
        evictionCount = 0
    }
    
    func getStatistics() -> TokenCacheStatistics {
        let totalRequests = hitCount + missCount
        let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0
        let estimatedMemoryMB = estimateMemoryUsage()
        
        return TokenCacheStatistics(
            hitCount: hitCount,
            missCount: missCount,
            totalRequests: totalRequests,
            hitRate: hitRate,
            cacheSize: cache.count,
            evictionCount: evictionCount,
            estimatedMemoryMB: estimatedMemoryMB
        )
    }
    
    func optimizeCache() {
        // Remove stale entries
        let staleKeys = cache.compactMap { key, entry in
            let age = Duration.seconds(Date.now.timeIntervalSince(entry.timestamp))
            return age > staleThreshold ? key : nil
        }
        
        for key in staleKeys {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            evictionCount += 1
        }
        
        // Evict low-value entries if over memory limit
        evictIfNeeded()
    }
    
    func configureCacheSettings(
        maxCacheSize: Int? = nil,
        maxMemoryUsageMB: Double? = nil,
        staleThreshold: Duration? = nil
    ) {
        if let maxCacheSize {
            self.maxCacheSize = maxCacheSize
        }
        if let maxMemoryUsageMB {
            self.maxMemoryUsageMB = maxMemoryUsageMB
        }
        if let staleThreshold {
            self.staleThreshold = staleThreshold
        }
        
        // Re-optimize after configuration changes
        evictIfNeeded()
    }
    
    // MARK: - Private Methods
    
    private func evictIfNeeded() {
        // Evict based on memory usage
        while estimateMemoryUsage() > maxMemoryUsageMB && !cache.isEmpty {
            evictLeastValuableEntry()
        }
        
        // Evict based on cache size
        while cache.count > maxCacheSize && !cache.isEmpty {
            evictLeastValuableEntry()
        }
    }
    
    private func evictLeastValuableEntry() {
        // Find the entry with the lowest value score
        let sortedEntries = cache.sorted { $0.value.score < $1.value.score }
        
        if let leastValuable = sortedEntries.first {
            cache.removeValue(forKey: leastValuable.key)
            accessOrder.removeAll { $0 == leastValuable.key }
            evictionCount += 1
        }
    }
    
    private func estimateMemoryUsage() -> Double {
        // Rough estimate: each token takes ~100 bytes, plus overhead
        let totalTokens = cache.values.reduce(0) { $0 + $1.tokens.count }
        let tokenMemoryMB = Double(totalTokens) * 100.0 / (1_024.0 * 1_024.0)
        
        // Add overhead for strings and structures (rough estimate)
        let overheadMB = Double(cache.count) * 0.1 // 100KB per entry overhead
        
        return tokenMemoryMB + overheadMB
    }
}

/// Token cache performance statistics
public struct TokenCacheStatistics: Sendable {
    public let hitCount: Int
    public let missCount: Int
    public let totalRequests: Int
    public let hitRate: Double
    public let cacheSize: Int
    public let evictionCount: Int
    public let estimatedMemoryMB: Double
    
    public var summary: String {
        """
        Cache Statistics:
        - Hit Rate: \(String(format: "%.1f", hitRate * 100))%
        - Total Requests: \(totalRequests) (Hits: \(hitCount), Misses: \(missCount))
        - Cache Size: \(cacheSize) entries
        - Evictions: \(evictionCount)
        - Memory Usage: \(String(format: "%.1f", estimatedMemoryMB))MB
        """
    }
}

// MARK: - Performance Monitor

/// Simple performance monitoring for syntax highlighting
@MainActor
final class SyntaxHighlightingPerformanceMonitor {
    enum Category: String {
        case syntaxHighlighting = "SyntaxHighlighting"
        case tokenApplication = "TokenApplication"
        case cacheOperation = "CacheOperation"
    }
    
    private var metrics: [Category: [Duration]] = [:]
    private let metricsLimit = 100
    
    func measure<T>(
        category: Category,
        operation: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = Duration.seconds(CFAbsoluteTimeGetCurrent() - startTime)
            recordMetric(category: category, duration: duration)
        }
        return try await operation()
    }
    
    private func recordMetric(category: Category, duration: Duration) {
        var categoryMetrics = metrics[category] ?? []
        categoryMetrics.append(duration)
        
        // Keep only recent metrics
        if categoryMetrics.count > metricsLimit {
            categoryMetrics.removeFirst()
        }
        
        metrics[category] = categoryMetrics
        
        // Log slow operations
        if duration > .milliseconds(100) {
            CrossPlatformLogger.logger().debug("⚠️ Slow \(category.rawValue): \(String(format: "%.3f", duration.timeInterval))s")
        }
    }
    
    func getAverageTime(for category: Category) -> Duration? {
        guard let categoryMetrics = metrics[category], !categoryMetrics.isEmpty else {
            return nil
        }
        // Sum all durations and divide by count
        let totalSeconds = categoryMetrics.reduce(0.0) { sum, duration in
            sum + duration.timeInterval
        }
        return Duration.seconds(totalSeconds / Double(categoryMetrics.count))
    }
    
    func reset() {
        metrics.removeAll()
    }
}
