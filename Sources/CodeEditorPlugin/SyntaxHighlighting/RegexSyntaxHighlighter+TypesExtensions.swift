import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Type alias for platform-specific color type used in regex highlighting
public typealias RegexHighlighterColor = PlatformColor

// MARK: - Language Definition Types

/// Language definition structure for regex-based syntax highlighting
public struct RegexLanguageDefinition: Sendable {
    public let name: String
    public let fileExtensions: [String]
    public let rules: [RegexHighlightRule]

    public init(name: String, fileExtensions: [String], rules: [RegexHighlightRule]) {
        self.name = name
        self.fileExtensions = fileExtensions
        // Pre-sort rules by priority once during initialization
        self.rules = rules.sorted { $0.priority > $1.priority }
    }
}

/// Highlight rule with regex pattern and token type
public struct RegexHighlightRule: Sendable {
    public let pattern: NSRegularExpression
    public let tokenType: RegexSyntaxTokenType
    public let priority: Int

    public init(pattern: String, tokenType: RegexSyntaxTokenType, priority: Int = 0) throws {
        self.pattern = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        self.tokenType = tokenType
        self.priority = priority
    }
}

// MARK: - Token Types

/// Token types for regex-based syntax highlighting
public enum RegexSyntaxTokenType: String, CaseIterable, Sendable {
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

    public var color: RegexHighlighterColor {
        SyntaxColorScheme.default.color(for: self)
    }
}
