import SwiftUI
import AppKit

@main
struct CodeEditorSampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.automatic)
    }
}