import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// Xcode-style overlay banner pinned to the top of the editor pane.
/// Drives `EditorController.find` / `findNext` / `findPrevious` /
/// `replaceAll`. Visibility is owned by `AppState.findOverlayVisible`
/// so the command-palette "Find…" entry can show / hide it.
struct FindReplaceOverlay: View {
    @Environment(\.codeEditorTheme) private var theme
    @Bindable var appState: AppState

    @FocusState private var focusedField: Field?

    private enum Field { case find, replace }

    var body: some View {
        VStack(spacing: 0) {
            findRow
            Divider().background(Color(tokens: theme.style.borders.variant))
            replaceRow
        }
        .padding(8)
        .background(panelBackground)
        .padding(10)
        .onAppear { focusedField = .find }
    }

    // MARK: - Find row

    private var findRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(tokens: theme.style.icon.muted))
                .frame(width: 16)
            TextField("Find", text: $appState.findText)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .focused($focusedField, equals: .find)
                .onSubmit {
                    Task { @MainActor in
                        _ = await appState.editorController.find(appState.findText)
                    }
                }
            matchBadge
            Button {
                Task { @MainActor in
                    _ = await appState.editorController.find(appState.findText)
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Re-run search")
            Button {
                _ = appState.editorController.findPrevious()
            } label: {
                Image(systemName: "chevron.up")
            }
            .help("Previous match")
            Button {
                _ = appState.editorController.findNext()
            } label: {
                Image(systemName: "chevron.down")
            }
            .help("Next match")
            Button {
                appState.findOverlayVisible = false
            } label: {
                Image(systemName: "xmark")
            }
            .help("Close")
        }
        .buttonStyle(.plain)
        .controlSize(.small)
    }

    @ViewBuilder
    private var matchBadge: some View {
        let count = appState.editorController.matchCount
        if count > 0 {
            let position = appState.editorController.currentMatchIndex + 1
            Text("\(position) / \(count)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(tokens: theme.style.text.muted))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(tokens: theme.style.elements.element.background))
                )
        } else if !appState.findText.isEmpty {
            Text("0")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(tokens: theme.style.text.muted))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        }
    }

    // MARK: - Replace row

    private var replaceRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(tokens: theme.style.icon.muted))
                .frame(width: 16)
            TextField("Replace", text: $appState.replaceText)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .focused($focusedField, equals: .replace)
            Spacer()
            Button("Replace All") {
                Task { @MainActor in
                    _ = await appState.editorController.replaceAll(
                        appState.findText,
                        with: appState.replaceText
                    )
                }
            }
            .disabled(appState.findText.isEmpty)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(tokens: theme.style.chrome.elevatedSurfaceBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(tokens: theme.style.borders.base), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
    }
}
