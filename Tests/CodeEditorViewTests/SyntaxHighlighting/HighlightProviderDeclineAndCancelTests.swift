import CodeEditorHighlightingCore
import CodeEditorLanguages
@testable import CodeEditorSyntaxHighlighting
import CodeEditorTextModel
@testable import CodeEditorView
import Foundation
import Testing

/// A value provider that will not highlight a document (over its size limit)
/// declines, and the editor's built-in highlighter takes the range.
private final class DecliningValueProvider: HighlightRangeProviding, @unchecked Sendable {
    func prepare(for _: HighlightDocumentSnapshot) async {}

    func invalidate(for _: HighlightTextEdit, in document: HighlightDocumentSnapshot) async -> HighlightInvalidation {
        .everything(length: document.utf16Length)
    }

    func highlights(in _: HighlightRange, of _: HighlightDocumentSnapshot) async throws -> [HighlightToken] {
        throw HighlightProviderDeclined()
    }
}

/// A provider whose first query is cancelled (its request was dropped, as the
/// tree-sitter provider does when a parse is superseded) and whose later
/// queries succeed.
@MainActor
private final class CancelOnceProvider: RangeHighlightProviding {
    var queryCount = 0

    func setUp(textView _: CodeEditorView, language _: Language) {}

    func applyEdit(textView _: CodeEditorView, range _: NSRange, delta _: Int) async -> IndexSet {
        IndexSet()
    }

    func queryHighlights(textView _: CodeEditorView, range: NSRange) async throws -> [HighlightedToken] {
        queryCount += 1
        if queryCount == 1 { throw CancellationError() }
        return [HighlightedToken(range: NSRange(location: range.location, length: 1), type: .keyword, text: "l")]
    }
}

@Suite("Highlight provider decline and cancellation")
struct HighlightProviderDeclineAndCancelTests {
    @Test("a declining value provider falls back to the built-in highlighter")
    @MainActor
    func decliningProviderFallsBack() async throws {
        let textView = CodeEditorView()
        #if canImport(AppKit)
        textView.string = "let value = 1"
        #else
        textView.text = "let value = 1"
        #endif
        let bridge = SnapshotHighlightProviderBridge(valueProvider: DecliningValueProvider())
        bridge.setUp(textView: textView, language: .swift)

        let tokens = try await bridge.queryHighlights(textView: textView, range: NSRange(location: 0, length: 13))

        #expect(tokens.contains { $0.type == .keyword && $0.range == NSRange(location: 0, length: 3) })
    }

    @Test("a cancelled query is neither a failure nor reported, and is re-queried")
    @MainActor
    func cancelledQueryIsRequeried() async throws {
        let provider = CancelOnceProvider()
        let container = StyledRangeContainer(documentLength: 100)
        let textView = CodeEditorView()
        let state = HighlightProviderState(
            provider: provider,
            providerID: 0,
            container: container,
            textView: textView,
            documentLength: 100,
            maxChunk: 20
        )

        // No `withExpectedIssue`: a `reportIssue` here fails the test.
        state.updateVisibleSet(IndexSet(integersIn: 10..<21), schedulesHighlighting: false)
        await state.highlightInvalidRanges()
        let deadline = Date().addingTimeInterval(2)
        while state.nextRange() != nil || provider.queryCount < 2, Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(provider.queryCount == 2, "the cancelled range was not re-queried")
        #expect(state.nextRange() == nil)
    }
}
