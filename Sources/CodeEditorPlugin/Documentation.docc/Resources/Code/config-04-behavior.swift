import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = """
    func processData(items: [String]) {
        // Auto-indent and bracket matching will help here
        for item in items {
            if item.count > 0 {
                print(item)
            }
        }
    }
    """

    @State private var config = EditorConfiguration()

    var body: some View {
        VStack {
            // Behavior configuration controls
            VStack(alignment: .leading, spacing: 10) {
                Text("Behavior Settings")
                    .font(.headline)

                Toggle("Auto Indent", isOn: $config.behavior.autoIndent)

                Toggle("Auto-closing Brackets", isOn: $config.behavior.autoClosingBrackets)

                Toggle("Bracket Matching", isOn: $config.behavior.bracketMatching)

                Toggle("Code Folding", isOn: $config.behavior.codeFolding)

                Toggle("Word Wrap", isOn: $config.behavior.wordWrap)

                Toggle("Show Completions", isOn: $config.behavior.showCompletions)
            }
            .padding()

            CodeEditor(text: $code)
                .codeLanguage(.swift)
                .environment(\.codeEditorConfiguration, config)
        }
    }
}
