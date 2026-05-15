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
            GotoLineSheet(controller: appState.editorController)
        }
        .sheet(isPresented: $appState.gotoSymbolSheetVisible) {
            GotoSymbolSheet(controller: appState.editorController)
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
        if appState.documents.active != nil {
            CodeEditor()
                .editorController(appState.editorController)
                .onTextChange { newText in
                    MainActor.assumeIsolated {
                        #if canImport(AppKit)
                        if let activeID = appState.documents.activeID {
                            appState.lsp.handleTextChange(id: activeID, newText: newText)
                        }
                        #endif
                    }
                }
                .activeDocument(in: appState.documents)
                .codeWorkspaceRoot(appState.workspaceRoot)
                .environment(\.codeEditorConfiguration, appState.configuration)
                .lineNumbers(appState.configuration.display.isLineNumbersEnabled)
                .becomeFirstResponder()
                .performanceObserver(appState.performanceObservation)
                .eventSystem(appState.eventSystem)
                #if canImport(AppKit)
                .onTextHover { position in
                    if let activeID = await appState.documents.activeID {
                        await appState.lsp.handleHover(at: position, in: activeID)
                    }
                }
                .onCommandClick { position in
                    Task { @MainActor in
                        if let activeID = appState.documents.activeID {
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
                .safeAreaInset(edge: .top, spacing: 0) {
                    if appState.findOverlayVisible {
                        FindReplaceOverlay(appState: appState)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
        } else {
            emptyState
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
