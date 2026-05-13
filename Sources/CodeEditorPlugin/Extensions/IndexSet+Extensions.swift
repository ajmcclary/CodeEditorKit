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
        self = RangeMutationEngine.transform(self, applying: mutations, policy: .preserveSurvivingSegments)
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
