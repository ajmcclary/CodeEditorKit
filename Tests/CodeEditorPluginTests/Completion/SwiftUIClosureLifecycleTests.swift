import CodeEditorCompletion
import CodeEditorDiagnostics
@testable import CodeEditorSwiftUI
#if canImport(SwiftUI)
import CodeEditorLanguages
@testable import CodeEditorPlugin
@testable import CodeEditorView
import XCTest

@MainActor
final class SwiftUIClosureLifecycleTests: XCTestCase {
    private func makeManager() -> CompletionManager {
        CompletionManager(memoryMonitor: MemoryMonitor())
    }

    func testFirstNonNilClosureRegistersAdapter() {
        let manager = makeManager()
        let registry = CompletionModifierRegistry()
        registry.reconcile(on: manager) { _ in [] }

        let ids = manager.registeredProviders.map(\.id)
        XCTAssertEqual(ids, ["swiftui-modifier"])
    }

    func testReRenderWithSameClosureKeepsSingleRegistration() {
        let manager = makeManager()
        let registry = CompletionModifierRegistry()
        let closure: @Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem] = { _ in [] }

        registry.reconcile(on: manager, closure: closure)
        registry.reconcile(on: manager, closure: closure)
        registry.reconcile(on: manager, closure: closure)

        XCTAssertEqual(manager.registeredProviders.count, 1)
    }

    func testReRenderWithDifferentClosureSwapsSlotNotProvider() async throws {
        let manager = makeManager()
        let registry = CompletionModifierRegistry()

        registry.reconcile(on: manager) { _ in
            [SwiftUICompletionItem(label: "A", kind: .keyword)]
        }

        let firstAdapter = manager.registeredProviders.first as? SwiftUIClosureCompletionProvider
        XCTAssertNotNil(firstAdapter)

        registry.reconcile(on: manager) { _ in
            [SwiftUICompletionItem(label: "B", kind: .keyword)]
        }

        let secondAdapter = manager.registeredProviders.first as? SwiftUIClosureCompletionProvider
        XCTAssertIdentical(firstAdapter, secondAdapter, "Adapter identity should be stable")

        let context = CompletionContextModel(text: "", cursorPosition: 0, language: .swift, lineText: "")
        let result = try await secondAdapter?.completions(for: context)
        XCTAssertEqual(result?.items.first?.label, "B")
    }

    func testTransitionToNilUnregistersAdapter() {
        let manager = makeManager()
        let registry = CompletionModifierRegistry()
        registry.reconcile(on: manager) { _ in [] }
        registry.reconcile(on: manager, closure: nil)

        XCTAssertTrue(manager.registeredProviders.isEmpty)
    }
}

#endif
