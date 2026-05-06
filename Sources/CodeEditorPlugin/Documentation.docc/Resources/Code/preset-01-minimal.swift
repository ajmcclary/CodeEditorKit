import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = """
    // Minimal preset provides a clean interface
    // - No line numbers
    // - No gutter
    // - Minimal UI distractions

    func greet(name: String) {
        print("Hello, \\(name)!")
    }
    """

    // Use the minimal preset for a clean look
    @State private var config = EditorConfiguration.minimal

    var body: some View {
        VStack {
            Text("Minimal Editor Preset")
                .font(.headline)
                .padding()

            Text("Perfect for focused writing and note-taking")
                .font(.caption)
                .foregroundColor(.secondary)

            CodeEditor(text: $code)
                .codeLanguage(.swift)
                .environment(\.codeEditorConfiguration, config)
                .padding()
        }
    }
}
