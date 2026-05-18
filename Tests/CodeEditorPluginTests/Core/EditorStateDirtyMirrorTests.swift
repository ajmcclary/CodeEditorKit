@testable import CodeEditorPlugin
@testable import CodeEditorView
import SwiftUI
import Testing

#if canImport(AppKit)

@MainActor
@Suite("EditorState.isDirty mirror")
struct EditorStateDirtyMirrorTests {
    private static func makeFixture(
        initialText: String = "hello"
    ) -> (CodeEditorCoordinator, CodeEditorContainerView, EditorState) {
        let textBinding = Binding<String>(
            get: { initialText },
            set: { _ in }
        )
        let coordinator = CodeEditorCoordinator(
            text: textBinding,
            onTextChange: nil,
            onSelectionChange: nil
        )
        let editorState = EditorState()
        coordinator.hostEditorState = editorState
        let container = CodeEditorContainerView()
        coordinator.setupContainer(
            container,
            text: initialText,
            language: .plainText,
            theme: .default,
            configuration: .default,
            runtimeDependencies: EditorRuntimeDependencies(),
            onTextChange: nil,
            onSelectionChange: nil
        )
        return (coordinator, container, editorState)
    }

    @Test("Initial mount leaves isDirty false")
    func initialMountIsClean() {
        let (_, _, state) = Self.makeFixture()
        #expect(state.isDirty == false)
    }

    @Test("User edit through updateState flips isDirty true")
    func userEditFlipsDirtyTrue() {
        let (coordinator, _, state) = Self.makeFixture(initialText: "hello")
        coordinator.updateState(
            text: "hello world",
            language: .plainText,
            configuration: .default
        )
        #expect(state.isDirty == true)
    }

    @Test("Edit back to baseline returns isDirty to false")
    func editBackToBaselineCleans() {
        let (coordinator, _, state) = Self.makeFixture(initialText: "hello")
        coordinator.updateState(
            text: "hello world",
            language: .plainText,
            configuration: .default
        )
        #expect(state.isDirty == true)
        coordinator.updateState(
            text: "hello",
            language: .plainText,
            configuration: .default
        )
        #expect(state.isDirty == false)
    }

    @Test("Host-driven binding swap resets baseline")
    func hostBindingSwapResetsBaseline() {
        let (coordinator, container, state) = Self.makeFixture(initialText: "alpha")
        coordinator.updateState(
            text: "alpha-edit",
            language: .plainText,
            configuration: .default
        )
        #expect(state.isDirty == true)

        coordinator.updateContainer(
            container,
            text: "BETA",
            language: .plainText,
            theme: .default,
            configuration: .default,
            runtimeDependencies: EditorRuntimeDependencies()
        )
        #expect(state.isDirty == false)
    }

    @Test("markClean on EditorController resets the baseline")
    func markCleanResetsBaseline() {
        let (coordinator, container, state) = Self.makeFixture(initialText: "hello")
        coordinator.updateState(
            text: "hello world",
            language: .plainText,
            configuration: .default
        )
        #expect(state.isDirty == true)

        let controller = EditorController()
        controller.attach(to: container.textView)
        controller.markClean()
        #expect(state.isDirty == false)

        coordinator.updateState(
            text: "hello world more",
            language: .plainText,
            configuration: .default
        )
        #expect(state.isDirty == true)
    }
}

#endif
