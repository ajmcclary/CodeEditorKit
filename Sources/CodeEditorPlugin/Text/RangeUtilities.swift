import Foundation

// MARK: - Range Processing Utilities

/// Consolidated range processing operations that eliminate duplication across
/// RangeValidator, RangeProcessor, NSRange+Extensions, and RangeMutation
public enum TextRangeUtilities {
    // MARK: - Supporting Types

    public enum RangeValidationResult {
        case valid
        case invalid(reason: ValidationFailureReason)
        case corrected(originalRange: NSRange, correctedRange: NSRange)

        public enum ValidationFailureReason {
            case negativeLocation
            case negativeLength
            case exceedsTextBounds(textLength: Int)
            case invalidLocation(location: Int, textLength: Int)
            case emptyRange
        }
    }

    public struct RangeOverlapInfo {
        public let overlapRange: NSRange?
        public let overlapLength: Int
        public let overlapType: OverlapType

        public enum OverlapType {
            case noOverlap
            case partial
            case complete       // One range completely contains the other
            case identical
        }

        public var hasOverlap: Bool {
            overlapType != .noOverlap
        }
    }

    public struct BatchRange {
        public let range: NSRange
        public let batchIndex: Int
        public let isLastBatch: Bool
        public let estimatedProcessingTime: TimeInterval
    }

    // MARK: - Range Validation

    /// Validates a range against text bounds with detailed error information
    /// Consolidates validation logic from RangeValidator and scattered checks
    public static func validateRange(_ range: NSRange, in text: String) -> RangeValidationResult {
        validateRange(range, textLength: text.utf16.count)
    }

    /// Validates a range against text length
    public static func validateRange(_ range: NSRange, textLength: Int) -> RangeValidationResult {
        // Check for negative location
        if range.location < 0 {
            let corrected = NSRange(location: 0, length: range.length)
            return .corrected(originalRange: range, correctedRange: corrected)
        }

        // Check for negative length
        if range.length < 0 {
            return .invalid(reason: .negativeLength)
        }

        // Check if location exceeds text bounds
        if range.location > textLength {
            return .invalid(reason: .invalidLocation(location: range.location, textLength: textLength))
        }

        // Check if range exceeds text bounds
        if NSMaxRange(range) > textLength {
            let maxLength = textLength - range.location
            let corrected = NSRange(location: range.location, length: maxLength)
            return .corrected(originalRange: range, correctedRange: corrected)
        }

        // Check for empty range (depending on use case, this might be valid)
        if range.length == 0 {
            return .valid // Empty ranges are often valid for cursor positions
        }

        return .valid
    }

    /// Clamps a range to fit within specified bounds
    /// Consolidates clamping logic from NSRange+Extensions
    public static func clampRange(_ range: NSRange, to bounds: NSRange) -> NSRange {
        let clampedLocation = max(bounds.location, min(range.location, NSMaxRange(bounds)))
        let maxLength = NSMaxRange(bounds) - clampedLocation
        let clampedLength = max(0, min(range.length, maxLength))

        return NSRange(location: clampedLocation, length: clampedLength)
    }

    /// Clamps a range to text length
    public static func clampRange(_ range: NSRange, toTextLength textLength: Int) -> NSRange {
        clampRange(range, to: NSRange(location: 0, length: textLength))
    }

    /// Normalizes a range by ensuring valid bounds and handling edge cases
    public static func normalizeRange(_ range: NSRange, textLength: Int) -> NSRange {
        let location = max(0, min(range.location, textLength))
        let maxLength = textLength - location
        let length = max(0, min(range.length, maxLength))

        return NSRange(location: location, length: length)
    }

    // MARK: - Range Transformations

