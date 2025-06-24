import Foundation
import SwiftParser
import SwiftSyntax
#if canImport(UIKit)
import UIKit

public typealias NSColor = UIColor
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - SyntaxHighlightingCoordinator

/// Coordinates between SwiftSyntax and regex-based highlighting for different languages
@MainActor
public final class SyntaxHighlightingCoordinator: @unchecked Sendable {
    // MARK: - Properties

    private let swiftHighlighter: SwiftSyntaxHighlighter
    private let regexHighlighter: RegexSyntaxHighlighter

    // MARK: - Initialization

    public init() {
        swiftHighlighter = SwiftSyntaxHighlighter()
        regexHighlighter = RegexSyntaxHighlighter()
    }

    // MARK: - Public Methods

    /// Detect language from file extension
    public func detectLanguage(from fileExtension: String) -> Language {
        let ext = fileExtension.lowercased()

        if ext == "swift" {
            return .swift
        }

        if let languageDefinition = regexHighlighter.languageDefinition(for: ext) {
            return .regex(languageDefinition)
        }

        return .plainText
    }

    /// Highlight source code based on detected or specified language
    public func highlight(source: String, language: Language) -> [HighlightedToken] {
        switch language {
        case .swift:
            swiftHighlighter.highlight(source: source).map { token in
                HighlightedToken(
                    range: token.range,
                    type: TokenType(from: token.type),
                    text: token.text
                )
            }

        case let .regex(definition):
            regexHighlighter.highlight(source: source, language: definition).map { token in
                HighlightedToken(
                    range: token.range,
                    type: TokenType(from: token.type),
                    text: token.text
                )
            }

        case .plainText:
            []
        }
    }

    /// Apply highlighting to an attributed string using adaptive colors
    public func applyHighlighting(to attributedString: NSMutableAttributedString, tokens: [HighlightedToken]) {
        // Remove existing syntax highlighting
        let range = NSRange(location: 0, length: attributedString.length)
        attributedString.removeAttribute(.foregroundColor, range: range)

        // Apply new highlighting with adaptive colors
        for token in tokens {
            guard token.range.location + token.range.length <= attributedString.length else {
                continue
            }
            // Use adaptive color system that works with macOS 26 Liquid Glass design
            attributedString.addAttribute(.foregroundColor, value: token.type.adaptiveColor, range: token.range)
        }
    }

    /// Get all supported file extensions
    public var supportedFileExtensions: [String] {
        var extensions = ["swift"]

        // Add regex-based language extensions
        for language in regexHighlighter.supportedLanguages.values {
            extensions.append(contentsOf: language.fileExtensions)
        }

        return Array(Set(extensions)).sorted()
    }

    deinit {
        // Cleanup if needed
    }
}

// MARK: - Language

public enum Language: Equatable {
    case swift
    case regex(RegexSyntaxHighlighter.LanguageDefinition)
    case plainText

    public var name: String {
        switch self {
        case .swift:
            "Swift"

        case let .regex(definition):
            definition.name

        case .plainText:
            "Plain Text"
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.swift, .swift),
             (.plainText, .plainText):
            true

        case let (.regex(lhsDef), .regex(rhsDef)):
            lhsDef.name == rhsDef.name

        default:
            false
        }
    }
}

// MARK: - TokenType

public enum TokenType: String, CaseIterable {
    case keyword
    case identifier
    case string
    case number
    case comment
    case type
    case function
    case property
    case `operator`
    case punctuation
    case whitespace
    case preprocessor
    case unknown

    /// Legacy color property - use adaptiveColor for macOS 26 compatibility
    @MainActor public var color: NSColor {
        AdaptiveColorSystem.syntaxColor(for: self)
    }

    /// Convert from SwiftSyntax token type
    init(from swiftType: SwiftSyntaxHighlighter.TokenType) {
        switch swiftType {
        case .keyword: self = .keyword
        case .identifier: self = .identifier
        case .string: self = .string
        case .number: self = .number
        case .comment: self = .comment
        case .type: self = .type
        case .function: self = .function
        case .property: self = .property
        case .operator: self = .operator
        case .punctuation: self = .punctuation
        case .whitespace: self = .whitespace
        case .unknown: self = .unknown
        }
    }

    /// Convert from regex highlighter token type
    init(from regexType: RegexSyntaxHighlighter.TokenType) {
        switch regexType {
        case .keyword: self = .keyword
        case .identifier: self = .identifier
        case .string: self = .string
        case .number: self = .number
        case .comment: self = .comment
        case .type: self = .type
        case .function: self = .function
        case .property: self = .property
        case .operator: self = .operator
        case .punctuation: self = .punctuation
        case .whitespace: self = .whitespace
        case .preprocessor: self = .preprocessor
        case .unknown: self = .unknown
        }
    }
}

// MARK: - HighlightedToken

public struct HighlightedToken {
    public let range: NSRange
    public let type: TokenType
    public let text: String

    public init(range: NSRange, type: TokenType, text: String) {
        self.range = range
        self.type = type
        self.text = text
    }
}

// MARK: - Extension for RegexSyntaxHighlighter

extension RegexSyntaxHighlighter {
    var supportedLanguages: [String: LanguageDefinition] {
        supportedLanguagesMap
    }
}
