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

    /// Called after an edit. Returns invalidated character indices.
    func applyEdit(textView: CodeEditorView, range: NSRange, delta: Int) async -> IndexSet

    /// Query highlights for a character range.
    func queryHighlights(textView: CodeEditorView, range: NSRange) async throws -> [HighlightedToken]
}

extension RangeHighlightProviding {
    func willApplyEdit(textView _: CodeEditorView, range _: NSRange) {}
}
