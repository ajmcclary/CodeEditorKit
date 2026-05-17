import Foundation

/// Template for code snippets supplied by language descriptors.
public struct SnippetTemplate: Sendable {
    public let label: String
    public let insertText: String
    public let description: String

    public init(label: String, insertText: String, description: String) {
        self.label = label
        self.insertText = insertText
        self.description = description
    }
}
