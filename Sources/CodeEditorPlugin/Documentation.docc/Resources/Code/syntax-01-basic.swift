import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = """
    // Swift code with syntax highlighting
    import Foundation

    struct User {
        let name: String
        let age: Int
        var isActive: Bool = true

        func greet() -> String {
            return "Hello, my name is \\(name)!"
        }
    }

    let user = User(name: "Alice", age: 30)
    logger.debug(user.greet())
    """

    var body: some View {
        VStack {
            Text("Basic Syntax Highlighting")
                .font(.headline)
                .padding()

            CodeEditor(text: $code)
                // Set the language for syntax highlighting
                .codeLanguage(.swift)
                .frame(minHeight: 400)
                .padding()
        }
    }
}
