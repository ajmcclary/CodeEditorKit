#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import CodeEditorPlugin
import SwiftUI

// MARK: - CodeEditorViewWrapper

/// Wrapper for CodeEditor on macOS native platform.
///
/// This wrapper provides NSViewRepresentable integration for macOS, which allows:
/// - Direct access to the underlying `CodeEditorView` (NSTextView)
/// - Manual scroll view configuration
/// - Annotation manager integration
/// - Fine-grained control over text view behavior
///
/// The complexity is necessary on macOS to properly integrate with AppKit
/// and provide features that SwiftUI doesn't expose natively.
///
/// ## Why Different from iOS/Catalyst?
/// 
/// The macOS version requires a custom NSViewRepresentable implementation because:
/// 1. **Scroll View Management**: macOS needs explicit NSScrollView setup and configuration,
///    while iOS handles this automatically through UITextView's built-in scrolling.
/// 2. **Annotation Manager Access**: The macOS wrapper provides direct access to the text view
///    for annotation scanning, which isn't available through the SwiftUI CodeEditor component.
/// 3. **Text Container Configuration**: macOS requires manual configuration of text container
///    properties for proper text wrapping and resizing behavior.
/// 4. **Delegate Pattern**: The NSViewRepresentable allows full CodeEditorViewDelegate
///    implementation for advanced text handling that SwiftUI doesn't expose.
/// 5. **Performance**: Direct NSTextView access allows for performance optimizations
///    specific to macOS that aren't possible through the SwiftUI layer.
struct MacOSCodeEditorViewWrapper: View, CodeEditorViewWrapperProtocol {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String
    let onTextViewReady: ((CodeEditorView) -> Void)?

    init(
        configuration: EditorConfiguration,
        text: Binding<String>,
        language: String,
        onTextViewReady: ((CodeEditorView) -> Void)? = nil
    ) {
        self.configuration = configuration
        self._text = text
        self.language = language
        self.onTextViewReady = onTextViewReady
    }

    var body: some View {
        UnifiedCodeEditorView(
            configuration: configuration,
            text: $text,
            language: language,
            onTextViewReady: onTextViewReady
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(PlatformColors.textBackgroundColor))
    }
}

// MARK: - UnifiedCodeEditorView

struct UnifiedCodeEditorView: NSViewRepresentable {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String
    let onTextViewReady: ((CodeEditorView) -> Void)?
    
    typealias NSViewType = CodeEditorContainerView

    func makeNSView(context: Context) -> CodeEditorContainerView {
        // Create the container view which includes minimap support
        let containerView = CodeEditorContainerView()
        
        // Apply configuration to the container
        containerView.configuration = configuration
        
        // Get the text view from the container
        let textView = containerView.textView
        
        // Configure the text view
        textView.setLanguage(fileExtension: language)
        textView.text = text
        
        // Configure the delegate
        textView.textDelegate = context.coordinator
        
        // Setup annotation manager
        context.coordinator.annotationManager = AnnotationManager(textView: textView)
        if configuration.display.enableAnnotations {
            context.coordinator.annotationManager?.scanForAnnotations()
        }
        
        // Store reference to text view for updates
        context.coordinator.textView = textView
        
        // Call ready callback if provided
        onTextViewReady?(textView)
        
        return containerView
    }

    func updateNSView(_ containerView: CodeEditorContainerView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        
        // Only update text if it's different to avoid cursor jumps
        if textView.text != text {
            textView.text = text
        }
        
        // Update container configuration (this handles minimap settings)
        containerView.configuration = configuration
        
        // Update language if needed
        textView.setLanguage(fileExtension: language)
        
        // Update annotation scanning based on configuration
        if configuration.display.enableAnnotations {
            if context.coordinator.annotationManager == nil {
                context.coordinator.annotationManager = AnnotationManager(textView: textView)
            }
            context.coordinator.annotationManager?.scanForAnnotations()
        } else {
            context.coordinator.annotationManager = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Coordinator
    
    class Coordinator: NSObject, CodeEditorViewDelegate {
        let parent: UnifiedCodeEditorView
        var annotationManager: AnnotationManager?
        weak var textView: CodeEditorView?

        init(parent: UnifiedCodeEditorView) {
            self.parent = parent
            super.init()
        }

        // MARK: - CodeEditorViewDelegate Required Methods
        
        func undoManager(for _: CodeEditorView) -> UndoManager? {
            nil
        }
        
        func textViewWillChangeText(_: Notification) {
            // Default implementation
        }
        
        func textViewDidChangeText(_: Notification) {
            // Default implementation
        }

        // MARK: - Text Change Notifications

        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? CodeEditorView {
                parent.text = textView.text ?? ""
                
                // Re-scan for annotations if enabled
                if parent.configuration.display.enableAnnotations {
                    annotationManager?.scanForAnnotations()
                }
            }
        }

        func textViewDidChangeSelection(_: Notification) {
            // Handle selection changes if needed
        }

        func textView(
            _: CodeEditorView,
            shouldChangeTextIn _: NSTextRange,
            replacementString: String?
        ) -> Bool {
            guard replacementString != nil else { return true }
            
            // Note: Tab handling and auto-indent would require deeper integration with CodeEditorView's
            // text system. For now, these features are documented but not implemented.
            
            return true
        }

        func textView(
            _: CodeEditorView,
            willChangeTextIn _: NSTextRange,
            replacementString _: String
        ) {
            // Default implementation
        }

        func textView(
            _: CodeEditorView,
            didChangeTextIn _: NSTextRange,
            replacementString _: String
        ) {
            // Default implementation
        }

        func textView(_: CodeEditorView, clickedOnLink _: Any, at _: any NSTextLocation) -> Bool {
            false
        }

        func textView(_: CodeEditorView, insertCompletionItem _: any CompletionItem) {
            // Default implementation
        }

        func textViewCompletionViewController(_: CodeEditorView) -> any CompletionViewControllerRepresentable {
            // For the sample app, we don't provide completion functionality
            // Return a minimal implementation that satisfies the protocol
            NoOpCompletionViewController()
        }

        func textViewInsertionPointView(
            _: CodeEditorView,
            frame _: CGRect
        ) -> (any InsertionPointIndicating)? {
            nil
        }

        func textView(
            _: CodeEditorView,
            clickedOnAttachment _: NSTextAttachment,
            at _: any NSTextLocation
        ) -> Bool {
            false
        }

        func textView(
            _: CodeEditorView,
            shouldAllowInteractionWith _: NSTextAttachment,
            at _: any NSTextLocation
        ) -> Bool {
            true
        }
    }
}

// MARK: - NoOpCompletionViewController

class NoOpCompletionViewController: NSViewController, CompletionViewControllerRepresentable {
    var items: [any CompletionItem] = []
    weak var delegate: CompletionViewControllerDelegate?
    
    func present(in _: PlatformView, at _: CGPoint) {
        // No-op
    }
    
    func dismiss() {
        // No-op
    }
    
    func update(with items: [any CompletionItem]) {
        self.items = items
    }
}

#endif
