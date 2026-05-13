#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing

@Suite("CompletionSampleCoordinator")
@MainActor
struct CompletionSampleCoordinatorTests {
    @Test("attach registers nine providers (eight built-ins + one demo)")
    func attachRegistersAllProviders() {
        let coordinator = CompletionSampleCoordinator()
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        controller.attach(to: view)

        coordinator.attach(controller: controller)
        defer { coordinator.detach() }

        let ids = controller.registeredCompletionProviders.map(\.id).sorted()
        #expect(ids.count == 9)
        #expect(ids.contains("sample.demo"))
        #expect(ids.contains("swift-universal"))
    }

    @Test("registered providers in the snapshot mirror the controller")
    func snapshotMirrorsController() {
        let coordinator = CompletionSampleCoordinator()
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        controller.attach(to: view)

        coordinator.attach(controller: controller)
        defer { coordinator.detach() }
        coordinator.refresh()

        #expect(coordinator.snapshot.registeredProviders.count == 9)
    }

    @Test("activity ring is bounded at 20 newest-first")
    func ringIsBounded() {
        let coordinator = CompletionSampleCoordinator()
        for index in 0..<25 {
            coordinator.record(.init(
                providerId: "p\(index)",
                language: .swift,
                triggerCharacter: nil,
                prefix: "",
                itemCount: 0,
                durationMs: 0,
                timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
                error: nil
            ))
        }
        #expect(coordinator.snapshot.recentActivity.count == 20)
        // Newest first.
        let topId = coordinator.snapshot.recentActivity.first?.providerId
        #expect(topId == "p24")
    }

    @Test("resetActivity clears recent and last but leaves controller stats alone")
    func resetActivity() {
        let coordinator = CompletionSampleCoordinator()
        coordinator.record(.init(
            providerId: "p",
            language: .swift,
            triggerCharacter: nil,
            prefix: "",
            itemCount: 1,
            durationMs: 0.5,
            timestamp: Date(),
            error: nil
        ))
        #expect(coordinator.snapshot.recentActivity.count == 1)
        #expect(coordinator.snapshot.lastActivity != nil)

        coordinator.resetActivity()

        #expect(coordinator.snapshot.recentActivity.isEmpty)
        #expect(coordinator.snapshot.lastActivity == nil)
    }

    @Test("snapshot before attach has zero requests and empty providers")
    func emptyBeforeAttach() {
        let coordinator = CompletionSampleCoordinator()
        #expect(coordinator.snapshot.registeredProviders.isEmpty)
        #expect(coordinator.snapshot.requests == 0)
        #expect(coordinator.snapshot.lastActivity == nil)
    }

    @Test("fireAtCursor calls through to the attached controller without crashing")
    func fireAtCursorIsSafe() async {
        let coordinator = CompletionSampleCoordinator()
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        view.isCodeCompletionEnabled = true
        controller.attach(to: view)
        coordinator.attach(controller: controller)
        defer { coordinator.detach() }

        coordinator.fireAtCursor()      // must not crash, even with empty buffer
    }
}
#endif
