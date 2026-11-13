import CodeEditorConfiguration
import CodeEditorDiagnostics
import CodeEditorLanguages
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import DesignKitThemes
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

    func discardUndoHistory(in _: CodeEditorContainerView) {
        operations.append("discardUndo")
    }

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

    private func state(_ text: String, _ dependencies: EditorRuntimeDependencies) -> EditorRenderState {
        EditorRenderState(
            text: text,
            language: .swift,
            configuration: .default,
            theme: .default,
            runtimeDependencies: dependencies
        )
    }

    @Test("the echo of the editor's latest write does not revert typing done since")
    func echoOfLatestWriteIsNotASwap() {
        let operations = RecordingRenderOperations()
        let binding = EditorBindingSynchronizer { _ in }
        let reconciler = EditorRenderReconciler(operations: operations, bindingSynchronizer: binding)
        let container = CodeEditorContainerView()
        let dependencies = EditorRuntimeDependencies(memoryMonitor: MemoryMonitor())
        reconciler.mount(state("abc", dependencies), in: container)

        // The editor writes "abcX", then the user types "Y" before SwiftUI
        // renders the written value.
        operations.storedText = "abcX"
        binding.receiveEditorText("abcX")
        binding.flush()
        operations.storedText = "abcXY"
        binding.receiveEditorText("abcXY")

        reconciler.update(state("abcX", dependencies), in: container)

        #expect(operations.storedText == "abcXY")
    }

    @Test("the host may return to text the editor wrote earlier (A, B, A)")
    func hostReturningToAnEarlierEditorValueIsApplied() {
        let operations = RecordingRenderOperations()
        let binding = EditorBindingSynchronizer { _ in }
        let reconciler = EditorRenderReconciler(operations: operations, bindingSynchronizer: binding)
        let container = CodeEditorContainerView()
        let dependencies = EditorRuntimeDependencies(memoryMonitor: MemoryMonitor())
        reconciler.mount(state("abc", dependencies), in: container)
        operations.storedText = "abcX"
        binding.receiveEditorText("abcX")
        binding.flush()
        reconciler.update(state("abcX", dependencies), in: container)

        reconciler.update(state("Q", dependencies), in: container)
        #expect(operations.storedText == "Q")
        reconciler.update(state("abcX", dependencies), in: container)
        #expect(operations.storedText == "abcX")
    }

    @Test("host text unchanged since the last render never overwrites newer typing")
    func laggingHostTextIsNotASwap() {
        let operations = RecordingRenderOperations()
        let binding = EditorBindingSynchronizer { _ in }
        let reconciler = EditorRenderReconciler(operations: operations, bindingSynchronizer: binding)
        let container = CodeEditorContainerView()
        let dependencies = EditorRuntimeDependencies(memoryMonitor: MemoryMonitor())
        reconciler.mount(state("abc", dependencies), in: container)
        operations.storedText = "abcX"
        binding.receiveEditorText("abcX")

        var changed = EditorConfiguration.default
        changed.display.isLineNumbersEnabled.toggle()
        reconciler.update(
            EditorRenderState(text: "abc", language: .swift, configuration: changed, theme: .default, runtimeDependencies: dependencies),
            in: container
        )

        #expect(operations.storedText == "abcX")
    }
}
