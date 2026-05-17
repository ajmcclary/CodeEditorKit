import CodeEditorDiagnostics
#if canImport(SwiftUI)
import CodeEditorLanguages
@testable import CodeEditorPlugin
import XCTest

@MainActor
final class SwiftUIClosureLifecycleTests: XCTestCase {
    private func makeManager() -> CompletionManager {
        CompletionManager(memoryMonitor: MemoryMonitor())
    }

    func testFirstNonNilClosureRegistersAdapter() {
        let manager = makeManager()
        let coordinator = TestCoordinator()
        coordinator.syncModifierProvider(on: manager) { _ in [] }

        let ids = manager.registeredProviders.map(\.id)
        XCTAssertEqual(ids, ["swiftui-modifier"])
    }

    func testReRenderWithSameClosureKeepsSingleRegistration() {
        let manager = makeManager()
        let coordinator = TestCoordinator()
        let closure: @Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem] = { _ in [] }

        coordinator.syncModifierProvider(on: manager, closure: closure)
        coordinator.syncModifierProvider(on: manager, closure: closure)
        coordinator.syncModifierProvider(on: manager, closure: closure)

        XCTAssertEqual(manager.registeredProviders.count, 1)
    }

    func testReRenderWithDifferentClosureSwapsSlotNotProvider() async throws {
        let manager = makeManager()
        let coordinator = TestCoordinator()

        coordinator.syncModifierProvider(on: manager) { _ in
            [SwiftUICompletionItem(label: "A", kind: .keyword)]
        }

        let firstAdapter = manager.registeredProviders.first as? SwiftUIClosureCompletionProvider
        XCTAssertNotNil(firstAdapter)

        coordinator.syncModifierProvider(on: manager) { _ in
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
        let coordinator = TestCoordinator()
        coordinator.syncModifierProvider(on: manager) { _ in [] }
        coordinator.syncModifierProvider(on: manager, closure: nil)

        XCTAssertTrue(manager.registeredProviders.isEmpty)
    }
}

@MainActor
private final class TestCoordinator: CodeEditorBaseCoordinator {
    override init() {
        super.init()
    }
}
#endif
