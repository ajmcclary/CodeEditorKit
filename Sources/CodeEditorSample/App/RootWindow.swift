#if canImport(AppKit)
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Vertical stack: tab strip + body + status bar. Reads theme,
/// configuration, and the document store from the shared `AppState`
/// (also consumed by the Settings window) so changes made in either
/// window propagate to the other. macOS only — see `IOSRootView`
/// for the iOS variant.
struct RootWindow: View {
    @Bindable var appState: AppState

    @State private var settingsVisible: Bool = true
    @State private var inspectorVisible: Bool = true

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

            if appState.paletteVisible {
                EditorCommandPalette(
                    isPresented: $appState.paletteVisible,
                    items: items,
                    onSelect: dispatch
                )
                .frame(maxWidth: 480)
                .padding(.top, 80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .codeTheme(appState.theme)
        .preferredColorScheme(appState.theme.appearance == .dark ? .dark : .light)
    }
}
#endif
