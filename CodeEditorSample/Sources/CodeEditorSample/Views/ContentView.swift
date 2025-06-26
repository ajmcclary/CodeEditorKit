import CodeEditorPlugin
import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    
    var body: some View {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            UnifiedContentView()
        } else {
            Text("macOS 13.0 or later required")
        }
        #elseif os(iOS) || os(visionOS)
        if #available(iOS 16.0, *) {
            UnifiedContentView()
        } else {
            Text("iOS 16.0 or later required")
        }
        #endif
    }
}
