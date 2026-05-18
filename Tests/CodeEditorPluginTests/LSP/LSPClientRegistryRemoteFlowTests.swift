@testable import CodeEditorLSP
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import Foundation
import XCTest

/// Verifies LSPClientRegistry's migration off the process-only legacy connect path.
///
/// The registry now translates a LanguageServerConfig to a transport-typed
/// LSPServerConfiguration via `config.makeServerConfiguration(workspaceRoot:)`
/// before calling `client.connect(configuration:, languageId:)`. We inject a
/// recording client so we can assert the payload shape without spinning up a
/// real WebSocket or Process.
@MainActor
final class LSPClientRegistryRemoteFlowTests: XCTestCase {
    func testRemoteConfigRoutesToRemotePayload() async throws {
        let url = try XCTUnwrap(URL(string: "wss://lsp.example.com/swift"))
        let recordedConfig = LSPClientRegistryRemoteFlowRecorder()
        let registry = LSPClientRegistry(clientFactory: recordedConfig.makeRecordingClient)
        registry.workspaceRoot = URL(fileURLWithPath: "/tmp/ws")

        let remote = LanguageServerConfig.remote(
            languageId: "swift",
            url: url,
            fileExtensions: ["swift"],
            authentication: .bearerToken("xyz"),
            autoStart: false
        )
        registry.registerLanguageServer(remote)

        try await registry.startLanguageServer(for: "swift")

        let snapshot = await recordedConfig.snapshot()
        let lastConfig = try XCTUnwrap(snapshot.configuration)
        guard case .remote(let payload) = lastConfig else {
            XCTFail("Expected .remote payload, got \(lastConfig)")
            return
        }
        XCTAssertEqual(payload.serverURL, url)
        XCTAssertEqual(snapshot.languageId, "swift")
    }

    #if canImport(AppKit)
    func testLocalConfigRoutesToLocalPayloadOnMac() async throws {
        let recordedConfig = LSPClientRegistryRemoteFlowRecorder()
        let registry = LSPClientRegistry(clientFactory: recordedConfig.makeRecordingClient)
        registry.workspaceRoot = URL(fileURLWithPath: "/tmp/ws")

        let local = LanguageServerConfig.local(
            languageId: "swift",
            serverPath: "/usr/bin/sourcekit-lsp",
            fileExtensions: ["swift"],
            autoStart: false,
            enablePathResolution: false    // Skip resolver — /usr/bin/sourcekit-lsp may not exist on CI.
        )
        registry.registerLanguageServer(local)

        try await registry.startLanguageServer(for: "swift")

        let snapshot = await recordedConfig.snapshot()
        let lastConfig = try XCTUnwrap(snapshot.configuration)
        guard case .local(let payload) = lastConfig else {
            XCTFail("Expected .local payload, got \(lastConfig)")
            return
        }
        XCTAssertEqual(payload.executablePath, "/usr/bin/sourcekit-lsp")
    }
    #endif
}

/// Records the configuration last passed to `connect(configuration:, languageId:)`.
/// Lives at file scope so the registry's client-factory closure can capture it.
actor LSPClientRegistryRemoteFlowRecorder {
    struct Snapshot: Sendable {
        let configuration: LSPServerConfiguration?
        let languageId: String?
    }

    private var lastConfiguration: LSPServerConfiguration?
    private var lastLanguageId: String?

    @MainActor
    func makeRecordingClient() async -> LSPClient {
        let client = await LSPClient.createAndSetup()
        client.recordingHandler = { [weak self] config, languageId in
            await self?.record(configuration: config, languageId: languageId)
        }
        return client
    }

    func snapshot() -> Snapshot {
        Snapshot(configuration: lastConfiguration, languageId: lastLanguageId)
    }

    func record(configuration: LSPServerConfiguration, languageId: String) {
        self.lastConfiguration = configuration
        self.lastLanguageId = languageId
    }
}
