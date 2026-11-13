import CodeEditorDiagnostics
import CodeEditorLSP
import Foundation
import Testing

/// A memory cleanup pass is routine: the monitor runs one whenever the host
/// process is over its threshold. The language servers, their
/// configurations and the open documents are live state, not caches.
@MainActor
@Suite("LSPManager through a memory cleanup pass")
struct LSPManagerMemoryCleanupTests {
    @Test("a pass keeps the server configurations and their file extensions")
    func aPassKeepsConfigurations() async throws {
        let monitor = MemoryMonitor.mock()
        let manager = LSPManager(memoryMonitor: monitor, workspaceRoot: nil)
        let url = try #require(URL(string: "wss://lsp.example.com/swift"))
        manager.registerLanguageServer(.remote(
            languageId: "swift",
            url: url,
            fileExtensions: ["swift"],
            autoStart: false
        ))
        let configurations = Set(manager.serverConfigurations.keys)

        await monitor.performCleanup()

        #expect(Set(manager.serverConfigurations.keys) == configurations)
        #expect(manager.serverConfigurations["swift"] != nil)
        #expect(manager.languageId(for: "swift") == "swift")
    }
}
