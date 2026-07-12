import CodeEditorDiagnostics
import CodeEditorLanguages
import Foundation

/// Owns cached completion responses and their expiration policy.
@MainActor
final class CompletionResponseCache {
    private let cache: LRUCache<CompletionCacheKey, CachedCompletionResult>
    private let expirationTime: TimeInterval
    let isEnabled: Bool

    init(
        capacity: Int,
        expirationTime: TimeInterval,
        isEnabled: Bool,
        memoryMonitor: MemoryMonitor
    ) {
        self.cache = LRUCache(capacity: capacity, memoryMonitor: memoryMonitor)
        self.expirationTime = expirationTime
        self.isEnabled = isEnabled
    }

    /// Returns an unexpired response when caching is enabled.
    func result(for context: CompletionContextModel) -> CompletionResult? {
        guard isEnabled else { return nil }
        let key = CompletionCacheKey(context: context)
        guard let cached = cache.get(key), !cached.isExpired else { return nil }
        return cached.result
    }

    /// Stores complete, non-empty responses when caching is enabled.
    func store(_ result: CompletionResult, for context: CompletionContextModel) {
        guard isEnabled, !result.isIncomplete, !result.items.isEmpty else { return }
        cache.set(
            CachedCompletionResult(
                result: result,
                expirationTime: expirationTime
            ),
            forKey: CompletionCacheKey(context: context)
        )
    }

    /// Removes every cached response.
    func clear() {
        cache.removeAll()
    }

    /// Number of cached responses.
    var count: Int {
        cache.count
    }

    /// Current LRU cache metrics.
    var statistics: CacheStatistics {
        cache.statistics
    }

    /// Rebinds memory-pressure observation without replacing cache contents.
    func setMemoryMonitor(_ monitor: MemoryMonitor) {
        cache.setMemoryMonitor(monitor)
    }
}
