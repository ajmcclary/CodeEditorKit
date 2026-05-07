import CodeEditorDesignTokens
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Horizontal split: settings | editor | inspector.
struct WindowBody: View {
    @Environment(\.codeEditorTheme) private var editorTheme
    @Binding var theme: Theme
    @Binding var configuration: EditorConfiguration
    @Bindable var documents: DocumentStore
    @Binding var settingsVisible: Bool
    @Binding var inspectorVisible: Bool

    var body: some View {
        HStack(spacing: 0) {
            if settingsVisible {
                SettingsSidebar(
                    theme: $theme,
                    configuration: $configuration,
                    documents: documents
                )
                columnSeparator
            }
            editorPane
            if inspectorVisible {
                columnSeparator
                InspectorSidebar(configuration: configuration)
            }
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
        if let activeID = documents.activeTabID {
            CodeEditor(text: documents.textBinding(for: activeID))
                .codeLanguage(documents.activeLanguage ?? .plainText)
                .environment(\.codeEditorConfiguration, configuration)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