    /// Applies mutations to a range with proper bounds checking
    /// Consolidates mutation logic from RangeMutation
    public static func applyMutations(_ mutations: [RangeMutation], to range: NSRange) -> NSRange? {
        var workingRange = range

        for mutation in mutations.sorted(by: { $0.range.location < $1.range.location }) {
            guard let transformedRange = applyMutation(mutation, to: workingRange) else {
                return nil // Mutation invalidated the range
            }
            workingRange = transformedRange
        }

        return workingRange
    }

    /// Merges overlapping ranges into consolidated ranges
    public static func mergeOverlappingRanges(_ ranges: [NSRange]) -> [NSRange] {
        guard !ranges.isEmpty else { return [] }

        let sortedRanges = ranges.sorted { $0.location < $1.location }
        var mergedRanges: [NSRange] = []
        var currentRange = sortedRanges[0]

        for range in sortedRanges.dropFirst() {
            if range.location <= NSMaxRange(currentRange) {
                // Ranges overlap or are adjacent, merge them
                let endLocation = max(NSMaxRange(currentRange), NSMaxRange(range))
                currentRange = NSRange(location: currentRange.location, length: endLocation - currentRange.location)
            } else {
                // No overlap, add current range and start new one
                mergedRanges.append(currentRange)
                currentRange = range
            }
        }

        mergedRanges.append(currentRange)
        return mergedRanges
    }

    /// Finds gaps between ranges in a text of given length
    public static func findRangeGaps(in ranges: [NSRange], totalLength: Int) -> [NSRange] {
        guard !ranges.isEmpty else {
            return [NSRange(location: 0, length: totalLength)]
        }

        let mergedRanges = mergeOverlappingRanges(ranges)
        var gaps: [NSRange] = []

        // Gap before first range
        if mergedRanges[0].location > 0 {
            gaps.append(NSRange(location: 0, length: mergedRanges[0].location))
        }

        // Gaps between ranges
        for index in 0..<mergedRanges.count - 1 {
            let currentEnd = NSMaxRange(mergedRanges[index])
            let nextStart = mergedRanges[index + 1].location

            if nextStart > currentEnd {
                gaps.append(NSRange(location: currentEnd, length: nextStart - currentEnd))
            }
        }

        // Gap after last range
        if let lastRange = mergedRanges.last {
            let lastEnd = NSMaxRange(lastRange)
            if lastEnd < totalLength {
                gaps.append(NSRange(location: lastEnd, length: totalLength - lastEnd))
            }
        }

        return gaps
    }

    // MARK: - Range Analysis

    /// Calculates detailed overlap information between two ranges
    /// Enhanced version of overlap calculation found in multiple files
    public static func calculateRangeOverlap(_ range1: NSRange, _ range2: NSRange) -> RangeOverlapInfo {
        let start1 = range1.location
        let end1 = NSMaxRange(range1)
        let start2 = range2.location
        let end2 = NSMaxRange(range2)

        // Check for no overlap
        if end1 <= start2 || end2 <= start1 {
            return RangeOverlapInfo(overlapRange: nil, overlapLength: 0, overlapType: .noOverlap)
        }

        // Calculate overlap range
        let overlapStart = max(start1, start2)
        let overlapEnd = min(end1, end2)
        let overlapRange = NSRange(location: overlapStart, length: overlapEnd - overlapStart)
        let overlapLength = overlapRange.length

        // Determine overlap type
        let overlapType: RangeOverlapInfo.OverlapType
        if range1 == range2 {
            overlapType = .identical
        } else if (start1 <= start2 && end1 >= end2) || (start2 <= start1 && end2 >= end1) {
            overlapType = .complete
        } else {
            overlapType = .partial
        }

        return RangeOverlapInfo(
            overlapRange: overlapRange,
            overlapLength: overlapLength,
            overlapType: overlapType
        )
    }

