import SwiftUI

/// Example demonstrating LSP integration with workspace root configuration
struct LSPExampleView: View {
    @State private var code = """
    import Foundation

    struct Person {
        let name: String
        let age: Int
    }

    func greet(person: Person) {
        // In a real app, you would log this
        // CrossPlatformLogger.logger().debug("Hello, \\(person.name)!")
        _ = person // Suppress unused warning
    }

    let john = Person(name: "John", age: 30)
    greet(person: john)
    """

    @State private var configuration = EditorConfiguration()

    var body: some View {
        VStack {
            Text("LSP-Enabled Code Editor")
                .font(.largeTitle)
                .padding()

            CodeEditor(text: $code)
                .codeLanguage(.swift)
                .codeWorkspaceRoot(getProjectRoot())
                .environment(\.codeEditorConfiguration, configuration)
                .frame(minHeight: 400)

            HStack {
                Text("Workspace: \(getProjectRoot()?.path ?? "Not Set")")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("LSP features enabled for Swift code completion")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            setupConfiguration()
        }
    }

    private func setupConfiguration() {
        // Enable features that benefit from LSP
        configuration.behavior.enableCodeCompletion = true
        configuration.display.enableSyntaxHighlighting = true

        // Set workspace root for LSP
        configuration.workspaceRoot = getProjectRoot()
    }

    private func getProjectRoot() -> URL? {
        // In a real app, this would be the project directory
        // For this example, we'll use the current directory
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}

// MARK: - Preview

struct LSPExampleView_Previews: PreviewProvider {
    static var previews: some View {
        LSPExampleView()
    }
}
