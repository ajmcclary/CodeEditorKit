#if canImport(AppKit)
import CodeEditorLanguages
@testable import CodeEditorPlugin
@testable import CodeEditorSample
@testable import CodeEditorView
import Foundation
import Testing

@Suite("BuiltInLanguageProviders")
@MainActor
struct BuiltInLanguageProvidersTests {
    @Test("factory returns exactly eight providers")
    func eightProviders() {
        #expect(BuiltInLanguageProviders.all().count == 8)
    }

    @Test("each provider id is unique")
    func uniqueIDs() {
        let ids = BuiltInLanguageProviders.all().map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("each provider has exactly one supported language and at least one trigger character")
    func shapesAreSensible() {
        for provider in BuiltInLanguageProviders.all() {
            #expect(provider.supportedLanguages.count == 1)
            #expect(!provider.triggerCharacters.isEmpty)
        }
    }

    @Test("covers Swift, Python, JavaScript, TypeScript, Go, Rust, Java, C")
    func expectedLanguages() {
        let coveredLanguages = Set(
            BuiltInLanguageProviders.all().flatMap(\.supportedLanguages)
        )
        let expected: Set<Language> = [
            .swift, .python, .javascript, .typescript,
            .go, .rust, .java, .c
        ]
        #expect(coveredLanguages == expected)
    }

    @Test("Swift provider returns a well-formed result")
    func swiftReturnsResult() async throws {
        guard let swiftProvider = BuiltInLanguageProviders.all().first(where: {
            $0.supportedLanguages == [.swift]
        }) else {
            #expect(Bool(false), "expected swift provider")
            return
        }

        let snippet = "let s: String = \"\"\ns."
        let context = CompletionContextModel(
            text: snippet,
            cursorPosition: snippet.count,
            language: .swift,
            triggerKind: .character,
            triggerCharacter: ".",
            lineText: "s."
        )

        let result = try await swiftProvider.completions(for: context)
        #expect(result.context.language == .swift)
    }
}
#endif
