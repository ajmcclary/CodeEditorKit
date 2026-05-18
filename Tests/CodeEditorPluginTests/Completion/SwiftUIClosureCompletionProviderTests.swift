#if canImport(SwiftUI)
import CodeEditorCompletion
import CodeEditorLanguages
@testable import CodeEditorPlugin
import XCTest

@MainActor
final class SwiftUIClosureCompletionProviderTests: XCTestCase {
    func testInitialIdentityAndShape() {
        let provider = SwiftUIClosureCompletionProvider()
        XCTAssertEqual(provider.id, "swiftui-modifier")
        XCTAssertEqual(
            provider.supportedLanguages,
            [],
            "Empty array means 'applies to every language' in CompletionManager"
        )
        XCTAssertEqual(
            provider.triggerCharacters,
            [],
            "Manual trigger only — hosts wanting trigger chars register their own provider"
        )
        XCTAssertTrue(
            provider.supportsSnippets,
            "SwiftUICompletionItem.insertText may contain ${…} snippet syntax"
        )
    }

    func testNilClosureReturnsEmptyResult() async throws {
        let provider = SwiftUIClosureCompletionProvider()
        provider.closure = nil

        let context = CompletionContextModel(
            text: "let x = ",
            cursorPosition: 8,
            language: .swift,
            lineText: "let x = "
        )

        let result = try await provider.completions(for: context)
        XCTAssertTrue(result.items.isEmpty)
    }

    func testClosureReceivesBridgedContext() async throws {
        let provider = SwiftUIClosureCompletionProvider()

        // We capture into a box so the closure can be @Sendable without
        // capturing test-local mutable state directly.
        actor Capture {
            var text: String?
            var position: Int?
            var language: Language?

            func record(text: String, position: Int, language: Language) {
                self.text = text
                self.position = position
                self.language = language
            }
        }
        let capture = Capture()

        provider.closure = { ctx in
            await capture.record(text: ctx.text, position: ctx.cursorPosition, language: ctx.language)
            return []
        }

        let context = CompletionContextModel(
            text: "func greet() {}",
            cursorPosition: 12,
            language: .swift,
            lineText: "func greet() {}"
        )

        _ = try await provider.completions(for: context)

        let capturedText = await capture.text
        let capturedPosition = await capture.position
        let capturedLanguage = await capture.language

        XCTAssertEqual(capturedText, "func greet() {}")
        XCTAssertEqual(capturedPosition, 12)
        XCTAssertEqual(capturedLanguage, .swift)
    }

    func testItemsTranslateFromSwiftUIToModel() async throws {
        let provider = SwiftUIClosureCompletionProvider()
        provider.closure = { _ in
            [
                SwiftUICompletionItem(
                    label: "forEach",
                    kind: .method,
                    detail: "Iterate over elements",
                    insertText: "forEach { <#element#> in\n    <#code#>\n}",
                    documentation: "Calls a closure on every element"
                )
            ]
        }

        let context = CompletionContextModel(
            text: "",
            cursorPosition: 0,
            language: .swift,
            lineText: ""
        )

        let result = try await provider.completions(for: context)
        XCTAssertEqual(result.items.count, 1)
        let item = try XCTUnwrap(result.items.first)
        XCTAssertEqual(item.label, "forEach")
        XCTAssertEqual(item.kind, .method)
        XCTAssertEqual(item.detail, "Iterate over elements")
        XCTAssertTrue(item.insertText.contains("forEach"))
        XCTAssertEqual(item.documentation, "Calls a closure on every element")
    }

    func testAllFifteenCompletionKindsRoundTrip() async throws {
        let provider = SwiftUIClosureCompletionProvider()

        let pairs: [(CompletionKind, CompletionItemKind)] = [
            (.keyword, .keyword),
            (.function, .function),
            (.method, .method),
            (.variable, .variable),
            (.constant, .constant),
            (.class, .class),
            (.struct, .struct),
            (.enum, .enum),
            (.interface, .interface),
            (.module, .module),
            (.property, .property),
            (.value, .value),
            (.reference, .reference),
            (.snippet, .snippet),
            (.text, .text)
        ]

        for (swiftUIKind, modelKind) in pairs {
            provider.closure = { _ in
                [SwiftUICompletionItem(label: "x", kind: swiftUIKind)]
            }

            let context = CompletionContextModel(
                text: "", cursorPosition: 0, language: .swift, lineText: ""
            )
            let result = try await provider.completions(for: context)
            XCTAssertEqual(
                result.items.first?.kind,
                modelKind,
                "SwiftUI \(swiftUIKind) should map to model \(modelKind)"
            )
        }
    }

    func testItemPriorityComesFromKindDefaultPriority() async throws {
        // The SwiftUI modifier API doesn't expose a priority field, so the
        // adapter stamps each item with its kind's defaultPriority — see
        // SwiftUIClosureCompletionProvider.swift docstring on the init.
        // This keeps modifier-supplied items from being buried behind
        // priority-80 keywords past the maxCompletions: 50 cap.
        let provider = SwiftUIClosureCompletionProvider()
        provider.closure = { _ in
            [
                SwiftUICompletionItem(label: "k", kind: .keyword),
                SwiftUICompletionItem(label: "s", kind: .snippet),
                SwiftUICompletionItem(label: "t", kind: .text)
            ]
        }

        let context = CompletionContextModel(
            text: "", cursorPosition: 0, language: .swift, lineText: ""
        )
        let result = try await provider.completions(for: context)

        let byLabel = Dictionary(uniqueKeysWithValues: result.items.map { ($0.label, $0.priority) })
        XCTAssertEqual(byLabel["k"], CompletionItemKind.keyword.defaultPriority)
        XCTAssertEqual(byLabel["s"], CompletionItemKind.snippet.defaultPriority)
        XCTAssertEqual(byLabel["t"], CompletionItemKind.text.defaultPriority)
    }

    func testInsertTextDefaultsToLabelWhenNil() async throws {
        let provider = SwiftUIClosureCompletionProvider()
        provider.closure = { _ in
            [SwiftUICompletionItem(label: "ifLet", kind: .snippet, insertText: nil)]
        }

        let context = CompletionContextModel(
            text: "", cursorPosition: 0, language: .swift, lineText: ""
        )
        let result = try await provider.completions(for: context)
        XCTAssertEqual(result.items.first?.insertText, "ifLet")
    }
}
#endif
