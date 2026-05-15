#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing

@MainActor
@Suite("WorkspaceModel")
struct WorkspaceModelTests {
    private func makeRoot(at path: String = "/tmp/ws") -> WorkspaceFileNode {
        WorkspaceFileNode(name: "ws", url: URL(fileURLWithPath: path), isDirectory: true)
    }

    private func makeChild(
        _ name: String,
        in rootPath: String = "/tmp/ws",
        isDirectory: Bool = false
    ) -> WorkspaceFileNode {
        WorkspaceFileNode(
            name: name,
            url: URL(fileURLWithPath: rootPath).appendingPathComponent(name),
            isDirectory: isDirectory
        )
    }

    @Test("setRoot(nil) clears state without invoking the factory")
    func setRootNilClearsState() {
        var factoryCalls = 0
        let model = WorkspaceModel { _ in
            factoryCalls += 1
            return StubWorkspaceFileTree(
                root: WorkspaceFileNode(name: "", url: URL(fileURLWithPath: "/"), isDirectory: true)
            )
        }

        model.setRoot(nil)

        #expect(factoryCalls == 0)
        #expect(model.rootURL == nil)
        #expect(model.rootNode == nil)
    }

    @Test("setRoot loads the root and applies ignore rules to filtered children")
    func setRootLoadsRoot() async {
        let root = makeRoot()
        let visible = makeChild("Sources", isDirectory: true)
        let hidden = makeChild(".git", isDirectory: true)
        let stub = StubWorkspaceFileTree(
            root: root,
            childrenByID: [root.id: [visible, hidden]]
        )

        let model = WorkspaceModel { _ in stub }
        model.setRoot(root.url)

        await Task.yield()

        #expect(model.rootURL == root.url)
        #expect(model.rootNode?.id == root.id)
        let filtered = model.filteredChildren(of: root.url)
        #expect(filtered.map(\.name) == ["Sources"])
    }

    @Test("setRoot starts watching and a subsequent setRoot(nil) stops")
    func setRootStartsAndStopsWatching() async {
        let root = makeRoot()
        let stub = StubWorkspaceFileTree(root: root)
        let model = WorkspaceModel { _ in stub }

        model.setRoot(root.url)
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(stub.startCount == 1)

        model.setRoot(nil)
        #expect(stub.stopCount == 1)
    }

    @Test("created event inserts a child into the parent's cached list")
    func createdEventInserts() async {
        let root = makeRoot()
        let stub = StubWorkspaceFileTree(root: root)
        let model = WorkspaceModel { _ in stub }
        model.setRoot(root.url)
        try? await Task.sleep(nanoseconds: 50_000_000)

        let newChild = makeChild("NewFile.swift")
        stub.send(.created(url: newChild.url))
        try? await Task.sleep(nanoseconds: 100_000_000)

        let children = model.filteredChildren(of: root.url)
        #expect(children.contains { $0.name == "NewFile.swift" })
    }

    @Test("deleted event removes the child from the parent's cached list")
    func deletedEventRemoves() async {
        let root = makeRoot()
        let existing = makeChild("Existing.swift")
        let stub = StubWorkspaceFileTree(root: root, childrenByID: [root.id: [existing]])
        let model = WorkspaceModel { _ in stub }
        model.setRoot(root.url)
        try? await Task.sleep(nanoseconds: 50_000_000)

        stub.send(.deleted(url: existing.url))
        try? await Task.sleep(nanoseconds: 100_000_000)

        let children = model.filteredChildren(of: root.url)
        #expect(!children.contains { $0.name == "Existing.swift" })
    }
}
#endif
