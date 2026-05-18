import CodeEditorCommon
import CodeEditorCompletion
import CodeEditorConfiguration
import CodeEditorLanguages
import CodeEditorPlatform
import CodeEditorTheming
#if canImport(AppKit)
import AppKit
import CodeEditorView
import SwiftUI

// MARK: - MacOS NSViewRepresentable

@available(macOS 13.0, *)
struct CodeEditorRepresentable: NSViewRepresentable {
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

    func makeNSView(context: Context) -> CodeEditorContainerView {
        CodeEditorRepresentableHelper.createAndSetupContainer(
            parameters: containerParameters,
            coordinator: context.coordinator
        )
    }

    func updateNSView(_ nsView: CodeEditorContainerView, context: Context) {
        CodeEditorRepresentableHelper.updateContainer(
            nsView,
            parameters: updateParameters(environment: context.environment),
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
