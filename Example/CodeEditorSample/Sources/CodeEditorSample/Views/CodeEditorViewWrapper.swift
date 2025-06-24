import SwiftUI
import CodeEditorPlugin

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

struct CodeEditorViewWithCallback: NSViewRepresentable {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String
    let onTextViewReady: (STTextView) -> Void
    
    func makeNSView(context: Context) -> STTextView {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        
        // Set delegate
        textView.textDelegate = context.coordinator
        
        // Set the text content
        textView.text = text
        
        // Apply configuration
        applyConfiguration(to: textView)
        
        // Notify that text view is ready
        onTextViewReady(textView)
        
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