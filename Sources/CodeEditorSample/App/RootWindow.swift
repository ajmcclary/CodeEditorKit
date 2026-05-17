import CodeEditorTheming
#if canImport(AppKit)
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Vertical stack: tab strip + body + status bar. Reads theme,
/// configuration, and the document store from the shared `AppState`
/// (also consumed by the Settings window) so changes made in either
/// window propagate to the other. macOS only — see `IOSRootView`
/// for the iOS variant.
///
/// The sample uses the **native NSWindow title bar and traffic lights**
/// on purpose. Do NOT add `EditorTitleBar`, `EditorTrafficLights`, or
/// `.windowStyle(.hiddenTitleBar)` here: `.hiddenTitleBar` hides the
/// title bar background but leaves the real traffic-light buttons
/// rendered in the window's top-left corner, so stacking
/// `EditorTitleBar` on top produces a visible "app inside an app".
/// `EditorTitleBar` remains in CodeEditorUI for hosts that genuinely
/// own their chrome (and hide the standard NSWindow buttons themselves);
/// it is exercised by `EditorTitleBarSnapshots`.
struct RootWindow: View {
    @Bindable var appState: AppState

    @State private var workspaceVisible: Bool = true
    @State private var inspectorVisible: Bool = true

    var body: some View {
        @Bindable var documents = appState.documents.store
        let (items, dispatch) = CommandPaletteCatalog.build(
            appState: appState,
            workspaceVisible: $workspaceVisible,
            inspectorVisible: $inspectorVisible
        )
        return ZStack {
            VStack(spacing: 0) {
                EditorTabStrip(
                    tabs: documents.tabsBinding,
                    activeTabID: $documents.activeID
                )
                // Breadcrumb trail from CodeEditorUI. Reads `\.editorState`
                // which the framework now populates automatically (language,
                // selection, line count). Cosmetic — kept inert (no tap
                // callback) so the sample doesn't have to define a nav model.
                EditorBreadcrumbView()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .platformGlassSurface(.tabBar)
                WindowBody(
                    appState: appState,
                    workspaceVisible: $workspaceVisible,
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
        .codeTheme(appState.theme.current)
        .preferredColorScheme(appState.theme.current.appearance == .dark ? .dark : .light)
        .navigationTitle(documents.active?.name ?? "CodeEditorSample")
    }
}
#endif
