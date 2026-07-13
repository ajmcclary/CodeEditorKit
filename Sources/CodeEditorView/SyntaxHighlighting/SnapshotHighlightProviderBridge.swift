import CodeEditorHighlightingCore
import CodeEditorLanguages
import CodeEditorSyntaxHighlighting
import Foundation

/// Bridges a value-oriented ``HighlightRangeProviding`` (the decentralized,
/// view-free highlight seam in `CodeEditorHighlightingCore`) onto the editor's
/// internal, view-based `RangeHighlightProviding` mechanics.
///
/// This is the internal adapter that lets `CodeEditorView`'s highlighting
/// pipeline drive providers through the new value contracts: the bridge is the
/// only place that reads the live view, converting it into immutable
/// ``HighlightDocumentSnapshot`` / ``HighlightTextEdit`` values before handing
/// off to the wrapped provider, and converting the provider's
/// ``HighlightToken`` / ``HighlightInvalidation`` results back into the units
/// the range-store pipeline consumes.
///
/// External conformers (e.g. a tree-sitter adapter) therefore never see an
/// editor view or the internal `RangeHighlightProviding` protocol.
@MainActor
final class SnapshotHighlightProviderBridge: RangeHighlightProviding {
    /// The wrapped value-oriented provider.
    let valueProvider: any HighlightRangeProviding

    private var language: Language = .plainText
    private var pendingPreviousText: String?

    init(valueProvider: any HighlightRangeProviding) {
        self.valueProvider = valueProvider
    }

    // MARK: - RangeHighlightProviding

    func setUp(textView: CodeEditorView, language: Language) {
        self.language = language
        let snapshot = Self.snapshot(from: textView, language: language)
        let provider = valueProvider
        Task { await provider.prepare(for: snapshot) }
    }

    func willApplyEdit(textView _: CodeEditorView, range _: NSRange) {
        pendingPreviousText = nil
    }

    func willApplyEdit(textView _: CodeEditorView, source: String, range _: NSRange) {
        pendingPreviousText = source
    }

    func applyEdit(textView: CodeEditorView, range: NSRange, delta: Int) async -> IndexSet {
        let snapshot = Self.snapshot(from: textView, language: language)
        let edit = HighlightTextEdit(
            editedRange: HighlightRange(range),
            changeInLength: delta,
            previousText: pendingPreviousText
        )
        pendingPreviousText = nil
        let invalidation = await valueProvider.invalidate(for: edit, in: snapshot)
        return Self.indexSet(from: invalidation)
    }

    func queryHighlights(textView: CodeEditorView, range: NSRange) async throws -> [HighlightedToken] {
        let snapshot = Self.snapshot(from: textView, language: language)
        let tokens = try await valueProvider.highlights(in: HighlightRange(range), of: snapshot)
        return tokens.map { token in
            HighlightedToken(
                range: token.range.nsRange,
                type: TokenType(rawValue: token.tokenType) ?? .identifier,
                text: token.text
            )
        }
    }

    // MARK: - Conversion helpers

    private static func snapshot(
        from textView: CodeEditorView,
        language: Language
    ) -> HighlightDocumentSnapshot {
        HighlightDocumentSnapshot(
            text: textView.textKitBridge.documentString,
            languageID: language.lspIdentifier
        )
    }

    private static func indexSet(from invalidation: HighlightInvalidation) -> IndexSet {
        var set = IndexSet()
        for range in invalidation.ranges where range.length > 0 {
            set.insert(integersIn: range.location..<range.upperBound)
        }
        return set
    }
}
