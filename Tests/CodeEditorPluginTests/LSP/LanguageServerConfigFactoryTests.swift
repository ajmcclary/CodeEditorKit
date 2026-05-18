@testable import CodeEditorLSP
@testable import CodeEditorPlugin
@testable import CodeEditorView
import Foundation
import Testing

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

        #expect(config.serverPath.isEmpty)
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

    @Test("`makeServerConfiguration` on `.remote` returns `.remote(_)` regardless of platform")
    func makeServerConfigurationRemoteShape() throws {
        let url = try #require(URL(string: "wss://lsp.example.com/swift"))
        let config = LanguageServerConfig.remote(
            languageId: "swift",
            url: url,
            fileExtensions: ["swift"],
            authentication: .bearerToken("xyz")
        )

        let server = try config.makeServerConfiguration(
            workspaceRoot: URL(fileURLWithPath: "/tmp")
        )

        guard case .remote(let remote) = server else {
            Issue.record("Expected .remote, got \(server)")
            return
        }
        #expect(remote.serverURL == url)
        if case .bearerToken(let token) = remote.authentication {
            #expect(token == "xyz")
        } else {
            Issue.record("Expected bearer-token authentication on the translated remote config")
        }
    }

    #if canImport(AppKit)
    @Test("`makeServerConfiguration` on `.local` returns `.local(_)` on macOS")
    func makeServerConfigurationLocalShapeOnMac() throws {
        let config = LanguageServerConfig.local(
            languageId: "swift",
            serverPath: "/usr/bin/sourcekit-lsp",
            fileExtensions: ["swift"],
            serverArguments: ["--log-file", "/tmp/x.log"]
        )

        let server = try config.makeServerConfiguration(
            workspaceRoot: URL(fileURLWithPath: "/tmp")
        )

        guard case .local(let local) = server else {
            Issue.record("Expected .local, got \(server)")
            return
        }
        #expect(local.executablePath == "/usr/bin/sourcekit-lsp")
        #expect(local.arguments == ["--log-file", "/tmp/x.log"])
        #expect(local.workingDirectory == URL(fileURLWithPath: "/tmp"))
    }
    #else
    @Test("`makeServerConfiguration` on `.local` throws on iOS")
    func makeServerConfigurationLocalThrowsOnIOS() {
        let config = LanguageServerConfig.local(
            languageId: "swift",
            serverPath: "/usr/bin/sourcekit-lsp",
            fileExtensions: ["swift"]
        )

        do {
            _ = try config.makeServerConfiguration(
                workspaceRoot: URL(fileURLWithPath: "/tmp")
            )
            Issue.record("Expected throw; got success")
        } catch let error as LSPError {
            if case .serverError(_, let message, _) = error {
                #expect(message.contains("AppKit") || message.contains("remote"))
            } else {
                Issue.record("Expected LSPError.serverError, got \(error)")
            }
        } catch {
            Issue.record("Expected LSPError, got \(error)")
        }
    }
    #endif
}
