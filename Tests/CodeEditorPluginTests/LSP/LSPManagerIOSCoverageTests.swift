#if !canImport(AppKit)
@testable import CodeEditorPlugin
import Foundation
import Testing

@Suite("LSP types instantiate on iOS")
@MainActor
struct LSPManagerIOSCoverageTests {
    @Test("LSPManager initializes on iOS")
    func lspManagerInitializesOnIOS() {
        let memoryMonitor = MemoryMonitor.mock()
        let manager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: nil)
        #expect(manager.activeClients.isEmpty)
    }

    @Test("registerLanguageServer(.remote) stores config on iOS")
    func remoteRegistrationOnIOS() throws {
        let memoryMonitor = MemoryMonitor.mock()
        let manager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: nil)
        let url = try #require(URL(string: "wss://lsp.example.com/swift"))
        manager.registerLanguageServer(.remote(
            languageId: "swift",
            url: url,
            fileExtensions: ["swift"],
            autoStart: false
        ))
        #expect(manager.serverConfigurations["swift"] != nil)
    }

    @Test("startLanguageServer with a .local config throws on iOS")
    func localStartThrowsOnIOS() async {
        let memoryMonitor = MemoryMonitor.mock()
        let manager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: nil)
        manager.registerLanguageServer(.local(
            languageId: "swift",
            serverPath: "/usr/bin/sourcekit-lsp",
            fileExtensions: ["swift"],
            autoStart: false,
            enablePathResolution: false
        ))

        do {
            try await manager.startLanguageServer(for: "swift")
            Issue.record("Expected throw on iOS for .local config")
        } catch let error as LSPError {
            if case .serverError(_, let message, _) = error {
                #expect(message.contains("AppKit") || message.contains("remote"))
            } else {
                Issue.record("Expected .serverError, got \(error)")
            }
        } catch {
            Issue.record("Expected LSPError, got \(error)")
        }
    }

    @Test("LSPCompletionProvider initializes on iOS")
    func completionProviderInitializesOnIOS() {
        let memoryMonitor = MemoryMonitor.mock()
        let manager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: nil)
        let provider = LSPCompletionProvider(lspManager: manager, supportedLanguages: [.swift])
        #expect(provider.supportedLanguages == [.swift])
    }

    @Test("LSPSemanticTokenProvider initializes on iOS")
    func semanticTokenProviderInitializesOnIOS() {
        let memoryMonitor = MemoryMonitor.mock()
        let manager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: nil)
        let provider = LSPSemanticTokenProvider(lspManager: manager, filePath: "/tmp/x.swift")
        _ = provider    // smoke test only — initializes without crashing
    }
}
#endif
