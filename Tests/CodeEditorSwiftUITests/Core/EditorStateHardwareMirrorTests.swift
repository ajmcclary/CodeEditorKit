import CodeEditorConfiguration
import CodeEditorDiagnostics
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import SwiftUI
import Testing

#if canImport(AppKit)

@MainActor
@Suite("EditorState.hardwareAccelerationActive mirror")
struct EditorStateHardwareMirrorTests {
    private static func makeFixture(
        useHardwareAcceleration: Bool
    ) -> (CodeEditorCoordinator, CodeEditorContainerView, EditorState) {
        var config: EditorConfiguration = .default
        config.performance.useHardwareAcceleration = useHardwareAcceleration

        let textBinding = Binding<String>(
            get: { "" },
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
            text: "",
            language: .plainText,
            theme: .default,
            configuration: config,
            runtimeDependencies: EditorRuntimeDependencies(),
            onTextChange: nil,
            onSelectionChange: nil
        )
        return (coordinator, container, editorState)
    }

    @Test("AppKit mount with useHardwareAcceleration true publishes true")
    func appKitMountWithKnobOn() {
        let (_, _, state) = Self.makeFixture(useHardwareAcceleration: true)
        #expect(state.hardwareAccelerationActive == true)
    }

    @Test("AppKit mount with useHardwareAcceleration false publishes false")
    func appKitMountWithKnobOff() {
        let (_, _, state) = Self.makeFixture(useHardwareAcceleration: false)
        #expect(state.hardwareAccelerationActive == false)
    }

    @Test("Sticky at mount: later updateContainer with flipped knob does not toggle the mirror")
    func stickyAtMount() {
        let (coordinator, container, state) = Self.makeFixture(useHardwareAcceleration: true)
        #expect(state.hardwareAccelerationActive == true)

        var flipped: EditorConfiguration = .default
        flipped.performance.useHardwareAcceleration = false
        coordinator.updateContainer(
            container,
            text: "",
            language: .plainText,
            theme: .default,
            configuration: flipped,
            runtimeDependencies: EditorRuntimeDependencies()
        )
        #expect(state.hardwareAccelerationActive == true)
    }
}

#endif
