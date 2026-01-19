import Foundation

// MARK: - Cache Coordinator Actor

/// Actor responsible for managing caching operations across the editor
@available(macOS 13.0, iOS 16.0, *)
public actor CacheCoordinatorActor {
    private var caches: [String: AnyCacheWrapper] = [:]

    /// Type-erased wrapper for CacheProtocol
    private struct AnyCacheWrapper: Sendable {
        let getValue: @Sendable (String) async -> (any Sendable)?
        let setValue: @Sendable (any Sendable, String, Int) async -> Void
        let contains: @Sendable (String) async -> Bool
        let clear: @Sendable () async -> Void

        init<Cache: CacheProtocol>(_ cache: Cache) where Cache.Value: Sendable {
            self.getValue = { key in
                await cache.getValue(for: key)
            }
            self.setValue = { value, key, cost in
                if let typedValue = value as? Cache.Value {
                    await cache.setValue(typedValue, for: key, cost: cost)
                }
            }
            self.contains = { key in
                await cache.contains(key: key)
            }
            self.clear = {
                await cache.clear()
            }
        }
    }

    private var cacheStats: [String: CacheStatistics] = [:]
    private let maxGlobalMemoryMB: Double = 200.0
    private var currentMemoryUsageMB: Double = 0.0

    /// Statistics for cache performance monitoring
    public struct CacheStatistics {
        /// Number of cache hits
        public let hits: Int
        /// Number of cache misses
        public let misses: Int
        /// Number of cache evictions performed
        public let evictions: Int
        /// Current memory usage in megabytes
        public let memoryUsageMB: Double
        /// Last time this cache was accessed
        public let lastAccessTime: Date
    }

    /// Register a cache with the coordinator
    public func registerCache<T: CacheProtocol>(_ cache: T, identifier: String) where T.Value: Sendable {
        caches[identifier] = AnyCacheWrapper(cache)
        cacheStats[identifier] = CacheStatistics(
            hits: 0,
            misses: 0,
            evictions: 0,
            memoryUsageMB: 0,
            lastAccessTime: Date()
        )
    }

    /// Get value from cache
    public func getValue<T: Sendable>(
        for key: String,
        from cacheId: String
    ) async -> T? {
        guard let cache = caches[cacheId] else { return nil }

        // Update stats
        if let stats = cacheStats[cacheId] {
            let hit = await cache.contains(key)
            cacheStats[cacheId] = CacheStatistics(
                hits: stats.hits + (hit ? 1 : 0),
                misses: stats.misses + (hit ? 0 : 1),
                evictions: stats.evictions,
                memoryUsageMB: stats.memoryUsageMB,
                lastAccessTime: Date()
            )
        }

        let value = await cache.getValue(key)
        return value as? T
    }

    /// Set value in cache
    public func setValue<T: Sendable>(
        _ value: T,
        for key: String,
        in cacheId: String,
        cost: Int = 1
    ) async {
        guard let cache = caches[cacheId] else { return }

        // Check memory pressure
        if currentMemoryUsageMB > maxGlobalMemoryMB * 0.9 {
            await performGlobalEviction()
        }

        await cache.setValue(value, key, cost)
    }

    /// Clear specific cache
    public func clearCache(_ cacheId: String) async {
        guard let cache = caches[cacheId] else { return }
        await cache.clear()

        if let stats = cacheStats[cacheId] {
            cacheStats[cacheId] = CacheStatistics(
                hits: stats.hits,
                misses: stats.misses,
                evictions: stats.evictions + 1,
                memoryUsageMB: 0,
                lastAccessTime: Date()
            )
        }
    }

    /// Perform global cache eviction based on LRU
    private func performGlobalEviction() async {
        // Find least recently used caches
        let sortedCaches = cacheStats.sorted { $0.value.lastAccessTime < $1.value.lastAccessTime }

        // Evict 20% of caches starting with LRU
        let evictionCount = max(1, sortedCaches.count / 5)
        for (cacheId, _) in sortedCaches.prefix(evictionCount) {
            await clearCache(cacheId)
        }
    }
}
