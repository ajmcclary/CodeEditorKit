#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension NSTextContentManager {
    func location(at offset: Int) -> NSTextLocation? {
        location(documentRange.location, offsetBy: offset)
    }

    var length: Int {
        offset(from: documentRange.location, to: documentRange.endLocation)
    }

    func location(line lineIdx: Int, character characterIdx: Int? = 0) -> NSTextLocation? {
        let linesTextElements = textElements(for: documentRange)
        guard linesTextElements.indices ~= lineIdx else {
            // https://forums.swift.org/t/invalid-diagnostic-location-after-text-edit/54761
            // kLogger.warning("Invalid region line: \(lineIdx). ")
            return nil
        }

        guard let startLocation = linesTextElements[lineIdx].elementRange?.location else {
            return nil
        }

        return location(startLocation, offsetBy: characterIdx ?? 0)
    }

    func position(_ location: NSTextLocation) -> (row: Int, column: Int)? {
        let linesElements = textElements(for: documentRange)
        if linesElements.isEmpty {
            return nil
        }

        let lineIdx: Int? = if location == documentRange.endLocation {
            max(0, linesElements.count - 1)
        } else if let foundLineIdx = linesElements.firstIndex(where: { element in
            guard let elementRange = element.elementRange else { return false }
            return elementRange.contains(location)
        }) {
            foundLineIdx
        } else {
            nil
        }

        guard let lineIdx,
              let elementRange = linesElements[lineIdx].elementRange else {
            return nil
        }

        let column = offset(from: elementRange.location, to: location)
        return (row: lineIdx, column: column)
    }

    /// Attributed string for the range
    /// - Parameter range: Text range, or nil for the whole document.
    /// - Returns: Attributed string, or nil.
    func attributedString(in range: NSTextRange?) -> NSAttributedString? {
        if let range, range.isEmpty {
            return nil
        }

        // fast path
        if let textContentStorage = self as? NSTextContentStorage {
            if let range {
                return textContentStorage.textStorage?.attributedSubstring(from: NSRange(range, in: self))
            } else {
                return textContentStorage.textStorage
            }
        }

        // slow path
        let result = NSMutableAttributedString()
        result.beginEditing()
        enumerateTextElements(from: range?.location) { textElement in
            if let range,
               let textParagraph = textElement as? NSTextParagraph,
               let elementRange = textElement.elementRange,
               let textContentManager = textElement.textContentManager {
                var shouldStop = false
                var needAdjustment = false
                var constrainedElementRange = elementRange
                if elementRange.contains(range.location) {
                    // start location
                    constrainedElementRange = NSTextRange(
                        location: range.location,
                        end: constrainedElementRange.endLocation
                    )!
                    needAdjustment = true
                }

                if elementRange.contains(range.endLocation) {
                    // end location
                    constrainedElementRange = NSTextRange(
                        location: constrainedElementRange.location,
                        end: range.endLocation
                    )!
                    needAdjustment = true
                    shouldStop = true
                }

                if needAdjustment {
                    if let constrainedRangeInDocument = NSTextRange(
                        location: constrainedElementRange.location,
                        end: constrainedElementRange.endLocation
                    ) {
                        let constrainedRangeInDocumentLength = constrainedRangeInDocument.length(in: textContentManager)
                        let leadingOffset = textContentManager.offset(
                            from: elementRange.location,
                            to: constrainedElementRange.location
                        )

                        // translate contentRangeInDocument from document namespace to textElement.attributedString namespace
                        let nsRangeInDocumentDocument = NSRange(
                            location: leadingOffset,
                            length: constrainedRangeInDocumentLength
                        )

                        result.append(
                            textParagraph.attributedString.attributedSubstring(from: nsRangeInDocumentDocument)
                        )
                    }
                } else {
                    result.append(
                        textParagraph.attributedString
                    )
                }

                if shouldStop {
                    return false
                }
            } else if range == nil, let textParagraph = textElement as? NSTextParagraph {
                result.append(
                    textParagraph.attributedString
                )
            }

            return true
        }

        result.fixAttributes(in: NSRange(location: 0, length: result.length))
        result.endEditing()
        if result.length == 0 {
            return nil
        }

        return result
    }

    /// Returns an array of text elements that intersect with the range you specify.
    /// - Parameter range: An NSTextRange that describes the range of text to process.
    /// - Returns: An array of NSTextElement.
    ///
    /// This method can return a set of elements that don't fill the entire range if the entire range isn't synchronously available. Uses `enumerateTextElements(from:options:using:)` to fill the array.
    ///
    /// This is working implementation, in contrary to buggy `textElements(for:)` (FB10019859)
    func textElementsNotBuggy(for range: NSTextRange) -> [NSTextElement] {
        var elements: [NSTextElement] = []

        if range.location == documentRange.endLocation {
            // last element is technically beyond the textElement.endLocation
            // but still.
            enumerateTextElements(from: range.endLocation, options: .reverse) { textElement in
                elements.append(textElement)
                return false
            }
        } else {
            enumerateTextElements(from: range.location, options: []) { textElement in
                var shouldCountinue = true
                if let elementRange = textElement.elementRange {
                    if range.intersects(elementRange) || elementRange.contains(range.location) {
                        elements.append(textElement)
                    } else {
                        shouldCountinue = false
                    }
                }

                return shouldCountinue
            }
        }
        return elements
    }
}
