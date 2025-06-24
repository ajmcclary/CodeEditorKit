import Foundation

/// Represents a mutation operation on a text range
public struct RangeMutation: Equatable {
    public let range: NSRange
    public let delta: Int
    public let version: Int

    public init(range: NSRange, delta: Int, version: Int = 0) {
        self.range = range
        self.delta = delta
        self.version = version
    }

    // MARK: - Transform Operations

    /// Transform an IndexSet based on this mutation
    public func transform(set: IndexSet) -> IndexSet {
        var result = IndexSet()

        for range in set.nsRangeView {
            if let transformed = transform(range: range) {
                result.insert(integersIn: transformed.location ..< transformed.upperBound)
            }
        }

        return result
    }

    /// Transform a single range based on this mutation
    private func transform(range: NSRange) -> NSRange? {
        // If the range is before the mutation, it's unchanged
        if range.upperBound <= self.range.location {
            return range
        }

        // If the range is after the mutation, shift it by delta
        if range.location >= self.range.upperBound {
            return NSRange(location: range.location + delta, length: range.length)
        }

        // If the mutation is a deletion that overlaps with the range
        if delta < 0 {
            let deletionEnd = self.range.location - delta

            // If the range is entirely within the deletion, it's removed
            if range.location >= self.range.location, range.upperBound <= deletionEnd {
                return nil
            }

            // Partial overlap - adjust the range
            if range.location < self.range.location, range.upperBound > deletionEnd {
                // Range spans the entire deletion
                return NSRange(location: range.location, length: range.length + delta)
            } else if range.location < self.range.location {
                // Range ends within the deletion
                return NSRange(location: range.location, length: self.range.location - range.location)
            } else {
                // Range starts within the deletion
                let newLocation = deletionEnd + delta
                let newLength = range.upperBound - deletionEnd
                return NSRange(location: newLocation, length: newLength)
            }
        }

        // For insertions that overlap
        if range.location <= self.range.location, range.upperBound > self.range.location {
            // Range contains the insertion point
            return NSRange(location: range.location, length: range.length + delta)
        }

        // Default case
        return range
    }
}
