#if canImport(AppKit)
import CodeEditorCommon
import CodeEditorPlugin
@testable import CodeEditorSample
import Testing

@MainActor
@Suite("LSPSampleCoordinator state")
struct LSPSampleCoordinatorStateTests {
    @Test func startsOff() {
        let coordinator = LSPSampleCoordinator(
            memoryMonitor: MemoryMonitor.mock(),
            serverResolver: StubProcessResolver.succeeds
        )
        #expect(coordinator.state == .off)
    }

    @Test func resolverFailureTransitionsToFailed() async {
        let coordinator = LSPSampleCoordinator(
            memoryMonitor: MemoryMonitor.mock(),
            serverResolver: StubProcessResolver.fails
        )

        await coordinator.start(workspaceRoot: nil)

        if case .failed(let message) = coordinator.state {
            // The coordinator renders `CodeEditorError.languageServerNotAvailable("Swift")`
            // with its built-in `recoverySuggestion`, so the failure message
            // names the language and points at language-server configuration.
            let lowered = message.lowercased()
            #expect(lowered.contains("language server"))
            #expect(message.contains("Swift"))
        } else {
            Issue.record("expected .failed, got \(coordinator.state)")
        }
    }

    @Test func stopFromOffIsANoOp() async {
        let coordinator = LSPSampleCoordinator(
            memoryMonitor: MemoryMonitor.mock(),
            serverResolver: StubProcessResolver.succeeds
        )
        #expect(coordinator.state == .off)

        await coordinator.stop()

        #expect(coordinator.state == .off)
    }
}
#endif
