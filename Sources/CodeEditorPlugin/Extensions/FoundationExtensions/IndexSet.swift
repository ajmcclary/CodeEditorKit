import Foundation

extension IndexSet {
    init(integersIn nsRange: NSRange) {
        self.init(integersIn: Range(nsRange) ?? 0 ..< 0)
    }

    /// Initialize from an array of NSRanges
    init(ranges: [NSRange]) {
        self.init()
        for range in ranges {
            insert(integersIn: range.location ..< (range.location + range.length))
        }
    }

    /// Insert a range into the index set
    mutating func insert(range: NSRange) {
        insert(integersIn: range.location ..< (range.location + range.length))
    }

    /// Apply mutations to the index set
    mutating func applying(_ mutations: [RangeMutation]) {
        // Apply each mutation in order
        for mutation in mutations {
            let range = mutation.range
            let delta = mutation.delta

            if delta > 0 {
                // Insertion - shift indices after the range
                let indicesToShift = filter { $0 >= range.location }
                for index in indicesToShift.reversed() {
                    remove(index)
                    insert(index + delta)
                }
            } else if delta < 0 {
                // Deletion - shift indices after the range and remove deleted indices
                let indicesToRemove = filter {
                    $0 >= range.location && $0 < range.location + range.length
                }
                for index in indicesToRemove {
                    remove(index)
                }

                let indicesToShift = filter { $0 >= range.location + range.length }
                for index in indicesToShift.reversed() {
                    remove(index)
                    insert(index + delta)
                }
            }
        }
    }

    /// Get NSRange view of the index set
    var nsRangeView: [NSRange] {
        var ranges: [NSRange] = []
        for range in rangeView {
            ranges.append(NSRange(location: range.lowerBound, length: range.count))
        }
        return ranges
    }
}
