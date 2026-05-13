#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#else
import Foundation
#endif

// MARK: - Range Processing Utilities

/// Consolidated range processing operations that eliminate duplication across
/// RangeValidator, RangeProcessor, NSRange+Extensions, and RangeMutation.
/// All offsets and lengths are UTF-16 code units to match `NSRange` and TextKit.
public enum TextRangeUtilities {
    // MARK: - Supporting Types

    /// Results of range validation operations with detailed error information.
    public enum RangeValidationResult {
        /// The range is valid and can be used safely.
        case valid
        /// The range is invalid with a specific reason for the failure.
        case invalid(reason: ValidationFailureReason)
        /// The range was corrected to fit within valid bounds.
        case corrected(originalRange: NSRange, correctedRange: NSRange)

        /// Specific reasons why range validation might fail.
        public enum ValidationFailureReason {
            /// The range location is negative.
            case negativeLocation
            /// The range length is negative.
            case negativeLength
            /// The range extends beyond the text boundaries.
            case exceedsTextBounds(textLength: Int)
            /// The range location is beyond the text length.
            case invalidLocation(location: Int, textLength: Int)
            /// The range has zero length (may be valid in some contexts).
            case emptyRange
        }
    }

    /// Detailed information about how two ranges overlap or relate to each other.
    public struct RangeOverlapInfo {
        /// The range of overlap between two ranges, if any.
        public let overlapRange: NSRange?
        /// The length of the overlapping region.
        public let overlapLength: Int
        /// The type of overlap relationship between the ranges.
        public let overlapType: OverlapType

        /// Categories describing how two ranges relate to each other.
        public enum OverlapType {
            /// The ranges do not overlap at all.
            case noOverlap
            /// The ranges partially overlap.
            case partial
            /// One range completely contains the other.
            case complete
            /// The ranges are identical.
            case identical
        }

        /// Whether the ranges have any overlap.
        public var hasOverlap: Bool {
            overlapType != .noOverlap
        }
    }

    /// Information about a batch range for processing large text efficiently.
    public struct BatchRange {
        /// The range of text covered by this batch.
        public let range: NSRange
        /// The sequential index of this batch in the processing order.
        public let batchIndex: Int
        /// Whether this is the final batch in the sequence.
        public let isLastBatch: Bool
        /// Estimated time required to process this batch.
        public let estimatedProcessingTime: TimeInterval
    }

    // MARK: - Range Validation

    // MARK: - Range Conversion

    /// Converts a UTF-16 `NSRange` to a TextKit text range.
    public static func convert(_ nsRange: NSRange, in textContentManager: NSTextContentManager) -> NSTextRange? {
        guard nsRange.location >= 0, nsRange.length >= 0 else { return nil }

        let documentRange = textContentManager.documentRange
        guard
            let startLocation = textContentManager.location(documentRange.location, offsetBy: nsRange.location),
            let endLocation = textContentManager.location(startLocation, offsetBy: nsRange.length)
        else {
            return nil
        }

        return NSTextRange(location: startLocation, end: endLocation)
    }

    /// Converts a TextKit text range to a UTF-16 `NSRange`.
    public static func convert(_ textRange: NSTextRange, in textContentManager: NSTextContentManager) -> NSRange? {
        let documentRange = textContentManager.documentRange
        let startOffset = textContentManager.offset(from: documentRange.location, to: textRange.location)
        let length = textContentManager.offset(from: textRange.location, to: textRange.endLocation)

        guard startOffset != NSNotFound, length != NSNotFound else { return nil }

        return NSRange(location: startOffset, length: length)
    }

    /// Converts a Swift string range to a UTF-16 `NSRange`.
    public static func convert(_ range: Range<String.Index>, in string: String) -> NSRange {
        NSRange(range, in: string)
    }

