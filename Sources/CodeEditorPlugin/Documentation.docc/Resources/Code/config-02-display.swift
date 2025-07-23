import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = "// Your Swift code here"
    @State private var config = EditorConfiguration()
    
    var body: some View {
        VStack {
            // Display configuration controls
            VStack(alignment: .leading, spacing: 10) {
                Text("Display Settings")
                    .font(.headline)
                
                Toggle("Show Line Numbers", isOn: $config.display.showLineNumbers)
                
                HStack {
                    Text("Font Size: \(Int(config.display.fontSize))")
                    Slider(value: $config.display.fontSize, in: 10...24, step: 1)
                }
                
                Toggle("Syntax Highlighting", isOn: $config.display.syntaxHighlighting)
                
                Toggle("Show Invisibles", isOn: $config.display.showInvisibles)
            }
            .padding()
            
            CodeEditor(text: $code)
                .codeLanguage(.swift)
                .environment(\.codeEditorConfiguration, config)
        }
    }
}
