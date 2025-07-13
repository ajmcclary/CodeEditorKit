import Foundation

/// Smart cache for syntax highlighting tokens with intelligent eviction strategies
actor SmartTokenCache {
    struct CacheKey: Hashable {
        let textHash: Int
        let textLength: Int
        let language: Language
        let version: Int
        
        init(text: String, language: Language, version: Int) {
            // Create hash of the entire text content
            var hasher = Hasher()
            hasher.combine(text) // Hash the entire text content
            hasher.combine(language)
            hasher.combine(version)
            
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
    var minComputationTimeToCache: Duration = .milliseconds(0) // Cache all results for testing
    
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
