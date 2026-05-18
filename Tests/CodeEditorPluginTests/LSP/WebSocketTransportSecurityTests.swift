import CodeEditorLSP
@testable import CodeEditorPlugin
@testable import CodeEditorView
import Foundation
import Testing

/// Regression: `WebSocketTransport.connect()` used to construct
/// `URLSessionConfiguration.default` and a delegate-less `URLSession`,
/// silently dropping `RemoteLSPConfiguration.securityOptions` and
/// `certificatePinning` (REVIEW.md LSP/Critical).
@Suite("WebSocketTransport security plumbing")
struct WebSocketTransportSecurityTests {
    @Test("makeURLSessionConfiguration maps minimum TLS 1.3 from security options")
    func minTLS13Mapping() {
        let config = WebSocketTransport.makeURLSessionConfiguration(
            transport: LSPTransportConfiguration(),
            security: SecurityOptions(minimumTLSVersion: .tls13)
        )
        #expect(config.tlsMinimumSupportedProtocolVersion == .TLSv13)
    }

    @Test("makeURLSessionConfiguration defaults to TLS 1.2 minimum")
    func minTLS12Default() {
        let config = WebSocketTransport.makeURLSessionConfiguration(
            transport: LSPTransportConfiguration(),
            security: SecurityOptions()
        )
        #expect(config.tlsMinimumSupportedProtocolVersion == .TLSv12)
    }

    @Test("createTransport forwards enterprise security config to WebSocketTransport")
    func enterpriseSecurityForwarded() async throws {
        let url = try #require(URL(string: "wss://lsp.example.com/swift"))
        let remoteConfig = RemoteLSPConfiguration.enterpriseServer(
            url: url,
            authentication: .bearerToken("test"),
            pinnedPublicKeys: [Data([0x01, 0x02, 0x03])]
        )
        let serverConfig = LSPServerConfiguration.remote(remoteConfig)
        let transport = try await serverConfig.createTransport()
        let ws = try #require(transport as? WebSocketTransport)
        let snapshot = await ws.securityConfigurationSnapshot()
        #expect(snapshot.minimumTLSVersion == .tls13)
        #expect(snapshot.pinningMethod == .publicKey)
        #expect(snapshot.pinnedDataCount == 1)
        #expect(snapshot.validateSSLCertificates == true)
    }

    @Test("createTransport defaults to validate=true with no pinning for publicServer")
    func publicServerDefaults() async throws {
        let url = try #require(URL(string: "wss://lsp.example.com/swift"))
        let remoteConfig = RemoteLSPConfiguration.publicServer(url: url)
        let serverConfig = LSPServerConfiguration.remote(remoteConfig)
        let transport = try await serverConfig.createTransport()
        let ws = try #require(transport as? WebSocketTransport)
        let snapshot = await ws.securityConfigurationSnapshot()
        #expect(snapshot.minimumTLSVersion == .tls12)
        #expect(snapshot.pinningMethod == nil)
        #expect(snapshot.pinnedDataCount == 0)
        #expect(snapshot.validateSSLCertificates == true)
    }
}
