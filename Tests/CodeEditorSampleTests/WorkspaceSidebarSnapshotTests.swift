#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
@testable import CodeEditorSample
import CodeEditorSearch
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import CodeEditorWorkspace
import Foundation
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class WorkspaceSidebarSnapshotTests: XCTestCase {
    // MARK: - Sidebar host (Files tab — default)

    func testFilesEmptyState() {
        let appState = AppState()
        let view = WorkspaceSidebar(
            workspace: appState.workspaceModel,
            search: appState.projectSearchModel,
            appState: appState
        )
        assertSnapshot(of: host(view), as: .image, named: "files-empty")
    }

    func testFilesLoaded() {
        let appState = AppState()
        let workspace = makeLoadedWorkspaceModel()
        let view = WorkspaceSidebar(
            workspace: workspace,
            search: appState.projectSearchModel,
            appState: appState
        )
        assertSnapshot(of: host(view), as: .image, named: "files-loaded")
    }

    // MARK: - Project search panel (rendered directly to bypass segmented tab)

    func testSearchReady() async {
        let appState = AppState()
        let workspace = makeLoadedWorkspaceModel()
        let stub = StubProjectSearchProvider()
        let search = ProjectSearchModel(adapter: stub)
        await search.setRoot(URL(fileURLWithPath: "/tmp/SampleWorkspace"))

        let view = ProjectSearchPanelView(
            model: search,
            workspace: workspace,
            appState: appState
        )
        assertSnapshot(of: host(view), as: .image, named: "search-ready")
    }

    func testSearchResultsPopulated() async {
        let appState = AppState()
        let workspace = makeLoadedWorkspaceModel()
        let stub = StubProjectSearchProvider()
        stub.setResults([
            ProjectSearchResult(
                fileURL: URL(fileURLWithPath: "/tmp/SampleWorkspace/Sources/Foo.swift"),
                lineNumber: 14,
                column: 9,
                matchedText: "TODO",
                contextLine: "// TODO: Implement feature"
            ),
            ProjectSearchResult(
                fileURL: URL(fileURLWithPath: "/tmp/SampleWorkspace/Tests/Bar.swift"),
                lineNumber: 7,
                column: 5,
                matchedText: "TODO",
                contextLine: "    TODO: assert behavior"
            )
        ])
        let search = ProjectSearchModel(adapter: stub)
        search.query = "TODO"
        await search.runSearch()

        let view = ProjectSearchPanelView(
            model: search,
            workspace: workspace,
            appState: appState
        )
        assertSnapshot(of: host(view), as: .image, named: "search-results")
    }

    func testSearchRegexError() async {
        let appState = AppState()
        let workspace = makeLoadedWorkspaceModel()
        let stub = StubProjectSearchProvider()
        struct Boom: Error, LocalizedError {
            var errorDescription: String? { "invalid regex" }
        }
        stub.setError(Boom())
        let search = ProjectSearchModel(adapter: stub)
        search.query = "[invalid"
        search.useRegex = true
        await search.runSearch()

        let view = ProjectSearchPanelView(
            model: search,
            workspace: workspace,
            appState: appState
        )
        assertSnapshot(of: host(view), as: .image, named: "search-regex-error")
    }

    // MARK: - Helpers

    private func makeLoadedWorkspaceModel() -> WorkspaceModel {
        let rootURL = URL(fileURLWithPath: "/tmp/SampleWorkspace")
        let model = WorkspaceModel { url in
            let root = WorkspaceFileNode(name: url.lastPathComponent, url: url, isDirectory: true)
            let children: [WorkspaceFileNode] = [
                WorkspaceFileNode(
                    name: "Sources",
                    url: url.appendingPathComponent("Sources"),
                    isDirectory: true
                ),
                WorkspaceFileNode(
                    name: "Tests",
                    url: url.appendingPathComponent("Tests"),
                    isDirectory: true
                ),
                WorkspaceFileNode(
                    name: "Package.swift",
                    url: url.appendingPathComponent("Package.swift"),
                    isDirectory: false
                ),
                WorkspaceFileNode(
                    name: "README.md",
                    url: url.appendingPathComponent("README.md"),
                    isDirectory: false
                )
            ]
            return SnapshotStubTree(root: root, children: children)
        }
        model.setRoot(rootURL)
        return model
    }

    private func host<V: View>(_ view: V) -> NSView {
        let hosting = NSHostingView(
            rootView: view
                .frame(width: 320, height: 480)
                .background(Color.white)
                .foregroundColor(.black)
                .environment(\.colorScheme, .light)
        )
        hosting.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        return hosting
    }
}

@MainActor
private final class SnapshotStubTree: WorkspaceFileTree, WorkspaceFileWatching {
    let root: WorkspaceFileNode
    private let cachedChildren: [WorkspaceFileNode]
    private let stream: AsyncStream<WorkspaceFileEvent>

    init(root: WorkspaceFileNode, children: [WorkspaceFileNode]) {
        self.root = root
        self.cachedChildren = children
        self.stream = AsyncStream { _ in }
    }

    func children(of node: WorkspaceFileNode) -> [WorkspaceFileNode] {
        node.id == root.id ? cachedChildren : []
    }

    func isDirectory(_ node: WorkspaceFileNode) -> Bool { node.isDirectory }

    func fileURL(for node: WorkspaceFileNode) -> URL { node.url }

    func refresh(node _: WorkspaceFileNode) async throws {}

    func startWatching(root _: URL) async throws {}

    func stopWatching() {}

    var events: AsyncStream<WorkspaceFileEvent> { stream }
}
#endif
