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
    let textDebounceInterval: Duration
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
        
        // Handle focus request from environment
        if context.environment.codeEditorBecomeFirstResponder {
            Task { @MainActor in
                uiView.textView.becomeFirstResponder()
            }
        }
    }
    
    static func dismantleUIView(_: CodeEditorContainerView, coordinator: CodeEditorCoordinator) {
        // Clean up resources when view is being removed
        coordinator.removeNotificationObservers()
        coordinator.textUpdateTask?.cancel()
    }
    
    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CodeEditorContainerView, context _: Context) -> CGSize? {
        let textView = uiView.textView
        
        // Save current frame
        let originalFrame = textView.frame
        
        // Set a temporary width for size calculation
        let width = proposal.width ?? UIScreen.main.bounds.width
        textView.frame.size.width = width
        
        // Calculate content size
        let sizeThatFits = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        
        // Restore original frame
        textView.frame = originalFrame
        
        var size = sizeThatFits
        
        // Add padding for line numbers if enabled
        if configuration.display.showLineNumbers {
            size.width += configuration.layout.gutterWidth
        }
        
        // Add text container insets
        let containerInset = textView.textContainerInset
        size.width += containerInset.left + containerInset.right
        size.height += containerInset.top + containerInset.bottom
        
        // Respect proposal constraints
        if let proposedWidth = proposal.width {
            size.width = min(size.width, proposedWidth)
        }
        
        if let proposedHeight = proposal.height {
            size.height = min(size.height, proposedHeight)
        }
        
        // Ensure minimum size
        size.width = max(size.width, 100)
        size.height = max(size.height, 50)
        
        return size
    }
    
    func makeCoordinator() -> CodeEditorCoordinator {
        let coordinator = CodeEditorCoordinator(text: $text, onTextChange: onTextChange, onSelectionChange: onSelectionChange)
        coordinator.textDebounceInterval = textDebounceInterval.timeInterval
        return coordinator
    }
    
    typealias Coordinator = CodeEditorCoordinator
}

#endif
