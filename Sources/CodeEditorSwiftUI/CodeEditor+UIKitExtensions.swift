#if canImport(UIKit)
import CodeEditorCommon
import CodeEditorCompletion
import CodeEditorLanguages
import CodeEditorView
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
    let hostEditorState: EditorState
    let onTextChange: ((String) -> Void)?
    let onSelectionChange: ((NSRange) -> Void)?
    let swiftUICompletionProvider: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?

    func makeUIView(context: Context) -> CodeEditorContainerView {
        CodeEditorRepresentableHelper.createAndSetupContainer(
            parameters: containerParameters,
            coordinator: context.coordinator
        )
    }

    func updateUIView(_ uiView: CodeEditorContainerView, context: Context) {
        CodeEditorRepresentableHelper.updateContainer(
            uiView,
            parameters: updateParameters(environment: context.environment),
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
