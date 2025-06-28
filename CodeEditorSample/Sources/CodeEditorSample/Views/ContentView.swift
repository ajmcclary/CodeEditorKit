import CodeEditorPlugin
import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    
    var body: some View {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if #available(macOS 13.0, *) {
            UnifiedContentView()
        } else {
            Text("macOS 13.0 or later required")
        }
        #elseif canImport(UIKit)
        if #available(iOS 16.0, visionOS 1.0, *) {
            UnifiedContentView()
        } else {
            Text("iOS 16.0 or later required")
        }
        #endif
    }
}
