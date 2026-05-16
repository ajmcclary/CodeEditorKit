#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#else
import Foundation
#endif

// MARK: - UTF16RangeConverter

/// Conversions between the editor's UTF-16 `NSRange` lingua franca and the
/// other coordinate systems used by TextKit2 and Swift `String`. Also owns
/// UTF-16 length and substring extraction so callers don't reach into
/// `.utf16.count` directly.
internal enum UTF16RangeConverter {
    /// UTF-16 code-unit length used by `NSRange`, `NSTextStorage`, and TextKit.
    static func utf16Length(of text: String) -> Int {
        text.utf16.count
    }

    /// Full UTF-16 `NSRange` of a Swift string.
    static func fullRange(in text: String) -> NSRange {
        NSRange(location: 0, length: utf16Length(of: text))
    }

    // MARK: - NSRange ↔ NSTextRange (TextKit2)

    /// Converts a UTF-16 `NSRange` to a TextKit2 text range.
    static func convert(_ nsRange: NSRange, in textContentManager: NSTextContentManager) -> NSTextRange? {
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

    /// Converts a TextKit2 text range to a UTF-16 `NSRange`.
    static func convert(_ textRange: NSTextRange, in textContentManager: NSTextContentManager) -> NSRange? {
        let documentRange = textContentManager.documentRange
        let startOffset = textContentManager.offset(from: documentRange.location, to: textRange.location)
        let length = textContentManager.offset(from: textRange.location, to: textRange.endLocation)

        guard startOffset != NSNotFound, length != NSNotFound else { return nil }

        return NSRange(location: startOffset, length: length)
    }

    // MARK: - NSRange ↔ Range<String.Index>

    /// Converts a Swift string range to a UTF-16 `NSRange`.
    static func convert(_ range: Range<String.Index>, in string: String) -> NSRange {
        NSRange(range, in: string)
    }

    /// Converts a UTF-16 `NSRange` to a Swift string range.
    static func convert(_ nsRange: NSRange, in string: String) -> Range<String.Index>? {
        Range(nsRange, in: string)
    }

    // MARK: - Substring Extraction

    /// Converts a UTF-16 `NSRange` into a Swift substring.
    static func substring(inUTF16Range range: NSRange, from text: String) -> String? {
        guard let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    /// Returns text before a UTF-16 offset, clamped to the document bounds.
    static func substring(upToUTF16Offset offset: Int, in text: String) -> String {
        let clampedOffset = max(0, min(offset, utf16Length(of: text)))
        return substring(
            inUTF16Range: NSRange(location: 0, length: clampedOffset),
            from: text
        ) ?? ""
    }

    /// Returns the character immediately before a UTF-16 offset.
    static func characterBeforeUTF16Offset(_ offset: Int, in text: String) -> Character? {
        substring(upToUTF16Offset: offset, in: text).last
    }

    /// Expands a UTF-16 range to valid Swift `String` character boundaries.
    static func characterAlignedRange(_ range: NSRange, in text: String) -> NSRange? {
        let textLength = utf16Length(of: text)
        let clampedRange = RangeValidationPolicy.clamp(range, toTextLength: textLength)
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
}
