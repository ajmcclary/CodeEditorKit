import CodeEditorPlugin
import SwiftUI

// Minimal test app (not the main entry point)
struct MinimalTestApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Testing minimal app without CodeEditor")
                .padding()
                .frame(minWidth: 400, minHeight: 300)
        }
    }
}
