import CodeEditorCommon
import CodeEditorLanguages
import Foundation

/// A thread-safe LRU (Least Recently Used) cache implementation
@MainActor
public final class LRUCache<Key: Hashable & Sendable, Value: Sendable> {
    private let storage: LinkedLRU<Key, Value>
    private let cacheId = UUID().uuidString
    private var memoryMonitor: MemoryMonitor

    /// Total number of items currently in cache
    public var count: Int { storage.count }

    /// Maximum capacity of the cache
    public var maxCapacity: Int { storage.capacity }

    /// Creates a new LRU cache with the specified capacity
    /// - Parameters:
    ///   - capacity: Maximum number of items to store
    ///   - memoryMonitor: Memory monitor for tracking cache memory usage
    public init(capacity: Int, memoryMonitor: MemoryMonitor) {
        self.storage = LinkedLRU(capacity: capacity)
        self.memoryMonitor = memoryMonitor

        // Register with memory monitor for cleanup
        registerWithMemoryMonitor()
    }

    /// Check if the cache is empty
    public var isEmpty: Bool {
        storage.isEmpty
    }

    /// Gets a value from the cache, moving it to most recently used
    /// - Parameter key: The key to look up
    /// - Returns: The cached value, or nil if not found
    public func get(_ key: Key) -> Value? {
        storage.value(forKey: key)
    }

    /// Sets a value in the cache
    /// - Parameters:
    ///   - value: The value to store
    ///   - key: The key to associate with the value
    public func set(_ value: Value, forKey key: Key) {
        storage.setValue(value, forKey: key)
    }

    /// Removes a value from the cache
    /// - Parameter key: The key to remove
    /// - Returns: The removed value, or nil if not found
    @discardableResult
    public func removeValue(forKey key: Key) -> Value? {
        storage.removeValue(forKey: key)
    }

    /// Removes all items from the cache
    public func removeAll() {
        storage.removeAll()
    }

    /// Checks if the cache contains a value for the given key
    /// - Parameter key: The key to check
    /// - Returns: true if the key exists in the cache
    public func contains(_ key: Key) -> Bool {
        storage.contains(key)
    }

    /// Returns all keys in the cache, ordered from most to least recently used
    public var allKeys: [Key] {
        storage.keysMostRecentFirst
    }

    /// Returns statistics about the cache
    public var statistics: CacheStatistics {
        CacheStatistics(
            currentSize: count,
            maxSize: storage.capacity,
            utilizationPercentage: Double(count) / Double(storage.capacity) * 100
        )
    }

    /// Register with memory monitor for automatic cleanup
    private func registerWithMemoryMonitor() {
        let id = cacheId
        let handler: @MainActor () -> CleanupResult = { [weak self] in
                guard let self else {
                    return CleanupResult(memoryFreedMB: 0, description: "Cache deallocated")
                }

                let beforeCount = self.count
                let itemsToRemove = max(1, beforeCount / 4) // Remove 25% of items

                for _ in 0..<itemsToRemove {
                    if !self.isEmpty {
                        self.storage.removeLeastRecent()
                    } else {
                        break
                    }
                }

                let afterCount = self.count
                let itemsRemoved = beforeCount - afterCount

                // Estimate memory freed (rough approximation)
                let estimatedMemoryMB = Double(itemsRemoved) * 0.001 // 1KB per item estimate

                return CleanupResult(
                    memoryFreedMB: estimatedMemoryMB,
                    description: "Removed \(itemsRemoved) cache items"
                )
        }

        memoryMonitor.registerCleanupHandler(
            identifier: "lru-cache-\(id)",
            priority: .normal,
            handler: handler
        )
    }
}

extension LRUCache: MemoryMonitorUsing {
    public func setMemoryMonitor(_ monitor: MemoryMonitor) {
        guard monitor !== memoryMonitor else { return }

        memoryMonitor.unregisterCleanupHandler(identifier: "lru-cache-\(cacheId)")
        memoryMonitor = monitor
        registerWithMemoryMonitor()
    }
}

/// Statistics about cache usage
public struct CacheStatistics: Sendable {
    public let currentSize: Int
    public let maxSize: Int
    public let utilizationPercentage: Double

    public var isFull: Bool {
        currentSize >= maxSize
    }

    public var availableSpace: Int {
        maxSize - currentSize
    }
}

// MARK: - Cache Key for Completion Results

/// Cache key for completion results
public struct CompletionCacheKey: Hashable, Sendable {
    public let text: String
    public let cursorPosition: Int
    public let languageIdentifier: String
    public let triggerCharacter: String?
    public let contextHash: Int

    public init(context: CompletionContextModel) {
        self.text = String(context.text.suffix(min(context.text.count, 100))) // Only cache last 100 chars
        self.cursorPosition = context.cursorPosition
        self.languageIdentifier = context.language.identifier
        self.triggerCharacter = context.triggerCharacter

        // Create a hash from relevant context information
        var hasher = Hasher()
        hasher.combine(text)
        hasher.combine(cursorPosition)
        hasher.combine(languageIdentifier)
        hasher.combine(triggerCharacter)
        hasher.combine(context.lineText)
        self.contextHash = hasher.finalize()
    }
}

/// Cached completion result with timestamp
public struct CachedCompletionResult: Sendable {
    public let result: CompletionResult
    public let timestamp: Date
    public let expirationTime: TimeInterval

    public init(result: CompletionResult, expirationTime: TimeInterval = 300) { // 5 minutes default
        self.result = result
        self.timestamp = Date()
        self.expirationTime = expirationTime
    }

    public var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > expirationTime
    }
}
