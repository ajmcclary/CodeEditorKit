@testable import CodeEditorLSP
import Foundation
import Testing

@Suite("WebSocketTransport lifecycle")
struct WebSocketTransportLifecycleTests {
    /// Nothing listens on the discard port: the task is `.running` right
    /// after `resume()`, which must not count as connected.
    @Test func connectToANonListeningEndpointFails() async throws {
        let url = try #require(URL(string: "ws://127.0.0.1:9/lsp"))
        let transport = WebSocketTransport(
            url: url,
            configuration: LSPTransportConfiguration(connectionTimeout: 3, autoReconnect: false)
        )
        await #expect(throws: LSPTransportError.self) {
            try await transport.connect()
        }
        #expect(await !transport.isConnected)
        await transport.disconnect()
    }

    /// Sends while disconnected are refused, not queued without bound for a
    /// server that will not have been re-initialised.
    @Test func sendWhileDisconnectedIsRefused() async throws {
        let url = try #require(URL(string: "ws://127.0.0.1:9/lsp"))
        let transport = WebSocketTransport(url: url)
        await #expect(throws: LSPTransportError.self) {
            try await transport.send(Data("{}".utf8))
        }
        await transport.disconnect()
    }
}
