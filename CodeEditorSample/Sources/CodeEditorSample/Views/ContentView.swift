import CodeEditorPlugin
import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    var body: some View {
        if #available(macOS 13.0, iOS 16.0, *) {
            UnifiedContentView()
        } else {
            VStack {
                Text("CodeEditor Sample")
                    .font(.largeTitle)
                    .padding()
                
                Text("Requires macOS 13.0+ or iOS 16.0+")
                    .padding()
            }
            .frame(minWidth: 400, minHeight: 300)
        }
    }
}
