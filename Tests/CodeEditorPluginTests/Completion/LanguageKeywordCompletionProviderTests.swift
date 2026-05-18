@testable import CodeEditorCompletion
import CodeEditorLanguages
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import XCTest

@MainActor
final class LanguageKeywordCompletionProviderTests: XCTestCase {
    func testIdEncodesLanguage() {
        let provider = LanguageKeywordCompletionProvider(language: .swift)
        XCTAssertEqual(provider.id, "builtin.keywords.swift")
    }

    func testSupportedLanguagesIsExactlyOneLanguage() {
        let provider = LanguageKeywordCompletionProvider(language: .python)
        XCTAssertEqual(provider.supportedLanguages, [.python])
    }

    func testTriggerCharactersIsEmpty() {
        let provider = LanguageKeywordCompletionProvider(language: .javascript)
        XCTAssertTrue(provider.triggerCharacters.isEmpty)
    }

    func testCompletionsForDescriptorBackedLanguageReturnsKeywords() async throws {
        let provider = LanguageKeywordCompletionProvider(language: .swift)
        let context = CompletionContextModel(
            text: "func ",
            cursorPosition: 5,
            language: .swift,
            lineText: ""
        )

        let result = try await provider.completions(for: context)

        XCTAssertFalse(result.items.isEmpty, "Swift keyword completions should not be empty")
        XCTAssertTrue(result.items.allSatisfy { $0.kind == .keyword },
                      "Every item should be of kind .keyword")
        XCTAssertTrue(result.items.allSatisfy { $0.priority == 80 },
                      "Every item should land at the SharedCompletionBuilder priority of 80 — pins the contract against drift")
    }

    func testCompletionsForUnknownLanguageFallsBackToGenericKeywords() async throws {
        let provider = LanguageKeywordCompletionProvider(language: .plainText)
        let context = CompletionContextModel(
            text: "",
            cursorPosition: 0,
            language: .plainText,
            lineText: ""
        )

        let result = try await provider.completions(for: context)
        let labels = Set(result.items.map(\.label))

        XCTAssertTrue(labels.contains("if"), "Generic fallback should include 'if'")
        XCTAssertTrue(labels.contains("return"), "Generic fallback should include 'return'")
    }
}
