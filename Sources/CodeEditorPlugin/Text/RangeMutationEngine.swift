import CodeEditorCommon
import Foundation

/// Policy used when a text edit intersects an existing UTF-16 range.
public enum RangeMutationPolicy: Sendable, Hashable {
    /// Drops ranges that overlap the edit.
    case invalidateOnOverlap
    /// Keeps only portions of existing ranges that survived the edit.
    case preserveSurvivingSegments
    /// Includes inserted text when the insertion point is inside an existing range.
    case expandForInsertions
}

/// Applies text mutations to UTF-16 ranges and index sets.
public enum RangeMutationEngine {
    /// Transforms one range into zero, one, or multiple surviving ranges.
    public static func transform(
        _ range: NSRange,
        applying mutation: RangeMutation,
        policy: RangeMutationPolicy
    ) -> [NSRange] {
        guard range.location != NSNotFound, mutation.range.location != NSNotFound else { return [] }

        let editStart = mutation.range.location
        let editEnd = NSMaxRange(mutation.range)
        let replacementLength = max(0, mutation.range.length + mutation.delta)
        let newEditEnd = editStart + replacementLength

        if mutation.range.length == 0, mutation.delta > 0 {
            return transformInsertion(
                range,
                insertionPoint: editStart,
                insertionLength: mutation.delta,
                policy: policy
            )
        }

        if NSMaxRange(range) <= editStart {
            return [range]
        }

        if range.location >= editEnd {
            return [NSRange(location: max(0, range.location + mutation.delta), length: range.length)]
        }

        guard policy != .invalidateOnOverlap else { return [] }

        var surviving: [NSRange] = []

        if range.location < editStart {
            surviving.append(NSRange(location: range.location, length: editStart - range.location))
        }

        if NSMaxRange(range) > editEnd {
            surviving.append(NSRange(location: newEditEnd, length: NSMaxRange(range) - editEnd))
        }

        if policy == .expandForInsertions, mutation.delta > 0, TextRangeUtilities.contains(range, mutation.range) {
            return [NSRange(location: range.location, length: max(0, range.length + mutation.delta))]
        }

        return surviving.filter { $0.length > 0 }
    }

    /// Transforms one range when callers require a single surviving range.
    public static func transformSingle(
        _ range: NSRange,
        applying mutation: RangeMutation,
        policy: RangeMutationPolicy
    ) -> NSRange? {
        let transformed = transform(range, applying: mutation, policy: policy)
        guard transformed.count == 1 else { return nil }
        return transformed[0]
    }

    /// Transforms an array of ranges and merges adjacent results.
    public static func transform(
        _ ranges: [NSRange],
        applying mutation: RangeMutation,
        policy: RangeMutationPolicy
    ) -> [NSRange] {
        let transformed = ranges.flatMap { transform($0, applying: mutation, policy: policy) }
        return TextRangeUtilities.merge(transformed)
    }

    /// Applies multiple mutations in ascending edit order.
    public static func transform(
        _ ranges: [NSRange],
        applying mutations: [RangeMutation],
        policy: RangeMutationPolicy
    ) -> [NSRange] {
        mutations
            .sorted { $0.range.location < $1.range.location }
            .reduce(ranges) { current, mutation in
                transform(current, applying: mutation, policy: policy)
            }
    }

    /// Transforms an index set by preserving only indices that survived the edit.
    public static func transform(
        _ set: IndexSet,
        applying mutation: RangeMutation,
        policy: RangeMutationPolicy = .preserveSurvivingSegments
    ) -> IndexSet {
        let transformedRanges = transform(set.nsRangeView, applying: mutation, policy: policy)
        return IndexSet(ranges: transformedRanges)
    }

    /// Transforms an index set through multiple edits.
    public static func transform(
        _ set: IndexSet,
        applying mutations: [RangeMutation],
        policy: RangeMutationPolicy = .preserveSurvivingSegments
    ) -> IndexSet {
        mutations.reduce(set) { current, mutation in
            transform(current, applying: mutation, policy: policy)
        }
    }

    private static func transformInsertion(
        _ range: NSRange,
        insertionPoint: Int,
        insertionLength: Int,
        policy: RangeMutationPolicy
    ) -> [NSRange] {
        if NSMaxRange(range) <= insertionPoint {
            return [range]
        }

        if range.location >= insertionPoint {
            return [NSRange(location: range.location + insertionLength, length: range.length)]
        }

        switch policy {
        case .invalidateOnOverlap:
            return []

        case .preserveSurvivingSegments:
            return [
                NSRange(location: range.location, length: insertionPoint - range.location),
                NSRange(location: insertionPoint + insertionLength, length: NSMaxRange(range) - insertionPoint)
            ].filter { $0.length > 0 }

        case .expandForInsertions:
            return [NSRange(location: range.location, length: range.length + insertionLength)]
        }
    }
}
