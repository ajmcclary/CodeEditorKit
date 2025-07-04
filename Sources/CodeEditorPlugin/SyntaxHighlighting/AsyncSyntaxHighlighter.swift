import Foundation
import os.log
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

private let kLogger = Logger(subsystem: "com.codeeditor.syntaxhighlighting", category: "AsyncSyntaxHighlighter")

/// Asynchronous syntax highlighter with debouncing and cancellation support
@MainActor
public final class AsyncSyntaxHighlighter {
    // MARK: - Properties
    
    private let coordinator: SyntaxHighlightingCoordinator
    private let backgroundHighlighter: BackgroundSyntaxHighlighter
    private var highlightingTask: Task<Void, Never>?
    private var debounceTimer: Timer?
    private var periodicOptimizationTimer: Timer?
    private let debounceInterval: TimeInterval
    private let performanceMonitor = SyntaxHighlightingPerformanceMonitor()
    
    // Smart cache for highlight results
    private var tokenCache = SmartTokenCache()
    
    // Enable background highlighting for large files
    public var enableBackgroundHighlighting: Bool = true
    
    // File size threshold for background highlighting
    public var backgroundHighlightingThreshold: Int = 10_000
    
    // MARK: - Initialization
    
    public init(debounceInterval: TimeInterval = 0.3) {
        self.coordinator = SyntaxHighlightingCoordinator()
        self.backgroundHighlighter = BackgroundSyntaxHighlighter()
        self.debounceInterval = debounceInterval
        
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
        // Cancel any pending debounce timer
        debounceTimer?.invalidate()
        
        // Schedule new highlighting
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.performHighlighting(for: textView, language: language, visibleRange: visibleRange)
            }
        }
    }
    
    /// Perform highlighting immediately (cancels any pending operations)
    public func highlightImmediately(
        for textView: CodeEditorView,
        language: Language,
        visibleRange: NSRange? = nil
    ) async {
        // Cancel debounce timer
        debounceTimer?.invalidate()
        debounceTimer = nil
        
        await performHighlighting(for: textView, language: language, visibleRange: visibleRange)
    }
    
    /// Cancel all pending highlighting operations
    public func cancelAllHighlighting() {
        debounceTimer?.invalidate()
        debounceTimer = nil
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
        staleThreshold: TimeInterval? = nil
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
                let tokens: [HighlightedToken]
                
                if self.enableBackgroundHighlighting && textLength > self.backgroundHighlightingThreshold {
                    // Use background highlighter for large files
                    tokens = await self.highlightWithBackgroundHighlighter(
                        text: text, 
                        language: language, 
                        visibleRange: visibleRange
                    )
                } else {
                    // Use synchronous highlighting for small files
                    tokens = await self.highlightInBackground(text: text, language: language)
                }
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                // Cache the results with performance metrics
                let endTime = CFAbsoluteTimeGetCurrent()
                let computationTime = endTime - startTime
                await self.tokenCache.setCachedTokens(tokens, for: cacheKey, computationTime: computationTime)
                
                // Apply tokens on main thread
                await MainActor.run {
                    self.applyTokens(tokens, to: textView, visibleRange: visibleRange)
                }
            }
        }
    }
    
    private func highlightInBackground(text: String, language: Language) async -> [HighlightedToken] {
        await Task { @MainActor [weak self] in
            guard let self else { return [] }
            return self.coordinator.highlight(source: text, language: language)
        }.value
    }
    
    private func highlightWithBackgroundHighlighter(
        text: String,
        language: Language,
        visibleRange: NSRange?
    ) async -> [HighlightedToken] {
        await withCheckedContinuation { continuation in
            let requestId = UUID().uuidString
            
            // Update visible range for priority highlighting
            if let visibleRange {
                backgroundHighlighter.updateVisibleRange(visibleRange)
            }
            
            // Request background highlighting with high priority for visible content
            let priority: HighlightingPriority = visibleRange != nil ? .high : .normal
            
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
                    // Fallback to synchronous highlighting on error
                    Task {
                        let fallbackTokens = await self.highlightInBackground(text: text, language: language)
                        continuation.resume(returning: fallbackTokens)
                    }
                }
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
        let rangeToHighlight = visibleRange ?? NSRange(location: 0, length: {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                return textView.string.count
            #else
                return textView.text?.count ?? 0
            #endif
        }())
        
        // Update text storage efficiently with both TextKit1 and TextKit2 support
        textStorage.beginEditing()
        
        // First, apply base text color to the entire range
        let baseTextColor = textView.textColor ?? PlatformColors.label
        textStorage.addAttribute(.foregroundColor, value: baseTextColor, range: rangeToHighlight)
        
        // Apply new highlighting
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
            
            // Apply color using platform abstraction for all platforms including Catalyst
            let tokenColor = token.type.adaptiveColor
            textStorage.addAttribute(.foregroundColor, value: tokenColor, range: token.range)
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
    
    /// Clean up resources before deinitialization
    public func cleanup() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        periodicOptimizationTimer?.invalidate()
        periodicOptimizationTimer = nil
        highlightingTask?.cancel()
        highlightingTask = nil
    }
    
    deinit {
        // Timer cleanup is handled in the cleanup() method which should be called before deallocation
        // The @MainActor isolated properties can't be accessed directly in deinit
    }
    
    // MARK: - Cache Management
    
    private func setupPeriodicCacheOptimization() {
        // Set up timer to periodically optimize cache (every 5 minutes)
        periodicOptimizationTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.optimizeCache()
            }
        }
    }
    
    private func registerCacheWithMemoryMonitor() {
        Task { @MainActor in
            MemoryMonitor.shared.registerCleanupHandler(
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
        let text: String
        let language: Language
        let version: Int
        
        func hash(into hasher: inout Hasher) {
            // Optimized hashing without substring allocations
            hasher.combine(text.count)
            hasher.combine(language)
            hasher.combine(version)
            
            // Hash first and last characters instead of creating substrings
            if !text.isEmpty {
                hasher.combine(text.first!)
                if text.count > 1 {
                    hasher.combine(text.last!)
                }
                
                // Hash a few strategic characters for better distribution
                if text.count > 100 {
                    let midIndex = text.index(text.startIndex, offsetBy: text.count / 2)
                    hasher.combine(text[midIndex])
                }
            }
        }
    }
    
    struct CacheEntry {
        let tokens: [HighlightedToken]
        let timestamp: Date
        let accessCount: Int
        let computationTime: TimeInterval
        let textLength: Int
        
        var score: Double {
            // Calculate cache value score based on multiple factors
            let ageFactor = 1.0 / (Date().timeIntervalSince(timestamp) + 1.0)
            let accessFactor = Double(accessCount)
            let sizeFactor = Double(textLength) / 10_000.0 // Favor larger files
            let computationFactor = computationTime * 10.0 // Favor expensive computations
            
            return ageFactor * 0.3 + accessFactor * 0.3 + sizeFactor * 0.2 + computationFactor * 0.2
        }
    }
    
    // MARK: - Configuration
    
    /// Maximum number of cache entries
    var maxCacheSize: Int = 50
    
    /// Maximum memory usage in MB (approximate)
    var maxMemoryUsageMB: Double = 100.0
    
    /// Time threshold for considering entries stale (in seconds)
    var staleThreshold: TimeInterval = 3_600 // 1 hour
    
    /// Minimum computation time to cache (avoid caching trivial computations)
    var minComputationTimeToCache: TimeInterval = 0.01 // 10ms
    
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
            if Date().timeIntervalSince(entry.timestamp) > staleThreshold {
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
        computationTime: TimeInterval
    ) {
        // Don't cache trivial computations
        guard computationTime >= minComputationTimeToCache else { return }
        
        let entry = CacheEntry(
            tokens: tokens,
            timestamp: Date(),
            accessCount: 1,
            computationTime: computationTime,
            textLength: key.text.count
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
            Date().timeIntervalSince(entry.timestamp) > staleThreshold ? key : nil
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
        staleThreshold: TimeInterval? = nil
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
    
    private var metrics: [Category: [TimeInterval]] = [:]
    private let metricsLimit = 100
    
    func measure<T>(
        category: Category,
        operation: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            recordMetric(category: category, duration: duration)
        }
        return try await operation()
    }
    
    private func recordMetric(category: Category, duration: TimeInterval) {
        var categoryMetrics = metrics[category] ?? []
        categoryMetrics.append(duration)
        
        // Keep only recent metrics
        if categoryMetrics.count > metricsLimit {
            categoryMetrics.removeFirst()
        }
        
        metrics[category] = categoryMetrics
        
        // Log slow operations
        if duration > 0.1 {
            kLogger.debug("⚠️ Slow \(category.rawValue): \(String(format: "%.3f", duration))s")
        }
    }
    
    func getAverageTime(for category: Category) -> TimeInterval? {
        guard let categoryMetrics = metrics[category], !categoryMetrics.isEmpty else {
            return nil
        }
        return categoryMetrics.reduce(0, +) / Double(categoryMetrics.count)
    }
    
    func reset() {
        metrics.removeAll()
    }
}
