import CodeEditorDesignTokens
import CodeEditorPlugin
import CodeEditorSwiftUI
import CodeEditorView
import SwiftUI

/// Bottom status bar — language indicator on the left, selection +
/// indentation + hardware-acceleration indicator on the right, plus a
/// trailing `@ViewBuilder` slot for host extras (e.g., LSP status,
/// branch name).
///
/// Reads `\.codeEditorTheme`, `\.codeEditorConfiguration`, and
/// `\.editorState` from the environment. Renders zero-fields when no
/// document is open (no selection in `EditorState`).
public struct EditorStatusBar<Trailing: View>: View {
    @Environment(\.codeEditorTheme) private var theme
    @Environment(\.codeEditorConfiguration) private var configuration
    @Environment(\.editorState) private var editorState

    private let trailing: () -> Trailing

    /// Creates a status bar.
    /// - Parameter trailing: `@ViewBuilder` slot for trailing host content.
    public init(@ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: 12) {
            languageBadge
            Spacer()
            selectionBadge
            indentationBadge
            hardwareAccelerationBadge
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(height: 28)
        .platformGlassSurface(.statusBar)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(tokens: theme.style.borders.base).opacity(0.5))
                .frame(height: 0.5)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Color(tokens: theme.style.text.muted))
    }

    @ViewBuilder
    private var languageBadge: some View {
        if let language = editorState.language {
            Label(language.name, systemImage: "chevron.left.slash.chevron.right")
                .labelStyle(.titleAndIcon)
        } else {
            Text("Plain Text")
        }
    }

    @ViewBuilder
    private var selectionBadge: some View {
        if let selection = editorState.selection {
            if selection.selectionLength == 0 {
                Text("Ln \(selection.line), Col \(selection.column)")
            } else {
                Text("Ln \(selection.line), Col \(selection.column) (\(selection.selectionLength) sel)")
            }
        } else {
            Text("Ln —")
        }
    }

    @ViewBuilder
    private var indentationBadge: some View {
        let mode = configuration.layout.insertSpacesForTabs ? "Spaces" : "Tabs"
        Text("\(mode): \(configuration.layout.tabWidth)")
    }

    @ViewBuilder
    private var hardwareAccelerationBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(editorState.hardwareAccelerationActive
                      ? Color(tokens: Tokens.Palette.Status.successDark)
                      : Color(tokens: theme.style.text.muted))
                .frame(width: 6, height: 6)
            Text(editorState.hardwareAccelerationActive ? "GPU" : "CPU")
        }
    }
}
