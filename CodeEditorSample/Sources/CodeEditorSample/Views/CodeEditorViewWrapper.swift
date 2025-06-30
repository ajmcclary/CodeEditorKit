#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import CodeEditorPlugin
import SwiftUI

// MARK: - CodeEditorViewWrapper

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
        // Note: Background color now managed by the plugin's theme system
    }
}

// MARK: - UnifiedCodeEditorView

struct UnifiedCodeEditorView: NSViewRepresentable {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String
    let onTextViewReady: ((CodeEditorView) -> Void)?

    func makeNSView(context: Context) -> CodeEditorContainerView {
        // Create the container view which manages the text view, gutter, and minimap
        let containerView = CodeEditorContainerView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let textView = containerView.textView

        // Set delegate
        textView.textDelegate = context.coordinator
        
        // Apply configuration to the container view
        containerView.configuration = configuration
        
        // Set language and text
        textView.setLanguage(fileExtension: language)
        textView.string = text
        
        // Set up annotation manager if enabled
        if configuration.display.enableAnnotations {
            context.coordinator.annotationManager = AnnotationManager(textView: textView)
            context.coordinator.annotationManager?.scanForAnnotations()
        }

        // Notify that text view is ready if callback provided
        onTextViewReady?(textView)

        return containerView
    }

    func updateNSView(_ containerView: CodeEditorContainerView, context: Context) {
        let textView = containerView.textView
        
        // Update text if changed
        if textView.string != text {
            textView.string = text
        }

        // Update configuration on the container view
        if containerView.configuration != configuration {
            containerView.configuration = configuration
            textView.setLanguage(fileExtension: language)
        }
        
        // Update annotations
        if configuration.display.enableAnnotations {
            if context.coordinator.annotationManager == nil {
                context.coordinator.annotationManager = AnnotationManager(textView: textView)
            }
            context.coordinator.annotationManager?.scanForAnnotations()
        } else {
            // Clear annotations if disabled
            context.coordinator.annotationManager?.clearAnnotations()
            context.coordinator.annotationManager = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, @preconcurrency CodeEditorViewDelegate {
        var parent: UnifiedCodeEditorView
        var annotationManager: AnnotationManager?

        init(_ parent: UnifiedCodeEditorView) {
            self.parent = parent
            super.init()
        }

        // MARK: - CodeEditorViewDelegate

        func undoManager(for _: CodeEditorView) -> UndoManager? {
            nil
        }

        func textViewWillChangeText(_: Notification) {
            // Default implementation
        }

        func textViewDidChangeText(_ notification: Notification) {
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
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return NoOpCompletionViewController()
            #else
            return NoOpCompletionViewController()
            #endif
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
#endif

// MARK: - iOS Implementation

#if canImport(UIKit)
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
        // Use the modern CodeEditor implementation
        CodeEditor(text: $text, language: detectLanguage(from: language))
            .showsLineNumbers(configuration.display.showLineNumbers)
            .highlightSelectedLine(configuration.display.highlightSelectedLine)
            .editable(configuration.behavior.isEditable)
    }
    
    private func detectLanguage(from fileExtension: String) -> Language {
        switch fileExtension.lowercased() {
        case "swift":
            return .swift
        case "py", "python":
            return .python
        case "js", "javascript":
            return .javascript
        case "json":
            return .json
        default:
            return .plainText
        }
    }
}
#endif

// MARK: - NoOpCompletionViewController

/// A minimal completion view controller implementation for the sample app
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
private class NoOpCompletionViewController: NSViewController, CompletionViewControllerProtocol {
    var items: [any CompletionItem] = []
    var delegate: CompletionViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view = NSView()
    }
}
#else
private class NoOpCompletionViewController: UIViewController, CompletionViewControllerProtocol {
    var items: [any CompletionItem] = []
    var delegate: CompletionViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view = UIView()
    }
}
#endif
