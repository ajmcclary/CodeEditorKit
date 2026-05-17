import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Builds `LineGeometry` arrays from an `NSTextStorage` using `NSString`
/// line enumeration for UTF-16 correctness across emoji, composed characters,
/// and surrogate pairs.
@MainActor
internal enum LineGeometryBuilder {
    /// Enumerate lines in the given text storage and return per-line geometry.
    /// Mirrors `NSString.getLineStart(_:end:contentsEnd:for:)` semantics, and
    /// appends a trailing zero-length record when the document ends with a
    /// line terminator (matching `NSTextStorage`'s view of "an empty line
    /// after the final terminator").
    static func geometries(
        from textStorage: NSTextStorage,
        defaultEstimatedHeight: CGFloat
    ) -> [LineGeometry] {
        // swiftlint:disable:next legacy_objc_type
        let nsString = textStorage.string as NSString
        let length = nsString.length

        guard length > 0 else {
            return [
                LineGeometry(
                    utf16Length: 0,
                    lineEndingLength: 0,
                    estimatedHeight: defaultEstimatedHeight
                )
            ]
        }

        var geometries: [LineGeometry] = []
        var index = 0
        var anyLineTerminated = false

        while index < length {
            var lineStart = 0, lineEnd = 0, contentsEnd = 0
            nsString.getLineStart(
                &lineStart,
                end: &lineEnd,
                contentsEnd: &contentsEnd,
                for: NSRange(location: index, length: 0)
            )
            let utf16Length = lineEnd - lineStart
            let lineEndingLength = lineEnd - contentsEnd
            geometries.append(LineGeometry(
                utf16Length: utf16Length,
                lineEndingLength: lineEndingLength,
                estimatedHeight: defaultEstimatedHeight
            ))
            anyLineTerminated = contentsEnd < lineEnd
            index = lineEnd
            if index >= length { break }
        }

        if anyLineTerminated && index == length {
            geometries.append(LineGeometry(
                utf16Length: 0,
                lineEndingLength: 0,
                estimatedHeight: defaultEstimatedHeight
            ))
        }

        return geometries
    }
}
