import Foundation

// MARK: - Completion Cache Manager

/// Manages caching of completion results for improved performance
@MainActor
internal final class CompletionCacheManager {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "CompletionCacheManager")

    // MARK: - Properties

    private var cache: [String: CacheEntry] = [:]
    private let maxCacheSize: Int
    private let maxCacheAge: TimeInterval

    // MARK: - Types

    private struct CacheEntry {
        let items: [CompletionItemModel]
        let timestamp: Date
    }

    // MARK: - Initialization

    init(maxCacheSize: Int = 50, maxCacheAge: TimeInterval = 300) { // 5 minutes default
        self.maxCacheSize = maxCacheSize
        self.maxCacheAge = maxCacheAge
    }

    // MARK: - Public Methods

    /// Generates a cache key for the given context
    internal func generateCacheKey(for context: CompletionContext) -> String {
        let components = [
            context.language.rawValue,
            context.prefix,
            context.triggerCharacter ?? "",
            String(context.currentLine.hash)
        ]
        return components.joined(separator: "_")
    }

    /// Retrieves cached completions if available and not expired
    internal func getCachedCompletions(for key: String) -> [CompletionItemModel] {
        cleanExpiredEntries()

        guard let entry = cache[key] else { return [] }

        // Check if entry is expired
        if Date().timeIntervalSince(entry.timestamp) > maxCacheAge {
            cache.removeValue(forKey: key)
            return []
        }

        logger.debug("Cache hit for key: \(key)")
        return entry.items
    }

    /// Caches completion items
    internal func cacheCompletions(_ items: [CompletionItemModel], for key: String) {
        // Ensure cache size limit
        if cache.count >= maxCacheSize {
            removeOldestEntry()
        }

        cache[key] = CacheEntry(items: items, timestamp: Date())
        logger.debug("Cached \(items.count) items for key: \(key)")
    }

    /// Clears all cached completions
    internal func clearCache() {
        cache.removeAll()
        logger.debug("Cache cleared")
    }

    /// Gets current cache statistics
    internal var cacheStatistics: (size: Int, hitRate: Double) {
        (size: cache.count, hitRate: calculateHitRate())
    }

    // MARK: - Private Methods

    private func cleanExpiredEntries() {
        let now = Date()
        let expiredKeys = cache.compactMap { key, entry -> String? in
            if now.timeIntervalSince(entry.timestamp) > maxCacheAge {
                return key
            }
            return nil
        }

        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }

        if !expiredKeys.isEmpty {
            logger.debug("Removed \(expiredKeys.count) expired cache entries")
        }
    }

    private func removeOldestEntry() {
        guard let oldestKey = cache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key else { return }
        cache.removeValue(forKey: oldestKey)
    }

    private var cacheHits = 0
    private var cacheMisses = 0

    internal func recordCacheHit() {
        cacheHits += 1
    }

    internal func recordCacheMiss() {
        cacheMisses += 1
    }

    private func calculateHitRate() -> Double {
        let total = cacheHits + cacheMisses
        guard total > 0 else { return 0.0 }
        return Double(cacheHits) / Double(total)
    }
}

// MARK: - Cache-aware Completion Item

extension CompletionItemModel {
    /// Creates a cache-friendly copy of the item
    internal func cacheableCopy() -> CompletionItemModel {
        // Create a copy without mutable state
        CompletionItemModel(
            label: label,
            insertText: insertText,
            kind: kind,
            detail: detail,
            documentation: documentation,
            sortText: sortText,
            filterText: filterText,
            priority: priority,
            snippetSupport: snippetSupport,
            deprecated: deprecated,
            preselect: preselect,
            textEdit: textEdit,
            additionalTextEdits: additionalTextEdits,
            id: id
        )
    }
}
