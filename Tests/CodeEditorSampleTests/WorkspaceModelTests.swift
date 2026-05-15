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

    /// Polls the predicate on the MainActor, yielding between checks
    /// for up to ~1 s. The watch task in WorkspaceModel needs at least
    /// one MainActor hop per event; a fixed sleep is flaky under
    /// parallel test load.
    private func waitFor(
        timeoutMs: Int = 1_000,
        predicate: @escaping () -> Bool
    ) async {
        let started = ContinuousClock.now
        let timeout = Duration.milliseconds(timeoutMs)
        while ContinuousClock.now - started < timeout {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
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
        await waitFor { stub.startCount == 1 }
        #expect(stub.startCount == 1)

        model.setRoot(nil)
        await waitFor { stub.stopCount == 1 }
        #expect(stub.stopCount == 1)
    }

    @Test("created event inserts a child into the parent's cached list")
    func createdEventInserts() async {
        let root = makeRoot()
        let stub = StubWorkspaceFileTree(root: root)
        let model = WorkspaceModel { _ in stub }
        model.setRoot(root.url)
        await waitFor { stub.startCount == 1 }

        let newChild = makeChild("NewFile.swift")
        stub.send(.created(url: newChild.url))
        await waitFor {
            model.filteredChildren(of: root.url).contains { $0.name == "NewFile.swift" }
        }

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
        await waitFor { stub.startCount == 1 }

        stub.send(.deleted(url: existing.url))
        await waitFor {
            !model.filteredChildren(of: root.url).contains { $0.name == "Existing.swift" }
        }

        let children = model.filteredChildren(of: root.url)
        #expect(!children.contains { $0.name == "Existing.swift" })
    }
}
#endif
