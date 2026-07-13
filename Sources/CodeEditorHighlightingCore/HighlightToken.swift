import Foundation

/// A styled span emitted by a highlight provider.
///
/// The token type is carried as a raw string (typically a token-type or
/// tree-sitter capture name) so the contract stays decoupled from any
/// concrete color-scheme or `TokenType` enum owned by the editor. Consumers
/// map the raw value to their own styling vocabulary.
public struct HighlightToken: Sendable, Equatable {
    /// The UTF-16 span the token covers, relative to the document.
    public var range: HighlightRange

    /// Raw token-type or capture name (e.g. `"keyword"`, `"string"`).
    public var tokenType: String

    /// The source text the token covers. May be empty when the provider
    /// does not carry the substring.
    public var text: String

    /// Creates a highlight token.
    public init(range: HighlightRange, tokenType: String, text: String) {
        self.range = range
        self.tokenType = tokenType
        self.text = text
    }
}
