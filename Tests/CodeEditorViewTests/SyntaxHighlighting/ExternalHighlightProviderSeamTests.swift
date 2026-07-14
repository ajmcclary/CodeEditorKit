import CodeEditorConfiguration
import CodeEditorHighlightingCore
import CodeEditorLanguages
@testable import CodeEditorSyntaxHighlighting
@testable import CodeEditorView
import Foundation
import Testing

/// A value-oriented provider with no reference to the editor view — exactly
/// what an external tree-sitter adapter looks like. Records the calls the
/// editor's pull loop makes so a test can prove the injected provider became
/// the primary highlight source.
@MainActor
private final class RecordingValueProvider: HighlightRangeProviding {
    private(set) var preparedLanguageIDs: [String] = []
    private(set) var queriedRanges: [HighlightRange] = []

    func prepare(for document: HighlightDocumentSnapshot) async {
        preparedLanguageIDs.append(document.languageID)
    }

    func invalidate(
        for _: HighlightTextEdit,
        in document: HighlightDocumentSnapshot
    ) async -> HighlightInvalidation {
        .everything(length: document.utf16Length)
    }

    func highlights(
        in range: HighlightRange,
        of _: HighlightDocumentSnapshot
    ) async throws -> [HighlightToken] {
        queriedRanges.append(range)
        return [HighlightToken(range: HighlightRange(location: 0, length: 3), tokenType: "keyword", text: "let")]
    }
}

@Suite("External highlight provider public seam")
struct ExternalHighlightProviderSeamTests {
    private static func rangeBasedConfig() -> EditorConfiguration {
        var config = EditorConfiguration()
        config.performance.usesRangeBasedHighlighting = true
        config.display.useRangeStoreHighlighting = true
        return config
    }

    @Test("no provider by default")
    @MainActor
    func defaultsToNil() {
        let textView = CodeEditorView()
        #expect(textView.externalHighlightProvider == nil)
    }

    @Test("injected provider is stored and exposed")
    @MainActor
    func storesInjectedProvider() {
        let textView = CodeEditorView()
        let provider = RecordingValueProvider()
        textView.setExternalHighlightProvider(provider)
        #expect(textView.externalHighlightProvider === provider)
    }

    @Test("injected provider becomes the primary highlight source and is prepared")
    @MainActor
    func injectedProviderDrivesPipeline() async throws {
        let textView = CodeEditorView()
        textView.configuration = Self.rangeBasedConfig()
        #if canImport(AppKit)
        textView.string = "let value = 1"
        #else
        textView.text = "let value = 1"
        #endif

        let provider = RecordingValueProvider()
        textView.setExternalHighlightProvider(provider)
        textView.applyConfiguration()

        // The range-based controller is active (proving the flag path built it)
        // and the injected provider was prepared as the primary provider — the
        // bridge calls `prepare(for:)` on `setUp`.
        #expect(textView.rangeBasedHighlightingStyleDataSourceForTesting != nil)
        try await Task.sleep(for: .milliseconds(5))
        #expect(provider.preparedLanguageIDs.isEmpty == false)
    }

    @Test("clearing the provider restores the built-in highlighter")
    @MainActor
    func clearingRestoresBuiltIn() {
        let textView = CodeEditorView()
        let provider = RecordingValueProvider()
        textView.setExternalHighlightProvider(provider)
        #expect(textView.externalHighlightProvider === provider)

        textView.setExternalHighlightProvider(nil)
        #expect(textView.externalHighlightProvider == nil)
    }

    @Test("re-installing the same provider is an identity no-op")
    @MainActor
    func identityGuardRebuildsOnce() {
        let textView = CodeEditorView()
        textView.configuration = Self.rangeBasedConfig()
        textView.applyConfiguration()

        let provider = RecordingValueProvider()
        textView.setExternalHighlightProvider(provider)
        let firstController = textView.rangeBasedHighlightingController
        // Same object again: guard short-circuits, so the controller is not
        // torn down and rebuilt.
        textView.setExternalHighlightProvider(provider)
        #expect(textView.rangeBasedHighlightingController === firstController)
    }
}