    /// Converts a UTF-16 `NSRange` to a Swift string range.
    public static func convert(_ nsRange: NSRange, in string: String) -> Range<String.Index>? {
        Range(nsRange, in: string)
    }

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

    /// Returns whether the range is within UTF-16 string bounds.
    public static func isValid(_ range: NSRange, in string: String) -> Bool {
        guard range.location >= 0, range.length >= 0 else { return false }
        return NSMaxRange(range) <= utf16Length(of: string)
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

    /// Clamps a UTF-16 range to the bounds of a string.
    public static func clamp(_ range: NSRange, to string: String) -> NSRange {
        clampRange(range, toTextLength: utf16Length(of: string))
    }

    /// Returns the UTF-16 code-unit length used by `NSRange`, `NSTextStorage`,
    /// and TextKit APIs throughout the editor.
    public static func utf16Length(of text: String) -> Int {
        text.utf16.count
    }

    /// Returns the full UTF-16 `NSRange` of a Swift string.
    public static func fullRange(in text: String) -> NSRange {
        NSRange(location: 0, length: utf16Length(of: text))
    }

    /// Converts a UTF-16 `NSRange` into a Swift substring.
    public static func substring(inUTF16Range range: NSRange, from text: String) -> String? {
        guard let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    /// Returns text before a UTF-16 offset, clamped to the document bounds.
    public static func substring(upToUTF16Offset offset: Int, in text: String) -> String {
        let clampedOffset = max(0, min(offset, utf16Length(of: text)))
        return substring(
            inUTF16Range: NSRange(location: 0, length: clampedOffset),
            from: text
        ) ?? ""
    }

    /// Returns the character immediately before a UTF-16 offset.
    public static func characterBeforeUTF16Offset(_ offset: Int, in text: String) -> Character? {
        substring(upToUTF16Offset: offset, in: text).last
    }

    /// Returns the current identifier prefix ending at a UTF-16 offset.
    public static func identifierPrefix(endingAtUTF16Offset offset: Int, in text: String) -> String {
        let prefix = substring(upToUTF16Offset: offset, in: text)
        var characters: [Character] = []

        for character in prefix.reversed() {
            guard isIdentifierCharacter(character) else { break }
            characters.append(character)
        }

        return String(characters.reversed())
    }

    /// Returns the UTF-16 range for the current identifier ending at an offset.
    public static func identifierRange(endingAtUTF16Offset offset: Int, in text: String) -> NSRange? {
        let clampedOffset = max(0, min(offset, utf16Length(of: text)))
        let prefix = identifierPrefix(endingAtUTF16Offset: clampedOffset, in: text)
        guard !prefix.isEmpty else { return nil }

        let length = utf16Length(of: prefix)
        return NSRange(location: clampedOffset - length, length: length)
    }

    /// Returns whether a character is an identifier constituent for editor features.
    public static func isIdentifierCharacter(_ character: Character) -> Bool {
        let identifierCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return character.unicodeScalars.allSatisfy { identifierCharacters.contains($0) }
    }

    /// Returns the line range containing a UTF-16 offset.
    public static func lineRange(containingUTF16Offset offset: Int, in text: String) -> NSRange {
        // swiftlint:disable:next legacy_objc_type
        let nsText = text as NSString
        guard nsText.length > 0 else {
            return NSRange(location: 0, length: 0)
        }

        let clampedLocation = max(0, min(offset, nsText.length))
        return nsText.lineRange(for: NSRange(location: clampedLocation, length: 0))
    }

    /// Returns the line text containing a UTF-16 offset without trailing newline characters.
    public static func lineText(containingUTF16Offset offset: Int, in text: String) -> String {
        // swiftlint:disable:next legacy_objc_type
        let nsText = text as NSString
        let range = lineRange(containingUTF16Offset: offset, in: text)
        guard NSMaxRange(range) <= nsText.length else { return "" }
        return nsText.substring(with: range).trimmingCharacters(in: .newlines)
    }

    /// Expands a UTF-16 range to valid Swift `String` character boundaries.
    public static func characterAlignedRange(_ range: NSRange, in text: String) -> NSRange? {
        let textLength = utf16Length(of: text)
        let clampedRange = clampRange(range, toTextLength: textLength)
        var start = clampedRange.location

        while start >= 0 {
            var end = NSMaxRange(clampedRange)
            while end <= textLength {
                let candidate = NSRange(location: start, length: end - start)
                if Range(candidate, in: text) != nil {
                    return candidate
                }
                end += 1
            }

            if start == 0 { break }
            start -= 1
        }

        return nil
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
            guard let transformedRange = RangeMutationEngine.transformSingle(
                workingRange,
                applying: mutation,
                policy: .invalidateOnOverlap
            ) else {
                return nil // Mutation invalidated the range
            }
            workingRange = transformedRange
        }

        return workingRange
    }

    /// Merges overlapping or adjacent ranges.
    public static func merge(_ ranges: [NSRange]) -> [NSRange] {
        mergeOverlappingRanges(ranges)
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

    /// Finds optimal batch ranges for processing large text efficiently.
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

    /// Checks if one UTF-16 range contains another.
    public static func contains(_ container: NSRange, _ contained: NSRange) -> Bool {
        range(container, contains: contained)
    }

    /// Checks if a range intersects with another range
    public static func range(_ range1: NSRange, intersects range2: NSRange) -> Bool {
        calculateRangeOverlap(range1, range2).hasOverlap
    }

    /// Checks if two UTF-16 ranges overlap.
    public static func overlaps(_ range1: NSRange, _ range2: NSRange) -> Bool {
        range(range1, intersects: range2)
    }

    /// Returns the non-empty intersection of two UTF-16 ranges.
    public static func intersect(_ range1: NSRange, _ range2: NSRange) -> NSRange? {
        let intersection = NSIntersectionRange(range1, range2)
        return intersection.length > 0 ? intersection : nil
    }

    /// Subtracts one UTF-16 range from another, returning surviving segments.
    public static func subtract(_ rangeToRemove: NSRange, from sourceRange: NSRange) -> [NSRange] {
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

    /// Adjusts ranges after an insertion, expanding ranges that contain the insertion point.
    public static func adjustRangesForInsertion(
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

    /// Adjusts ranges after a deletion, preserving surviving range segments.
    public static func adjustRangesForDeletion(_ ranges: [NSRange], deletionRange: NSRange) -> [NSRange] {
        let mutation = RangeMutation(range: deletionRange, delta: -deletionRange.length)
        return RangeMutationEngine.transform(ranges, applying: mutation, policy: .preserveSurvivingSegments)
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

    // MARK: - Line Utilities

    /// Calculate character offset for a given line index
    /// - Parameters:
    ///   - lineIndex: The zero-based index of the line
    ///   - lines: Array of line strings
    /// - Returns: The character offset from the start of text to the beginning of the line
    public static func locationForLine(_ lineIndex: Int, in lines: [String]) -> Int {
        var location = 0
        for index in 0..<lineIndex {
            location += utf16Length(of: lines[index]) + 1 // +1 for newline
        }
        return location
    }

    /// Returns all UTF-16 line ranges in the string, including line terminators.
    public static func lineRanges(in string: String) -> [NSRange] {
        // swiftlint:disable:next legacy_objc_type
        let nsText = string as NSString
        guard nsText.length > 0 else { return [] }

        var ranges: [NSRange] = []
        var location = 0
        while location < nsText.length {
            let lineRange = nsText.lineRange(for: NSRange(location: location, length: 0))
            ranges.append(lineRange)
            let nextLocation = NSMaxRange(lineRange)
            guard nextLocation > location else { break }
            location = nextLocation
        }
        return ranges
    }

    /// Returns the zero-based line number for a UTF-16 offset.
    public static func lineNumber(for offset: Int, in string: String) -> Int {
        let clampedOffset = max(0, min(offset, utf16Length(of: string)))
        guard clampedOffset > 0 else { return 0 }

        let prefix = substring(upToUTF16Offset: clampedOffset, in: string)
        return prefix.reduce(into: 0) { count, character in
            if character == "\n" {
                count += 1
            }
        }
    }

    /// Returns the UTF-16 range for a zero-based line number.
    public static func startOfLine(_ lineNumber: Int, in string: String) -> Int? {
        let ranges = lineRanges(in: string)
        guard lineNumber >= 0, lineNumber < ranges.count else { return nil }
        return ranges[lineNumber].location
    }

    /// Returns the UTF-16 line range containing an offset.
    public static func lineRange(containing offset: Int, in string: String) -> NSRange {
        lineRange(containingUTF16Offset: offset, in: string)
    }

    /// Returns the identifier-like word range at a UTF-16 offset.
    public static func wordRange(at offset: Int, in string: String) -> NSRange? {
        let clampedOffset = max(0, min(offset, utf16Length(of: string)))
        guard let insertionRange = Range(NSRange(location: clampedOffset, length: 0), in: string) else {
            return nil
        }

        var start = insertionRange.lowerBound
        while start > string.startIndex {
            let previous = string.index(before: start)
            guard isIdentifierCharacter(string[previous]) else { break }
            start = previous
        }

        var end = insertionRange.lowerBound
        while end < string.endIndex, isIdentifierCharacter(string[end]) {
            end = string.index(after: end)
        }

        guard start < end else { return nil }
        return NSRange(start..<end, in: string)
    }

    /// Batch processes UTF-16 ranges in ascending order.
    public static func batchProcess<T>(
        ranges: [NSRange],
        in string: String,
        operation: (NSRange, String) -> T
    ) -> [T] {
        ranges.sorted { $0.location < $1.location }.map { operation($0, string) }
    }

    /// Finds the UTF-16 range visible in a viewport when line metrics are known.
    public static func visibleRanges(
        in viewport: CGRect,
        lineHeight: CGFloat,
        totalLines: Int,
        string: String
    ) -> [NSRange] {
        guard lineHeight > 0, totalLines > 0 else { return [] }

        let firstVisibleLine = max(0, Int(viewport.minY / lineHeight))
        let lastVisibleLine = min(totalLines - 1, Int(viewport.maxY / lineHeight) + 1)
        let ranges = lineRanges(in: string)
        guard firstVisibleLine < ranges.count else { return [] }

        let endLine = min(lastVisibleLine, ranges.count - 1)
        guard firstVisibleLine <= endLine else { return [] }
        let visible = ranges[firstVisibleLine...endLine]
        guard let first = visible.first, let last = visible.last else { return [] }

        return [NSRange(location: first.location, length: NSMaxRange(last) - first.location)]
    }
}

// MARK: - Private Helpers

extension TextRangeUtilities {
    static func adjustBatchLengthToLineBoundary(text: String, startLocation: Int, targetLength: Int) -> Int {
        let textLength = TextRangeUtilities.utf16Length(of: text)
        let endLocation = min(startLocation + targetLength, textLength)
        let searchRange = NSRange(location: startLocation, length: endLocation - startLocation)

        // Look for the last newline within the target range
        if let searchText = TextRangeUtilities.substring(inUTF16Range: searchRange, from: text),
           let lastNewlineRange = searchText.range(of: "\n", options: .backwards) {
            let prefixThroughNewline = searchText[..<lastNewlineRange.upperBound]
            return TextRangeUtilities.utf16Length(of: String(prefixThroughNewline))
        }

        return targetLength // No newline found, use original length
    }

    static func estimateProcessingTime(for length: Int) -> TimeInterval {
        // Simple heuristic: 1ms per 1000 characters
        Double(length) / 1_000.0 * 0.001
    }
}
