#if canImport(AppKit)
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// macOS left-rail workspace surface. Segmented switcher between a
/// file tree (`FilePanelView`) and project search
/// (`ProjectSearchPanelView`). Owns no model state — both panels
/// are driven by AppState's WorkspaceModel and ProjectSearchModel.
struct WorkspaceSidebar: View {
    @Bindable var workspace: WorkspaceModel
    @Bindable var search: ProjectSearchModel
    @Bindable var appState: AppState
    @State private var tab: Tab = .files

    enum Tab: String, CaseIterable, Hashable, Identifiable {
        case files = "Files"
        case search = "Search"

        var id: String { rawValue }
    }

    var body: some View {
        EditorSidebarShell(sectionTitle: tab.rawValue) {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)

                switch tab {
                case .files:
                    FilePanelView(model: workspace, appState: appState)

                case .search:
                    ProjectSearchPanelView(model: search, workspace: workspace, appState: appState)
                }
            }
        }
        .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
    }
}
#endif
