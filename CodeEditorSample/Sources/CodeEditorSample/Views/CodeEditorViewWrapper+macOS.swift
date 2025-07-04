#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import CodeEditorPlugin
import SwiftUI

// MARK: - CodeEditorViewWrapper

struct CodeEditorViewWrapper: View {
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
    
    typealias NSViewType = NSScrollView

    func makeNSView(context: Context) -> NSScrollView {
        // Create scroll view first
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !configuration.layout.wrapLines
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]
        
        // Create text view with a reasonable initial size
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
        
        // Configure text view for scrolling
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !configuration.layout.wrapLines
        textView.autoresizingMask = .width
        
        // Configure text container
        textView.textContainer?.widthTracksTextView = configuration.layout.wrapLines
        textView.textContainer?.containerSize = NSSize(
            width: configuration.layout.wrapLines ? 300 : CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        
        // Set up scroll view
        scrollView.documentView = textView
        
        // Configure the text view
        configuration.apply(to: textView)
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
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        
        // Only update text if it's different to avoid cursor jumps
        if textView.text != text {
            textView.text = text
        }
        
        // Update configuration
        configuration.apply(to: textView)
        
        // Update language if needed
        textView.setLanguage(fileExtension: language)
        
        // Update scroll view settings
        nsView.hasHorizontalScroller = !configuration.layout.wrapLines
        textView.isHorizontallyResizable = !configuration.layout.wrapLines
        textView.textContainer?.widthTracksTextView = configuration.layout.wrapLines
        
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
        
        func undoManager(for textView: CodeEditorView) -> UndoManager? {
            nil
        }
        
        func textViewWillChangeText(_ notification: Notification) {
            // Default implementation
        }
        
        func textViewDidChangeText(_ notification: Notification) {
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
            _ textView: CodeEditorView,
            shouldChangeTextIn affectedCharRange: NSTextRange,
            replacementString: String?
        ) -> Bool {
            guard replacementString != nil else { return true }
            
            // Note: Tab handling and auto-indent would require deeper integration with CodeEditorView's
            // text system. For now, these features are documented but not implemented.
            
            return true
        }

        func textView(
            _ textView: CodeEditorView,
            willChangeTextIn affectedCharRange: NSTextRange,
            replacementString: String
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

        func textViewCompletionViewController(_: CodeEditorView) -> any CompletionViewControllerProtocol {
            // For the sample app, we don't provide completion functionality
            // Return a minimal implementation that satisfies the protocol
            return NoOpCompletionViewController()
        }

        func textViewInsertionPointView(
            _: CodeEditorView,
            frame _: CGRect
        ) -> (any InsertionPointIndicatorProtocol)? {
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

class NoOpCompletionViewController: NSViewController, CompletionViewControllerProtocol {
    var items: [any CompletionItem] = []
    weak var delegate: CompletionViewControllerDelegate?
    
    func present(in containerView: PlatformView, at location: CGPoint) {
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