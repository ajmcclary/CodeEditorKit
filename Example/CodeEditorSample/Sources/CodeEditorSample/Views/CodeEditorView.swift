import AppKit
import CodeEditorPlugin
import SwiftUI

struct CodeEditorView: NSViewRepresentable {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String

    func makeNSView(context: Context) -> NSScrollView {
        print("DEBUG makeNSView: Creating STTextView with NSScrollView")
        print("DEBUG makeNSView: Input text length = \(text.count)")
        print("DEBUG makeNSView: Input text preview = \(String(text.prefix(50)))")

        // Create NSScrollView
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        
        // Create STTextView with proper frame - use a reasonable initial size
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        // Set delegate
        textView.textDelegate = context.coordinator

        // Set the text content
        textView.text = text
        print("DEBUG makeNSView: After setting text: \(textView.text?.count ?? -1) characters")
        print("DEBUG makeNSView: Text preview after setting: \(String((textView.text ?? "").prefix(50)))")

        // Apply configuration
        applyConfiguration(to: textView)

        // Plugin system has been removed - custom functionality would be integrated directly
        // if configuration.enableCustomPlugin {
        //     // Custom annotation functionality would be integrated directly into STTextView
        // }

        // Configure text view for scroll view
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        
        // Set the text view as the document view
        scrollView.documentView = textView
        
        // Ensure the text view is properly laid out
        textView.invalidateIntrinsicContentSize()

        // NSTextView handles layout automatically
        textView.needsLayout = true
        textView.needsDisplay = true

        // Text color will be set by applyConfiguration

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context _: Context) {
        guard let textView = scrollView.documentView as? STTextView else { return }
        print("DEBUG updateNSView: Called with text length = \(text.count)")
        print("DEBUG updateNSView: Current textView text length = \(textView.text?.count ?? -1)")

        // Update text if changed
        if textView.text != text {
            print("DEBUG updateNSView: Text changed, updating...")
            textView.text = text
            print("DEBUG updateNSView: After update: \(textView.text?.count ?? -1) characters")
        } else {
            print("DEBUG updateNSView: Text unchanged")
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
        print("DEBUG applyConfiguration: theme = \(configuration.theme)")
        print("DEBUG applyConfiguration: textColor = \(configuration.theme.textColor)")
        print("DEBUG applyConfiguration: backgroundColor = \(configuration.theme.backgroundColor)")
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
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, @preconcurrency STTextViewDelegate {
        var parent: CodeEditorView

        init(_ parent: CodeEditorView) {
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
