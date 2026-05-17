import CodeEditorConfiguration
#if canImport(AppKit)
import CodeEditorDesignTokens
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Horizontal split: workspace | editor | inspector. macOS only —
/// `IOSRootView` provides the iOS layout via `NavigationSplitView`.
/// Global settings live in `Settings { SettingsScene(...) }` (⌘,).
struct WindowBody: View {
    @Environment(\.codeEditorTheme) private var editorTheme
    @Bindable var appState: AppState
    @Binding var workspaceVisible: Bool
    @Binding var inspectorVisible: Bool

    var body: some View {
        HStack(spacing: 0) {
            if workspaceVisible {
                WorkspaceSidebar(
                    workspace: appState.workspaceModel,
                    search: appState.projectSearchModel,
                    appState: appState
                )
                .onChange(of: appState.workspaceRoot) { _, newValue in
                    appState.workspaceModel.setRoot(newValue)
                    Task { @MainActor [projectSearchModel = appState.projectSearchModel] in
                        await projectSearchModel.setRoot(newValue)
                    }
                }
                columnSeparator
            }
            editorPane
            if inspectorVisible {
                columnSeparator
                InspectorSidebar(appState: appState)
            }
        }
        .sheet(isPresented: $appState.gotoLineSheetVisible) {
            GotoLineSheet(controller: appState.documents.editorController)
        }
        .sheet(isPresented: $appState.gotoSymbolSheetVisible) {
            GotoSymbolSheet(controller: appState.documents.editorController)
        }
    }

    private var columnSeparator: some View {
        Rectangle()
            .fill(Color(tokens: editorTheme.style.borders.variant))
            .frame(width: 0.5)
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var editorPane: some View {
        if appState.documents.store.active != nil {
            CodeEditor()
                .editorController(appState.documents.editorController)
                .onTextChange { newText in
                    #if canImport(AppKit)
                    if let activeID = appState.documents.store.activeID {
                        appState.lsp.handleTextChange(id: activeID, newText: newText)
                    }
                    #endif
                }
                .activeDocument(in: appState.documents.store)
                .codeWorkspaceRoot(appState.workspaceRoot)
                .environment(\.codeEditorConfiguration, appState.configuration.current)
                .lineNumbers(appState.configuration.current.display.isLineNumbersEnabled)
                .becomeFirstResponder()
                .performanceObserver(appState.performanceObservation)
                .eventSystem(appState.eventSystem)
                #if canImport(AppKit)
                .onTextHover { position in
                    if let activeID = await appState.documents.store.activeID {
                        await appState.lsp.handleHover(at: position, in: activeID)
                    }
                }
                .onCommandClick { position in
                    if let activeID = appState.documents.store.activeID {
                        Task {
                            await appState.lsp.jumpToDefinition(at: position, in: activeID)
                        }
                    }
                }
                .popover(item: Binding(
                    get: { appState.lsp.hoverSession.displayed },
                    set: { appState.lsp.hoverSession.displayed = $0 }
                )) { display in
                    LSPHoverPopover(markdown: display.markdown)
                }
                #endif
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #if canImport(AppKit)
                .onAppear { appState.lsp.currentWorkspaceRoot = appState.workspaceRoot }
                .onChange(of: appState.workspaceRoot) { _, newValue in
                    appState.lsp.currentWorkspaceRoot = newValue
                }
                #endif
                .modifier(FindReplacePlumbing(appState: appState))
        } else {
            emptyState
        }
    }

    private struct FindReplacePlumbing: ViewModifier {
        @Bindable var appState: AppState

        func body(content: Content) -> some View {
            content
                .modifier(FindReplaceOverlayAttachment(appState: appState))
                .modifier(FindReplaceClearHooks(appState: appState))
        }
    }

    private struct FindReplaceOverlayAttachment: ViewModifier {
        @Bindable var appState: AppState

        func body(content: Content) -> some View {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    overlay
                }
                .task(id: appState.findReplace.searchRequest(activeDocumentID: appState.documents.store.activeID)) {
                    await appState.findReplace.runDebouncedSearch(controller: appState.documents.editorController)
                }
        }

        @ViewBuilder
        private var overlay: some View {
            if appState.findReplace.isOverlayVisible {
                FindReplaceOverlay(
                    model: appState.findReplace,
                    controller: appState.documents.editorController,
                    isReadOnly: !appState.configuration.current.behavior.isEditable
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private struct FindReplaceClearHooks: ViewModifier {
        @Bindable var appState: AppState

        func body(content: Content) -> some View {
            content
                .onChange(of: appState.findReplace.isOverlayVisible) { _, isVisible in
                    if !isVisible {
                        appState.documents.editorController.clearSearch()
                    }
                }
                .onChange(of: appState.documents.store.activeID) { _, _ in
                    clearAndBump()
                }
                .onChange(of: appState.documents.store.active?.text) { _, _ in
                    clearAndBump()
                }
                .onChange(of: appState.documents.store.active?.language) { _, _ in
                    clearAndBump()
                }
                .onChange(of: appState.theme.current.id) { _, _ in
                    clearAndBump()
                }
        }

        private func clearAndBump() {
            appState.documents.editorController.clearSearch()
            appState.findReplace.markDocumentEdited()
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No tabs open")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Use ⌘⇧P → New Tab")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
