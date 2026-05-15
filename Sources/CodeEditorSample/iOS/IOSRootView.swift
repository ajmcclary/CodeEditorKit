#if !canImport(AppKit)
import CodeEditorPlugin
import SwiftUI

/// iOS / iPadOS root scene for the sample.
///
/// On iPad: 3-column `NavigationSplitView` with a toolbar-toggleable
/// inspector column hosting `InspectorPanelStack`. The inspector
/// column is visible only when the `.editor` sidebar destination is
/// selected; switching to any other destination collapses it.
///
/// On iPhone: `NavigationSplitView` collapses to single-stack
/// navigation automatically. The toolbar inspector toggle is hidden
/// in compact width classes; the `.inspectors` sidebar destination
/// remains the iPhone path into the panel stack.
struct IOSRootView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Bindable var appState: AppState

    @State private var sidebarSelection: IOSSidebarSection? = .editor
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var showingPerformanceReport = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } content: {
            detail(for: selectedSection)
                .navigationTitle(title(for: selectedSection))
                .toolbar { toolbar(documents: appState.documents.store) }
        } detail: {
            inspectorRail
        }
        .onChange(of: sidebarSelection) { _, newValue in
            if newValue != .editor {
                columnVisibility = .doubleColumn
            }
        }
        .codeTheme(appState.theme.current)
        .preferredColorScheme(appState.theme.current.appearance == .dark ? .dark : .light)
        .sheet(item: $appState.documents.pendingSaveAs) { state in
            ExportDocumentSheet(
                temporaryURL: state.temporaryURL,
                onPick: { url in
                    appState.documents.finalizeSaveAs(to: url)
                    appState.documents.pendingSaveAs = nil
                },
                onCancel: { appState.documents.pendingSaveAs = nil }
            )
        }
        .sheet(isPresented: $appState.documents.pendingOpenFile) {
            ImportDocumentSheet(
                onPick: { url in
                    appState.documents.store.openFile(url: url)
                    appState.documents.pendingOpenFile = false
                },
                onCancel: { appState.documents.pendingOpenFile = false }
            )
        }
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

        case .inspectors:
            InspectorPanelStack(
                appState: appState,
                showingPerformanceReport: $showingPerformanceReport
            )
        }
    }

    private func title(for section: IOSSidebarSection) -> String {
        switch section {
        case .editor:
            return appState.documents.store.active?.name ?? "Editor"

        case .settings:
            return "Editor Settings"

        case .themes:
            return "Themes"

        case .languages:
            return "Languages"

        case .inspectors:
            return "Inspectors"
        }
    }

    @ViewBuilder
    private var inspectorRail: some View {
        if selectedSection == .editor {
            InspectorPanelStack(
                appState: appState,
                showingPerformanceReport: $showingPerformanceReport
            )
            .navigationTitle("Inspectors")
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var editor: some View {
        if appState.documents.store.active != nil {
            CodeEditor()
                .editorController(appState.documents.editorController)
                .activeDocument(in: appState.documents.store)
                .environment(\.codeEditorConfiguration, appState.configuration.current)
                .codeTheme(appState.theme.current)
                .codeWorkspaceRoot(appState.workspaceRoot)
                .becomeFirstResponder()
                .eventSystem(appState.eventSystem)
                .performanceObserver(appState.performanceObservation)
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
                DisplayKnobsSection(configuration: appState.configuration, expansion: .always)
                LayoutKnobsSection(configuration: appState.configuration, expansion: .always)
                BehaviorKnobsSection(configuration: appState.configuration, expansion: .always)
                PerformanceKnobsSection(configuration: appState.configuration, expansion: .always)
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
                    appState.theme.current = ThemeCatalog.theme(named: theme.name)
                } label: {
                    Label(
                        theme.name,
                        systemImage: theme.name == appState.theme.current.name ? "checkmark.circle.fill" : "circle"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var languagePanel: some View {
        if let activeID = appState.documents.store.activeID {
            List {
                ForEach(LanguageCatalog.all, id: \.self) { language in
                    Button {
                        appState.documents.store.setLanguageRenaming(language, of: activeID)
                    } label: {
                        Label(
                            language.name,
                            systemImage: language == appState.documents.store.active?.language ? "checkmark.circle.fill" : "circle"
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
    private func toolbar(documents: EditorDocuments) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Save", action: appState.documents.requestSave)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(appState.documents.store.active == nil)
                Button("Save As…", action: appState.documents.requestSaveAs)
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(appState.documents.store.active == nil)
                Divider()
                Button("New Tab") { documents.newTab() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Open File…", action: appState.documents.requestOpenFile)
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            } label: {
                Label("File", systemImage: "doc")
            }
        }

        if hSizeClass != .compact {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    columnVisibility = (columnVisibility == .all) ? .doubleColumn : .all
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .disabled(selectedSection != .editor)
            }
        }
    }
}

private enum IOSSidebarSection: String, Identifiable, CaseIterable {
    case editor
    case settings
    case themes
    case languages
    case inspectors

    var id: String { rawValue }

    var title: String {
        switch self {
        case .editor: "Editor"
        case .settings: "Editor Settings"
        case .themes: "Themes"
        case .languages: "Languages"
        case .inspectors: "Inspectors"
        }
    }

    var icon: String {
        switch self {
        case .editor: "doc.text"
        case .settings: "slider.horizontal.3"
        case .themes: "paintpalette"
        case .languages: "text.alignleft"
        case .inspectors: "magnifyingglass"
        }
    }
}
#endif
