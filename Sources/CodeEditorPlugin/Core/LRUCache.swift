import Foundation

/// A thread-safe LRU (Least Recently Used) cache implementation
@MainActor
public final class LRUCache<Key: Hashable, Value>: @unchecked Sendable {
    private final class Node {
        let key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
    
    private var capacity: Int
    private var cache: [Key: Node] = [:]
    private let head = Node(key: "" as! Key, value: "" as! Value) // Dummy head
    private let tail = Node(key: "" as! Key, value: "" as! Value) // Dummy tail
    private let cacheId = UUID().uuidString
    
    /// Total number of items currently in cache
    public var count: Int { cache.count }
    
    /// Maximum capacity of the cache
    public var maxCapacity: Int { capacity }
    
    /// Creates a new LRU cache with the specified capacity
    /// - Parameter capacity: Maximum number of items to store
    public init(capacity: Int) {
        self.capacity = max(1, capacity)
        head.next = tail
        tail.prev = head
        
        // Register with memory monitor for cleanup
        registerWithMemoryMonitor()
    }
    
    /// Gets a value from the cache, moving it to most recently used
    /// - Parameter key: The key to look up
    /// - Returns: The cached value, or nil if not found
    public func get(_ key: Key) -> Value? {
        guard let node = cache[key] else { return nil }
        
        // Move to head (most recently used)
        moveToHead(node)
        return node.value
    }
    
    /// Sets a value in the cache
    /// - Parameters:
    ///   - value: The value to store
    ///   - key: The key to associate with the value
    public func set(_ value: Value, forKey key: Key) {
        if let existingNode = cache[key] {
            // Update existing node
            existingNode.value = value
            moveToHead(existingNode)
        } else {
            // Add new node
            let newNode = Node(key: key, value: value)
            cache[key] = newNode
            addToHead(newNode)
            
            // Remove least recently used if over capacity
            if cache.count > capacity {
                let tail = removeTail()
                cache.removeValue(forKey: tail.key)
            }
        }
    }
    
    /// Removes a value from the cache
    /// - Parameter key: The key to remove
    /// - Returns: The removed value, or nil if not found
    @discardableResult
    public func removeValue(forKey key: Key) -> Value? {
        guard let node = cache.removeValue(forKey: key) else { return nil }
        removeNode(node)
        return node.value
    }
    
    /// Removes all items from the cache
    public func removeAll() {
        cache.removeAll()
        head.next = tail
        tail.prev = head
    }
    
    /// Checks if the cache contains a value for the given key
    /// - Parameter key: The key to check
    /// - Returns: true if the key exists in the cache
    public func contains(_ key: Key) -> Bool {
        cache[key] != nil
    }
    
    /// Returns all keys in the cache, ordered from most to least recently used
    public var allKeys: [Key] {
        var keys: [Key] = []
        var current = head.next
        while current !== tail {
            keys.append(current!.key)
            current = current!.next
        }
        return keys
    }
    
    /// Returns statistics about the cache
    public var statistics: CacheStatistics {
        CacheStatistics(
            currentSize: count,
            maxSize: capacity,
            utilizationPercentage: Double(count) / Double(capacity) * 100
        )
    }
    
    // MARK: - Private Methods
    
    private func addToHead(_ node: Node) {
        node.prev = head
        node.next = head.next
        head.next?.prev = node
        head.next = node
    }
    
    private func removeNode(_ node: Node) {
        node.prev?.next = node.next
        node.next?.prev = node.prev
    }
    
    private func moveToHead(_ node: Node) {
        removeNode(node)
        addToHead(node)
    }
    
    private func removeTail() -> Node {
        let lastNode = tail.prev!
        removeNode(lastNode)
        return lastNode
    }
    
    /// Register with memory monitor for automatic cleanup
    private func registerWithMemoryMonitor() {
        Task { @MainActor in
            MemoryMonitor.shared.registerCleanupHandler(
                identifier: "lru-cache-\(cacheId)",
                priority: .normal
            ) { @MainActor [weak self] in
                guard let self else {
                    return CleanupResult(memoryFreedMB: 0, description: "Cache deallocated")
                }
                
                let beforeCount = self.count
                let itemsToRemove = max(1, beforeCount / 4) // Remove 25% of items
                
                for _ in 0..<itemsToRemove {
                    if !self.isEmpty {
                        let tail = self.removeTail()
                        self.cache.removeValue(forKey: tail.key)
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
        }
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
