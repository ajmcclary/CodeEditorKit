import Foundation

package final class SymbolRangeIndex<Value> {
    private final class Node {
        let range: NSRange
        let value: Value
        var maxUpperBound: Int
        var left: Node?
        var right: Node?

        init(range: NSRange, value: Value) {
            self.range = range
            self.value = value
            self.maxUpperBound = NSMaxRange(range)
        }
    }

    private var root: Node?

    package init() {}

    package func insert(range: NSRange, value: Value) {
        root = insert(range: range, value: value, into: root)
    }

    package func findContaining(location: Int) -> [Value] {
        var results: [Value] = []
        findContaining(location: location, in: root, results: &results)
        return results
    }

    package func removeAll() {
        root = nil
    }

    private func insert(range: NSRange, value: Value, into node: Node?) -> Node {
        guard let node else {
            return Node(range: range, value: value)
        }

        if range.location < node.range.location {
            node.left = insert(range: range, value: value, into: node.left)
        } else {
            node.right = insert(range: range, value: value, into: node.right)
        }

        node.maxUpperBound = max(node.maxUpperBound, NSMaxRange(range))
        return node
    }

    private func findContaining(location: Int, in node: Node?, results: inout [Value]) {
        guard let node else { return }

        if let left = node.left, left.maxUpperBound >= location {
            findContaining(location: location, in: left, results: &results)
        }

        if node.range.location <= location, location <= NSMaxRange(node.range) {
            results.append(node.value)
        }

        if location >= node.range.location {
            findContaining(location: location, in: node.right, results: &results)
        }
    }
}
