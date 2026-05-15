#if canImport(AppKit)
import CodeEditorPlugin
import Foundation

/// File-tree state + WorkspaceFileWatching subscription for the
/// sample's workspace surface. macOS-only.
///
/// The model owns:
/// - the current root and root node
/// - a lazy cache of children keyed by directory URL
/// - the set of expanded directory URLs (drives disclosure)
/// - the file-watching task that mutates the cache incrementally
@MainActor
@Observable
final class WorkspaceModel {
    typealias TreeProvider = WorkspaceFileTree & WorkspaceFileWatching

    private(set) var rootURL: URL?
    private(set) var rootNode: WorkspaceFileNode?
    private(set) var childrenByURL: [URL: [WorkspaceFileNode]] = [:]
    var expandedDirectoryURLs: Set<URL> = []
    var selectedFileURL: URL?
    private(set) var loadError: Error?

    private var provider: TreeProvider?
    private var watchTask: Task<Void, Never>?
    private let factory: @MainActor (URL) -> TreeProvider

    init(
        factory: @escaping @MainActor (URL) -> TreeProvider = { url in
            MacOSWorkspaceFileManager(rootURL: url)
        }
    ) {
        self.factory = factory
    }

    /// Sets a new root. Tears down the previous watcher and replaces
    /// the file provider. Passing `nil` clears all state.
    func setRoot(_ url: URL?) {
        watchTask?.cancel()
        watchTask = nil
        provider?.stopWatching()
        provider = nil
        childrenByURL = [:]
        expandedDirectoryURLs = []
        loadError = nil

        guard let url else {
            rootURL = nil
            rootNode = nil
            return
        }

        let newProvider = factory(url)
        provider = newProvider
        rootURL = url
        rootNode = newProvider.root
        expandedDirectoryURLs.insert(url)

        let rootChildren = newProvider.children(of: newProvider.root)
        childrenByURL[url] = rootChildren

        watchTask = Task { [weak self] in
            do {
                try await newProvider.startWatching(root: url)
            } catch {
                await MainActor.run { self?.loadError = error }
                return
            }
            for await event in newProvider.events {
                guard !Task.isCancelled else { break }
                await MainActor.run { self?.apply(event: event) }
            }
        }
    }

    /// Toggle a directory's expansion. Loads children on first expand.
    func toggleExpanded(_ url: URL) async {
        if expandedDirectoryURLs.contains(url) {
            expandedDirectoryURLs.remove(url)
            return
        }
        expandedDirectoryURLs.insert(url)
        if childrenByURL[url] == nil {
            await loadChildren(for: url)
        }
    }

    /// Re-fetch a directory's children from the provider.
    func refresh(directory url: URL) async {
        await loadChildren(for: url)
    }

    /// Cached children, filtered through `WorkspaceIgnoreRules`,
    /// sorted directories-first then alpha by name.
    func filteredChildren(of url: URL) -> [WorkspaceFileNode] {
        let cached = childrenByURL[url] ?? []
        return cached
            .filter { !WorkspaceIgnoreRules.shouldHide(name: $0.name) }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    // MARK: - Private

    private func loadChildren(for url: URL) async {
        guard let provider, let parentNode = nodeForURL(url) else { return }
        do {
            try await provider.refresh(node: parentNode)
        } catch {
            loadError = error
        }
        childrenByURL[url] = provider.children(of: parentNode)
    }

    private func nodeForURL(_ url: URL) -> WorkspaceFileNode? {
        if url == rootURL { return rootNode }
        for (_, nodes) in childrenByURL {
            if let match = nodes.first(where: { $0.url == url }) {
                return match
            }
        }
        return nil
    }

    private func apply(event: WorkspaceFileEvent) {
        switch event {
        case .created(let url):
            insert(url: url)

        case .deleted(let url):
            remove(url: url)

        case let .renamed(oldURL, newURL):
            remove(url: oldURL)
            insert(url: newURL)

        case .modified:
            // Modifications don't change tree structure; ignored for tree.
            break
        }
    }

    /// Returns the parent URL in the same canonical form used in
    /// `childrenByURL`. `URL.deletingLastPathComponent()` adds a
    /// trailing slash; we normalize by rebuilding from `.path`.
    private func parentKey(for url: URL) -> URL {
        URL(fileURLWithPath: url.deletingLastPathComponent().path)
    }

    private func insert(url: URL) {
        let parentURL = parentKey(for: url)
        guard childrenByURL[parentURL] != nil else { return }
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let node = WorkspaceFileNode(
            name: url.lastPathComponent,
            url: url,
            isDirectory: isDir
        )
        var siblings = childrenByURL[parentURL] ?? []
        guard !siblings.contains(where: { $0.url == url }) else { return }
        siblings.append(node)
        childrenByURL[parentURL] = siblings
    }

    private func remove(url: URL) {
        let parentURL = parentKey(for: url)
        guard var siblings = childrenByURL[parentURL] else { return }
        siblings.removeAll { $0.url == url }
        childrenByURL[parentURL] = siblings
        childrenByURL.removeValue(forKey: url)
        expandedDirectoryURLs.remove(url)
    }
}
#endif
