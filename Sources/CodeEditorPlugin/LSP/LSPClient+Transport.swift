import Foundation

/// Extension to LSPClient that adds transport-based initialization
/// This allows LSPClient to work on all platforms, not just macOS
@available(macOS 10.15, iOS 13.0, *)
extension LSPClient {
    /// Initialize LSPClient with a specific transport
    /// - Parameter transport: The transport to use for communication
    public convenience init(transport: LSPTransport) {
        self.init()
        self.transport = transport
    }
    
    /// Connect using server configuration that automatically selects appropriate transport
    /// - Parameter configuration: Unified server configuration
    public func connect(configuration: LSPServerConfiguration) async throws {
        // Create appropriate transport based on configuration
        let transport = try await configuration.createTransport()
        self.transport = transport
        
        // Extract base configuration
        let baseConfig: ServerConfiguration
        switch configuration {
        case .local(let localConfig):
            baseConfig = ServerConfiguration(
                languageId: "swift", // TODO: Make this configurable
                serverPath: localConfig.executablePath,
                workspaceRoot: localConfig.workingDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                serverArguments: localConfig.arguments
            )

        case .remote(let remoteConfig):
            baseConfig = ServerConfiguration(
                languageId: "swift", // TODO: Make this configurable
                serverPath: remoteConfig.serverURL.absoluteString,
                workspaceRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                serverArguments: []
            )
        }
        
        // Connect using the base implementation
        try await connect(configuration: baseConfig)
    }
}
