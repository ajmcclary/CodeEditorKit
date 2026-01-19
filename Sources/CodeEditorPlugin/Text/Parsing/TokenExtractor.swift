import Foundation

// MARK: - Token Extractor

/// Extracts and classifies tokens from text with language context support.
public enum TokenExtractor {
    // MARK: - Public API

    /// Extracts tokens matching a specific pattern
    public static func extractTokensMatching(
        pattern: String,
        in text: String,
        language: Language? = nil
    ) -> [TextToken] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, options: [], range: range)

        return matches.compactMap { match in
            guard let stringRange = Range(match.range, in: text) else { return nil }
            let matchedText = String(text[stringRange])
            let tokenType = classifyToken(matchedText, language: language)

            return TextToken(
                text: matchedText,
                range: match.range,
                type: tokenType,
                language: language
            )
        }
    }

    /// Classifies a token based on its content and language context
    public static func classifyToken(_ text: String, language: Language?) -> TextToken.TokenType {
        if text.allSatisfy({ $0.isWhitespace }) { return .whitespace }
        if text.allSatisfy({ $0.isNumber }) { return .number }
        if text.hasPrefix("\"") || text.hasPrefix("'") { return .string }
        if text.hasPrefix("//") || text.hasPrefix("#") { return .comment }
        if text.count == 1, let firstChar = text.first, firstChar.isPunctuation { return .punctuation }

        // Check for keywords based on language
        if let language {
            let keywords = LanguagePatternDetector.getKeywords(for: language)
            if keywords.contains(text) { return .keyword }
        }

        if text.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            return .identifier
        }

        return .`operator`
    }

    /// Classifies a character into a type category
    public static func classifyCharacterType(_ char: Character) -> CharacterType {
        if char.isLetter { return .letter }
        if char.isNumber { return .digit }
        if char == "_" { return .underscore }
        if char.isWhitespace { return .whitespace }
        if char.isPunctuation { return .punctuation }
        return .other
    }

    // MARK: - Types

    /// Character type categories for classification.
    public enum CharacterType {
        /// Alphabetic letter character.
        case letter
        /// Numeric digit character.
        case digit
        /// Underscore character (_).
        case underscore
        /// Whitespace character (space, tab, etc.).
        case whitespace
        /// Punctuation character.
        case punctuation
        /// Any other character type.
        case other
    }

    /// A parsed token from text with type classification and language context.
    public struct TextToken {
        /// The actual text content of this token.
        public let text: String
        /// The location and length of this token in the source text.
        public let range: NSRange
        /// The classification type of this token.
        public let type: TokenType
        /// The programming language context, if applicable.
        public let language: Language?

        /// Categories for classifying text tokens based on their syntactic role.
        public enum TokenType {
            /// Programming language identifiers and variable names.
            case identifier
            /// Language keywords and reserved words.
            case keyword
            /// String literals and quoted text.
            case string
            /// Numeric literals and constants.
            case number
            /// Comments and documentation.
            case comment
            /// Operators and special symbols.
            case `operator`
            /// Punctuation marks and delimiters.
            case punctuation
            /// Space and tab characters.
            case whitespace
            /// Line break characters.
            case newline
        }
    }
}
