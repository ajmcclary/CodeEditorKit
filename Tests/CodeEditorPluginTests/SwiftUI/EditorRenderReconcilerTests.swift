import CodeEditorConfiguration
import CodeEditorDiagnostics
import CodeEditorLanguages
@testable import CodeEditorSwiftUI
import CodeEditorTheming
@testable import CodeEditorView
import Testing

@MainActor
private final class RecordingRenderOperations: EditorRenderOperating {
    private(set) var operations: [String] = []
    var storedText = ""

    func applyRuntime(_: EditorRuntimeDependencies, to _: CodeEditorContainerView) {
        operations.append("runtime")
    }

    func text(in _: CodeEditorContainerView) -> String {
        storedText
    }

    func setText(_ text: String, in _: CodeEditorContainerView, preserveSelection _: Bool) {
        operations.append("text")
        storedText = text
    }

    func setLanguage(_: Language, in _: CodeEditorContainerView) {
        operations.append("language")
    }

    func applySystemColorsIfNeeded(in _: CodeEditorContainerView) {}

    func setConfiguration(_: EditorConfiguration, in _: CodeEditorContainerView) {
        operations.append("configuration")
    }

    func stampThemeForeground(in _: CodeEditorContainerView) {}

    func applyTheme(_: Theme, to _: CodeEditorContainerView) {
        operations.append("theme")
    }

    func invalidate(_: CodeEditorContainerView) {}

    func reset() {
        operations.removeAll()
    }
}

@MainActor
@Suite("EditorRenderReconciler")
struct EditorRenderReconcilerTests {
    @Test("mount order is deterministic and unchanged updates apply runtime first")
    func operationOrdering() {
        let operations = RecordingRenderOperations()
        let reconciler = EditorRenderReconciler(operations: operations)
        let container = CodeEditorContainerView()
        let dependencies = EditorRuntimeDependencies(memoryMonitor: MemoryMonitor())
        let state = EditorRenderState(
            text: "let value = 1",
            language: .swift,
            configuration: .default,
            theme: .default,
            runtimeDependencies: dependencies
        )

        reconciler.mount(state, in: container)
        #expect(operations.operations == [
            "runtime", "text", "language", "configuration", "theme"
        ])

        operations.reset()
        let changed = reconciler.update(state, in: container)

        #expect(changed == false)
        #expect(operations.operations == ["runtime"])
    }
}
