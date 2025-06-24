import AppKit
import CodeEditorPlugin
import SwiftUI

struct CodeEditorView: NSViewRepresentable {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String

    func makeNSView(context: Context) -> STTextView {
        print("DEBUG makeNSView: Creating STTextView")
        print("DEBUG makeNSView: Input text length = \(text.count)")
        print("DEBUG makeNSView: Input text preview = \(String(text.prefix(50)))")

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

        // Ensure the text view is properly laid out
        textView.invalidateIntrinsicContentSize()

        // NSTextView handles layout automatically
        textView.needsLayout = true
        textView.needsDisplay = true

        // Text color will be set by applyConfiguration

        return textView
    }

    func updateNSView(_ textView: STTextView, context _: Context) {
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

        func textViewDidChangeText(_ notification: Notification) {
            if let textView = notification.object as? STTextView {
                parent.text = textView.text ?? ""
            }
        }

        func textViewDidChangeSelection(_: Notification) {
            // Handle selection changes if needed
        }
    }
}
