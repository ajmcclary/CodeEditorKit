#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
import Testing

@MainActor
@Suite("EditorController.selectRange")
struct EditorControllerSelectRangeTests {
    @Test("selectRange is a no-op when no view is attached")
    func noViewAttached() {
        let controller = EditorController()
        // Should not crash; nothing observable to assert beyond non-crash.
        controller.selectRange(NSRange(location: 0, length: 4))
    }

    @Test("selectRange updates the attached view's selection")
    func selectsRangeInAttachedView() {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        view.string = "Hello, world"
        controller.attach(to: view)

        controller.selectRange(NSRange(location: 7, length: 5), scroll: false)

        #expect(view.selectedRange() == NSRange(location: 7, length: 5))
    }
}
#endif
