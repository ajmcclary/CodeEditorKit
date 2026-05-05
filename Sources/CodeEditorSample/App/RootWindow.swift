import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Vertical stack: title bar + tab strip + body + status bar.
/// Owns sidebar visibility flags and the command-palette presentation
/// flag. Will receive ⌘⇧P binding in Task 14.
struct RootWindow: View {
    @State private var theme: Theme = ThemeCatalog.default
    @State private var configuration: EditorConfiguration = PresetCatalog.default.configuration
    @State private var documentStore = DocumentStore()
    @State private var settingsVisible: Bool = true
    @State private var inspectorVisible: Bool = true
    @State private var paletteVisible: Bool = false

    var body: some View {
        // Apple-documented pattern for projecting bindings into an
        // @Observable class held in @State: shadow with @Bindable
        // inside body so `$documents.tabs` / `$documents.activeTabID`
        // produce real Bindings rather than Binding<DocumentStore>.
        @Bindable var documents = documentStore
        VStack(spacing: 0) {
            EditorTitleBar(title: "CodeEditorSample")
            EditorTabStrip(
                tabs: $documents.tabs,
                activeTabID: $documents.activeTabID
            )
            WindowBody(
                theme: $theme,
                configuration: $configuration,
                documents: documentStore,
                settingsVisible: $settingsVisible,
                inspectorVisible: $inspectorVisible
            )
            EditorStatusBar()
        }
        .codeTheme(theme)
        .environment(\.codeEditorConfiguration, configuration)
    }
}
