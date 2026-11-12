import CodeEditorConfiguration
import Foundation

// The selection is a UTF-16 range into the document, so the text is read as
// an NSString throughout.
// swiftlint:disable legacy_objc_type

// MARK: - TypedInputAction

/// What the editor does with one typed character or newline.
internal enum TypedInputAction: Equatable {
    /// Insert the typed text unchanged.
    case passThrough
    /// Replace the selection with `text`, then leave the caret
    /// `caretBacktrack` UTF-16 units before the end of the inserted text.
    case insert(String, caretBacktrack: Int)
    /// Insert nothing; move the caret past the character already there.
    case stepOver
}

// MARK: - TypedInputPolicy

/// Decides how `behavior.autoCloseBrackets`, `behavior.autoCloseQuotes` and
/// `behavior.isAutoIndentEnabled` change typed input.
///
/// Pure: it reads the text and the selection and returns an action. The text
/// view applies the action through its normal insertion path, so undo, the
/// delegate chain and change notifications behave as for any typed text.
@MainActor
internal enum TypedInputPolicy {
    private static let brackets: [String: String] = ["(": ")", "[": "]", "{": "}"]
    private static let quotes: Set<String> = ["\"", "'", "`"]

    /// - Parameters:
    ///   - typed: The text the user typed: one character, or `"\n"`.
    ///   - selection: The range the typed text replaces.
    ///   - text: The document.
    static func action(
        for typed: String,
        selection: NSRange,
        in text: NSString,
        configuration: EditorConfiguration,
        textEditingService: TextEditingService
    ) -> TypedInputAction {
        guard selection.location != NSNotFound, NSMaxRange(selection) <= text.length else {
            return .passThrough
        }
        if typed == "\n" {
            return newline(at: selection, in: text, configuration: configuration, textEditingService: textEditingService)
        }
        guard (typed as NSString).length == 1 else { return .passThrough }

        let behavior = configuration.behavior
        if behavior.autoCloseBrackets {
            if let close = brackets[typed] {
                return open(typed, close: close, selection: selection, in: text)
            }
            if brackets.values.contains(typed), selection.length == 0, character(at: selection.location, in: text) == typed {
                return .stepOver
            }
        }
        if behavior.autoCloseQuotes, quotes.contains(typed) {
            return quote(typed, selection: selection, in: text)
        }
        return .passThrough
    }

    // MARK: - Brackets and quotes

    private static func open(_ open: String, close: String, selection: NSRange, in text: NSString) -> TypedInputAction {
        if selection.length > 0 {
            return .insert(open + text.substring(with: selection) + close, caretBacktrack: 1)
        }
        // Before a word the bracket is being put in front of it, not around nothing.
        if let next = character(at: selection.location, in: text), isWordCharacter(next) {
            return .passThrough
        }
        return .insert(open + close, caretBacktrack: 1)
    }

    private static func quote(_ quote: String, selection: NSRange, in text: NSString) -> TypedInputAction {
        if selection.length > 0 {
            return .insert(quote + text.substring(with: selection) + quote, caretBacktrack: 1)
        }
        let next = character(at: selection.location, in: text)
        if next == quote { return .stepOver }
        let previous = selection.location > 0 ? character(at: selection.location - 1, in: text) : nil
        // An apostrophe inside a word, a quote closing a string typed by
        // hand, or the second quote of an empty pair.
        if let previous, isWordCharacter(previous) || previous == quote { return .passThrough }
        if let next, isWordCharacter(next) { return .passThrough }
        return .insert(quote + quote, caretBacktrack: 1)
    }

    // MARK: - Newline

    private static func newline(
        at selection: NSRange,
        in text: NSString,
        configuration: EditorConfiguration,
        textEditingService: TextEditingService
    ) -> TypedInputAction {
        guard configuration.behavior.isAutoIndentEnabled else { return .passThrough }

        let lineStart = text.lineRange(for: NSRange(location: selection.location, length: 0)).location
        let beforeCaret = text.substring(with: NSRange(location: lineStart, length: selection.location - lineStart))
        let indentation = textEditingService.calculateIndentation(
            forNewLineAfter: beforeCaret,
            configuration: configuration
        )

        // Return between a bracket pair opens the block: the caret goes on
        // an indented line of its own, the closer below it.
        let currentIndent = String(beforeCaret.prefix { $0 == " " || $0 == "\t" })
        if let opener = beforeCaret.last.map(String.init), let close = brackets[opener],
           character(at: NSMaxRange(selection), in: text) == close {
            let tail = "\n" + currentIndent
            return .insert("\n" + indentation + tail, caretBacktrack: (tail as NSString).length)
        }
        guard !indentation.isEmpty else { return .passThrough }
        return .insert("\n" + indentation, caretBacktrack: 0)
    }

    // MARK: - Helpers

    private static func character(at location: Int, in text: NSString) -> String? {
        guard location >= 0, location < text.length else { return nil }
        return text.substring(with: text.rangeOfComposedCharacterSequence(at: location))
    }

    private static func isWordCharacter(_ character: String) -> Bool {
        character.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || $0 == "_" }
    }
}

// swiftlint:enable legacy_objc_type
