import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = """
    struct Person {
        var name: String
        var age: Int

        func greet() {
            print("Hello, my name is \\(name)")
        }
    }
    """

    @State private var config = EditorConfiguration()

    var body: some View {
        VStack {
            // Layout configuration controls
            VStack(alignment: .leading, spacing: 10) {
                Text("Layout Settings")
                    .font(.headline)

                HStack {
                    Text("Tab Width: \(config.layout.tabWidth)")
                    Stepper("", value: $config.layout.tabWidth, in: 2...8)
                }

                Toggle("Insert Spaces", isOn: $config.layout.insertSpaces)

                HStack {
                    Text("Line Height: \(config.layout.lineHeightMultiple, specifier: "%.1f")")
                    Slider(value: $config.layout.lineHeightMultiple, in: 1.0...2.0, step: 0.1)
                }

                HStack {
                    Text("Gutter Width: \(Int(config.layout.gutterWidth))")
                    Slider(value: $config.layout.gutterWidth, in: 30...60, step: 5)
                }
            }
            .padding()

            CodeEditor(text: $code)
                .codeLanguage(.swift)
                .environment(\.codeEditorConfiguration, config)
        }
    }
}
