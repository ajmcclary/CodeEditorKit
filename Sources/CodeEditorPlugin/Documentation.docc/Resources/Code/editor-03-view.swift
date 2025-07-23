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
        // Add the CodeEditor view with text binding
        CodeEditor(text: $code)
    }
}
