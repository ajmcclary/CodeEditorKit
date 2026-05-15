#if canImport(AppKit)
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// File-tree panel content. Three states:
/// - no root: ContentUnavailableView + Open Folder… button
/// - loaded: OutlineGroup-style lazy tree
/// - error overlay: inline row above the tree
struct FilePanelView: View {
    @Environment(\.codeEditorTheme) private var theme
    @Bindable var model: WorkspaceModel
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if let error = model.loadError {
                errorBanner(error)
            }
            content
            footer
        }
    }

    @ViewBuilder
    private var content: some View {
        if let root = model.rootNode {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    rowsForChildren(of: root.url, depth: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No folder open", systemImage: "folder.badge.questionmark")
        } description: {
            Text("Open a folder to browse and search its files.")
        } actions: {
            Button("Open Folder…") {
                WorkspacePicker.choose(currentRoot: model.rootURL) {
                    appState.workspaceRoot = $0
                }
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func rowsForChildren(of url: URL, depth: Int) -> AnyView {
        let children = model.filteredChildren(of: url)
        return AnyView(
            ForEach(children) { node in
                row(for: node, depth: depth)
                if node.isDirectory, model.expandedDirectoryURLs.contains(node.url) {
                    rowsForChildren(of: node.url, depth: depth + 1)
                }
            }
        )
    }

    private func row(for node: WorkspaceFileNode, depth: Int) -> some View {
        Button {
            handleTap(on: node)
        } label: {
            HStack(spacing: 6) {
                Spacer().frame(width: CGFloat(depth) * 12)
                if node.isDirectory {
                    Image(systemName: model.expandedDirectoryURLs.contains(node.url)
                          ? "chevron.down"
                          : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(tokens: theme.style.icon.muted))
                        .frame(width: 10)
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color(tokens: theme.style.icon.muted))
                } else {
                    Spacer().frame(width: 10)
                    Image(systemName: "doc.text")
                        .foregroundStyle(Color(tokens: theme.style.icon.muted))
                }
                Text(node.name)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .background(
                (model.selectedFileURL == node.url)
                ? Color(tokens: theme.style.text.accent).opacity(0.15)
                : Color.clear
            )
        }
        .buttonStyle(.plain)
    }

    private func handleTap(on node: WorkspaceFileNode) {
        if node.isDirectory {
            Task { await model.toggleExpanded(node.url) }
        } else {
            model.selectedFileURL = node.url
            appState.documents.store.openFile(url: node.url)
        }
    }

    private func errorBanner(_ error: Error) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)
            Text(error.localizedDescription)
                .font(.system(size: 11))
                .foregroundStyle(Color(tokens: theme.style.text.base))
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(tokens: theme.style.elements.element.background))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text(model.rootURL?.path ?? "No folder")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(tokens: theme.style.text.muted))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                if let url = model.rootURL {
                    Task { await model.refresh(directory: url) }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Reload")
            .disabled(model.rootURL == nil)

            Button {
                WorkspacePicker.choose(currentRoot: model.rootURL) {
                    appState.workspaceRoot = $0
                }
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.plain)
            .help("Open Folder…")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay(
            Rectangle()
                .fill(Color(tokens: theme.style.borders.variant))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}
#endif
