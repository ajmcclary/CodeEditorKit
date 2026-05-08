import SwiftUI

@main
struct CodeEditorSampleApp: App {
    #if canImport(AppKit)
    @NSApplicationDelegateAdaptor(CodeEditorSampleAppDelegate.self) private var appDelegate
    #endif

    /// Shared @Observable state for the whole app — main window and
    /// Settings (cmd-,) window read and mutate the same instance.
    @State private var appState = AppState()

    #if canImport(AppKit)
    var body: some Scene {
        WindowGroup("CodeEditorSample") {
            RootWindow(appState: appState)
                .frame(minWidth: 980, minHeight: 640)
                .frame(width: 1_380, height: 880)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsScene(appState: appState)
        }
    }
    #else
    var body: some Scene {
        WindowGroup("CodeEditorSample") {
            IOSRootView(appState: appState)
        }
    }
    #endif
}
