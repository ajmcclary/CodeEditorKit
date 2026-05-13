#if canImport(AppKit)
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
            #expect(message.lowercased().contains("sourcekit-lsp"))
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
