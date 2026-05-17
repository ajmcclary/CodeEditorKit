import Foundation

// MARK: - RangeValidationPolicy

/// Validation, clamping, and normalization of UTF-16 ranges against text
/// bounds. Owns the validation result vocabulary that callers use to
/// distinguish "valid" from "corrected" from "invalid with reason".
internal enum RangeValidationPolicy {
    // MARK: - Result Types

    /// Results of range validation operations with detailed error information.
    enum ValidationResult {
        case valid
        case invalid(reason: FailureReason)
        case corrected(originalRange: NSRange, correctedRange: NSRange)

        enum FailureReason {
            case negativeLocation
            case negativeLength
            case exceedsTextBounds(textLength: Int)
            case invalidLocation(location: Int, textLength: Int)
            case emptyRange
        }
    }

    // MARK: - Validation

    /// Validates a range against a text's UTF-16 length.
    static func validateRange(_ range: NSRange, in text: String) -> ValidationResult {
        validateRange(range, textLength: UTF16RangeConverter.utf16Length(of: text))
    }

    /// Validates a range against an explicit text length.
    static func validateRange(_ range: NSRange, textLength: Int) -> ValidationResult {
        if range.location < 0 {
            let corrected = NSRange(location: 0, length: range.length)
            return .corrected(originalRange: range, correctedRange: corrected)
        }

        if range.length < 0 {
            return .invalid(reason: .negativeLength)
        }

        if range.location > textLength {
            return .invalid(reason: .invalidLocation(location: range.location, textLength: textLength))
        }

        if NSMaxRange(range) > textLength {
            let maxLength = textLength - range.location
            let corrected = NSRange(location: range.location, length: maxLength)
            return .corrected(originalRange: range, correctedRange: corrected)
        }

        if range.length == 0 {
            return .valid // Empty ranges are often valid (cursor positions).
        }

        return .valid
    }

    /// Whether the range is within UTF-16 string bounds.
    package static func isValid(_ range: NSRange, in string: String) -> Bool {
        guard range.location >= 0, range.length >= 0 else { return false }
        return NSMaxRange(range) <= UTF16RangeConverter.utf16Length(of: string)
    }

    // MARK: - Clamping & Normalization

    /// Clamps a range to fit within specified bounds.
    package static func clampRange(_ range: NSRange, to bounds: NSRange) -> NSRange {
        let clampedLocation = max(bounds.location, min(range.location, NSMaxRange(bounds)))
        let maxLength = NSMaxRange(bounds) - clampedLocation
        let clampedLength = max(0, min(range.length, maxLength))

        return NSRange(location: clampedLocation, length: clampedLength)
    }

    /// Clamps a range to a text length.
    package static func clamp(_ range: NSRange, toTextLength textLength: Int) -> NSRange {
        clampRange(range, to: NSRange(location: 0, length: textLength))
    }

    /// Clamps a UTF-16 range to the bounds of a string.
    package static func clamp(_ range: NSRange, to string: String) -> NSRange {
        clamp(range, toTextLength: UTF16RangeConverter.utf16Length(of: string))
    }

    /// Normalizes a range by ensuring valid bounds and handling edge cases.
    static func normalizeRange(_ range: NSRange, textLength: Int) -> NSRange {
        let location = max(0, min(range.location, textLength))
        let maxLength = textLength - location
        let length = max(0, min(range.length, maxLength))

        return NSRange(location: location, length: length)
    }
}
