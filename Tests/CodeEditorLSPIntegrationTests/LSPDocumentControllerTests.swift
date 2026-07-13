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
}
