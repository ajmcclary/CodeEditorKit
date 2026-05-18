#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorView
import CodeEditorWorkspace
import Foundation

@MainActor
final class StubWorkspaceFileTree: WorkspaceFileTree, WorkspaceFileWatching {
    var rootNode: WorkspaceFileNode
    var childrenByID: [String: [WorkspaceFileNode]]
    var startCount = 0
    var stopCount = 0
    private var continuation: AsyncStream<WorkspaceFileEvent>.Continuation?
    private(set) var eventStream: AsyncStream<WorkspaceFileEvent>

    init(
        root: WorkspaceFileNode,
        childrenByID: [String: [WorkspaceFileNode]] = [:]
    ) {
        self.rootNode = root
        self.childrenByID = childrenByID
        var localContinuation: AsyncStream<WorkspaceFileEvent>.Continuation?
        self.eventStream = AsyncStream { continuation in
            localContinuation = continuation
        }
        self.continuation = localContinuation
    }

    var root: WorkspaceFileNode { rootNode }

    func children(of node: WorkspaceFileNode) -> [WorkspaceFileNode] {
        childrenByID[node.id] ?? []
    }

    func isDirectory(_ node: WorkspaceFileNode) -> Bool { node.isDirectory }

    func fileURL(for node: WorkspaceFileNode) -> URL { node.url }

    func refresh(node _: WorkspaceFileNode) async throws { /* no-op */ }

    func startWatching(root _: URL) async throws { startCount += 1 }

    func stopWatching() { stopCount += 1 }

    var events: AsyncStream<WorkspaceFileEvent> { eventStream }

    func send(_ event: WorkspaceFileEvent) {
        continuation?.yield(event)
    }

    func finish() {
        continuation?.finish()
    }
}
#endif
