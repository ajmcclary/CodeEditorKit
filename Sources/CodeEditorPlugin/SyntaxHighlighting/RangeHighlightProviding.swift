import CodeEditorLanguages
import Foundation

/// Protocol for highlight providers that produce ranges of styled tokens.
///
/// Multiple providers (syntax, LSP, spellcheck) can coexist and their
/// results are merged by `StyledRangeContainer` by priority.
@MainActor
internal protocol RangeHighlightProviding: AnyObject {
    /// Called once during initialization and on language changes.
    func setUp(textView: CodeEditorView, language: Language)

    /// Called before text storage applies an edit. Default: no-op.
    func willApplyEdit(textView: CodeEditorView, range: NSRange)

    /// Called before the provider processes an already-applied edit, with the
    /// pre-edit source snapshot. Providers with byte-oriented incremental
    /// parsers need this to translate UTF-16 edit ranges into old/new byte
    /// ranges without guessing from the post-edit text.
    func willApplyEdit(textView: CodeEditorView, source: String, range: NSRange)

    /// Called after an edit. Returns invalidated character indices.
    func applyEdit(textView: CodeEditorView, range: NSRange, delta: Int) async -> IndexSet

    /// Query highlights for a character range.
    func queryHighlights(textView: CodeEditorView, range: NSRange) async throws -> [HighlightedToken]
}

extension RangeHighlightProviding {
    func willApplyEdit(textView _: CodeEditorView, range _: NSRange) {}

    func willApplyEdit(textView: CodeEditorView, source _: String, range: NSRange) {
        willApplyEdit(textView: textView, range: range)
    }
}
