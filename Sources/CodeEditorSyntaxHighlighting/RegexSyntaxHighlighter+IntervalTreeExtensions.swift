import Foundation

// MARK: - Interval Tree for O(log n) overlap checking

/// A balanced interval tree for efficient range overlap queries
package struct IntervalTree {
    private var root: Node?

    private class Node {
        let range: NSRange
        var maxEnd: Int
        var left: Node?
        var right: Node?
        var height: Int = 1

        init(range: NSRange) {
            self.range = range
            self.maxEnd = NSMaxRange(range)
        }
    }

    /// Insert a new range into the tree
    mutating func insert(_ range: NSRange) {
        root = insertNode(root, range)
    }

    /// Check if any range in the tree overlaps with the given range
    package func hasOverlap(with range: NSRange) -> Bool {
        checkOverlap(root, range)
    }

    // MARK: - Private Helper Methods

    private func insertNode(_ node: Node?, _ range: NSRange) -> Node {
        guard let node else {
            return Node(range: range)
        }

        if range.location < node.range.location {
            node.left = insertNode(node.left, range)
        } else {
            node.right = insertNode(node.right, range)
        }

        // Update height and maxEnd
        node.height = 1 + max(height(node.left), height(node.right))
        updateMaxEnd(node)

        // Balance the tree
        return balance(node)
    }

    private func checkOverlap(_ node: Node?, _ range: NSRange) -> Bool {
        guard let node else {
            return false
        }

        // Check if current node overlaps
        if NSIntersectionRange(node.range, range).length > 0 {
            return true
        }

        // If left subtree exists and its max end is >= range start, check left
        if let left = node.left, left.maxEnd > range.location {
            if checkOverlap(left, range) {
                return true
            }
        }

        // If right subtree exists and current node's start is < range end, check right
        if node.range.location < NSMaxRange(range) {
            if checkOverlap(node.right, range) {
                return true
            }
        }

        return false
    }

    private func updateMaxEnd(_ node: Node) {
        var maxEnd = NSMaxRange(node.range)
        if let left = node.left {
            maxEnd = max(maxEnd, left.maxEnd)
        }
        if let right = node.right {
            maxEnd = max(maxEnd, right.maxEnd)
        }
        node.maxEnd = maxEnd
    }

    private func height(_ node: Node?) -> Int {
        node?.height ?? 0
    }

    private func getBalance(_ node: Node?) -> Int {
        guard let node else { return 0 }
        return height(node.left) - height(node.right)
    }

    private func rotateRight(_ y: Node) -> Node {
        guard let x = y.left else {
            // This should never happen in a properly balanced tree
            return y
        }
        let temp = x.right

        x.right = y
        y.left = temp

        y.height = 1 + max(height(y.left), height(y.right))
        x.height = 1 + max(height(x.left), height(x.right))

        updateMaxEnd(y)
        updateMaxEnd(x)

        return x
    }

    private func rotateLeft(_ x: Node) -> Node {
        guard let y = x.right else {
            // This should never happen in a properly balanced tree
            return x
        }
        let temp = y.left

        y.left = x
        x.right = temp

        x.height = 1 + max(height(x.left), height(x.right))
        y.height = 1 + max(height(y.left), height(y.right))

        updateMaxEnd(x)
        updateMaxEnd(y)

        return y
    }

    private func balance(_ node: Node) -> Node {
        let balance = getBalance(node)

        // Left-heavy
        if balance > 1 {
            if let left = node.left, getBalance(left) < 0 {
                node.left = rotateLeft(left)
            }
            return rotateRight(node)
        }

        // Right-heavy
        if balance < -1 {
            if let right = node.right, getBalance(right) > 0 {
                node.right = rotateRight(right)
            }
            return rotateLeft(node)
        }

        return node
    }
}
