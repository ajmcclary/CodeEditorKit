import CodeEditorHighlightingCore
import CodeEditorLanguages
@testable import CodeEditorSyntaxHighlighting
@testable import CodeEditorView
import Foundation
import Testing

/// A value-oriented provider implemented with no reference to the editor view —
/// exactly what an external tree-sitter / LSP adapter would look like.
@MainActor
private final class MockValueHighlightProvider: HighlightRangeProviding {
    private(set) var preparedLanguageIDs: [String] = []
    private(set) var invalidateEdits: [HighlightTextEdit] = []
    private(set) var queriedRanges: [HighlightRange] = []

    func prepare(for document: HighlightDocumentSnapshot) async {
        preparedLanguageIDs.append(document.languageID)
    }

    func invalidate(
        for edit: HighlightTextEdit,
        in document: HighlightDocumentSnapshot
    ) async -> HighlightInvalidation {
        invalidateEdits.append(edit)
        return .everything(length: document.utf16Length)
    }

    func highlights(
        in range: HighlightRange,
        of document: HighlightDocumentSnapshot
    ) async throws -> [HighlightToken] {
        queriedRanges.append(range)
        guard !document.isEmpty else { return [] }
        return [HighlightToken(range: HighlightRange(location: 0, length: 3), tokenType: "keyword", text: "let")]
    }
}

@Suite("Value highlight provider bridge")
struct ValueHighlightProviderBridgeTests {
    @Test("bridge converts snapshot queries into HighlightedToken values")
    @MainActor
    func bridgeConvertsQueries() async throws {
        let textView = CodeEditorView()
        #if canImport(AppKit)
        textView.string = "let value = 1"
        #else
        textView.text = "let value = 1"
        #endif

        let valueProvider = MockValueHighlightProvider()
        let bridge = SnapshotHighlightProviderBridge(valueProvider: valueProvider)
        bridge.setUp(textView: textView, language: .swift)

        let tokens = try await bridge.queryHighlights(
            textView: textView,
            range: NSRange(location: 0, length: 3)
        )

        #expect(tokens.count == 1)
        #expect(tokens.first?.type == .keyword)
        #expect(tokens.first?.range == NSRange(location: 0, length: 3))
        #expect(valueProvider.queriedRanges == [HighlightRange(location: 0, length: 3)])
    }

    @Test("bridge threads the pre-edit source into the value edit")
    @MainActor
    func bridgeThreadsPreviousText() async {
        let textView = CodeEditorView()
        #if canImport(AppKit)
        textView.string = "let value = 1"
        #else
        textView.text = "let value = 1"
        #endif

        let valueProvider = MockValueHighlightProvider()
        let bridge = SnapshotHighlightProviderBridge(valueProvider: valueProvider)
        bridge.setUp(textView: textView, language: .swift)

        bridge.willApplyEdit(textView: textView, source: "let value = ", range: NSRange(location: 12, length: 0))
        let invalidated = await bridge.applyEdit(
            textView: textView,
            range: NSRange(location: 12, length: 0),
            delta: 1
        )

        #expect(invalidated.isEmpty == false)
        #expect(valueProvider.invalidateEdits.count == 1)
        #expect(valueProvider.invalidateEdits.first?.previousText == "let value = ")
        #expect(valueProvider.invalidateEdits.first?.changeInLength == 1)
    }

    @Test("controller registers and unregisters a value supplemental provider")
    @MainActor
    func controllerRegistersValueProvider() async throws {
        let textView = CodeEditorView()
        #if canImport(AppKit)
        textView.string = "let value = 1"
        #else
        textView.text = "let value = 1"
        #endif
        try await Task.sleep(for: .milliseconds(1))

        let controller = RangeBasedHighlightingController(textView: textView, language: .swift)
        defer { controller.detach() }

        let supplemental = MockValueHighlightProvider()
        controller.registerSupplementalProvider(supplemental, priority: -1)
        // Registering the same value provider twice is a no-op.
        controller.registerSupplementalProvider(supplemental, priority: -1)
        controller.unregisterSupplementalProvider(supplemental)
        // Unregistering an unknown provider is a safe no-op.
        controller.unregisterSupplementalProvider(MockValueHighlightProvider())
    }
}
