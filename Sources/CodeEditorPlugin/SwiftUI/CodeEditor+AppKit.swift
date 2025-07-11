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
    let memoryMonitor: MemoryMonitor
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
            memoryMonitor: memoryMonitor,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
        return container
    }
    
    func updateNSView(_ nsView: CodeEditorContainerView, context: Context) {
        context.coordinator.updateContainer(nsView, text: text, language: language, theme: theme, configuration: configuration)
        
        // Handle focus request from environment using coordinator's tracking
        context.coordinator.requestFocusIfNeeded(
            for: nsView,
            shouldBecomeFirstResponder: context.environment.codeEditorBecomeFirstResponder
        )
        
        // Reset tracking if focus is no longer requested
        if !context.environment.codeEditorBecomeFirstResponder {
            context.coordinator.resetFocusTracking()
        }
    }
    
    static func dismantleNSView(_: CodeEditorContainerView, coordinator: CodeEditorCoordinator) {
        CodeEditorRepresentableHelper.dismantle(coordinator: coordinator)
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
        if configuration.display.isLineNumbersEnabled {
            size.width += configuration.layout.gutterWidth
        }
        
        if configuration.display.showMinimap {
            size.width += configuration.layout.minimapWidth
        }
        
        // Add text container insets
        let containerInset = textView.textContainerInset
        size.width += containerInset.width * 2
        size.height += containerInset.height * 2
        
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
