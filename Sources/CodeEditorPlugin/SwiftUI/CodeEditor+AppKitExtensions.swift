#if canImport(AppKit)
import AppKit
import SwiftUI

// MARK: - MacOS NSViewRepresentable

@available(macOS 13.0, *)
struct CodeEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    let language: Language
    let theme: Theme
    let configuration: EditorConfiguration
    let memoryMonitor: MemoryMonitor
    let textDebounceInterval: Duration
    let interactionState: Binding<EditorInteractionState>
    let editorController: EditorController?
    let onTextChange: ((String) -> Void)?
    let onSelectionChange: ((NSRange) -> Void)?

    func makeNSView(context: Context) -> CodeEditorContainerView {
        let parameters = CodeEditorRepresentableHelper.ContainerParameters(
            text: text,
            language: language,
            theme: theme,
            configuration: configuration,
            memoryMonitor: memoryMonitor,
            interactionState: interactionState,
            editorController: editorController,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )

        return CodeEditorRepresentableHelper.createAndSetupContainer(
            parameters: parameters,
            coordinator: context.coordinator
        )
    }

    func updateNSView(_ nsView: CodeEditorContainerView, context: Context) {
        let parameters = CodeEditorRepresentableHelper.UpdateParameters(
            text: text,
            language: language,
            theme: theme,
            configuration: configuration,
            interactionState: interactionState,
            editorController: editorController,
            environment: context.environment
        )

        CodeEditorRepresentableHelper.updateContainer(
            nsView,
            parameters: parameters,
            coordinator: context.coordinator
        )
    }

    static func dismantleNSView(_: CodeEditorContainerView, coordinator: CodeEditorCoordinator) {
        CodeEditorRepresentableHelper.dismantle(coordinator: coordinator)
    }

    @available(macOS 13.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: CodeEditorContainerView, context _: Context) -> CGSize? {
        CodeEditorRepresentableHelper.calculateSize(
            for: nsView,
            proposal: proposal,
            configuration: configuration
        )
    }

    func makeCoordinator() -> CodeEditorCoordinator {
        CodeEditorRepresentableHelper.makeCoordinator(
            text: $text,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            textDebounceInterval: textDebounceInterval,
            interactionState: interactionState
        )
    }

    typealias Coordinator = CodeEditorCoordinator
}

#endif
