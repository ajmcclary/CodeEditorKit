import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = """
    // Presentation preset optimizes for demos
    // - Larger font size (18pt)
    // - Increased line spacing
    // - High contrast syntax highlighting
    // - Smooth animations
    
    class DataManager {
        private var cache = [String: Data]()
        
        func fetchData(from url: URL) async throws -> Data {
            // Check cache first
            if let cached = cache[url.absoluteString] {
                return cached
            }
            
            // Fetch new data
            let (data, _) = try await URLSession.shared.data(from: url)
            cache[url.absoluteString] = data
            return data
        }
    }
    """
    
    // Use the presentation preset for demos
    @State private var config = EditorConfiguration.presentation
    
    var body: some View {
        VStack {
            Text("Presentation Mode Preset")
                .font(.largeTitle)
                .padding()
            
            Text("Optimized for live coding and demonstrations")
                .font(.title3)
                .foregroundColor(.secondary)
            
            CodeEditor(text: $code)
                .codeLanguage(.swift)
                .environment(\.codeEditorConfiguration, config)
                .padding()
                .frame(minHeight: 500)
        }
        .background(Color.black)
        .preferredColorScheme(.dark) // Best for presentations
    }
}
