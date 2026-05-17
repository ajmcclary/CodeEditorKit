import Foundation

/// Language-specific regex rule carried by a `LanguageDescriptor`.
package struct DescriptorHighlightRule: Sendable {
    package let pattern: String
    package let tokenType: RegexSyntaxTokenType
    package let priority: Int

    package init(_ pattern: String, _ tokenType: RegexSyntaxTokenType, priority: Int) {
        self.pattern = pattern
        self.tokenType = tokenType
        self.priority = priority
    }
}
