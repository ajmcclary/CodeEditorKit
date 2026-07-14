import Foundation
import Testing
@testable import CodeEditorLSP

@Suite struct LSPClientTransportRequiredTests {
    /// The legacy connect overload no longer falls back to spawning a
    /// server process: with no transport configured it throws
    /// `LSPError.transportNotConfigured` (all platforms). Local servers are
    /// reached via `ProcessTransport`, installed by the
    /// `connect(configuration:languageId:)` overload or `init(transport:)`.
    @Test @MainActor func legacyConnectWithoutTransportThrows() async {
        let client = LSPClient()
        let configuration = LSPClient.ServerConfiguration(
            languageId: "swift",
            serverPath: "/usr/bin/true",
            workspaceRoot: URL(fileURLWithPath: "/tmp")
        )
        do {
            try await client.connect(configuration: configuration)
            Issue.record("connect succeeded without a transport")
        } catch let error as LSPError {
            guard case .transportNotConfigured = error else {
                Issue.record("expected .transportNotConfigured, got \(error)")
                return
            }
        } catch {
            Issue.record("expected LSPError.transportNotConfigured, got \(error)")
        }
        client.disconnect()
    }
}
