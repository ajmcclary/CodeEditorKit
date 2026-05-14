import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - HighlightingStrategyExecutor

/// Centralized executor for syntax highlighting strategies
/// Eliminates duplicate switch statements in SyntaxHighlightingCoordinator
internal struct HighlightingStrategyExecutor {
    // MARK: - Properties

    private let swiftHighlighter: SwiftSyntaxHighlighter
    private let regexHighlighter: RegexSyntaxHighlighter
    private let fastJSONTokenizer: FastJSONTokenizer

    // MARK: - Initialization

    init(
        swiftHighlighter: SwiftSyntaxHighlighter,
        regexHighlighter: RegexSyntaxHighlighter,
        fastJSONTokenizer: FastJSONTokenizer
    ) {
        self.swiftHighlighter = swiftHighlighter
        self.regexHighlighter = regexHighlighter
        self.fastJSONTokenizer = fastJSONTokenizer
    }

    // MARK: - Public Methods

    /// Highlights source code using the appropriate strategy for the given language
    /// - Parameters:
    ///   - source: The source code to highlight
    ///   - language: The programming language of the source
    /// - Returns: Array of highlighted tokens
    func highlight(source: String, language: Language) -> [HighlightedToken] {
        let strategy = determineStrategy(for: language)
        return executeStrategy(strategy, source: source, language: language)
    }

    // MARK: - Strategy Pattern

    /// Determines the highlighting strategy for a given language
    private func determineStrategy(for language: Language) -> HighlightingStrategy {
        switch language {
        case .swift:
            return .swiftSyntax

        case .json:
            return .fastJSON

        case .plainText:
            return .noHighlighting

        default:
            return .regex
        }
    }

    /// Executes the specified highlighting strategy
    private func executeStrategy(
        _ strategy: HighlightingStrategy,
        source: String,
        language: Language
    ) -> [HighlightedToken] {
        switch strategy {
        case .swiftSyntax:
            return swiftHighlighter.highlight(source: source)

        case .fastJSON:
            return highlightJSON(source: source)

        case .regex:
            return highlightWithRegex(source: source, language: language)

        case .noHighlighting:
            return []
        }
    }

    // MARK: - Private Helpers

    /// Highlights JSON using the specialized tokenizer
    private func highlightJSON(source: String) -> [HighlightedToken] {
        fastJSONTokenizer.tokenize(source).compactMap { token in
            guard let type = mapJSONTokenType(token.type) else { return nil }
            return HighlightedToken(range: token.range, type: type, text: "")
        }
    }

    /// Maps the tokenizer's internal classification to the framework's `TokenType`
    /// without round-tripping through a `PlatformColor`. The previous color-based
    /// detour collapsed any theme override that mapped two categories to the same
    /// hue.
    private func mapJSONTokenType(_ tokenizerType: FastJSONTokenizer.TokenType) -> TokenType? {
        switch tokenizerType {
        case .string:
            return .string

        case .number:
            return .number

        case .boolean, .null:
            return .keyword

        case .key:
            return .property

        case .openBrace, .closeBrace, .openBracket, .closeBracket, .comma, .colon:
            return .punctuation

        case .invalid:
            return .unknown

        case .whitespace:
            return nil
        }
    }

    /// Highlights source using regex-based highlighter
    private func highlightWithRegex(source: String, language: Language) -> [HighlightedToken] {
        if let languageDefinition = regexHighlighter.languageDefinition(for: language) {
            return regexHighlighter.highlight(source: source, language: languageDefinition)
        }
        return []
    }
}

// MARK: - HighlightingStrategy

/// Defines the available highlighting strategies
public enum HighlightingStrategy: Sendable {
    /// Use SwiftSyntax AST-based highlighting (Swift only)
    case swiftSyntax
    /// Use fast JSON tokenizer
    case fastJSON
    /// Use regex-based highlighting
    case regex
    /// No highlighting (plain text)
    case noHighlighting
}
