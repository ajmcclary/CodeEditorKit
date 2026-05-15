#if canImport(AppKit)
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

struct ProjectSearchPanelView: View {
    @Environment(\.codeEditorTheme) private var theme
    @Bindable var model: ProjectSearchModel
    @Bindable var workspace: WorkspaceModel
    @Bindable var appState: AppState
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            header
            statusLine
            resultsList
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            TextField("Search workspace…", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .onChange(of: model.query) { _, _ in scheduleDebouncedSearch() }

            HStack(spacing: 6) {
                Toggle(isOn: $model.caseSensitive) { Text("Aa") }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .onChange(of: model.caseSensitive) { _, _ in runImmediately() }

                Toggle(isOn: $model.useRegex) { Text(".*") }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .onChange(of: model.useRegex) { _, _ in runImmediately() }

                TextField("ext: swift, md", text: $model.extensionFilter)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .onChange(of: model.extensionFilter) { _, _ in scheduleDebouncedSearch() }
            }

            HStack(spacing: 8) {
                Button {
                    Task { await model.reindex() }
                } label: {
                    Label("Reindex", systemImage: "arrow.triangle.2.circlepath")
                }
                .controlSize(.small)
                .disabled(workspace.rootURL == nil)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusLine: some View {
        Text(statusText)
            .font(.system(size: 10))
            .foregroundStyle(Color(tokens: theme.style.text.muted))
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusText: String {
        switch model.status {
        case .idle:
            return "Open a folder to enable project search"

        case .indexing:
            return "Indexing \(model.indexedFileCount) files…"

        case .ready:
            return "Ready · \(model.indexedFileCount) files indexed"

        case .searching:
            return "Searching…"

        case let .results(matches, files):
            return "\(matches) matches in \(files) files"

        case .noMatches:
            return "No matches"

        case let .error(message):
            return message
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        if model.results.isEmpty {
            Spacer()
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groupedResults, id: \.0) { fileURL, hits in
                        Text(relativePath(for: fileURL))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(tokens: theme.style.text.muted))
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                            .padding(.bottom, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(Array(hits.enumerated()), id: \.offset) { _, hit in
                            resultRow(for: hit)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var groupedResults: [(URL, [ProjectSearchResult])] {
        var seen: [URL] = []
        var buckets: [URL: [ProjectSearchResult]] = [:]
        for result in model.results {
            if buckets[result.fileURL] == nil { seen.append(result.fileURL) }
            buckets[result.fileURL, default: []].append(result)
        }
        return seen.map { ($0, buckets[$0] ?? []) }
    }

    private func relativePath(for fileURL: URL) -> String {
        guard let root = workspace.rootURL else { return fileURL.path }
        let rootPath = root.path
        let filePath = fileURL.path
        if filePath.hasPrefix(rootPath) {
            let stripped = String(filePath.dropFirst(rootPath.count))
            return stripped.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return fileURL.path
    }

    private func resultRow(for hit: ProjectSearchResult) -> some View {
        Button {
            openResult(hit)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text("\(hit.lineNumber)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(tokens: theme.style.text.muted))
                    .frame(width: 36, alignment: .trailing)
                Text(hit.contextLine)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func openResult(_ hit: ProjectSearchResult) {
        appState.documents.store.openFile(url: hit.fileURL)
        appState.documents.editorController.selectMatch(hit)
    }

    // MARK: - Debounce

    private func scheduleDebouncedSearch() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await model.runSearch()
        }
    }

    private func runImmediately() {
        debounceTask?.cancel()
        Task { await model.runSearch() }
    }
}
#endif
