import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = """
    def fibonacci(n):
        '''Calculate the nth Fibonacci number'''
        if n <= 0:
            return 0
        elif n == 1:
            return 1
        else:
            return fibonacci(n-1) + fibonacci(n-2)

    # Test the function
    for i in range(10):
        logger.debug(f"F({i}) = {fibonacci(i)}")
    """

    @State private var fileName = "fibonacci.py"

    var body: some View {
        VStack {
            Text("Auto Language Detection")
                .font(.headline)
                .padding()

            HStack {
                Text("File: ")
                TextField("filename", text: $fileName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
            }
            .padding(.horizontal)

            CodeEditor(text: $code)
                // Detect language from file extension
                .codeLanguage(forFileExtension: fileName.components(separatedBy: ".").last ?? "")
                .frame(minHeight: 400)
                .padding()

            Text("Try changing the extension to .js, .swift, .rb, etc.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
