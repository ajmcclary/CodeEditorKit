import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    // Note: No @State for code - it's read-only
    let code = """
    // Read-only preset is perfect for viewing code
    // - Editing disabled
    // - Selection allowed for copying
    // - All viewing features enabled
    
    struct APIResponse: Codable {
        let status: Int
        let message: String
        let data: [String: Any]
        
        func validate() throws {
            guard status == 200 else {
                throw APIError.invalidStatus(status)
            }
        }
    }
    """
    
    // Use the read-only preset
    @State private var config = EditorConfiguration.readOnly
    
    var body: some View {
        VStack {
            Text("Read-Only Editor Preset")
                .font(.headline)
                .padding()
            
            Text("Perfect for documentation, tutorials, and code reviews")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Note: Using .constant for read-only binding
            CodeEditor(text: .constant(code))
                .codeLanguage(.swift)
                .environment(\.codeEditorConfiguration, config)
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                .padding()
        }
    }
}
