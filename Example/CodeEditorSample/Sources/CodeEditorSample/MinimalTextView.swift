import SwiftUI
import AppKit
import CodeEditorPlugin

// A minimal wrapper that focuses on making STTextView editable
struct MinimalTextView: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSView {
        // Create a container view
        let containerView = NSView()
        
        // Create the STTextView
        let textView = STTextView(frame: .zero)
        textView.isEditable = true
        textView.isSelectable = true
        textView.text = text
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textDelegate = context.coordinator
        
        // Add it to the container
        containerView.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textView.topAnchor.constraint(equalTo: containerView.topAnchor),
            textView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Store the text view for updates
        context.coordinator.textView = textView
        
        // Debug: Print the view hierarchy
        print("DEBUG: View hierarchy:")
        print("  Container: \(containerView)")
        print("  STTextView: \(textView)")
        print("  STTextView now inherits from NSTextView")
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let textView = context.coordinator.textView,
           textView.text != text {
            textView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    class Coordinator: NSObject, @preconcurrency STTextViewDelegate {
        var parent: MinimalTextView
        weak var textView: STTextView?
        
        init(_ parent: MinimalTextView) {
            self.parent = parent
        }
        
        func textViewDidChangeText(_ notification: Notification) {
            if let textView = notification.object as? STTextView {
                parent.text = textView.text ?? ""
            }
        }
    }
}

// Test view to use the minimal text view
struct MinimalTextTestView: View {
    @State private var text = "Try typing here..."
    
    var body: some View {
        VStack {
            Text("Minimal STTextView Test")
                .font(.headline)
            
            MinimalTextView(text: $text)
                .frame(height: 200)
                .border(Color.blue)
            
            Text("Current text: \(text)")
                .padding()
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}