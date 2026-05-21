import Foundation

/// Extension to LSPClient that adds transport-based initialization.
/// Available on all platforms — the underlying transport (ProcessTransport on macOS,
/// WebSocketTransport everywhere) is selected by `LSPServerConfiguration.createTransport()`.
@available(macOS 10.15, iOS 13.0, *)
extension LSPClient {
    /// Initialize LSPClient with a specific transport.
    /// - Parameter transport: The transport to use for communication.
    public convenience init(transport: LSPTransport) {
        self.init()
        self.transport = transport
    }

    /// Connect using a transport-typed server configuration.
    /// - Parameters:
    ///   - configuration: Unified server configuration (`.local` or `.remote`).
    ///   - languageId: LSP language identifier (e.g. "swift", "python") used during init handshake.
    /// - Throws: Whatever `LSPServerConfiguration.createTransport()` throws
    ///   (e.g. WebSocket / certificate-pinning errors for `.remote`,
    ///   process-spawn errors for `.local`), plus everything
    ///   `connect(configuration: ServerConfiguration)` throws when it runs
    ///   the init handshake. See that method for the LSPError surface.
    public func connect(configuration: LSPServerConfiguration, languageId: String) async throws {
        // Test-only hook (production callers leave this nil).
        if let handler = recordingHandler {
            await handler(configuration, languageId)
            return
        }

        // Create appropriate transport based on configuration.
        let transport = try await configuration.createTransport()
        self.transport = transport

        // Extract a legacy ServerConfiguration so the transport-aware
        // `connect(configuration: ServerConfiguration)` body at LSPClient.swift:138
        // can run the init handshake without changes.
        let baseConfig: ServerConfiguration
        switch configuration {
        case .local(let localConfig):
            baseConfig = ServerConfiguration(
                languageId: languageId,
                serverPath: localConfig.executablePath,
                workspaceRoot: localConfig.workingDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                serverArguments: localConfig.arguments
            )

        case .remote(let remoteConfig):
            baseConfig = ServerConfiguration(
                languageId: languageId,
                serverPath: remoteConfig.serverURL.absoluteString,
                workspaceRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                serverArguments: []
            )
        }

        // Connect using the base implementation. Because `self.transport` is now non-nil,
        // it takes the transport branch and bypasses `processManager.startServerProcess(...)`.
        try await connect(configuration: baseConfig)
    }
}
