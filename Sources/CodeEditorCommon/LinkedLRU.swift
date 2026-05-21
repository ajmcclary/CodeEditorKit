import Foundation

/// Doubly-linked-list-backed least-recently-used cache.
///
/// `value(forKey:)`, `setValue(_:forKey:)`, `removeValue(forKey:)`, and the
/// capacity-eviction step are all O(1). `removeAll(where:)` is O(n) in the
/// current entry count.
///
/// Thread-unsafe by design: callers provide their own synchronization. The
/// in-tree consumers wrap it with their existing isolation discipline
/// (`ParagraphStyleCache`'s serial `DispatchQueue`, `LayoutCache`'s
/// `@MainActor`), so introducing an internal lock would be redundant overhead
/// on the hot layout path this helper exists to optimize.
public final class LinkedLRU<Key: Hashable, Value> {
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

    /// Maximum number of entries the cache will retain. Reached only by
    /// growth — `setValue` evicts the LRU entry once `count > capacity`.
    public let capacity: Int

    private var nodes: [Key: Node] = [:]
    private var head: Node?
    private var tail: Node?

    /// - Parameter capacity: Maximum entry count. Must be positive.
    public init(capacity: Int) {
        precondition(capacity > 0, "LinkedLRU capacity must be positive")
        self.capacity = capacity
    }

    /// Current entry count.
    public var count: Int { nodes.count }

    /// True iff the cache has no entries.
    public var isEmpty: Bool { nodes.isEmpty }

    /// Returns the value for `key`, promoting it to most-recently-used.
    /// Returns nil if the key is not present.
    public func value(forKey key: Key) -> Value? {
        guard let node = nodes[key] else {
            return nil
        }
        moveToHead(node)
        return node.value
    }

    /// Inserts or updates the value for `key`, promoting it to
    /// most-recently-used. Evicts the LRU entry if the capacity is exceeded.
    public func setValue(_ value: Value, forKey key: Key) {
        if let existing = nodes[key] {
            existing.value = value
            moveToHead(existing)
            return
        }

        let node = Node(key: key, value: value)
        nodes[key] = node
        insertAtHead(node)

        if nodes.count > capacity, let evict = tail {
            detach(evict)
            nodes.removeValue(forKey: evict.key)
        }
    }

    /// Removes the entry for `key` without touching anything else's access
    /// order. Returns the removed value if one was present.
    @discardableResult
    public func removeValue(forKey key: Key) -> Value? {
        guard let node = nodes.removeValue(forKey: key) else {
            return nil
        }
        detach(node)
        return node.value
    }

    /// Removes every entry whose key matches `keyMatches`. Other entries keep
    /// their existing access order.
    public func removeAll(where keyMatches: (Key) -> Bool) {
        let keysToRemove = nodes.keys.filter(keyMatches)
        for key in keysToRemove {
            removeValue(forKey: key)
        }
    }

    /// Removes every entry from the cache.
    public func removeAll() {
        nodes.removeAll()
        head = nil
        tail = nil
    }

    // MARK: - Linked-list bookkeeping

    private func insertAtHead(_ node: Node) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil {
            tail = node
        }
    }

    private func detach(_ node: Node) {
        let prev = node.prev
        let next = node.next
        prev?.next = next
        next?.prev = prev
        if head === node {
            head = next
        }
        if tail === node {
            tail = prev
        }
        node.prev = nil
        node.next = nil
    }

    private func moveToHead(_ node: Node) {
        if head === node {
            return
        }
        detach(node)
        insertAtHead(node)
    }
}
