#if !canImport(AppKit)
import CodeEditorPlugin
import SwiftUI

/// iOS / iPadOS root scene for the sample app.
///
/// The macOS sample uses a custom three-pane shell from `CodeEditorUI`
/// (`EditorSidebarShell`, `EditorTabStrip`, `EditorCommandPalette`) — those
/// components are AppKit-only by design. On iOS we use a `NavigationSplitView`
/// with the same `DocumentStore` and `EditorConfiguration` so the
/// underlying state model is shared.
struct IOSRootView: View {
    @Bindable var appState: AppState

    @State private var sidebarSelection: IOSSidebarSection? = .settings

    var body: some View {
        let documents = appState.documents
        let activeTabName: String = {
            guard let id = documents.activeTabID else { return "Editor" }
            return documents.tabs.first { $0.id == id }?.name ?? "Editor"
        }()
        return NavigationSplitView {
            sidebar
        } detail: {
            editor
                .navigationTitle(activeTabName)
                .toolbar { toolbar(documents: documents) }
        }
        .codeTheme(appState.theme)
        .environment(\.codeEditorConfiguration, appState.configuration)
        .preferredColorScheme(appState.theme.appearance == .dark ? .dark : .light)
    }

    private var sidebar: some View {
        List(selection: $sidebarSelection) {
            ForEach(IOSSidebarSection.allCases) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.icon)
                }
            }
        }
        .navigationTitle("CodeEditorSample")
    }

    @ViewBuilder
    private var editor: some View {
        if let activeID = appState.documents.activeTabID {
            CodeEditor(text: appState.documents.textBinding(for: activeID))
                .codeLanguage(appState.documents.activeLanguage ?? .plainText)
                .environment(\.codeEditorConfiguration, appState.configuration)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No tabs open",
                systemImage: "doc.text",
                description: Text("Tap + in the toolbar to start a new document.")
            )
        }
    }

    @ToolbarContentBuilder
    private func toolbar(documents: DocumentStore) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                documents.newTab()
            } label: {
                Label("New Tab", systemImage: "plus")
            }
        }
    }
}

private enum IOSSidebarSection: String, Identifiable, CaseIterable {
    case settings
    case themes
    case languages

    var id: String { rawValue }

    var title: String {
        switch self {
        case .settings: "Editor Settings"
        case .themes: "Themes"
        case .languages: "Languages"
        }
    }

    var icon: String {
        switch self {
        case .settings: "slider.horizontal.3"
        case .themes: "paintpalette"
        case .languages: "text.alignleft"
        }
    }
}
#endif
