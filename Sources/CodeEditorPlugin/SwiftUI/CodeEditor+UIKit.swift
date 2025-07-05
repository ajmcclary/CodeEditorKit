#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - IOS/Catalyst UIViewRepresentable

@available(iOS 16.0, *)
struct CodeEditorRepresentable: UIViewRepresentable {
    @Binding var text: String
    let language: Language
    let theme: CodeEditorSwiftUITheme
    let configuration: EditorConfiguration
    @Binding var isFocused: Bool
    let onTextChange: ((String) -> Void)?
    let onSelectionChange: ((NSRange) -> Void)?
    
    func makeUIView(context: Context) -> CodeEditorContainerView {
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
        // Set up the text view delegate for iOS
        context.coordinator.setupTextViewDelegate(container.textView)
        return container
    }
    
    func updateUIView(_ uiView: CodeEditorContainerView, context: Context) {
        context.coordinator.updateContainer(uiView, text: text, language: language, theme: theme, configuration: configuration)
    }
    
    func makeCoordinator() -> CodeEditorCoordinator {
        CodeEditorCoordinator(text: $text, onTextChange: onTextChange, onSelectionChange: onSelectionChange)
    }
    
    typealias Coordinator = CodeEditorCoordinator
}

#endif
