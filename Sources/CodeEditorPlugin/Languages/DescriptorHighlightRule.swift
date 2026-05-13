import Foundation

/// Language-specific regex rule carried by a `LanguageDescriptor`.
internal struct DescriptorHighlightRule: Sendable {
    let pattern: String
    let tokenType: RegexSyntaxTokenType
    let priority: Int

    init(_ pattern: String, _ tokenType: RegexSyntaxTokenType, priority: Int) {
        self.pattern = pattern
        self.tokenType = tokenType
        self.priority = priority
    }
}
