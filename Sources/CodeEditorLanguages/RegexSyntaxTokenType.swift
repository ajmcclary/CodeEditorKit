import Foundation

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
}
