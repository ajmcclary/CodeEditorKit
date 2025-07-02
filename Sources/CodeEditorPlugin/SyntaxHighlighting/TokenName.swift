import Foundation

/// Represents a unique identifier for syntax token types in themes.
///
/// `TokenName` is used as a key to map token types (like "keyword", "string", etc.)
/// to their corresponding colors and fonts in a ``Theme``. Each token name represents
/// a specific syntactic element that can be styled independently.
///
/// ## Overview
///
/// Token names follow a hierarchical naming convention using dot notation, allowing
/// themes to provide specific styles for detailed token types while falling back to
/// more general styles when specific ones aren't defined.
///
/// ## Common Token Names
///
/// The following token names are commonly used across languages:
///
/// - `"keyword"` - Language keywords (if, for, while, return, etc.)
/// - `"keyword.control"` - Control flow keywords
/// - `"keyword.declaration"` - Declaration keywords (class, struct, func)
/// - `"string"` - String literals
/// - `"string.interpolation"` - String interpolation expressions
/// - `"comment"` - Code comments
/// - `"comment.documentation"` - Documentation comments
/// - `"type"` - Type names and declarations
/// - `"type.builtin"` - Built-in types (Int, String, Bool)
/// - `"function"` - Function names
/// - `"function.call"` - Function invocations
/// - `"variable"` - Variable names
/// - `"variable.property"` - Property names
/// - `"number"` - Numeric literals
/// - `"operator"` - Operators (+, -, *, /, etc.)
/// - `"punctuation"` - Punctuation marks
///
/// ## Creating Token Names
///
/// ```swift
/// // Using string literal
/// let keywordToken: TokenName = "keyword"
///
/// // Using initializer
/// let functionToken = TokenName("function.call")
///
/// // Using hierarchical naming
/// let controlKeyword = TokenName("keyword.control.flow")
/// ```
///
/// ## Theme Integration
///
/// ```swift
/// let theme = Theme(name: "MyTheme")
/// let keywordColor = theme.color(forToken: "keyword")
/// let stringColor = theme.color(forToken: TokenName("string"))
/// ```
///
/// - SeeAlso: ``Theme``, ``TokenType``, ``HighlightedToken``
public struct TokenName: Hashable, Decodable, CustomStringConvertible, ExpressibleByStringLiteral, Sendable {
    /// The default token name used when no specific token type is available.
    ///
    /// This token name is used as a fallback for text that doesn't match any
    /// specific syntax category. Themes should provide a neutral color for this token.
    ///
    /// - Note: The value is a UUID to ensure it doesn't conflict with any
    ///         language-specific token names.
    public static let `default`: TokenName = "EB6F2FBA-B90E-41BC-874E-67916516D889"

    /// The internal string value of the token name.
    private let value: String

    /// Creates a token name from a string literal.
    ///
    /// This initializer enables the use of string literals to create token names,
    /// making the API more ergonomic.
    ///
    /// ```swift
    /// let token: TokenName = "keyword"
    /// ```
    ///
    /// - Parameter value: The string literal representing the token name.
    public init(stringLiteral value: StringLiteralType) {
        self.value = value
    }

    /// Creates a token name from a string.
    ///
    /// Use this initializer when you need to create token names programmatically
    /// or from dynamic values.
    ///
    /// ```swift
    /// let tokenType = "function.call"
    /// let token = TokenName(tokenType)
    /// ```
    ///
    /// - Parameter string: The string value for the token name.
    public init(_ string: StringLiteralType) {
        value = string
    }

    /// A textual representation of the token name.
    ///
    /// Returns the underlying string value of the token name, which is used
    /// as the key when looking up styles in themes.
    ///
    /// ```swift
    /// let token = TokenName("keyword")
    /// logger.debug(token.description) // Prints: "keyword"
    /// ```
    public var description: String {
        value
    }
}
