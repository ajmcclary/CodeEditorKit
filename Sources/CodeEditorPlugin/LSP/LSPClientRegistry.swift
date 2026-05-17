import CodeEditorCommon
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

    /// Path resolver for finding language server executables (macOS only — iOS apps are sandboxed).
    #if canImport(AppKit)
    private let pathResolver = LSPPathResolver()
    #endif

    /// Test-only client factory. Production uses `LSPClient.createAndSetup()`.
    private let clientFactory: @MainActor () async -> LSPClient

    // MARK: - Initialization

    init() {
        self.clientFactory = { await LSPClient.createAndSetup() }
        setupDefaultConfigurations()
        rebuildExtensionCache()
    }

    /// Test initializer — substitute the client factory.
    init(clientFactory: @escaping @MainActor () async -> LSPClient) {
        self.clientFactory = clientFactory
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
                do {
                    try await startLanguageServer(for: config.languageId, retryConfig: config.retryConfiguration)
                } catch {
                    logger.error("Failed to auto-start LSP server for \(config.languageId): \(error.localizedDescription)")
                }
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

    /// Start a language server for the given language with retry support
    /// - Parameters:
    ///   - languageId: Language identifier
    ///   - retryConfig: Retry configuration (defaults to nil, which uses the server's configured retry settings)
    func startLanguageServer(
        for languageId: String,
        retryConfig: LSPRetryConfiguration? = nil
    ) async throws {
        guard let config = serverConfigurations[languageId] else {
            throw LSPError.invalidResponse("No configuration found for language: \(languageId)")
        }

        // Use provided retry config or fall back to the server's configured retry settings
        let effectiveRetryConfig = retryConfig ?? config.retryConfiguration

        // Remote configs don't need a workspace root (WebSocket transport ignores it).
        // Local configs require one — Process needs a working directory.
        let effectiveWorkspaceRoot: URL
        if config.remoteURL != nil {
            effectiveWorkspaceRoot = workspaceRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        } else {
            guard let root = workspaceRoot else {
                throw LSPError.invalidResponse("No workspace root set")
            }
            effectiveWorkspaceRoot = root
        }

        // Don't start if already running
        if activeClients[languageId] != nil {
            return
        }

        logger.info("Starting LSP server for \(languageId)")

        // Resolve the executable path on macOS for local-shaped configs.
        // Remote-shaped configs and iOS short-circuit (no resolver).
        let resolvedConfig: LanguageServerConfig
        #if canImport(AppKit)
        if config.remoteURL == nil, config.enablePathResolution {
            guard let resolved = pathResolver.resolvePath(config.serverPath) else {
                throw LSPError.invalidResponse("Language server executable not found: \(config.serverPath)")
            }
            logger.debug("Resolved server path for \(languageId): \(config.serverPath) -> \(resolved)")
            resolvedConfig = LanguageServerConfig.local(
                languageId: config.languageId,
                serverPath: resolved,
                fileExtensions: config.fileExtensions,
                serverArguments: config.serverArguments,
                capabilities: config.capabilities,
                autoStart: config.autoStart,
                enablePathResolution: false,
                retryConfiguration: config.retryConfiguration
            )
        } else {
            resolvedConfig = config
        }
        #else
        resolvedConfig = config
        #endif

        let client = await clientFactory()
        let serverConfig = try resolvedConfig.makeServerConfiguration(workspaceRoot: effectiveWorkspaceRoot)

        // Attempt connection with retry logic
        var lastError: Error?

        for attempt in 0...effectiveRetryConfig.maxRetries {
            do {
                try await client.connect(configuration: serverConfig, languageId: languageId)
                activeClients[languageId] = client
                logger.info("Successfully started LSP server for \(languageId) on attempt \(attempt + 1)")
                return
            } catch {
                lastError = error

                if attempt < effectiveRetryConfig.maxRetries {
                    let delay = effectiveRetryConfig.delay(for: attempt)
                    logger.warning("Failed to start LSP server for \(languageId) on attempt \(attempt + 1)/\(effectiveRetryConfig.maxRetries + 1). Retrying in \(String(format: "%.1f", delay))s. Error: \(error.localizedDescription)")

                    // Wait before retrying
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                    // Reset client state for retry
                    client.disconnect()
                } else {
                    logger.error("Failed to start LSP server for \(languageId) after \(effectiveRetryConfig.maxRetries + 1) attempts. Error: \(error.localizedDescription)")
                }
            }
        }

        // Throw the last error if all retries failed
        throw lastError ?? LSPError.serverError(code: -1, message: "Failed to start LSP server after retries", data: nil)
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
    /// - Parameter retryConfig: Retry configuration for restarting servers
    func restartAllClients(retryConfig: LSPRetryConfiguration = .default) async {
        let clientsToRestart = Array(activeClients.keys)

        // Stop all clients
        for languageId in clientsToRestart {
            stopLanguageServer(for: languageId)
        }

        // Restart clients that should auto-start
        for languageId in clientsToRestart {
            if let config = serverConfigurations[languageId], config.autoStart {
                do {
                    try await startLanguageServer(for: languageId, retryConfig: retryConfig)
                } catch {
                    logger.error("Failed to restart LSP server for \(languageId): \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Language Server Availability

    /// Check if a language server is available for the given configuration.
    /// Remote configs are "available" iff they carry a URL.
    /// Local configs require AppKit; on iOS they always return false.
    func isLanguageServerAvailable(_ config: LanguageServerConfig) -> Bool {
        if config.remoteURL != nil {
            return true
        }
        #if canImport(AppKit)
        if config.enablePathResolution {
            return pathResolver.isAvailable(config.serverPath)
        }
        return FileManager.default.fileExists(atPath: config.serverPath)
        #else
        return false
        #endif
    }

    /// Get all available paths for a language server executable.
    /// macOS-only — iOS returns an empty array (no executable resolution under sandbox).
    func findLanguageServerPaths(for executableName: String) -> [String] {
        #if canImport(AppKit)
        return pathResolver.findAllPaths(for: executableName)
        #else
        _ = executableName
        return []
        #endif
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

    /// Resolve the actual path that would be used for a language server.
    /// macOS-only for local configs. Returns the remote URL string for remote configs.
    /// Returns nil for local configs on iOS.
    func resolveLanguageServerPath(_ config: LanguageServerConfig) -> String? {
        if let url = config.remoteURL {
            return url.absoluteString
        }
        #if canImport(AppKit)
        if config.enablePathResolution {
            return pathResolver.resolvePath(config.serverPath)
        }
        return FileManager.default.fileExists(atPath: config.serverPath) ? config.serverPath : nil
        #else
        return nil
        #endif
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

// MARK: - Language Enum Extensions

extension LSPClientRegistry {
    /// Register a language server configuration using Language enum
    /// - Parameters:
    ///   - language: The Language enum case
    ///   - serverPath: Path to the language server executable
    ///   - serverArguments: Command line arguments for the server
    ///   - fileExtensions: File extensions associated with this language
    ///   - capabilities: Client capabilities
    ///   - autoStart: Whether to auto-start the server
    ///   - enablePathResolution: Whether to enable path resolution
    func registerLanguageServer(
        for language: Language,
        serverPath: String,
        serverArguments: [String] = [],
        fileExtensions: [String] = [],
        capabilities: ClientCapabilities = ClientCapabilities(),
        autoStart: Bool = false,
        enablePathResolution: Bool = true
    ) {
        let config = LanguageServerConfig(
            languageId: language.lspIdentifier,
            serverPath: serverPath,
            fileExtensions: fileExtensions,
            serverArguments: serverArguments,
            capabilities: capabilities,
            autoStart: autoStart,
            enablePathResolution: enablePathResolution
        )
        registerLanguageServer(config)
    }

    /// Start a language server for the given language
    /// - Parameters:
    ///   - language: Language enum case
    ///   - retryConfig: Retry configuration (defaults to standard retry settings)
    func startLanguageServer(for language: Language, retryConfig: LSPRetryConfiguration = .default) async throws {
        try await startLanguageServer(for: language.lspIdentifier, retryConfig: retryConfig)
    }

    /// Stop a language server for the given language
    /// - Parameter language: Language enum case
    func stopLanguageServer(for language: Language) {
        stopLanguageServer(for: language.lspIdentifier)
    }

    /// Get LSP client for a language
    /// - Parameter language: Language enum case
    /// - Returns: LSP client if available
    func client(for language: Language) -> LSPClient? {
        client(for: language.lspIdentifier)
    }

    /// Get language from file URL using Language enum
    /// - Parameter fileURL: File URL to check
    /// - Returns: Language if detected, nil otherwise
    func language(for fileURL: URL) -> Language? {
        guard let languageId = languageId(for: fileURL.path) else { return nil }

        // Map LSP language IDs back to Language enum cases
        switch languageId {
        case "swift": return .swift

        case "typescript", "javascript":
            // Check file extension to distinguish between JS and TS
            let ext = fileURL.pathExtension.lowercased()
            return (ext == "ts" || ext == "tsx") ? .typescript : .javascript

        case "python": return .python
        case "go": return .go
        case "rust": return .rust
        case "c": return .c
        case "cpp": return .cpp
        case "java": return .java
        case "html": return .html
        case "css": return .css
        case "json": return .json
        case "markdown": return .markdown
        case "yaml": return .yaml
        case "xml": return .xml
        case "sql": return .sql
        case "ruby": return .ruby
        case "php": return .php
        case "shellscript": return .shell
        default: return .plainText
        }
    }
}
