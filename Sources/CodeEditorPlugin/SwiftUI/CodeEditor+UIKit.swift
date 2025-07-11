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
    let memoryMonitor: MemoryMonitor
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
            memoryMonitor: memoryMonitor,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
        // Set up the text view delegate for iOS
        context.coordinator.setupTextViewDelegate(container.textView)
        return container
    }
    
    func updateUIView(_ uiView: CodeEditorContainerView, context: Context) {
        context.coordinator.updateContainer(uiView, text: text, language: language, theme: theme, configuration: configuration)
        
        // Handle focus request from environment using coordinator's tracking
        context.coordinator.requestFocusIfNeeded(
            for: uiView,
            shouldBecomeFirstResponder: context.environment.codeEditorBecomeFirstResponder
        )
        
        // Reset tracking if focus is no longer requested
        if !context.environment.codeEditorBecomeFirstResponder {
            context.coordinator.resetFocusTracking()
        }
    }
    
    static func dismantleUIView(_: CodeEditorContainerView, coordinator: CodeEditorCoordinator) {
        CodeEditorRepresentableHelper.dismantle(coordinator: coordinator)
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
        
        // Apply common size constraints
        return CodeEditorRepresentableHelper.applyCommonSizeConstraints(size, proposal: proposal)
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
