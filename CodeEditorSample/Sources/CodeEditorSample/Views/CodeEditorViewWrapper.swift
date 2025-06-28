#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import CodeEditorPlugin
import SwiftUI

// MARK: - CodeEditorViewWrapper

#if canImport(AppKit)
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

    func makeNSView(context: Context) -> NSScrollView {
        // Create NSScrollView
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !configuration.layout.wrapLines
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        
        // Configure smooth scrolling
        if configuration.performance.smoothScrolling {
            scrollView.scrollerStyle = .overlay
            scrollView.verticalScrollElasticity = .automatic
            scrollView.horizontalScrollElasticity = .automatic
        } else {
            scrollView.scrollerStyle = .legacy
            scrollView.verticalScrollElasticity = .none
            scrollView.horizontalScrollElasticity = .none
        }

        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        // Set delegate
        textView.textDelegate = context.coordinator
        
        // Ensure autoresizing mask is properly set
        textView.autoresizingMask = [.width, .height]

        // Apply configuration FIRST before setting text
        applyConfiguration(to: textView)
        
        // Configure text view for scroll view based on word wrap setting
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !configuration.layout.wrapLines
        textView.textContainer?.widthTracksTextView = configuration.layout.wrapLines
        textView.textContainer?.heightTracksTextView = false
        
        // Set container width for non-wrapping mode
        if !configuration.layout.wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        // Set the text view as the document view
        scrollView.documentView = textView
        
        // NOW set the text content after the view is in the hierarchy
        textView.string = text
        
        // Ensure text attributes are set
        textView.textColor = PlatformColors.label
        textView.font = PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize, weight: .regular)
        textView.backgroundColor = PlatformColors.textBackgroundColor
        textView.drawsBackground = true
        
        // Force layout update after setting text
        if let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {
            layoutManager.ensureLayout(for: textContainer)
        }
        
        // Set up annotation manager if enabled
        if configuration.display.enableAnnotations {
            context.coordinator.annotationManager = AnnotationManager(textView: textView)
            context.coordinator.annotationManager?.scanForAnnotations()
        }

        // Ensure the text view is properly laid out
        textView.invalidateIntrinsicContentSize()
        textView.needsLayout = true
        textView.needsDisplay = true
        
        // Schedule a layout update after a brief delay to ensure proper rendering
        DispatchQueue.main.async {
            textView.needsDisplay = true
            textView.needsLayout = true
            
            // Force a complete re-render by triggering a text change
            let currentText = textView.string
            textView.string = ""
            textView.string = currentText
            
            if let layoutManager = textView.layoutManager,
               let textContainer = textView.textContainer {
                layoutManager.ensureLayout(for: textContainer)
            }
        }

        // Notify that text view is ready if callback provided
        onTextViewReady?(textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CodeEditorView else { return }
        
        // Update text if changed
        if textView.string != text {
            textView.string = text
            // Force a layout update after setting text
            textView.needsLayout = true
            textView.needsDisplay = true
        }

        // Check if configuration actually changed before applying
        if textView.configuration != configuration {
            applyConfiguration(to: textView)
        }
        
        // Update scroll view settings based on word wrap
        scrollView.hasHorizontalScroller = !configuration.layout.wrapLines
        
        // Update smooth scrolling settings
        if configuration.performance.smoothScrolling {
            scrollView.scrollerStyle = .overlay
            scrollView.verticalScrollElasticity = .automatic
            scrollView.horizontalScrollElasticity = .automatic
        } else {
            scrollView.scrollerStyle = .legacy
            scrollView.verticalScrollElasticity = .none
            scrollView.horizontalScrollElasticity = .none
        }
        
        // Update text container settings for word wrap
        textView.isHorizontallyResizable = !configuration.layout.wrapLines
        textView.textContainer?.widthTracksTextView = configuration.layout.wrapLines
        
        // Set container width for non-wrapping mode
        if !configuration.layout.wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        } else {
            // Reset container size for wrapping mode
            if let scrollViewWidth = scrollView.enclosingScrollView?.contentSize.width {
                textView.textContainer?.containerSize = NSSize(
                    width: scrollViewWidth,
                    height: CGFloat.greatestFiniteMagnitude
                )
            }
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

    private func applyConfiguration(to textView: CodeEditorView) {
        // Set language FIRST, before applying configuration
        // This ensures syntax highlighting works properly when the configuration enables it
        textView.setLanguage(fileExtension: language)
        
        // Apply the full configuration
        configuration.apply(to: textView)
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
            fatalError("Completion view controller not implemented")
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
        // Use the actual CodeEditorSwiftUIView implementation
        CodeEditorSwiftUIView(
            text: $text,
            language: detectLanguage(from: language),
            showLineNumbers: configuration.display.showLineNumbers,
            highlightSelectedLine: configuration.display.highlightSelectedLine,
            isEditable: configuration.behavior.isEditable,
            becomeFirstResponderOnAppear: configuration.behavior.isEditable
        )
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
