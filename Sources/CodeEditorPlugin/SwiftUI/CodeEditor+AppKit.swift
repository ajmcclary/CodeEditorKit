#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import SwiftUI

// MARK: - MacOS NSViewRepresentable

@available(macOS 13.0, *)
struct CodeEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    let language: Language
    let theme: CodeEditorSwiftUITheme
    let configuration: EditorConfiguration
    @Binding var isFocused: Bool
    let onTextChange: ((String) -> Void)?
    let onSelectionChange: ((NSRange) -> Void)?
    
    func makeNSView(context: Context) -> CodeEditorContainerView {
        let container = CodeEditorContainerView()
        context.coordinator.setupContainer(
            container,
            text: text,
            language: language,
            theme: theme,
            configuration: configuration,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
        return container
    }
    
    func updateNSView(_ nsView: CodeEditorContainerView, context: Context) {
        context.coordinator.updateContainer(nsView, text: text, language: language, theme: theme, configuration: configuration)
    }
    
    func makeCoordinator() -> CodeEditorCoordinator {
        CodeEditorCoordinator(text: $text, onTextChange: onTextChange, onSelectionChange: onSelectionChange)
    }
    
    typealias Coordinator = CodeEditorCoordinator
}

#endif
