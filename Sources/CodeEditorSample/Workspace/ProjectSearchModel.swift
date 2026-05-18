#if canImport(AppKit)
import CodeEditorPlugin
import CodeEditorSearch
import Foundation

/// Project-wide search state + ProjectSearchProvider adapter for the
/// sample's workspace surface. Independent of WorkspaceModel.
@MainActor
@Observable
final class ProjectSearchModel {
    enum Status: Equatable, Sendable {
        case idle
        case indexing
        case searching
        case ready
        case results(matchCount: Int, fileCount: Int)
        case noMatches
        case error(message: String)
    }

    var query: String = ""
    var caseSensitive: Bool = false
    var useRegex: Bool = false
    var extensionFilter: String = ""
    private(set) var results: [ProjectSearchResult] = []
    private(set) var status: Status = .idle
    private(set) var indexedFileCount: Int = 0

    private let adapter: ProjectSearchProvider
    private var indexTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private(set) var indexedRoot: URL?

    init(adapter: ProjectSearchProvider = PortableProjectSearchAdapter()) {
        self.adapter = adapter
    }

    /// Sets a new root. Cancels any in-flight work, then walks the
    /// directory and feeds the index. `nil` clears state.
    func setRoot(_ url: URL?) async {
        indexTask?.cancel()
        searchTask?.cancel()
        adapter.cancelSearch()
        adapter.clearIndex()
        results = []
        indexedFileCount = 0
        indexedRoot = nil

        guard let url else {
            status = .idle
            return
        }

        status = .indexing
        let urls = await enumerateFiles(at: url)
        indexedFileCount = urls.count
        do {
            try await adapter.indexFiles(urls: urls)
            indexedRoot = url
            status = .ready
        } catch {
            status = .error(message: error.localizedDescription)
        }
    }

    /// Run the current query with the current options. Cancels any
    /// in-flight search.
    func runSearch() async {
        searchTask?.cancel()
        adapter.cancelSearch()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clear()
            return
        }
        status = .searching
        let options = ProjectSearchOptions(
            caseSensitive: caseSensitive,
            useRegex: useRegex,
            maxResults: 200,
            fileExtensions: parsedExtensionFilter()
        )
        do {
            let found = try await adapter.search(query: trimmed, options: options)
            results = found
            if found.isEmpty {
                status = .noMatches
            } else {
                let fileCount = Set(found.map(\.fileURL)).count
                status = .results(matchCount: found.count, fileCount: fileCount)
            }
        } catch {
            status = .error(message: error.localizedDescription)
        }
    }

    /// Cancel any in-flight search; preserve existing results.
    func cancel() {
        searchTask?.cancel()
        adapter.cancelSearch()
        if !results.isEmpty {
            let fileCount = Set(results.map(\.fileURL)).count
            status = .results(matchCount: results.count, fileCount: fileCount)
        } else {
            status = indexedRoot == nil ? .idle : .ready
        }
    }

    /// Reset query + results. Index is retained.
    func clear() {
        searchTask?.cancel()
        adapter.cancelSearch()
        query = ""
        results = []
        status = indexedRoot == nil ? .idle : .ready
    }

    /// Re-walk the indexed root and re-feed the index.
    func reindex() async {
        guard let indexedRoot else { return }
        await setRoot(indexedRoot)
    }

    // MARK: - Private

    func parsedExtensionFilter() -> [String] {
        let raw = extensionFilter
        let separators = CharacterSet(charactersIn: ", \t")
        let pieces = raw
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return pieces.map { piece -> String in
            var trimmed = piece
            if trimmed.hasPrefix(".") { trimmed.removeFirst() }
            return trimmed.lowercased()
        }
    }

    private func enumerateFiles(at root: URL) async -> [URL] {
        await Task.detached(priority: .userInitiated) {
            var results: [URL] = []
            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return results
            }
            while let url = enumerator.nextObject() as? URL {
                let name = url.lastPathComponent
                if WorkspaceIgnoreRules.shouldHide(name: name) {
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if isDir { enumerator.skipDescendants() }
                    continue
                }
                let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
                guard isRegular else { continue }
                if WorkspaceIgnoreRules.isBinaryExtension(url.pathExtension) { continue }
                results.append(url)
            }
            return results
        }.value
    }
}
#endif
