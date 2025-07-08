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
    let textDebounceInterval: Duration
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
        
        // Handle focus request from environment
        if context.environment.codeEditorBecomeFirstResponder {
            Task { @MainActor in
                nsView.window?.makeFirstResponder(nsView.textView)
            }
        }
    }
    
    static func dismantleNSView(_: CodeEditorContainerView, coordinator: CodeEditorCoordinator) {
        // Clean up resources when view is being removed
        coordinator.removeNotificationObservers()
        coordinator.textUpdateTask?.cancel()
    }
    
    @available(macOS 13.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: CodeEditorContainerView, context _: Context) -> CGSize? {
        let textView = nsView.textView
        
        // Calculate intrinsic content size based on text
        let textContainer = textView.textContainer
        let layoutManager = textView.layoutManager
        
        guard let textContainer,
              let layoutManager else {
            return proposal.replacingUnspecifiedDimensions()
        }
        
        // Force layout
        layoutManager.ensureLayout(for: textContainer)
        
        // Get the used rect
        let usedRect = layoutManager.usedRect(for: textContainer)
        var size = usedRect.size
        
        // Add padding for line numbers and minimap if enabled
        if configuration.display.showLineNumbers {
            size.width += configuration.layout.gutterWidth
        }
        
        if configuration.display.showMinimap {
            size.width += configuration.layout.minimapWidth
        }
        
        // Add text container insets
        let containerInset = textView.textContainerInset
        size.width += containerInset.width * 2
        size.height += containerInset.height * 2
        
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
