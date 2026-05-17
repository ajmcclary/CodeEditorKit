// swiftlint:disable missing_docs
import Foundation

extension IndexSet {
    public init(integersIn nsRange: NSRange) {
        self.init(integersIn: Range(nsRange) ?? 0 ..< 0)
    }

    /// Initialize from an array of NSRanges
    public init(ranges: [NSRange]) {
        self.init()
        for range in ranges {
            insert(integersIn: range.location ..< (range.location + range.length))
        }
    }

    /// Insert a range into the index set
    public mutating func insert(range: NSRange) {
        insert(integersIn: range.location ..< (range.location + range.length))
    }

    /// Get NSRange view of the index set
    public var nsRangeView: [NSRange] {
        var ranges: [NSRange] = []
        for range in rangeView {
            ranges.append(NSRange(location: range.lowerBound, length: range.count))
        }
        return ranges
    }
}

// swiftlint:enable missing_docs
