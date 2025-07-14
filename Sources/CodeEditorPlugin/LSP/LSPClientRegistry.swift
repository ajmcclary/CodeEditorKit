#if canImport(AppKit) && !targetEnvironment(macCatalyst)
// LSP functionality is only available on macOS

import Foundation

/// Manages the lifecycle of LSP clients and language server operations
@MainActor
final class LSPClientRegistry {
    // MARK: - State
    
    /// Active LSP clients by language ID
    private(set) var activeClients: [String: LSPClient] = [:]
    
    /// Registered language server configurations
    private(set) var serverConfigurations: [String: LanguageServerConfig] = [:]
    
    /// Cached extension to language ID mappings for performance
    private var extensionToLanguageIdCache: [String: String] = [:]
    
    /// Current workspace root
    var workspaceRoot: URL?
    
    /// Logger for debugging
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.lsp", category: "LSPClientRegistry")
    
    /// Path resolver for finding language server executables
    private let pathResolver = LSPPathResolver()
    
    // MARK: - Initialization
    
    init() {
        setupDefaultConfigurations()
        rebuildExtensionCache()
    }
    
    // MARK: - Configuration Management
    
    /// Register a language server configuration
    /// - Parameter config: Server configuration
    func registerLanguageServer(_ config: LanguageServerConfig) {
        serverConfigurations[config.languageId] = config
        rebuildExtensionCache()
        logger.info("Registered LSP server for \(config.languageId)")
        
        // Auto-start if configured and we have a workspace
        if config.autoStart, workspaceRoot != nil {
            Task {
                try? await startLanguageServer(for: config.languageId)
            }
        }
    }
    
    /// Unregister a language server configuration
    /// - Parameter languageId: Language identifier
    func unregisterLanguageServer(for languageId: String) {
        // Stop client if running
        if let client = activeClients.removeValue(forKey: languageId) {
            client.disconnect()
        }
        
        serverConfigurations.removeValue(forKey: languageId)
        rebuildExtensionCache()
        logger.info("Unregistered LSP server for \(languageId)")
    }
    
    /// Get language ID for a file extension
    /// - Parameter fileExtension: File extension (with or without dot)
    /// - Returns: Language ID if found
    func languageId(for fileExtension: String) -> String? {
        let ext = fileExtension.hasPrefix(".") ? fileExtension : ".\(fileExtension)"
        return extensionToLanguageIdCache[ext]
    }
    
    // MARK: - Client Management
    
    /// Start a language server for the given language
    /// - Parameter languageId: Language identifier
    func startLanguageServer(for languageId: String) async throws {
        guard let config = serverConfigurations[languageId] else {
            throw LSPError.invalidResponse("No configuration found for language: \(languageId)")
        }
        
        guard let workspaceRoot else {
            throw LSPError.invalidResponse("No workspace root set")
        }
        
        // Don't start if already running
        if activeClients[languageId] != nil {
            return
        }
        
        logger.info("Starting LSP server for \(languageId)")
        
        // Resolve the server path if path resolution is enabled
        let resolvedServerPath: String
        if config.enablePathResolution {
            guard let resolved = pathResolver.resolvePath(config.serverPath) else {
                throw LSPError.invalidResponse("Language server executable not found: \(config.serverPath)")
            }
            resolvedServerPath = resolved
            logger.debug("Resolved server path for \(languageId): \(config.serverPath) -> \(resolvedServerPath)")
        } else {
            resolvedServerPath = config.serverPath
        }
        
        let client = LSPClient()
        let serverConfig = LSPClient.ServerConfiguration(
            languageId: languageId,
            serverPath: resolvedServerPath,
            workspaceRoot: workspaceRoot,
            serverArguments: config.serverArguments,
            capabilities: config.capabilities
        )
        
        try await client.connect(configuration: serverConfig)
        activeClients[languageId] = client
        
        logger.info("Successfully started LSP server for \(languageId)")
    }
    
    /// Stop a language server
    /// - Parameter languageId: Language identifier
    func stopLanguageServer(for languageId: String) {
        guard let client = activeClients.removeValue(forKey: languageId) else {
            return
        }
        
        logger.info("Stopping LSP server for \(languageId)")
        client.disconnect()
    }
    
    /// Stop all running language servers
    func stopAllServers() {
        let clientsToStop = Array(activeClients.keys)
        for languageId in clientsToStop {
            stopLanguageServer(for: languageId)
        }
    }
    
    /// Get LSP client for a language
    /// - Parameter languageId: Language identifier
    /// - Returns: LSP client if available
    func client(for languageId: String) -> LSPClient? {
        activeClients[languageId]
    }
    
