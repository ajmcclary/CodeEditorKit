import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = """
function hello() {
    console.log("Hello, World!");
}

hello();
"""
    
    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(.javascript)
            // Add styling
            .frame(minHeight: 300)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding()
    }
}