    /// Finds optimal batch ranges for processing large text efficiently
    /// Consolidates batching logic from AsyncTextProcessor
    public static func findOptimalBatchRanges(
        totalLength: Int,
        batchSize: Int,
        preferLineBoundaries: Bool = true,
        text: String? = nil
    ) -> [BatchRange] {
        guard totalLength > 0 && batchSize > 0 else { return [] }

        var batches: [BatchRange] = []
        var currentLocation = 0
        var batchIndex = 0

        while currentLocation < totalLength {
            let remainingLength = totalLength - currentLocation
            var batchLength = min(batchSize, remainingLength)

            // Try to end at line boundary if possible
            if preferLineBoundaries && batchLength < remainingLength, let text {
                batchLength = adjustBatchLengthToLineBoundary(
                    text: text,
                    startLocation: currentLocation,
                    targetLength: batchLength
                )
            }

            let range = NSRange(location: currentLocation, length: batchLength)
            let isLastBatch = NSMaxRange(range) >= totalLength
            let estimatedTime = estimateProcessingTime(for: batchLength)

            batches.append(BatchRange(
                range: range,
                batchIndex: batchIndex,
                isLastBatch: isLastBatch,
                estimatedProcessingTime: estimatedTime
            ))

            currentLocation += batchLength
            batchIndex += 1
        }

        return batches
    }

    // MARK: - Range Utilities

    /// Checks if a range contains another range
    public static func range(_ container: NSRange, contains contained: NSRange) -> Bool {
        container.location <= contained.location &&
               NSMaxRange(container) >= NSMaxRange(contained)
    }

    /// Checks if a range intersects with another range
    public static func range(_ range1: NSRange, intersects range2: NSRange) -> Bool {
        calculateRangeOverlap(range1, range2).hasOverlap
    }

    /// Calculates the distance between two ranges
    public static func distanceBetween(_ range1: NSRange, and range2: NSRange) -> Int {
        if range(range1, intersects: range2) {
            return 0 // Overlapping ranges have zero distance
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

    /// Expands a range by the specified amount in both directions
    public static func expandRange(_ range: NSRange, by amount: Int, maxLength: Int) -> NSRange {
        let newLocation = max(0, range.location - amount)
        let newEnd = min(maxLength, NSMaxRange(range) + amount)
        return NSRange(location: newLocation, length: newEnd - newLocation)
    }

    /// Contracts a range by the specified amount from both directions
    public static func contractRange(_ range: NSRange, by amount: Int) -> NSRange {
        let newLocation = range.location + amount
        let newLength = max(0, range.length - (amount * 2))
        return NSRange(location: newLocation, length: newLength)
    }
}

// MARK: - Private Helpers

extension TextRangeUtilities {
    static func applyMutation(_ mutation: RangeMutation, to range: NSRange) -> NSRange? {
        let mutationRange = mutation.range

        if range.location >= NSMaxRange(mutationRange) {
            // Range is after mutation, adjust location
            let offset = mutation.delta
            return NSRange(location: range.location + offset, length: range.length)
        } else if NSMaxRange(range) <= mutationRange.location {
            // Range is before mutation, no change needed
            return range
        } else {
            // Range overlaps with mutation, this is complex and depends on mutation type
            // For safety, we'll return nil to indicate the range is invalidated
            return nil
        }
    }

    static func adjustBatchLengthToLineBoundary(text: String, startLocation: Int, targetLength: Int) -> Int {
        let endLocation = min(startLocation + targetLength, text.count)
        let searchRange = text.index(text.startIndex, offsetBy: startLocation)..<text.index(text.startIndex, offsetBy: endLocation)

        // Look for the last newline within the target range
        if let lastNewlineRange = text.range(of: "\n", options: .backwards, range: searchRange) {
            let newlineLocation = text.distance(from: text.startIndex, to: lastNewlineRange.upperBound)
            return newlineLocation - startLocation
        }

        return targetLength // No newline found, use original length
    }

    static func estimateProcessingTime(for length: Int) -> TimeInterval {
        // Simple heuristic: 1ms per 1000 characters
        Double(length) / 1_000.0 * 0.001
    }
}
