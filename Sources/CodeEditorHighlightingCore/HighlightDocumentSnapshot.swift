import Foundation

/// An immutable snapshot of the document a highlight provider is asked to
/// tokenize.
///
/// Providers receive snapshots — never a live editor view — so an external
/// package (for example a tree-sitter adapter) can implement
/// ``HighlightRangeProviding`` with no dependency on the editor surface and
/// no main-actor requirement.
public struct HighlightDocumentSnapshot: Sendable, Equatable {
    /// The full document text at the moment the snapshot was taken.
    public var text: String

    /// The language identifier the document is being highlighted as.
    public var languageID: String

    /// Creates a snapshot.
    public init(text: String, languageID: String) {
        self.text = text
        self.languageID = languageID
    }

    /// The document length in UTF-16 code units (the unit editor ranges use).
    public var utf16Length: Int { text.utf16.count }

    /// Whether the snapshot carries no text.
    public var isEmpty: Bool { text.isEmpty }
}
