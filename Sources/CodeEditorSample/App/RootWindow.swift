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

    @State private var workspaceVisible: Bool = true
    @State private var inspectorVisible: Bool = true

    var body: some View {
        @Bindable var documents = appState.documents
        let (items, dispatch) = CommandPaletteCatalog.build(
            appState: appState,
            workspaceVisible: $workspaceVisible,
            inspectorVisible: $inspectorVisible
        )
        return ZStack {
            VStack(spacing: 0) {
                // Custom title bar from CodeEditorUI. This brings in
                // `EditorTrafficLights` and the `.platformGlassSurface(.titleBar)`
                // modifier transitively, so all three components are exercised
                // by the sample.
                EditorTitleBar(
                    title: documents.active?.name ?? "CodeEditorSample",
                    trafficLights: TrafficLightsConfiguration(
                        onClose: { NSApp.keyWindow?.performClose(nil) },
                        onMinimize: { NSApp.keyWindow?.performMiniaturize(nil) },
                        onZoom: { NSApp.keyWindow?.performZoom(nil) }
                    )
                )
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
    }
}
#endif
