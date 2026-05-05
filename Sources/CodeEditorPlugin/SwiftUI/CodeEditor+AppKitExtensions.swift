#if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
    @Binding var isFocused: Bool
    let textDebounceInterval: Duration
    let onTextChange: ((String) -> Void)?
    let onSelectionChange: ((NSRange) -> Void)?

    func makeNSView(context: Context) -> CodeEditorContainerView {
        let parameters = CodeEditorRepresentableHelper.ContainerParameters(
            text: text,
            language: language,
            theme: theme,
            configuration: configuration,
            memoryMonitor: memoryMonitor,
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
            textDebounceInterval: textDebounceInterval
        )
    }

    typealias Coordinator = CodeEditorCoordinator
}

#endif
