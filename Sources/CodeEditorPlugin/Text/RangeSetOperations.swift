import Foundation

// MARK: - RangeSetOperations

/// Set algebra over UTF-16 ranges: overlap analysis, merging, gaps,
/// intersection / subtraction, distance, expansion / contraction, and
/// mutation-driven adjustments (insert / delete).
internal enum RangeSetOperations {
    // MARK: - Overlap Vocabulary

    /// Detailed information about how two ranges overlap or relate.
    struct OverlapInfo {
        let overlapRange: NSRange?
        let overlapLength: Int
        let overlapType: OverlapKind

        enum OverlapKind {
            case noOverlap
            case partial
            case complete
            case identical
        }

        var hasOverlap: Bool { overlapType != .noOverlap }
    }

    // MARK: - Overlap & Intersection

    /// Detailed overlap relationship between two ranges.
    package static func overlap(_ range1: NSRange, _ range2: NSRange) -> OverlapInfo {
        let start1 = range1.location
        let end1 = NSMaxRange(range1)
        let start2 = range2.location
        let end2 = NSMaxRange(range2)

        if end1 <= start2 || end2 <= start1 {
            return OverlapInfo(overlapRange: nil, overlapLength: 0, overlapType: .noOverlap)
        }

        let overlapStart = max(start1, start2)
        let overlapEnd = min(end1, end2)
        let overlapRange = NSRange(location: overlapStart, length: overlapEnd - overlapStart)

        let overlapType: OverlapInfo.OverlapKind
        if range1 == range2 {
            overlapType = .identical
        } else if (start1 <= start2 && end1 >= end2) || (start2 <= start1 && end2 >= end1) {
            overlapType = .complete
        } else {
            overlapType = .partial
        }

        return OverlapInfo(
            overlapRange: overlapRange,
            overlapLength: overlapRange.length,
            overlapType: overlapType
        )
    }

    package static func contains(_ container: NSRange, _ contained: NSRange) -> Bool {
        container.location <= contained.location &&
            NSMaxRange(container) >= NSMaxRange(contained)
    }

    package static func overlaps(_ range1: NSRange, _ range2: NSRange) -> Bool {
        overlap(range1, range2).hasOverlap
    }

    /// Non-empty intersection of two UTF-16 ranges.
    package static func intersect(_ range1: NSRange, _ range2: NSRange) -> NSRange? {
        let intersection = NSIntersectionRange(range1, range2)
        return intersection.length > 0 ? intersection : nil
    }

    // MARK: - Merge / Gaps

    /// Merge overlapping or adjacent ranges into consolidated ranges.
    package static func merge(_ ranges: [NSRange]) -> [NSRange] {
        guard !ranges.isEmpty else { return [] }

        let sortedRanges = ranges.sorted { $0.location < $1.location }
        var mergedRanges: [NSRange] = []
        var currentRange = sortedRanges[0]

        for range in sortedRanges.dropFirst() {
            if range.location <= NSMaxRange(currentRange) {
                let endLocation = max(NSMaxRange(currentRange), NSMaxRange(range))
                currentRange = NSRange(location: currentRange.location, length: endLocation - currentRange.location)
            } else {
                mergedRanges.append(currentRange)
                currentRange = range
            }
        }

        mergedRanges.append(currentRange)
        return mergedRanges
    }

    /// Find gaps between ranges in a text of given length.
    package static func gaps(in ranges: [NSRange], totalLength: Int) -> [NSRange] {
        guard !ranges.isEmpty else {
            return [NSRange(location: 0, length: totalLength)]
        }

        let mergedRanges = merge(ranges)
        var result: [NSRange] = []

        if mergedRanges[0].location > 0 {
            result.append(NSRange(location: 0, length: mergedRanges[0].location))
        }

        for index in 0..<mergedRanges.count - 1 {
            let currentEnd = NSMaxRange(mergedRanges[index])
            let nextStart = mergedRanges[index + 1].location

            if nextStart > currentEnd {
                result.append(NSRange(location: currentEnd, length: nextStart - currentEnd))
            }
        }

        if let lastRange = mergedRanges.last {
            let lastEnd = NSMaxRange(lastRange)
            if lastEnd < totalLength {
                result.append(NSRange(location: lastEnd, length: totalLength - lastEnd))
            }
        }

        return result
    }

    /// Subtract one UTF-16 range from another, returning surviving segments.
    package static func subtract(_ rangeToRemove: NSRange, from sourceRange: NSRange) -> [NSRange] {
        guard let intersection = intersect(sourceRange, rangeToRemove) else {
            return [sourceRange]
        }

        if intersection == sourceRange {
            return []
        }

        var result: [NSRange] = []
        if intersection.location > sourceRange.location {
            result.append(NSRange(
                location: sourceRange.location,
                length: intersection.location - sourceRange.location
            ))
        }

        let intersectionEnd = NSMaxRange(intersection)
        let sourceEnd = NSMaxRange(sourceRange)
        if intersectionEnd < sourceEnd {
            result.append(NSRange(location: intersectionEnd, length: sourceEnd - intersectionEnd))
        }

        return result
    }

    // MARK: - Distance / Expand / Contract

    package static func distance(between range1: NSRange, and range2: NSRange) -> Int {
        if overlaps(range1, range2) {
            return 0
        }

        let end1 = NSMaxRange(range1)
        let start1 = range1.location
        let end2 = NSMaxRange(range2)
        let start2 = range2.location

        if end1 <= start2 {
            return start2 - end1
        } else {
            return start1 - end2
        }
    }

    package static func expand(_ range: NSRange, by amount: Int, maxLength: Int) -> NSRange {
        let newLocation = max(0, range.location - amount)
        let newEnd = min(maxLength, NSMaxRange(range) + amount)
        return NSRange(location: newLocation, length: newEnd - newLocation)
    }

    package static func contract(_ range: NSRange, by amount: Int) -> NSRange {
        let newLocation = range.location + amount
        let newLength = max(0, range.length - (amount * 2))
        return NSRange(location: newLocation, length: newLength)
    }

    // MARK: - Mutation-Driven Adjustments

    /// Apply mutations to a single range with overlap-invalidation policy.
    static func applyMutations(_ mutations: [RangeMutation], to range: NSRange) -> NSRange? {
        var workingRange = range

        for mutation in mutations.sorted(by: { $0.range.location < $1.range.location }) {
            guard let transformedRange = RangeMutationEngine.transformSingle(
                workingRange,
                applying: mutation,
                policy: .invalidateOnOverlap
            ) else {
                return nil
            }
            workingRange = transformedRange
        }

        return workingRange
    }

    /// Adjust ranges after an insertion, expanding ranges that contain the insertion point.
    static func adjustForInsertion(
        _ ranges: [NSRange],
        insertionPoint: Int,
        insertionLength: Int
    ) -> [NSRange] {
        let mutation = RangeMutation(
            range: NSRange(location: insertionPoint, length: 0),
            delta: max(0, insertionLength)
        )
        return RangeMutationEngine.transform(ranges, applying: mutation, policy: .expandForInsertions)
    }

    /// Adjust ranges after a deletion, preserving surviving range segments.
    static func adjustForDeletion(_ ranges: [NSRange], deletionRange: NSRange) -> [NSRange] {
        let mutation = RangeMutation(range: deletionRange, delta: -deletionRange.length)
        return RangeMutationEngine.transform(ranges, applying: mutation, policy: .preserveSurvivingSegments)
    }
}
