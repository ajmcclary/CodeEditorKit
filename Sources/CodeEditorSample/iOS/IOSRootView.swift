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

    @State private var sidebarSelection: IOSSidebarSection? = .editor

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail(for: selectedSection)
                .navigationTitle(title(for: selectedSection))
                .toolbar { toolbar(documents: appState.documents) }
        }
        .codeTheme(appState.theme)
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

    private var selectedSection: IOSSidebarSection {
        sidebarSelection ?? .editor
    }

    @ViewBuilder
    private func detail(for section: IOSSidebarSection) -> some View {
        switch section {
        case .editor:
            editor

        case .settings:
            settingsPanel

        case .themes:
            themePanel

        case .languages:
            languagePanel
        }
    }

    private func title(for section: IOSSidebarSection) -> String {
        switch section {
        case .editor:
            guard let id = appState.documents.activeTabID else { return "Editor" }
            return appState.documents.tabs.first { $0.id == id }?.name ?? "Editor"

        case .settings:
            return "Editor Settings"

        case .themes:
            return "Themes"

        case .languages:
            return "Languages"
        }
    }

    @ViewBuilder
    private var editor: some View {
        if let activeID = appState.documents.activeTabID {
            CodeEditor(text: appState.documents.textBinding(for: activeID))
                .onTextChange { newText in
                    appState.documents.markDirty(activeID, newText: newText)
                }
                .editorController(appState.editorController)
                .editorInteractionState(appState.documents.interactionBinding(for: activeID))
                .codeEditorEnvironment(
                    language: appState.documents.activeLanguage ?? .plainText,
                    configuration: appState.configuration,
                    becomeFirstResponder: .yes,
                    workspaceRoot: appState.workspaceRoot
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No tabs open",
                systemImage: "doc.text",
                description: Text("Tap + in the toolbar to start a new document.")
            )
        }
    }

    private var settingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                DisplayKnobsSection(configuration: $appState.configuration, expansion: .always)
                LayoutKnobsSection(configuration: $appState.configuration, expansion: .always)
                BehaviorKnobsSection(configuration: $appState.configuration, expansion: .always)
                PerformanceKnobsSection(configuration: $appState.configuration, expansion: .always)
                WorkspaceKnobsSection(workspaceRoot: $appState.workspaceRoot, expansion: .always)
                AnnotationsKnobsSection(appState: appState, expansion: .always)
            }
            .padding(.vertical, 12)
        }
    }

    private var themePanel: some View {
        List {
            ForEach(ThemeCatalog.all, id: \.name) { theme in
                Button {
                    appState.theme = ThemeCatalog.theme(named: theme.name)
                } label: {
                    Label(
                        theme.name,
                        systemImage: theme.name == appState.theme.name ? "checkmark.circle.fill" : "circle"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var languagePanel: some View {
        if let activeID = appState.documents.activeTabID {
            List {
                ForEach(LanguageCatalog.all, id: \.self) { language in
                    Button {
                        appState.documents.setLanguage(language, of: activeID)
                    } label: {
                        Label(
                            language.name,
                            systemImage: language == appState.documents.activeLanguage ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "No Active Tab",
                systemImage: "doc.text",
                description: Text("Create a tab before choosing a language.")
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
    case editor
    case settings
    case themes
    case languages

    var id: String { rawValue }

    var title: String {
        switch self {
        case .editor: "Editor"
        case .settings: "Editor Settings"
        case .themes: "Themes"
        case .languages: "Languages"
        }
    }

    var icon: String {
        switch self {
        case .editor: "doc.text"
        case .settings: "slider.horizontal.3"
        case .themes: "paintpalette"
        case .languages: "text.alignleft"
        }
    }
}
#endif
