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
    /// - Parameters:
    ///   - configuration: Unified server configuration
    ///   - language: The language to use for LSP communication
    public func connect(configuration: LSPServerConfiguration, language: Language) async throws {
        // Create appropriate transport based on configuration
        let transport = try await configuration.createTransport()
        self.transport = transport
        
        // Extract base configuration
        let baseConfig: ServerConfiguration
        switch configuration {
        case .local(let localConfig):
            baseConfig = ServerConfiguration(
                languageId: language.lspIdentifier,
                serverPath: localConfig.executablePath,
                workspaceRoot: localConfig.workingDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                serverArguments: localConfig.arguments
            )

        case .remote(let remoteConfig):
            baseConfig = ServerConfiguration(
                languageId: language.lspIdentifier,
                serverPath: remoteConfig.serverURL.absoluteString,
                workspaceRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                serverArguments: []
            )
        }
        
        // Connect using the base implementation
        try await connect(configuration: baseConfig)
    }
}
