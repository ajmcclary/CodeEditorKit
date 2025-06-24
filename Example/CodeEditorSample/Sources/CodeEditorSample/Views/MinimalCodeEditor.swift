import SwiftUI
import AppKit
import CodeEditorPlugin

struct MinimalCodeEditor: View {
    @State private var code = """
    import Foundation
    
    // Sample Swift code
    func greet(name: String) -> String {
        return "Hello, \\(name)!"
    }
    
    let result = greet(name: "World")
    print(result)
    """
    
    var body: some View {
        VStack {
            Text("STTextView Test")
                .font(.headline)
                .padding()
            
            STTextViewWrapper()
                .frame(minHeight: 400)
                .border(Color.red, width: 2)
        }
        .padding()
    }
}

struct STTextViewWrapper: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        // Create a container view
        let containerView = NSView()
        
        // Create STTextView
        let textView = STTextView(frame: .zero)
        textView.text = "Hello from STTextView!"
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.backgroundColor = .white
        textView.textColor = .black
        
        // Add to container
        containerView.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: containerView.topAnchor),
            textView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Nothing to update
    }
}