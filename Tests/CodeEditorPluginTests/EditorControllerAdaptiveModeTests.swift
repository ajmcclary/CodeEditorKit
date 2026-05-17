import CodeEditorDiagnostics
@testable import CodeEditorPlugin
import Testing

@Suite("EditorController.adaptivePerformanceMode")
struct EditorControllerAdaptiveModeTests {
    @Test
    @MainActor
    func returnsNilBeforeAttach() {
        let controller = EditorController()
        #expect(controller.adaptivePerformanceMode == nil)
    }
}
