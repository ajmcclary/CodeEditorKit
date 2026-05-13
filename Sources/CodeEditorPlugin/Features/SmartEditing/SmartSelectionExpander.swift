import Foundation

// MARK: - Smart Selection Expander

/// Handles intelligent selection expansion
@MainActor
public enum SmartSelectionExpander {
    // MARK: - Expand Selection

    /// Expand selection to logical boundaries
    /// - Parameter textView: The code editor view
    public static func expandSelection(in textView: CodeEditorView) {
        let currentRange = textView.selectedRange

        // Try different expansion levels
        if let expandedRange = expandToWord(from: currentRange, in: textView) {
            textView.selectedRange = expandedRange
        } else if let expandedRange = expandToLine(from: currentRange, in: textView) {
            textView.selectedRange = expandedRange
        } else if let expandedRange = expandToBrackets(from: currentRange, in: textView) {
            textView.selectedRange = expandedRange
        }
    }

    // MARK: - Word Expansion

    /// Expand selection to word boundaries
    /// - Parameters:
    ///   - range: The current selection range
    ///   - textView: The code editor view
    /// - Returns: The expanded range, or nil if expansion not possible
    public static func expandToWord(from range: NSRange, in textView: CodeEditorView) -> NSRange? {
        guard let text = textView.text else { return nil }
        return TextRangeUtilities.wordRange(at: range.location, in: text)
    }

    // MARK: - Line Expansion

    /// Expand selection to line boundaries
    /// - Parameters:
    ///   - range: The current selection range
    ///   - textView: The code editor view
    /// - Returns: The expanded range, or nil if expansion not possible
    public static func expandToLine(from range: NSRange, in textView: CodeEditorView) -> NSRange? {
        guard let text = textView.text else { return nil }
        return TextRangeUtilities.lineRange(containing: range.location, in: text)
    }

    // MARK: - Bracket Expansion

    /// Expand selection to enclosing brackets
    /// - Parameters:
    ///   - range: The current selection range
    ///   - textView: The code editor view
    /// - Returns: The expanded range, or nil if expansion not possible
    public static func expandToBrackets(from range: NSRange, in textView: CodeEditorView) -> NSRange? {
        guard let text = textView.text else { return nil }

        // Find enclosing brackets
        var startPos = range.location
        var endPos = NSMaxRange(range)

        // Stack to track bracket pairs
        var bracketStack: [Character] = []

        // Search backward for opening bracket
        while startPos > 0 {
            startPos -= 1
            guard let charIndex = text.utf16.index(
                text.utf16.startIndex,
                offsetBy: startPos,
                limitedBy: text.utf16.endIndex
            ) else { break }

            let char = text.utf16[charIndex]
            // Handle surrogate pairs safely
            guard let scalar = UnicodeScalar(char),
                  !UTF16.isLeadSurrogate(char) && !UTF16.isTrailSurrogate(char) else {
                continue
            }
            let unicodeChar = Character(scalar)

            if [")", "]", "}"].contains(unicodeChar) {
                bracketStack.append(unicodeChar)
            } else if ["(", "[", "{"].contains(unicodeChar) {
                if bracketStack.isEmpty {
                    // Found unmatched opening bracket
                    break
                } else {
                    bracketStack.removeLast()
                }
            }
        }

        // Search forward for closing bracket
        bracketStack.removeAll()
        while endPos < text.utf16.count {
            guard let charIndex = text.utf16.index(
                text.utf16.startIndex,
                offsetBy: endPos,
                limitedBy: text.utf16.endIndex
            ) else { break }

            let char = text.utf16[charIndex]
            // Handle surrogate pairs safely
            guard let scalar = UnicodeScalar(char),
                  !UTF16.isLeadSurrogate(char) && !UTF16.isTrailSurrogate(char) else {
                endPos += 1
                continue
            }
            let unicodeChar = Character(scalar)

            if ["(", "[", "{"].contains(unicodeChar) {
                bracketStack.append(unicodeChar)
            } else if [")", "]", "}"].contains(unicodeChar) {
                if bracketStack.isEmpty {
                    // Found unmatched closing bracket
                    endPos += 1
                    break
                } else {
                    bracketStack.removeLast()
                }
            }
            endPos += 1
        }

        // Return expanded range if we found brackets
        if startPos < range.location && endPos > NSMaxRange(range) {
            return NSRange(location: startPos, length: endPos - startPos)
        }

        return nil
    }
}
