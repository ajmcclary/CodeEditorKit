#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - IOS/iOS UIViewRepresentable

@available(iOS 16.0, *)
struct CodeEditorRepresentable: UIViewRepresentable {
    @Binding var text: String
    let language: Language
    let theme: Theme
    let configuration: EditorConfiguration
    let runtimeDependencies: EditorRuntimeDependencies
    let textDebounceInterval: Duration
    let interactionState: Binding<EditorInteractionState>
    let editorController: EditorController?
    let onTextChange: ((String) -> Void)?
    let onSelectionChange: ((NSRange) -> Void)?

    func makeUIView(context: Context) -> CodeEditorContainerView {
        let parameters = CodeEditorRepresentableHelper.ContainerParameters(
            text: text,
            language: language,
            theme: theme,
            configuration: configuration,
            runtimeDependencies: runtimeDependencies,
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

    func updateUIView(_ uiView: CodeEditorContainerView, context: Context) {
        let parameters = CodeEditorRepresentableHelper.UpdateParameters(
            text: text,
            language: language,
            theme: theme,
            configuration: configuration,
            runtimeDependencies: runtimeDependencies,
            interactionState: interactionState,
            editorController: editorController,
            environment: context.environment
        )

        CodeEditorRepresentableHelper.updateContainer(
            uiView,
            parameters: parameters,
            coordinator: context.coordinator
        )
    }

    static func dismantleUIView(_: CodeEditorContainerView, coordinator: CodeEditorCoordinator) {
        CodeEditorRepresentableHelper.dismantle(coordinator: coordinator)
    }

    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CodeEditorContainerView, context _: Context) -> CGSize? {
        CodeEditorRepresentableHelper.calculateSize(
            for: uiView,
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
