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
            // Set the language for syntax highlighting
            .codeLanguage(.javascript)
    }
}
