import SwiftUI
import AppKit
import CodeEditorPlugin

struct TestEditableView: View {
    @State private var text = "Test if editing works"
    
    var body: some View {
        VStack {
            Text("Direct STTextView Test")
                .font(.headline)
            
            DirectSTTextViewWrapper()
                .frame(height: 200)
                .border(Color.blue)
            
            Text("Basic NSTextView Test")
                .font(.headline)
            
            BasicTextViewWrapper()
                .frame(height: 200)
                .border(Color.green)
        }
        .padding()
        .frame(width: 600, height: 500)
    }
}

struct DirectSTTextViewWrapper: NSViewRepresentable {
    func makeNSView(context: Context) -> STTextView {
        let textView = STTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.text = "Try editing this STTextView directly"
        textView.font = NSFont.systemFont(ofSize: 14)
        
        // Debug output
        print("STTextView isEditable: \(textView.isEditable)")
        print("STTextView isSelectable: \(textView.isSelectable)")
        
        // Try to make it first responder
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        
        return textView
    }
    
    func updateNSView(_ nsView: STTextView, context: Context) {}
}

struct BasicTextViewWrapper: NSViewRepresentable {
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.string = "Try editing this NSTextView"
        textView.font = NSFont.systemFont(ofSize: 14)
        
        return textView
    }
    
    func updateNSView(_ nsView: NSTextView, context: Context) {}
}