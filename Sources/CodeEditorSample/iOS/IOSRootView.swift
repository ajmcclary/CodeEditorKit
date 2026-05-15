#if !canImport(AppKit)
import CodeEditorPlugin
import SwiftUI

/// iOS / iPadOS root scene for the sample app.
///
/// The macOS sample uses a custom three-pane shell from `CodeEditorUI`
/// (`EditorSidebarShell`, `EditorTabStrip`, `EditorCommandPalette`) — those
/// components are AppKit-only by design. On iOS we use a `NavigationSplitView`
/// with the same `EditorDocuments` and `EditorConfiguration` so the
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
        .sheet(item: $appState.pendingSaveAs) { state in
            ExportDocumentSheet(
                temporaryURL: state.temporaryURL,
                onPick: { url in
                    appState.finalizeSaveAs(to: url)
                    appState.pendingSaveAs = nil
                },
                onCancel: { appState.pendingSaveAs = nil }
            )
        }
        .sheet(isPresented: $appState.pendingOpenFile) {
            ImportDocumentSheet(
                onPick: { url in
                    appState.documents.openFile(url: url)
                    appState.pendingOpenFile = false
                },
                onCancel: { appState.pendingOpenFile = false }
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
            inspectorsUnavailable
        }
    }

    private func title(for section: IOSSidebarSection) -> String {
        switch section {
        case .editor:
            return appState.documents.active?.name ?? "Editor"

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

    /// EventLog (cross-platform) plus an explainer for the macOS-only
    /// inspectors. The sample's other inspector panels live in `Sidebars/`
    /// behind `#if canImport(AppKit)` because they depend on AppKit
    /// pasteboard APIs and macOS-only chrome (`EditorSidebarShell`).
    private var inspectorsUnavailable: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                EventLogPanel(
                    entries: appState.eventLog.snapshot.entries,
                    totals: appState.eventLog.snapshot.totals,
                    mutedCategories: appState.eventLog.mutedCategories,
                    paused: appState.eventLog.paused,
                    onToggleCategory: { category in
                        appState.eventLog.setMuted(category, !appState.eventLog.mutedCategories.contains(category))
                    },
                    onTogglePause: { appState.eventLog.setPaused(!appState.eventLog.paused) },
                    onClear: { appState.eventLog.clear() }
                )

                Divider()

                ContentUnavailableView {
                    Label("Other inspectors are macOS-only", systemImage: "macwindow.badge.plus")
                } description: {
                    Text(
                        """
                        The LSP, Completion, Performance, and Annotations inspectors \
                        live in `Sources/CodeEditorSample/Sidebars/` and are gated to \
                        AppKit. The underlying CodeEditorPlugin APIs (LSPManager, \
                        CompletionManager, PerformanceInsights, AnnotationsHub) work \
                        on iOS — only the sample's inspector chrome is desktop-only.

                        The workspace surface (Files / Search left rail) is also \
                        macOS-only in the current sample. The framework's \
                        WorkspaceFileTree, WorkspaceFileWatching, and \
                        PortableProjectSearchAdapter are usable from any platform, \
                        but the sample's UI for them sits inside WindowBody (AppKit).

                        Remote LSP servers work on iOS: use \
                        `LanguageServerConfig.remote(url:)` with `LSPManager` to wire \
                        up a WebSocket-backed language server. Local servers require \
                        AppKit's `Process` API (macOS only) and throw an `LSPError` \
                        at start time on iOS.
                        """
                    )
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var editor: some View {
        if appState.documents.active != nil {
            CodeEditor()
                .editorController(appState.editorController)
                .activeDocument(in: appState.documents)
                .environment(\.codeEditorConfiguration, appState.configuration)
                .codeTheme(appState.theme)
                .codeWorkspaceRoot(appState.workspaceRoot)
                .becomeFirstResponder()
                .eventSystem(appState.eventSystem)
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
        if let activeID = appState.documents.activeID {
            List {
                ForEach(LanguageCatalog.all, id: \.self) { language in
                    Button {
                        appState.documents.setLanguageRenaming(language, of: activeID)
                    } label: {
                        Label(
                            language.name,
                            systemImage: language == appState.documents.active?.language ? "checkmark.circle.fill" : "circle"
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
                Button("Save", action: appState.requestSave)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(appState.documents.active == nil)
                Button("Save As…", action: appState.requestSaveAs)
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(appState.documents.active == nil)
                Divider()
                Button("New Tab") { documents.newTab() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Open File…", action: appState.requestOpenFile)
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            } label: {
                Label("File", systemImage: "doc")
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
