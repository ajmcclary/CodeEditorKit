#if canImport(AppKit)
import CodeEditorLanguages
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing

@Suite("DemoCompletionProvider")
@MainActor
struct DemoCompletionProviderTests {
    @Test("returns the full snippet catalogue on any language")
    func returnsFullCatalogue() async throws {
        let provider = DemoCompletionProvider()

        let context = CompletionContextModel(
            text: "",
            cursorPosition: 0,
            language: .swift
        )
        let result = try await provider.completions(for: context)

        let labels = result.items.map(\.label).sorted()
        #expect(labels == ["FIXME:", "MARK:", "NOTE:", "TODO:", "WARNING:"])
    }

    @Test("has empty supportedLanguages so it applies to all")
    func appliesToAllLanguages() {
        let provider = DemoCompletionProvider()
        #expect(provider.supportedLanguages.isEmpty)
    }

    @Test("id is stable")
    func stableID() {
        #expect(DemoCompletionProvider().id == "sample.demo")
    }
}
#endif
