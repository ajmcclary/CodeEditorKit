import Foundation

// MARK: - Auto Bracketing Engine

/// Handles automatic bracket and quote pair insertion
@MainActor
public enum AutoBracketingEngine {
    // MARK: - Character Insertion

    /// Handle character insertion for auto-bracket functionality
    /// - Parameters:
    ///   - text: The character being inserted
    ///   - range: The range where insertion occurs
    ///   - textView: The code editor view
    ///   - bracketPairs: Available bracket pairs
    ///   - configuration: Smart editing configuration
    /// - Returns: True if the insertion was handled, false otherwise
    public static func handleCharacterInsertion(
        _ text: String,
        at range: NSRange,
        in textView: CodeEditorView,
        bracketPairs: [SmartEditingBracketPair],
        configuration: SmartEditingConfiguration
    ) -> Bool {
        guard configuration.autoInsertBrackets else { return false }

        // Check if this is an opening bracket
        if let pair = bracketPairs.first(where: { $0.open == text }) {
            return handleOpeningBracket(pair, at: range, in: textView)
        }

        // Check if this is a closing bracket
        if let pair = bracketPairs.first(where: { $0.close == text }) {
            return handleClosingBracket(pair, at: range, in: textView)
        }

        return false
    }

    // MARK: - Opening Bracket

    private static func handleOpeningBracket(
        _ pair: SmartEditingBracketPair,
        at range: NSRange,
        in textView: CodeEditorView
    ) -> Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let textStorage = textView.textStorage else { return false }
        #else
        let textStorage = textView.textStorage
        #endif

        // For quotes, check if we should auto-pair
        if pair.isQuote {
            // Don't auto-pair if there's already a matching quote
            if range.location < textStorage.length {
                let nextChar = textStorage.attributedSubstring(
                    from: NSRange(location: range.location, length: 1)
                ).string
                if nextChar == pair.close {
                    // Just move cursor past the quote
                    textView.selectedRange = NSRange(location: range.location + 1, length: 0)
                    return true
                }
            }

            // Don't auto-pair inside words
            if range.location > 0 {
                let prevChar = textStorage.attributedSubstring(
                    from: NSRange(location: range.location - 1, length: 1)
                ).string
                if prevChar.rangeOfCharacter(from: CharacterSet.alphanumerics) != nil {
                    return false
                }
            }
        }

        // Insert both opening and closing brackets
        let insertString = pair.open + pair.close
        textStorage.replaceCharacters(in: range, with: insertString)

        // Position cursor between brackets
        textView.selectedRange = NSRange(location: range.location + 1, length: 0)

        return true
    }

    // MARK: - Closing Bracket

    private static func handleClosingBracket(
        _ pair: SmartEditingBracketPair,
        at range: NSRange,
        in textView: CodeEditorView
    ) -> Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let textStorage = textView.textStorage else { return false }
        #else
        let textStorage = textView.textStorage
        #endif

        // Check if the next character is the same closing bracket
        if range.location < textStorage.length {
            let nextChar = textStorage.attributedSubstring(
                from: NSRange(location: range.location, length: 1)
            ).string

            if nextChar == pair.close {
                // Skip over the closing bracket
                textView.selectedRange = NSRange(location: range.location + 1, length: 0)
                return true
            }
        }

        return false
    }
}
