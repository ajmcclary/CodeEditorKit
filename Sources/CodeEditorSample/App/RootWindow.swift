#if canImport(AppKit)
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Vertical stack: tab strip + body + status bar. Reads theme,
/// configuration, and the document store from the shared `AppState`
/// (also consumed by the Settings window) so changes made in either
/// window propagate to the other. macOS / Catalyst only — see
/// `IOSRootView` for the iOS variant.
struct RootWindow: View {
    @Bindable var appState: AppState

    @State private var settingsVisible: Bool = true
    @State private var inspectorVisible: Bool = true
    @State private var paletteVisible: Bool = false

    var body: some View {
        @Bindable var documents = appState.documents
        let (items, dispatch) = CommandPaletteCatalog.build(
            appState: appState,
            settingsVisible: $settingsVisible,
            inspectorVisible: $inspectorVisible
        )
        return ZStack {
            VStack(spacing: 0) {
                EditorTabStrip(
                    tabs: $documents.tabs,
                    activeTabID: $documents.activeTabID
                )
                WindowBody(
                    appState: appState,
                    settingsVisible: $settingsVisible,
                    inspectorVisible: $inspectorVisible
                )
                EditorStatusBar()
            }

            if paletteVisible {
                EditorCommandPalette(
                    isPresented: $paletteVisible,
                    items: items,
                    onSelect: dispatch
                )
                .frame(maxWidth: 480)
                .padding(.top, 80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .codeTheme(appState.theme)
        .environment(\.codeEditorConfiguration, appState.configuration)
        .preferredColorScheme(appState.theme.appearance == .dark ? .dark : .light)
        .background(togglePaletteShortcut)
    }

    private var togglePaletteShortcut: some View {
        Button("Toggle Palette") { paletteVisible.toggle() }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .opacity(0)
            .frame(width: 0, height: 0)
    }
}
#endif
