import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = "// Your Swift code here"

    // Create a default configuration
    @State private var config = EditorConfiguration()

    var body: some View {
        VStack {
            // The configuration comes with sensible defaults
            Text("Default Configuration")
                .font(.headline)
                .padding()

            CodeEditor(text: $code)
                .codeLanguage(.swift)
                .environment(\.codeEditorConfiguration, config)
        }
    }
}
