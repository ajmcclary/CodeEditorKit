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
        .commands {
            // Single source of truth for sample keyboard shortcuts.
            // Each command mutates the shared `AppState` directly so
            // the palette, sidebars, sheets, and overlay are all
            // reachable from the menu bar and via cmd-key chords.
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    appState.documents.newTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Tab") {
                    if let id = appState.documents.activeTabID {
                        appState.documents.close(id)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            CommandGroup(after: .textEditing) {
                Button("Find / Replace…") {
                    appState.findOverlayVisible = true
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Go to Line…") {
                    appState.gotoLineSheetVisible = true
                }
                .keyboardShortcut("l", modifiers: .command)

                Button("Go to Symbol…") {
                    appState.editorController.refreshSymbols()
                    appState.gotoSymbolSheetVisible = true
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Command Palette…") {
                    appState.paletteVisible.toggle()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }

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
