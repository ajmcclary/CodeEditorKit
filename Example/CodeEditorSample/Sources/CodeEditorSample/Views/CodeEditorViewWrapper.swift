import CodeEditorPlugin
import SwiftUI

// MARK: - CodeEditorViewWrapper

struct CodeEditorViewWrapper: View {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String
    let onTextViewReady: (STTextView) -> Void

    var body: some View {
        CodeEditorViewWithCallback(
            configuration: configuration,
            text: $text,
            language: language,
            onTextViewReady: onTextViewReady
        )
        .background(Color(configuration.theme.backgroundColor))
    }
}

// MARK: - CodeEditorViewWithCallback

struct CodeEditorViewWithCallback: NSViewRepresentable {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String
    let onTextViewReady: (STTextView) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        // Create NSScrollView
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        // Set delegate
        textView.textDelegate = context.coordinator

        // Set the text content
        textView.text = text

        // Configure text view for scroll view
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        
        // Set the text view as the document view
        scrollView.documentView = textView
        
        // Apply configuration
        applyConfiguration(to: textView)

        // Notify that text view is ready
        onTextViewReady(textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context _: Context) {
        guard let textView = scrollView.documentView as? STTextView else { return }
        // Update text if changed
        if textView.text != text {
            textView.text = text
        }

        // Update configuration
        applyConfiguration(to: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func applyConfiguration(to textView: STTextView) {
        // Basic settings
        textView.isEditable = configuration.isEditable
        textView.isSelectable = true

        // Line numbers
        textView.showsLineNumbers = configuration.showLineNumbers

        // Font
        textView.font = NSFont.monospacedSystemFont(
            ofSize: configuration.fontSize,
            weight: .regular
        )

        // Colors
        textView.textColor = configuration.theme.textColor
        textView.backgroundColor = configuration.theme.backgroundColor
        textView.selectedLineHighlightColor = configuration.theme.selectedLineColor

        // Line highlighting
        textView.highlightSelectedLine = configuration.highlightSelectedLine

        // Invisible characters
        textView.showsInvisibleCharacters = configuration.showInvisibleCharacters

        // Text container settings
        textView.widthTracksTextView = configuration.wrapLines
        textView.isHorizontallyResizable = !configuration.wrapLines

        // Make sure the text view is properly sized
        textView.isVerticallyResizable = true

        // Tab settings
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = []
        paragraphStyle.defaultTabInterval = CGFloat(configuration.tabWidth) * 7.0
        paragraphStyle.lineSpacing = configuration.lineSpacing
        textView.defaultParagraphStyle = paragraphStyle

        // Set language for syntax highlighting using file extension
        textView.setLanguage(fileExtension: language)
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, @preconcurrency STTextViewDelegate {
        var parent: CodeEditorViewWithCallback

        init(_ parent: CodeEditorViewWithCallback) {
            self.parent = parent
            super.init()
        }

        // MARK: - STTextViewDelegate
        
        func undoManager(for textView: STTextView) -> UndoManager? {
            return nil
        }
        
        func textViewWillChangeText(_ notification: Notification) {
            // Default implementation
        }

        func textViewDidChangeText(_ notification: Notification) {
            if let textView = notification.object as? STTextView {
                parent.text = textView.text ?? ""
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            // Handle selection changes if needed
        }
        
        func textView(
            _ textView: STTextView,
            shouldChangeTextIn affectedCharRange: NSTextRange,
            replacementString: String?
        ) -> Bool {
            return true
        }
        
        func textView(
            _ textView: STTextView,
            willChangeTextIn affectedCharRange: NSTextRange,
            replacementString: String
        ) {
            // Default implementation
        }
        
        func textView(
            _ textView: STTextView,
            didChangeTextIn affectedCharRange: NSTextRange,
            replacementString: String
        ) {
            // Default implementation
        }
        
        func textView(_ textView: STTextView, clickedOnLink link: Any, at location: any NSTextLocation) -> Bool {
            return false
        }
        
        func textView(_ textView: STTextView, insertCompletionItem item: any STCompletionItem) {
            // Default implementation
        }
        
        func textViewCompletionViewController(_ textView: STTextView) -> any STCompletionViewControllerProtocol {
            fatalError("Completion view controller not implemented")
        }
        
        func textViewInsertionPointView(
            _ textView: STTextView,
            frame: CGRect
        ) -> (any STInsertionPointIndicatorProtocol)? {
            return nil
        }
        
        func textView(
            _ textView: STTextView,
            clickedOnAttachment attachment: NSTextAttachment,
            at location: any NSTextLocation
        ) -> Bool {
            return false
        }
        
        func textView(
            _ textView: STTextView,
            shouldAllowInteractionWith attachment: NSTextAttachment,
            at location: any NSTextLocation
        ) -> Bool {
            return true
        }
    }
}
