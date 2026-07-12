import CodeEditorDiagnostics
@testable import CodeEditorView
import Testing

@MainActor
@Suite("Memory management policy")
struct MemoryManagementPolicyTests {
    @Test("disabled policy does not register coordinator cleanup")
    func disabledRegistration() {
        let monitor = MemoryMonitor()
        let view = CodeEditorView(frame: .zero)
        let coordinator = MemoryManagementCoordinator(
            memoryMonitor: monitor,
            policy: .disabled,
            editorView: view
        )

        #expect(coordinator.hasRegisteredCleanupHandler == false)
    }
}
