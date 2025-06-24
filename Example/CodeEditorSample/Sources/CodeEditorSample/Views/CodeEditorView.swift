import SwiftUI
import AppKit
import CodeEditorPlugin

struct CodeEditorView: NSViewRepresentable {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String
    
    func makeNSView(context: Context) -> STTextView {
        // Create STTextView with proper frame
        let textView = STTextView(frame: .zero)
        
        // Set delegate
        textView.textDelegate = context.coordinator
        
        // Set the text content
        textView.text = text
        print("DEBUG: Setting text with \(text.count) characters")
        print("DEBUG: Text after setting: \(textView.text ?? "nil")")
        
        // Apply configuration
        applyConfiguration(to: textView)
        
        // Add custom plugin if enabled
        if configuration.enableCustomPlugin {
            let customPlugin = CustomAnnotationPlugin()
            textView.addPlugin(customPlugin)
        }
        
        // Ensure the text view is properly laid out
        textView.invalidateIntrinsicContentSize()
        
        // Force initial layout
        textView.textLayoutManager.ensureLayout(for: textView.textLayoutManager.documentRange)
        textView.textLayoutManager.textViewportLayoutController.layoutViewport()
        textView.needsLayout = true
        textView.needsDisplay = true
        
        // Force text color to ensure it's not white on white
        textView.textColor = NSColor.black
        
        return textView
    }
    
    func updateNSView(_ textView: STTextView, context: Context) {
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
        
        func textViewDidChangeSelection(_ notification: Notification) {
            // Handle selection changes if needed
        }
    }
}