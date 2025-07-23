import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    // Simulate a large file
    @State private var code = generateLargeFile()
    @State private var config = EditorConfiguration()
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            Text("Performance Optimization")
                .font(.headline)
                .padding()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Large File Performance Settings")
                    .font(.subheadline)
                
                Toggle("Async Highlighting", isOn: $config.performance.asyncHighlighting)
                    .help("Process syntax highlighting in background")
                
                HStack {
                    Text("Delay: \(config.performance.highlightingDelay, specifier: "%.1f")s")
                    Slider(value: $config.performance.highlightingDelay, in: 0.1...2.0)
                }
                
                Toggle("Cache Highlights", isOn: $config.performance.cacheHighlights)
                    .help("Cache highlighting results for better performance")
                
                Toggle("Incremental Layout", isOn: $config.performance.useIncrementalLayout)
                    .help("Only re-layout changed portions")
                
                Text("File size: ~\(code.count / 1_024)KB")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            if isLoading {
                ProgressView("Loading large file...")
                    .padding()
            } else {
                CodeEditor(text: $code)
                    .codeLanguage(.swift)
                    .environment(\.codeEditorConfiguration, config)
                    .frame(minHeight: 400)
                    .padding()
            }
            
            HStack {
                Button("Load Small File") {
                    code = generateSmallFile()
                }
                
                Button("Load Large File") {
                    isLoading = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        code = generateLargeFile()
                        isLoading = false
                    }
                }
                
                Button("Load Huge File") {
                    isLoading = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        code = generateHugeFile()
                        isLoading = false
                    }
                }
            }
            .padding()
        }
        .onAppear {
            // Enable performance features for large files
            config.performance.asyncHighlighting = true
            config.performance.cacheHighlights = true
            config.performance.maxHighlightingFileSize = 1_024 * 1_024 // 1MB
        }
    }
    
    static func generateSmallFile() -> String {
        """
        // Small file - highlighting should be instant
        struct AppState {
            var users: [User] = []
            var isLoading = false
        }
        """
    }
    
    static func generateLargeFile() -> String {
        var result = "// Large file with many lines\n"
        for index in 0..<500 {
            result += """
            
            func process_\(index)(data: [Int]) -> [Int] {
                // Function \(index) of 500
                let filtered = data.filter { $0 > 0 }
                let mapped = filtered.map { $0 * 2 }
                let sorted = mapped.sorted()
                return sorted
            }
            
            """
        }
        return result
    }
    
    static func generateHugeFile() -> String {
        var result = "// Huge file - performance settings critical\n"
        for index in 0..<2_000 {
            result += """
            
            class Service_\(index): BaseService {
                private var cache = [String: Any]()
                
                func fetchData() async throws -> Data {
                    // Simulated service method \(index)
                    let url = URL(string: "https://api.example.com/data/\(index)")!
                    let (data, _) = try await URLSession.shared.data(from: url)
                    return data
                }
                
                func processResult(_ data: Data) -> Result<Model, Error> {
                    do {
                        let decoded = try JSONDecoder().decode(Model.self, from: data)
                        return .success(decoded)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            
            """
        }
        return result
    }
}
