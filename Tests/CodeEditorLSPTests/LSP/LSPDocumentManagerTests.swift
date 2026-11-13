@testable import CodeEditorLSP
import Foundation
import Testing

@Suite("LSP document manager state")
struct LSPDocumentManagerTests {
    /// A document whose server could not start was never opened by any
    /// server, so it must not be tracked as open (later didChanges would be
    /// sent for it).
    @Test @MainActor func failedServerStartLeavesTheDocumentClosed() async throws {
        let registry = LSPClientRegistry { await LSPClient.createAndSetup() }
        registry.workspaceRoot = URL(fileURLWithPath: "/tmp")
        let manager = LSPDocumentManager(clientRegistry: registry)

        try await manager.openDocument(filePath: "/tmp/a.zz", content: "a", languageId: "no-such-language")

        #expect(manager.getDocument(for: "/tmp/a.zz") == nil)
    }
}
