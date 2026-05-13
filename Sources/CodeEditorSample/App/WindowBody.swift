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
        if let activeID = appState.documents.activeTabID {
            ZStack(alignment: .top) {
                CodeEditor(text: appState.documents.textBinding(for: activeID))
                    .editorController(appState.editorController)
                    .codeLanguage(appState.documents.activeLanguage ?? .plainText)
                    .codeWorkspaceRoot(appState.workspaceRoot)
                    .environment(\.codeEditorConfiguration, appState.configuration)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
