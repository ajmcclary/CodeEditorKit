#if canImport(AppKit)
import CodeEditorDesignTokens
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Horizontal split: settings | editor | inspector. macOS only —
/// `IOSRootView` provides the iOS layout via `NavigationSplitView`.
struct WindowBody: View {
    @Environment(\.codeEditorTheme) private var editorTheme
    @Bindable var appState: AppState
    @Binding var settingsVisible: Bool
    @Binding var inspectorVisible: Bool

    var body: some View {
        HStack(spacing: 0) {
            if settingsVisible {
                SettingsSidebar(
                    appState: appState
                )
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
