import Foundation

/// Smart cache for syntax highlighting tokens with intelligent eviction strategies
actor SmartTokenCache {
    struct CacheKey: Hashable {
        let text: String
        let textLength: Int
        let textFingerprint: UInt64
        let language: Language
        let version: Int

        init(text: String, language: Language, version: Int) {
            self.text = text
            self.textLength = TextRangeUtilities.utf16Length(of: text)
            self.textFingerprint = Self.fingerprint(text)
            self.language = language
            self.version = version
        }

        static func == (lhs: CacheKey, rhs: CacheKey) -> Bool {
            lhs.textLength == rhs.textLength &&
            lhs.textFingerprint == rhs.textFingerprint &&
            lhs.language == rhs.language &&
            lhs.version == rhs.version &&
            lhs.text == rhs.text
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(textLength)
            hasher.combine(textFingerprint)
            hasher.combine(language)
            hasher.combine(version)
        }

        private static func fingerprint(_ text: String) -> UInt64 {
            var hash: UInt64 = 0xcbf29ce484222325
            for byte in text.utf8 {
                hash ^= UInt64(byte)
                hash &*= 0x100000001b3
            }
            return hash
        }
    }

    struct CacheEntry {
        let tokens: [HighlightedToken]
        let timestamp: Date
        let accessCount: Int
        let computationTime: Duration
        let textLength: Int
        let lastViewportRange: NSRange? // Track last visible range

        var score: Double {
            // Calculate cache value score based on multiple factors
            let ageInSeconds = Date.now.timeIntervalSince(timestamp)
            let ageFactor = 1.0 / (ageInSeconds + 1.0)
            let accessFactor = Double(accessCount)
            let sizeFactor = Double(textLength) / 10_000.0 // Favor larger files
            let computationFactor = computationTime.timeInterval * 10.0 // Favor expensive computations

            return ageFactor * 0.3 + accessFactor * 0.3 + sizeFactor * 0.2 + computationFactor * 0.2
        }

        /// Get viewport-filtered tokens to reduce memory usage
        func tokensInViewport(_ viewportRange: NSRange) -> [HighlightedToken] {
            // Return only tokens that overlap with the viewport
            let expandedRange = NSRange(
                location: max(0, viewportRange.location - 1_000),
                length: viewportRange.length + 2_000
            )

            return tokens.filter { token in
                NSLocationInRange(token.range.location, expandedRange) ||
                NSLocationInRange(NSMaxRange(token.range) - 1, expandedRange) ||
                NSLocationInRange(expandedRange.location, token.range)
            }
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
    var minComputationTimeToCache: Duration = .milliseconds(0) // Cache all results for testing

    // MARK: - State

    private var cache: [CacheKey: CacheEntry] = [:]
    private var accessOrder: [CacheKey] = []
    private var hitCount: Int = 0
    private var missCount: Int = 0
    private var evictionCount: Int = 0

    // MARK: - Public Methods

    func getCachedTokens(for key: CacheKey, viewportRange: NSRange? = nil) -> [HighlightedToken] {
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
                textLength: entry.textLength,
                lastViewportRange: viewportRange ?? entry.lastViewportRange
            )
            cache[key] = entry

            // Move to end of access order
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)

            hitCount += 1

            // Return viewport-filtered tokens if viewport is provided
            if let viewportRange {
                return entry.tokensInViewport(viewportRange)
            }
            return entry.tokens
        }

        missCount += 1
        return []
    }

    func setCachedTokens(
        _ tokens: [HighlightedToken],
        for key: CacheKey,
        computationTime: Duration,
        viewportRange: NSRange? = nil
    ) {
        // Don't cache trivial computations
        guard computationTime >= minComputationTimeToCache else { return }

        let entry = CacheEntry(
            tokens: tokens,
            timestamp: Date(),
            accessCount: 1,
            computationTime: computationTime,
            textLength: key.textLength,
            lastViewportRange: viewportRange
        )

        cache[key] = entry
        accessOrder.removeAll { $0 == key }
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

    /// Optimize cache memory by retaining only viewport-relevant tokens
    func optimizeForMemory(currentViewport: NSRange?) {
        guard let viewport = currentViewport else { return }

        // Update all cache entries to retain only viewport-relevant tokens
        for (key, entry) in cache {
            let viewportTokens = entry.tokensInViewport(viewport)

            // Only update if we're actually reducing token count significantly
            if Double(viewportTokens.count) < Double(entry.tokens.count) * 0.8 {
                let optimizedEntry = CacheEntry(
                    tokens: viewportTokens,
                    timestamp: entry.timestamp,
                    accessCount: entry.accessCount,
                    computationTime: entry.computationTime,
                    textLength: entry.textLength,
                    lastViewportRange: viewport
                )
                cache[key] = optimizedEntry
            }
        }
    }

    /// Predictively prefetch tokens for anticipated viewport movement
    func prefetchTokens(
        for predictedRange: NSRange,
        text: String,
        language: Language,
        priority _: TaskPriority = .low
    ) async {
        // Check if we already have tokens for this range
        let cacheKey = CacheKey(text: text, language: language, version: 0)
        let cachedTokens = getCachedTokens(for: cacheKey)

        // If we have tokens, check if the predicted range is covered
        if !cachedTokens.isEmpty {
            let coveredRange = cachedTokens.reduce(NSRange(location: Int.max, length: 0)) { result, token in
                if result.location == Int.max {
                    return token.range
                }
                return NSUnionRange(result, token.range)
            }

            // If predicted range is already covered, no need to prefetch
            if NSLocationInRange(predictedRange.location, coveredRange) &&
               NSLocationInRange(NSMaxRange(predictedRange) - 1, coveredRange) {
                return
            }
        }

        // Schedule background tokenization for the predicted range
        Task {
            // This is a placeholder - actual tokenization would happen through
            // the syntax highlighting coordinator
            await Task.yield()
        }
    }

    /// Analyze scroll patterns to predict future viewport positions
    func predictNextViewport(
        currentViewport: NSRange,
        scrollVelocity: Double,
        documentLength: Int
    ) -> NSRange? {
        // Simple prediction based on scroll velocity
        guard abs(scrollVelocity) > 0.1 else { return nil }

        let predictedOffset = Int(scrollVelocity * 0.5) // Predict 0.5 seconds ahead
        let predictedLocation = max(
            0,
            min(documentLength - currentViewport.length, currentViewport.location + predictedOffset)
        )

        return NSRange(location: predictedLocation, length: currentViewport.length)
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
        let now = Date.now
        let staleKeys = cache.compactMap { key, entry in
            let elapsedTime = now.timeIntervalSince(entry.timestamp)
            let staleThresholdSeconds = Double(staleThreshold.components.seconds) + Double(staleThreshold.components.attoseconds) / 1e18
            // Use >= instead of > to handle edge cases where times are exactly equal
            return elapsedTime >= staleThresholdSeconds ? key : nil
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
        // Evict based on memory usage with circuit breaker to prevent infinite loops
        var iterations = 0
        let maxIterations = cache.count + 10 // Safety limit to prevent infinite loops

        while estimateMemoryUsage() > maxMemoryUsageMB && !cache.isEmpty && iterations < maxIterations {
            evictLeastValuableEntry()
            iterations += 1
        }

        // Evict based on cache size with circuit breaker
        iterations = 0
        while cache.count > maxCacheSize && !cache.isEmpty && iterations < maxIterations {
            evictLeastValuableEntry()
            iterations += 1
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
        // Base memory for cache structure
        guard !cache.isEmpty else { return 0.0 }

        // Rough estimate: each token takes ~100 bytes, plus overhead
        let totalTokens = cache.values.reduce(0) { $0 + $1.tokens.count }
        let tokenMemoryMB = Double(totalTokens) * 100.0 / (1_024.0 * 1_024.0)

        // Add overhead for cache entries and keys
        // Each entry has: key (hash + metadata), tokens array, timestamp, counters
        let baseOverheadPerEntry = 1_024.0 // 1KB base overhead per entry
        let textLengthOverhead = cache.keys.reduce(0.0) { sum, key in
            sum + Double(key.textLength) * 2.0 // 2 bytes per character for hash storage
        }

        let overheadMB = (Double(cache.count) * baseOverheadPerEntry + textLengthOverhead) / (1_024.0 * 1_024.0)

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
