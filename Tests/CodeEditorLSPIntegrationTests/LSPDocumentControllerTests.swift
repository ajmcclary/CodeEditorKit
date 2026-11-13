import CodeEditorDiagnostics
import CodeEditorLSP
@testable import CodeEditorLSPIntegration
@testable import CodeEditorView
import Foundation
import Testing

@MainActor
private final class LSPContentCoordinatorSpy: LSPContentCoordinating {
    private(set) var detachCount = 0

    func detach() {
        detachCount += 1
    }
}

@MainActor
@Suite("LSP document controller ownership")
struct LSPDocumentControllerTests {
    @Test("LSP controller detaches document coordination idempotently")
    func lspDetachReleasesDocumentCoordinator() {
        let contentCoordinator = LSPContentCoordinatorSpy()
        let controller = LSPDocumentController()
        controller.install(contentCoordinator: contentCoordinator)

        controller.attach(to: CodeEditorView(frame: .zero))
        controller.detach()
        controller.detach()

        #expect(contentCoordinator.detachCount == 1)
    }

    @Test("LSPSemanticTokenProvider initializes without a view")
    func semanticTokenProviderInitializes() {
        let manager = LSPManager(memoryMonitor: MemoryMonitor.mock(), workspaceRoot: nil)
        let provider = LSPSemanticTokenProvider(lspManager: manager, filePath: "/tmp/x.swift")
        _ = provider // smoke test only — initializes without crashing
    }

    @Test("LSPEditorBridge owns a manager and attaches to a view")
    func editorBridgeAttaches() {
        let view = CodeEditorView(frame: .zero)
        let bridge = LSPEditorBridge(view: view)
        #expect(bridge.lspManager.activeClients.isEmpty)
        bridge.detach()
    }

    @Test("a pending change batch outlives a released LSPManager")
    func pendingBatchAfterManagerRelease() async throws {
        let view = CodeEditorView(frame: .zero)
        var manager: LSPManager? = LSPManager(memoryMonitor: MemoryMonitor.mock(), workspaceRoot: nil)
        weak let weakManager = manager
        let coordinator = try LSPContentCoordinator(
            textView: view,
            lspManager: #require(manager),
            filePath: "/tmp/x.swift",
            languageId: "swift"
        )
        coordinator.textStorageWillApplyEdit(WillEditEvent(
            preEditRange: NSRange(location: 0, length: 0),
            replacementText: "a",
            preEditLineRange: 0...0
        ))
        coordinator.textStorageDidApplyEdit(TextEditEvent(
            editedRange: NSRange(location: 0, length: 1),
            changeInLength: 1,
            documentLength: 1,
            editedCharacters: true
        ))

        // The host drops the bridge (and its manager) without detach().
        manager = nil
        #expect(weakManager == nil)

        // The batch fires after 250 ms; it must not touch the released manager.
        try await Task.sleep(for: .milliseconds(400))
        coordinator.detach()
    }
}
