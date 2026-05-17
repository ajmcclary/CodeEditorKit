#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#else
import Foundation
#endif

// swiftlint:disable missing_docs
// Every method on the facade is a one-line delegation. Documentation lives
// on the focused modules (`UTF16RangeConverter`, `RangeValidationPolicy`,
// `LineRangeIndex`, `RangeSetOperations`, `RangeBatchPlanner`) so it doesn't
// drift out of sync with two copies on every change.

// MARK: - TextRangeUtilities (Public Facade)

/// Compatibility facade over the focused range modules. Every method is a
/// one-line delegation; the implementations live in `UTF16RangeConverter`,
/// `RangeValidationPolicy`, `LineRangeIndex`, `RangeSetOperations`, and
/// `RangeBatchPlanner`. New code should prefer the focused modules directly.
///
/// All offsets and lengths are UTF-16 code units to match `NSRange` and TextKit.
public enum TextRangeUtilities {
    // MARK: - Re-exposed Public Types

    /// Result vocabulary for range validation. Backed by `RangeValidationPolicy.ValidationResult`.
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

        init(_ underlying: RangeValidationPolicy.ValidationResult) {
            switch underlying {
            case .valid:
                self = .valid

            case let .invalid(reason):
                self = .invalid(reason: ValidationFailureReason(reason))

            case let .corrected(originalRange, correctedRange):
                self = .corrected(originalRange: originalRange, correctedRange: correctedRange)
            }
        }
    }

    /// Overlap relationship between two ranges. Backed by `RangeSetOperations.OverlapInfo`.
    public struct RangeOverlapInfo {
        public let overlapRange: NSRange?
        public let overlapLength: Int
        public let overlapType: OverlapType

        public enum OverlapType {
            case noOverlap
            case partial
            case complete
            case identical
        }

        public var hasOverlap: Bool {
            overlapType != .noOverlap
        }

        init(_ underlying: RangeSetOperations.OverlapInfo) {
            self.overlapRange = underlying.overlapRange
            self.overlapLength = underlying.overlapLength
            self.overlapType = OverlapType(underlying.overlapType)
        }
    }

    /// Batch range descriptor. Backed by `RangeBatchPlanner.BatchRange`.
    public struct BatchRange {
        public let range: NSRange
        public let batchIndex: Int
        public let isLastBatch: Bool
        public let estimatedProcessingTime: TimeInterval

        init(_ underlying: RangeBatchPlanner.BatchRange) {
            self.range = underlying.range
            self.batchIndex = underlying.batchIndex
            self.isLastBatch = underlying.isLastBatch
            self.estimatedProcessingTime = underlying.estimatedProcessingTime
        }
    }

    // MARK: - Conversion (→ UTF16RangeConverter)

    public static func convert(_ nsRange: NSRange, in textContentManager: NSTextContentManager) -> NSTextRange? {
        UTF16RangeConverter.convert(nsRange, in: textContentManager)
    }

    public static func convert(_ textRange: NSTextRange, in textContentManager: NSTextContentManager) -> NSRange? {
        UTF16RangeConverter.convert(textRange, in: textContentManager)
    }

    public static func convert(_ range: Range<String.Index>, in string: String) -> NSRange {
        UTF16RangeConverter.convert(range, in: string)
    }

    public static func convert(_ nsRange: NSRange, in string: String) -> Range<String.Index>? {
        UTF16RangeConverter.convert(nsRange, in: string)
    }

    public static func utf16Length(of text: String) -> Int {
        UTF16RangeConverter.utf16Length(of: text)
    }

    public static func fullRange(in text: String) -> NSRange {
        UTF16RangeConverter.fullRange(in: text)
    }

    public static func substring(inUTF16Range range: NSRange, from text: String) -> String? {
        UTF16RangeConverter.substring(inUTF16Range: range, from: text)
    }

    public static func substring(upToUTF16Offset offset: Int, in text: String) -> String {
        UTF16RangeConverter.substring(upToUTF16Offset: offset, in: text)
    }

    public static func characterBeforeUTF16Offset(_ offset: Int, in text: String) -> Character? {
        UTF16RangeConverter.characterBeforeUTF16Offset(offset, in: text)
    }

    public static func characterAlignedRange(_ range: NSRange, in text: String) -> NSRange? {
        UTF16RangeConverter.characterAlignedRange(range, in: text)
    }

    // MARK: - Validation (→ RangeValidationPolicy)

    public static func validateRange(_ range: NSRange, in text: String) -> RangeValidationResult {
        RangeValidationResult(RangeValidationPolicy.validateRange(range, in: text))
    }

    public static func validateRange(_ range: NSRange, textLength: Int) -> RangeValidationResult {
        RangeValidationResult(RangeValidationPolicy.validateRange(range, textLength: textLength))
    }

    public static func isValid(_ range: NSRange, in string: String) -> Bool {
        RangeValidationPolicy.isValid(range, in: string)
    }

    public static func clampRange(_ range: NSRange, to bounds: NSRange) -> NSRange {
        RangeValidationPolicy.clampRange(range, to: bounds)
    }

    public static func clampRange(_ range: NSRange, toTextLength textLength: Int) -> NSRange {
        RangeValidationPolicy.clamp(range, toTextLength: textLength)
    }

    public static func clamp(_ range: NSRange, to string: String) -> NSRange {
        RangeValidationPolicy.clamp(range, to: string)
    }

    public static func normalizeRange(_ range: NSRange, textLength: Int) -> NSRange {
        RangeValidationPolicy.normalizeRange(range, textLength: textLength)
    }

    // MARK: - Line / Word / Identifier (→ LineRangeIndex)

    public static func lineRange(containingUTF16Offset offset: Int, in text: String) -> NSRange {
        LineRangeIndex.lineRange(containingUTF16Offset: offset, in: text)
    }

    public static func lineText(containingUTF16Offset offset: Int, in text: String) -> String {
        LineRangeIndex.lineText(containingUTF16Offset: offset, in: text)
    }

    public static func lineRanges(in string: String) -> [NSRange] {
        LineRangeIndex.lineRanges(in: string)
    }

    public static func lineNumber(for offset: Int, in string: String) -> Int {
        LineRangeIndex.lineNumber(for: offset, in: string)
    }

    public static func startOfLine(_ lineNumber: Int, in string: String) -> Int? {
        LineRangeIndex.startOfLine(lineNumber, in: string)
    }

    public static func lineRange(containing offset: Int, in string: String) -> NSRange {
        LineRangeIndex.lineRange(containingUTF16Offset: offset, in: string)
    }

    public static func wordRange(at offset: Int, in string: String) -> NSRange? {
        LineRangeIndex.wordRange(at: offset, in: string)
    }

    public static func locationForLine(_ lineIndex: Int, in lines: [String]) -> Int {
        LineRangeIndex.locationForLine(lineIndex, in: lines)
    }

    public static func identifierPrefix(endingAtUTF16Offset offset: Int, in text: String) -> String {
        LineRangeIndex.identifierPrefix(endingAtUTF16Offset: offset, in: text)
    }

    public static func identifierRange(endingAtUTF16Offset offset: Int, in text: String) -> NSRange? {
        LineRangeIndex.identifierRange(endingAtUTF16Offset: offset, in: text)
    }

    public static func isIdentifierCharacter(_ character: Character) -> Bool {
        LineRangeIndex.isIdentifierCharacter(character)
    }

    // MARK: - Set Operations (→ RangeSetOperations)

    public static func applyMutations(_ mutations: [RangeMutation], to range: NSRange) -> NSRange? {
        RangeSetOperations.applyMutations(mutations, to: range)
    }

    public static func merge(_ ranges: [NSRange]) -> [NSRange] {
        RangeSetOperations.merge(ranges)
    }

    public static func mergeOverlappingRanges(_ ranges: [NSRange]) -> [NSRange] {
        RangeSetOperations.merge(ranges)
    }

    public static func findRangeGaps(in ranges: [NSRange], totalLength: Int) -> [NSRange] {
        RangeSetOperations.gaps(in: ranges, totalLength: totalLength)
    }

    public static func calculateRangeOverlap(_ range1: NSRange, _ range2: NSRange) -> RangeOverlapInfo {
        RangeOverlapInfo(RangeSetOperations.overlap(range1, range2))
    }

    public static func range(_ container: NSRange, contains contained: NSRange) -> Bool {
        RangeSetOperations.contains(container, contained)
    }

    public static func contains(_ container: NSRange, _ contained: NSRange) -> Bool {
        RangeSetOperations.contains(container, contained)
    }

    public static func range(_ range1: NSRange, intersects range2: NSRange) -> Bool {
        RangeSetOperations.overlaps(range1, range2)
    }

    public static func overlaps(_ range1: NSRange, _ range2: NSRange) -> Bool {
        RangeSetOperations.overlaps(range1, range2)
    }

    public static func intersect(_ range1: NSRange, _ range2: NSRange) -> NSRange? {
        RangeSetOperations.intersect(range1, range2)
    }

    public static func subtract(_ rangeToRemove: NSRange, from sourceRange: NSRange) -> [NSRange] {
        RangeSetOperations.subtract(rangeToRemove, from: sourceRange)
    }

    public static func adjustRangesForInsertion(
        _ ranges: [NSRange],
        insertionPoint: Int,
        insertionLength: Int
    ) -> [NSRange] {
        RangeSetOperations.adjustForInsertion(ranges, insertionPoint: insertionPoint, insertionLength: insertionLength)
    }

    public static func adjustRangesForDeletion(_ ranges: [NSRange], deletionRange: NSRange) -> [NSRange] {
        RangeSetOperations.adjustForDeletion(ranges, deletionRange: deletionRange)
    }

    public static func distanceBetween(_ range1: NSRange, and range2: NSRange) -> Int {
        RangeSetOperations.distance(between: range1, and: range2)
    }

    public static func expandRange(_ range: NSRange, by amount: Int, maxLength: Int) -> NSRange {
        RangeSetOperations.expand(range, by: amount, maxLength: maxLength)
    }

    public static func contractRange(_ range: NSRange, by amount: Int) -> NSRange {
        RangeSetOperations.contract(range, by: amount)
    }

    // MARK: - Batching (→ RangeBatchPlanner)

    public static func findOptimalBatchRanges(
        totalLength: Int,
        batchSize: Int,
        preferLineBoundaries: Bool = true,
        text: String? = nil
    ) -> [BatchRange] {
        let plan = RangeBatchPlanner.plan(
            totalLength: totalLength,
            batchSize: batchSize,
            preferLineBoundaries: preferLineBoundaries,
            text: text
        )
        return plan.map(BatchRange.init)
    }

    public static func batchProcess<T>(
        ranges: [NSRange],
        in string: String,
        operation: (NSRange, String) -> T
    ) -> [T] {
        RangeBatchPlanner.batchProcess(ranges: ranges, in: string, operation: operation)
    }

    public static func visibleRanges(
        in viewport: CGRect,
        lineHeight: CGFloat,
        totalLines: Int,
        string: String
    ) -> [NSRange] {
        RangeBatchPlanner.visibleRanges(in: viewport, lineHeight: lineHeight, totalLines: totalLines, string: string)
    }
}

// MARK: - Result Bridge Helpers

extension TextRangeUtilities.RangeValidationResult.ValidationFailureReason {
    init(_ underlying: RangeValidationPolicy.ValidationResult.FailureReason) {
        switch underlying {
        case .negativeLocation:
            self = .negativeLocation

        case .negativeLength:
            self = .negativeLength

        case let .exceedsTextBounds(length):
            self = .exceedsTextBounds(textLength: length)

        case let .invalidLocation(location, length):
            self = .invalidLocation(location: location, textLength: length)

        case .emptyRange:
            self = .emptyRange
        }
    }
}

extension TextRangeUtilities.RangeOverlapInfo.OverlapType {
    init(_ underlying: RangeSetOperations.OverlapInfo.OverlapKind) {
        switch underlying {
        case .noOverlap:
            self = .noOverlap

        case .partial:
            self = .partial

        case .complete:
            self = .complete

        case .identical:
            self = .identical
        }
    }
}

// swiftlint:enable missing_docs
