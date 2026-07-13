import Foundation

/// A description of a single text edit, handed to a highlight provider so it
/// can compute which document regions its previous highlights no longer
/// cover.
///
/// `previousText` carries the pre-edit document when available; byte-oriented
/// incremental parsers need it to translate the UTF-16 edited range into
/// old/new byte ranges without guessing from the post-edit text.
public struct HighlightTextEdit: Sendable, Equatable {
    /// The pre-edit UTF-16 range that was replaced.
    public var editedRange: HighlightRange

    /// The signed change in document length (new length minus old length).
    public var changeInLength: Int

    /// The full document text before the edit, when the caller captured it.
    public var previousText: String?

    /// Creates a text edit descriptor.
    public init(
        editedRange: HighlightRange,
        changeInLength: Int,
        previousText: String? = nil
    ) {
        self.editedRange = editedRange
        self.changeInLength = changeInLength
        self.previousText = previousText
    }
}
