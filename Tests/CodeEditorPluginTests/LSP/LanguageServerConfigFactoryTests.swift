import Foundation
import Testing
@testable import CodeEditorPlugin

@Suite("LanguageServerConfig factory invariants")
struct LanguageServerConfigFactoryTests {

    @Test("`.local(...)` factory produces a local-shaped config")
    func localFactoryProducesLocalShape() {
        let config = LanguageServerConfig.local(
            languageId: "swift",
            serverPath: "/usr/bin/sourcekit-lsp",
            fileExtensions: ["swift"]
        )

        #expect(config.serverPath == "/usr/bin/sourcekit-lsp")
        #expect(config.remoteURL == nil)
        #expect(config.languageId == "swift")
        #expect(config.fileExtensions == ["swift"])
    }

    @Test("`.remote(url:)` factory produces a remote-shaped config")
    func remoteFactoryProducesRemoteShape() throws {
        let url = try #require(URL(string: "wss://lsp.example.com/swift"))
        let config = LanguageServerConfig.remote(
            languageId: "swift",
            url: url,
            fileExtensions: ["swift"]
        )

        #expect(config.serverPath == "")
        #expect(config.remoteURL == url)
        #expect(config.remoteHeaders.isEmpty)
        #expect(config.remoteAuthentication == nil)
        #expect(config.languageId == "swift")
    }

    @Test("Existing positional init still produces a local-shaped config (source compat)")
    func positionalInitIsLocalShaped() {
        let config = LanguageServerConfig(
            languageId: "python",
            serverPath: "/usr/local/bin/pylsp",
            fileExtensions: ["py", "pyw"]
        )

        #expect(config.serverPath == "/usr/local/bin/pylsp")
        #expect(config.remoteURL == nil)
        #expect(config.languageId == "python")
    }

    @Test("`.remote(...)` factory preserves auth, headers, and transport overrides")
    func remoteFactoryPreservesOptionalFields() throws {
        let url = try #require(URL(string: "wss://lsp.example.com/swift"))
        let transport = LSPTransportConfiguration(autoReconnect: false, maxReconnectAttempts: 1, reconnectDelay: 0.5)
        let config = LanguageServerConfig.remote(
            languageId: "swift",
            url: url,
            fileExtensions: ["swift"],
            headers: ["X-Test": "1"],
            authentication: .bearerToken("xyz"),
            transportConfiguration: transport
        )

        #expect(config.remoteHeaders == ["X-Test": "1"])
        if case .bearerToken(let token) = config.remoteAuthentication {
            #expect(token == "xyz")
        } else {
            Issue.record("Expected .bearerToken authentication, got \(String(describing: config.remoteAuthentication))")
        }
        #expect(config.remoteTransportConfiguration?.autoReconnect == false)
    }
}
