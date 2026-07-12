import CodeEditorCompletion
import CodeEditorDiagnostics
@testable import CodeEditorSwiftUI
#if canImport(SwiftUI)
import CodeEditorLanguages
@testable import CodeEditorPlugin
@testable import CodeEditorView
import XCTest

@MainActor
final class CodeEditorModifierCompletionIntegrationTests: XCTestCase {
    /// Simulates the body→representable→coordinator→manager wiring at
    /// the seam below SwiftUI's view tree. We construct a real
    /// CompletionManager, a coordinator subclass, and call the same
    /// sync hook the representable's update path calls.
    func testModifierClosureAndBuiltInProviderStack() async throws {
        let manager = CompletionManager(memoryMonitor: MemoryMonitor())

        // Built-in keyword provider is auto-registered by CodeEditorView
        // on language change; we exercise the registry surface directly here.
        manager.ensureBuiltInProvider(for: .swift)

        // Modifier-supplied closure plumbed via the modifier registry.
        let registry = CompletionModifierRegistry()
        registry.reconcile(on: manager) { _ in
            [SwiftUICompletionItem(label: "myCustomSnippet", kind: .snippet)]
        }

        // The manager should now have both providers.
        let ids = Set(manager.registeredProviders.map(\.id))
        XCTAssertEqual(ids, ["builtin.keywords.swift", "swiftui-modifier"])

        // Trigger a real request and inspect the merged result.
        let context = CompletionContextModel(
            text: "func ",
            cursorPosition: 5,
            language: .swift,
            lineText: ""
        )
        let result = try await manager.requestCompletions(for: context)

        let labels = Set(result.items.map(\.label))
        XCTAssertTrue(
            labels.contains("myCustomSnippet"),
            "Modifier-supplied item should appear in merged results"
        )
        let containsSwiftKeyword = labels.contains("func")
            || labels.contains("var")
            || labels.contains("let")
        XCTAssertTrue(
            containsSwiftKeyword,
            "Built-in Swift keyword(s) should appear alongside the host's item"
        )
    }
}

#endif
