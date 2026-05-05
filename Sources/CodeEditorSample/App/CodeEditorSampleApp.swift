import SwiftUI

@main
struct CodeEditorSampleApp: App {
    var body: some Scene {
        WindowGroup("CodeEditorSample") {
            RootWindow()
                .frame(minWidth: 980, minHeight: 640)
                .frame(width: 1_380, height: 880)
        }
        .windowResizability(.contentSize)
    }
}
