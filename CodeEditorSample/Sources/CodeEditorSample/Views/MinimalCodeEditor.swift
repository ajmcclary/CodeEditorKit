import AppKit
import CodeEditorPlugin
import SwiftUI

// MARK: - MinimalCodeEditor

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
            Text("CodeEditorView Test")
                .font(.headline)
                .padding()

            MinimalCodeEditorWrapper()
                .frame(minHeight: 400)
                .border(Color.red, width: 2)
        }
        .padding()
    }
}

// MARK: - MinimalCodeEditorWrapper

struct MinimalCodeEditorWrapper: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        // Create a container view
        let containerView = NSView()

        // Create CodeEditorView
        let textView = CodeEditorView(frame: NSRect.zero)
        textView.text = "Hello from CodeEditorView!"
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

    func updateNSView(_: NSView, context _: Context) {
        // Nothing to update
    }
}