    /// Restart all clients (used when workspace root changes)
    func restartAllClients() async {
        let clientsToRestart = Array(activeClients.keys)
        
        // Stop all clients
        for languageId in clientsToRestart {
            stopLanguageServer(for: languageId)
        }
        
        // Restart clients that should auto-start
        for languageId in clientsToRestart {
            if let config = serverConfigurations[languageId], config.autoStart {
                try? await startLanguageServer(for: languageId)
            }
        }
    }
    
    // MARK: - Language Server Availability
    
    /// Check if a language server is available for the given configuration
    /// - Parameter config: Language server configuration to check
    /// - Returns: True if the server executable can be found
    func isLanguageServerAvailable(_ config: LanguageServerConfig) -> Bool {
        if config.enablePathResolution {
            return pathResolver.isAvailable(config.serverPath)
        } else {
            return FileManager.default.fileExists(atPath: config.serverPath)
        }
    }
    
    /// Get all available paths for a language server executable
    /// - Parameter executableName: Name of the executable (e.g., "typescript-language-server")
    /// - Returns: Array of absolute paths where the executable was found
    func findLanguageServerPaths(for executableName: String) -> [String] {
        pathResolver.findAllPaths(for: executableName)
    }
    
    /// Get availability status for all configured language servers
    /// - Returns: Dictionary mapping language IDs to availability status
    func getLanguageServerAvailability() -> [String: Bool] {
        var availability: [String: Bool] = [:]
        
        for (languageId, config) in serverConfigurations {
            availability[languageId] = isLanguageServerAvailable(config)
        }
        
        return availability
    }
    
    /// Resolve the actual path that would be used for a language server
    /// - Parameter config: Language server configuration
    /// - Returns: The resolved absolute path, or nil if not found
    func resolveLanguageServerPath(_ config: LanguageServerConfig) -> String? {
        if config.enablePathResolution {
            return pathResolver.resolvePath(config.serverPath)
        } else {
            return FileManager.default.fileExists(atPath: config.serverPath) ? config.serverPath : nil
        }
    }
    
    /// Cleanup all resources
    func cleanup() {
        // Disconnect all clients
        for client in activeClients.values {
            client.disconnect()
        }
        activeClients.removeAll()
        
        // Clear extension cache
        extensionToLanguageIdCache.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// Rebuild the extension to language ID cache for fast lookups
    private func rebuildExtensionCache() {
        extensionToLanguageIdCache.removeAll()
        
        for (languageId, config) in serverConfigurations {
            for fileExtension in config.fileExtensions {
                let normalizedExt = fileExtension.hasPrefix(".") ? fileExtension : ".\(fileExtension)"
                // If there's a conflict, the first registered language wins
                if extensionToLanguageIdCache[normalizedExt] == nil {
                    extensionToLanguageIdCache[normalizedExt] = languageId
                }
            }
        }
        
        logger.debug("Rebuilt extension cache with \(extensionToLanguageIdCache.count) mappings")
    }
    
    private func setupDefaultConfigurations() {
        // Add common language server configurations with executable names
        // These will be resolved automatically using PATH and common install locations
        // Override with environment variables: LSP_<EXECUTABLE>_PATH
        
        // TypeScript/JavaScript (requires typescript-language-server)
        // Install: npm install -g typescript-language-server
        registerLanguageServer(LanguageServerConfig(
            languageId: "typescript",
            serverPath: "typescript-language-server",
            fileExtensions: [".ts", ".tsx", ".js", ".jsx"],
            serverArguments: ["--stdio"],
            enablePathResolution: true
        ))
        
        // Python (requires pylsp - Python LSP Server)
        // Install: pip install python-lsp-server
        registerLanguageServer(LanguageServerConfig(
            languageId: "python",
            serverPath: "pylsp",
            fileExtensions: [".py"],
            serverArguments: [],
            enablePathResolution: true
        ))
        
        // Rust (requires rust-analyzer)
        // Install: rustup component add rust-analyzer
        registerLanguageServer(LanguageServerConfig(
            languageId: "rust",
            serverPath: "rust-analyzer",
            fileExtensions: [".rs"],
            serverArguments: [],
            enablePathResolution: true
        ))
        
        // Go (requires gopls)
        // Install: go install golang.org/x/tools/gopls@latest
        registerLanguageServer(LanguageServerConfig(
            languageId: "go",
            serverPath: "gopls",
            fileExtensions: [".go"],
            serverArguments: [],
            enablePathResolution: true
        ))
        
        // Swift (requires sourcekit-lsp, typically bundled with Xcode)
        // Available at: /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp
        registerLanguageServer(LanguageServerConfig(
            languageId: "swift",
            serverPath: "sourcekit-lsp",
            fileExtensions: [".swift"],
            serverArguments: [],
            enablePathResolution: true
        ))
    }
}

#endif // canImport(AppKit) && !targetEnvironment(macCatalyst)
