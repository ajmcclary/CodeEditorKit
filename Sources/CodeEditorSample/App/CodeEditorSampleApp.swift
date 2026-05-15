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
        }
        // Hide the standard NSWindow title bar so the embedded
        // `EditorTitleBar` chrome owns the top of the window.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1_380, height: 880)
        .windowResizability(.contentMinSize)
        .commands {
            // Single source of truth for sample keyboard shortcuts.
            // Each command mutates the shared `AppState` directly so
            // the palette, sidebars, sheets, and overlay are all
            // reachable from the menu bar and via cmd-key chords.
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    appState.documents.store.newTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Open Folder…") {
                    WorkspacePicker.choose(currentRoot: appState.workspaceRoot) {
                        appState.workspaceRoot = $0
                    }
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Open File…") {
                    appState.documents.requestOpenFile()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Close Tab") {
                    if let id = appState.documents.store.activeID {
                        appState.documents.store.close(id)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)

                // ⌘S — save the active tab back to its on-disk URL. On Untitled
                // tabs (no URL), requestSave transparently chains to requestSaveAs
                // so the user sees the NSSavePanel instead of a silent log entry.
                Button("Save") {
                    appState.documents.requestSave()
                }
                .keyboardShortcut("s", modifiers: .command)

                // ⇧⌘S — explicit Save As…. Always presents NSSavePanel; on confirm
                // the active document rebinds (url, name, language, isDirty all
                // update). The previous on-disk file (if any) is left untouched.
                Button("Save As…") {
                    appState.documents.requestSaveAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandGroup(after: .textEditing) {
                Button("Find / Replace…") {
                    appState.findReplace.isOverlayVisible = true
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Go to Line…") {
                    appState.gotoLineSheetVisible = true
                }
                .keyboardShortcut("l", modifiers: .command)

                Button("Go to Symbol…") {
                    appState.documents.editorController.refreshSymbols()
                    appState.gotoSymbolSheetVisible = true
                }
                .keyboardShortcut("o", modifiers: [.command, .control])

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
