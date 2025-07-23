import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = """
    // Large file with thousands of lines...
    // Performance settings help maintain smooth scrolling
    """

    @State private var config = EditorConfiguration()

    var body: some View {
        VStack {
            // Performance configuration controls
            VStack(alignment: .leading, spacing: 10) {
                Text("Performance Settings")
                    .font(.headline)

                Toggle("Async Highlighting", isOn: $config.performance.asyncHighlighting)
                    .help("Process syntax highlighting in background")

                HStack {
                    Text("Highlight Delay: \(config.performance.highlightingDelay, specifier: "%.1f")s")
                    Slider(value: $config.performance.highlightingDelay, in: 0.1...2.0, step: 0.1)
                }

                HStack {
                    Text("Max Highlight Size: \(config.performance.maxHighlightingFileSize / 1_024)KB")
                    Slider(
                        value: Binding(
                            get: { Double(config.performance.maxHighlightingFileSize) / 1_024 },
                            set: { config.performance.maxHighlightingFileSize = Int($0 * 1_024) }
                        ),
                        in: 100...2_000,
                        step: 100
                    )
                }

                Toggle("Cache Highlights", isOn: $config.performance.cacheHighlights)

                Toggle("Use Incremental Layout", isOn: $config.performance.useIncrementalLayout)
            }
            .padding()

            CodeEditor(text: $code)
                .codeLanguage(.swift)
                .environment(\.codeEditorConfiguration, config)
        }
    }
}
