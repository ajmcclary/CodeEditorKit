import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = "// Your Swift code here"
    @State private var config = EditorConfiguration()

    init() {
        // Configure the editor
        _config = State(initialValue: {
            var configuration = EditorConfiguration()
            configuration.display.isLineNumbersEnabled = true
            configuration.display.syntaxHighlighting = true
            configuration.display.fontSize = 14
            configuration.layout.tabWidth = 4
            configuration.behavior.isAutoIndentEnabled = true
            return configuration
        }())
    }

    var body: some View {
        VStack {
            Text("Configured Editor")
                .font(.headline)
                .padding()

            CodeEditor(text: $code)
                .codeLanguage(.swift)
                // Apply configuration using environment
                .environment(\.codeEditorConfiguration, config)
                .frame(minHeight: 400)
        }
    }
}
