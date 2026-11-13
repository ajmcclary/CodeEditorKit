import Foundation

/// Point-in-range queries over symbol ranges.
///
/// Stored as an array sorted by location with an implicit balanced interval
/// tree over it (each subarray's middle element carries the largest upper
/// bound in that subarray). There are no node objects: the previous
/// pointer-based tree was unbalanced, so symbols arriving in location order
/// formed one spine and its recursive insert overflowed the main thread's
/// stack on a ~200 KB JSON document (and releasing such a spine recurses
/// too). Depth is now at most log2(count), and queries are iterative.
package final class SymbolRangeIndex<Value> {
    private var entries: [(range: NSRange, value: Value)] = []
    /// `maxUpperBound[mid]` for the subarray whose middle index is `mid`.
    private var maxUpperBound: [Int] = []
    private var needsRebuild = false

    package init() {}

    /// Adds one range. The index is rebuilt (sorted, balanced) before the
    /// next query, so any insertion order keeps it shallow.
    package func insert(range: NSRange, value: Value) {
        entries.append((range, value))
        needsRebuild = true
    }

    /// Replaces the contents with `newEntries` in one sorted build.
    package func replaceAll(with newEntries: [(NSRange, Value)]) {
        entries = newEntries.map { (range: $0.0, value: $0.1) }
        needsRebuild = true
    }

    package func findContaining(location: Int) -> [Value] {
        rebuildIfNeeded()
        var results: [(location: Int, value: Value)] = []
        var pending: [(lower: Int, upper: Int)] = [(0, entries.count)]
        while let (lower, upper) = pending.popLast() {
            guard lower < upper else { continue }
            let mid = (lower + upper) / 2
            guard maxUpperBound[mid] >= location else { continue }
            let range = entries[mid].range
            if range.location <= location, location <= NSMaxRange(range) {
                results.append((range.location, entries[mid].value))
            }
            pending.append((lower, mid))
            // Everything right of `mid` starts at or after it.
            if range.location <= location {
                pending.append((mid + 1, upper))
            }
        }
        // In location order, as the tree's in-order traversal returned them.
        return results.sorted { $0.location < $1.location }.map(\.value)
    }

    package func removeAll() {
        entries.removeAll()
        maxUpperBound.removeAll()
        needsRebuild = false
    }

    private func rebuildIfNeeded() {
        guard needsRebuild else { return }
        needsRebuild = false
        entries = entries.enumerated()
            .sorted { lhs, rhs in
                lhs.element.range.location != rhs.element.range.location
                    ? lhs.element.range.location < rhs.element.range.location
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
        maxUpperBound = Array(repeating: 0, count: entries.count)
        _ = fillMaxUpperBound(lower: 0, upper: entries.count)
    }

    /// Recursion depth is log2(count): the subarrays halve.
    private func fillMaxUpperBound(lower: Int, upper: Int) -> Int {
        guard lower < upper else { return Int.min }
        let mid = (lower + upper) / 2
        let value = max(
            NSMaxRange(entries[mid].range),
            fillMaxUpperBound(lower: lower, upper: mid),
            fillMaxUpperBound(lower: mid + 1, upper: upper)
        )
        maxUpperBound[mid] = value
        return value
    }
}
