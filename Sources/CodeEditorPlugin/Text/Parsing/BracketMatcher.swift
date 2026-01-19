import Foundation

// MARK: - Bracket Matcher

/// Finds matching braces, brackets, and parentheses in text.
public enum BracketMatcher {
    // MARK: - Public API

    /// Finds matching braces/brackets/parentheses at a given position
    /// - Parameters:
    ///   - text: The text to search in
    ///   - position: The position of the brace to match
    /// - Returns: An NSRange covering both braces if found, nil otherwise
    public static func findMatchingBraces(in text: String, at position: Int) -> NSRange? {
        guard position < text.count else { return nil }

        let char = text[text.index(text.startIndex, offsetBy: position)]
        let bracePairs: [Character: Character] = [
            "(": ")", "[": "]", "{": "}",
            ")": "(", "]": "[", "}": "{"
        ]

        guard let matchingChar = bracePairs[char] else { return nil }

        let isClosing = [")", "]", "}"].contains(char)
        let searchDirection = isClosing ? -1 : 1
        let openChars = isClosing ? [matchingChar] : [char]
        let closeChars = isClosing ? [char] : [matchingChar]

        var depth = 1
        var searchIndex = position + searchDirection

        while searchIndex >= 0 && searchIndex < text.count {
            let currentChar = text[text.index(text.startIndex, offsetBy: searchIndex)]

            if openChars.contains(currentChar) {
                depth += isClosing ? -1 : 1
            } else if closeChars.contains(currentChar) {
                depth += isClosing ? 1 : -1
            }

            if depth == 0 {
                let startPos = min(position, searchIndex)
                let length = abs(searchIndex - position) + 1
                return NSRange(location: startPos, length: length)
            }

            searchIndex += searchDirection
        }

        return nil // No matching brace found
    }

    /// Finds the matching brace and returns detailed information
    /// - Parameters:
    ///   - text: The text to search in
    ///   - position: The position of the brace to match
    /// - Returns: A BraceMatch with details if found, nil otherwise
    public static func findMatchingBrace(in text: String, at position: Int) -> BraceMatch? {
        guard let range = findMatchingBraces(in: text, at: position) else {
            return nil
        }

        let char = text[text.index(text.startIndex, offsetBy: position)]
        let isOpening = ["(", "[", "{"].contains(char)

        return BraceMatch(
            openPosition: isOpening ? position : range.location,
            closePosition: isOpening ? range.location + range.length - 1 : position,
            braceType: BraceType(from: char)
        )
    }

    // MARK: - Types

    /// Information about a matched brace pair
    public struct BraceMatch {
        /// Position of the opening brace
        public let openPosition: Int
        /// Position of the closing brace
        public let closePosition: Int
        /// Type of brace pair
        public let braceType: BraceType
    }

    /// Types of brace pairs.
    public enum BraceType {
        /// Parentheses pair ().
        case parentheses
        /// Square brackets pair [].
        case brackets
        /// Curly braces pair {}.
        case braces

        init(from char: Character) {
            switch char {
            case "(", ")": self = .parentheses
            case "[", "]": self = .brackets
            default: self = .braces
            }
        }
    }
}
