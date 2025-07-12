#if canImport(AppKit) && !targetEnvironment(macCatalyst)
// LSP functionality is only available on macOS

import Foundation
#if canImport(Combine)
import Combine
#endif

/// Manages Language Server Protocol (LSP) clients for different programming languages.
///
/// `LSPManager` provides a unified interface for integrating language servers into the code editor.
/// It handles server lifecycle, document synchronization, and request routing for features like
/// code completion, hover information, diagnostics, and more.
///
/// ## Overview
///
/// The manager supports multiple language servers running simultaneously, each handling
/// different file types. It automatically starts and stops servers based on open documents
/// and provides graceful error handling and recovery.
///
/// ## Basic Usage
///
/// ```swift
/// let lspManager = LSPManager(workspaceRoot: projectURL)
///
/// // Configure a language server
/// let swiftConfig = LSPManager.LanguageServerConfig(
///     languageId: "swift",
///     serverPath: "/usr/bin/sourcekit-lsp",
///     fileExtensions: ["swift"]
/// )
/// try await lspManager.registerLanguageServer(config: swiftConfig)
///
/// // Open a document
/// let documentURI = "file:///path/to/file.swift"
/// try await lspManager.openDocument(uri: documentURI, text: sourceCode)
///
/// // Request code completion
/// let completions = try await lspManager.requestCompletion(
///     uri: documentURI,
///     position: Position(line: 10, character: 15)
/// )
/// ```
///
/// ## Supported Features
///
/// - **Document Synchronization**: Open, close, and change notifications
/// - **Code Completion**: Context-aware suggestions with documentation
/// - **Hover Information**: Type information and documentation on hover
/// - **Diagnostics**: Real-time error and warning detection
/// - **Go to Definition**: Navigate to symbol definitions
/// - **Find References**: Locate all usages of a symbol
/// - **Document Symbols**: Outline view of file structure
/// - **Formatting**: Code formatting and range formatting
///
/// ## Language Server Configuration
///
/// Each language server requires configuration including:
/// - Server executable path
/// - Command-line arguments
/// - File extensions to handle
/// - Client capabilities
///
/// ## Error Handling
///
/// The manager provides robust error handling:
/// - Automatic server restart on crash
/// - Request timeout handling
/// - Graceful degradation when servers are unavailable
///
/// - SeeAlso: `LSPClient`, `LanguageServerConfig`, `LSPProtocol`
@available(macOS 10.15, iOS 13.0, *)
@MainActor
public final class LSPManager: ObservableObject {
    // MARK: - Configuration
    
    /// Configuration for a language server.
    ///
    /// Defines how to start and communicate with a language server for a specific
    /// programming language.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = LanguageServerConfig(
    ///     languageId: "python",
    ///     serverPath: "/usr/local/bin/pylsp",
    ///     fileExtensions: ["py", "pyw"],
    ///     serverArguments: ["--log-file", "/tmp/pylsp.log"],
    ///     capabilities: .init(completion: true, hover: true),
    ///     autoStart: true
    /// )
    /// ```
    public struct LanguageServerConfig: Sendable {
        public let languageId: String
        public let serverPath: String
        public let serverArguments: [String]
        public let fileExtensions: [String]
        public let capabilities: ClientCapabilities
        public let autoStart: Bool
        public let enablePathResolution: Bool
        
        public init(
            languageId: String,
            serverPath: String,
            fileExtensions: [String],
            serverArguments: [String] = [],
            capabilities: ClientCapabilities = .default,
            autoStart: Bool = true,
            enablePathResolution: Bool = true
        ) {
            self.languageId = languageId
            self.serverPath = serverPath
            self.serverArguments = serverArguments
            self.fileExtensions = fileExtensions
            self.capabilities = capabilities
            self.autoStart = autoStart
            self.enablePathResolution = enablePathResolution
        }
    }
    
    // MARK: - State
    
    /// Active LSP clients by language ID
    @Published public private(set) var activeClients: [String: LSPClient] = [:]
    
    /// Registered language server configurations
    @Published public private(set) var serverConfigurations: [String: LanguageServerConfig] = [:]
    
    /// Open documents by URI
    private var openDocuments: [String: OpenDocument] = [:]
    
    /// Cached extension to language ID mappings for performance
    private var extensionToLanguageIdCache: [String: String] = [:]
    
    /// Current workspace root
    public var workspaceRoot: URL? {
        didSet {
            if workspaceRoot != oldValue {
                // Restart all clients with new workspace root
                Task {
                    await restartAllClients()
                }
            }
        }
    }
    
    /// Logger for debugging
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.lsp", category: "LSPManager")
    
    /// Path resolver for finding language server executables
    private let pathResolver = LSPPathResolver()
    
    // MARK: - Types
    
    private struct OpenDocument {
        let uri: String
        let languageId: String
        var version: Int
        let filePath: String
        
        mutating func incrementVersion() {
            version += 1
        }
    }
    
    @MainActor
    public struct LSPCompletionItem: CompletionItem {
        public let item: any CompletionItem
        public let languageId: String
        public let client: LSPClient
        
        nonisolated public var id: String { 
            // Generate a unique ID based on item properties
            "\(languageId)-\(UUID().uuidString)"
        }
        
        public var view: PlatformView { item.view }
        
        public init(item: any CompletionItem, languageId: String, client: LSPClient) {
            self.item = item
            self.languageId = languageId
            self.client = client
        }
    }
    
    // MARK: - Initialization
    
    private let memoryMonitor: MemoryMonitor
    
    public init(memoryMonitor: MemoryMonitor, workspaceRoot: URL? = nil) {
        self.workspaceRoot = workspaceRoot
        self.memoryMonitor = memoryMonitor
        setupDefaultConfigurations()
        rebuildExtensionCache() // Build initial cache with default configurations
        
        // Register with memory monitor after initialization
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.memoryMonitor.registerCleanupHandler(
                identifier: "lsp-manager",
                priority: .normal
            ) { @MainActor [weak self] in
                guard let self else {
                    return CleanupResult(memoryFreedMB: 0, description: "LSPManager deallocated")
                }
                
                let beforeClientCount = self.activeClients.count
                let beforeDocumentCount = self.openDocuments.count
                
                // Disconnect all clients
                for client in self.activeClients.values {
                    client.disconnect()
                }
                self.activeClients.removeAll()
                
                // Clear open documents
                self.openDocuments.removeAll()
                
                // Clear extension cache
                let cacheSize = self.extensionToLanguageIdCache.count
                self.extensionToLanguageIdCache.removeAll()
                
                // Estimate memory freed (rough estimate)
                let estimatedMemoryMB = Double(beforeClientCount) * 5.0 + Double(beforeDocumentCount) * 0.1 + Double(cacheSize) * 0.001
                
                return CleanupResult(
                    memoryFreedMB: estimatedMemoryMB,
                    description: "Disconnected \(beforeClientCount) LSP clients, cleared \(beforeDocumentCount) documents, and \(cacheSize) extension mappings"
                )
            }
        }
    }
    
    deinit {
        // Note: Cannot access @MainActor isolated properties in deinit
        // Clients will be automatically cleaned up by ARC
    }
    
    // MARK: - Configuration Management
    
    /// Register a language server configuration
    /// - Parameter config: Server configuration
    public func registerLanguageServer(_ config: LanguageServerConfig) {
        serverConfigurations[config.languageId] = config
        rebuildExtensionCache() // Update cache after adding new configuration
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
    public func unregisterLanguageServer(for languageId: String) {
        // Stop client if running
        if let client = activeClients.removeValue(forKey: languageId) {
            client.disconnect()
        }
        
        serverConfigurations.removeValue(forKey: languageId)
        rebuildExtensionCache() // Update cache after removing configuration
        logger.info("Unregistered LSP server for \(languageId)")
    }
    
    /// Get language ID for a file extension
    /// - Parameter fileExtension: File extension (with or without dot)
    /// - Returns: Language ID if found
    public func languageId(for fileExtension: String) -> String? {
        let ext = fileExtension.hasPrefix(".") ? fileExtension : ".\(fileExtension)"
        
        // Use cached lookup for O(1) performance
        return extensionToLanguageIdCache[ext]
    }
    
    // MARK: - Client Management
    
    /// Start a language server for the given language
    /// - Parameter languageId: Language identifier
    public func startLanguageServer(for languageId: String) async throws {
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
        
        // Reopen any documents for this language
        await reopenDocuments(for: languageId)
        
        logger.info("Successfully started LSP server for \(languageId)")
    }
    
    /// Stop a language server
    /// - Parameter languageId: Language identifier
    public func stopLanguageServer(for languageId: String) {
        guard let client = activeClients.removeValue(forKey: languageId) else {
            return
        }
        
        logger.info("Stopping LSP server for \(languageId)")
        client.disconnect()
    }
    
    /// Stop all running language servers
    public func stopAllServers() {
        let clientsToStop = Array(activeClients.keys)
        for languageId in clientsToStop {
            stopLanguageServer(for: languageId)
        }
    }
    
    /// Get LSP client for a language
    /// - Parameter languageId: Language identifier
    /// - Returns: LSP client if available
    public func client(for languageId: String) -> LSPClient? {
        activeClients[languageId]
    }
    
    // MARK: - Document Management
    
    /// Open a document in the appropriate LSP server
    /// - Parameters:
    ///   - filePath: Path to the file
    ///   - content: File content
    ///   - languageId: Optional language ID (will be inferred from file extension if not provided)
    public func openDocument(
        filePath: String,
        content: String,
        languageId: String? = nil
    ) async throws {
        let uri = "file://\(filePath)"
        let inferredLanguageId = languageId ?? languageIdFromFilePath(filePath)
        
        guard let finalLanguageId = inferredLanguageId else {
            logger.debug("No language server configured for file: \(filePath)")
            return
        }
        
        // Store document info
        let document = OpenDocument(
            uri: uri,
            languageId: finalLanguageId,
            version: 1,
            filePath: filePath
        )
        openDocuments[uri] = document
        
        // Start language server if not running
        if activeClients[finalLanguageId] == nil {
            do {
                try await startLanguageServer(for: finalLanguageId)
            } catch {
                logger.error("Failed to start language server for \(finalLanguageId): \(error.localizedDescription)")
                return
            }
        }
        
        // Open document in LSP server
        if let client = activeClients[finalLanguageId] {
            try await client.openDocument(
                uri: uri,
                languageId: finalLanguageId,
                version: document.version,
                text: content
            )
            
            logger.debug("Opened document in LSP: \(filePath)")
        }
    }
    
    /// Update document content
    /// - Parameters:
    ///   - filePath: Path to the file
    ///   - content: New content
    ///   - changes: Incremental changes (optional, will send full content if not provided)
    public func updateDocument(
        filePath: String,
        content: String,
        changes: [TextDocumentContentChangeEvent] = []
    ) async throws {
        let uri = "file://\(filePath)"
        
        guard var document = openDocuments[uri] else {
            logger.debug("Document not open: \(filePath)")
            return
        }
        
        document.incrementVersion()
        openDocuments[uri] = document
        
        guard let client = activeClients[document.languageId] else {
            logger.debug("No active client for language: \(document.languageId)")
            return
        }
        
        let finalChanges = changes.isEmpty ? [
            TextDocumentContentChangeEvent(text: content)
        ] : changes
        
        try await client.updateDocument(
            uri: uri,
            version: document.version,
            changes: finalChanges
        )
        
        logger.debug("Updated document in LSP: \(filePath)")
    }
    
    /// Close a document
    /// - Parameter filePath: Path to the file
    public func closeDocument(filePath: String) async throws {
        let uri = "file://\(filePath)"
        
        guard let document = openDocuments.removeValue(forKey: uri) else {
            return
        }
        
        guard let client = activeClients[document.languageId] else {
            return
        }
        
        try await client.closeDocument(uri: uri)
        logger.debug("Closed document in LSP: \(filePath)")
    }
    
    // MARK: - Language Features
    
    /// Request completion for a file position
    /// - Parameters:
    ///   - filePath: Path to the file
    ///   - line: Line number (zero-based)
    ///   - character: Character offset (zero-based)
    /// - Returns: Completion items
    public func requestCompletion(
        filePath: String,
        line: Int,
        character: Int
    ) async throws -> [LSPCompletionItem] {
        let uri = "file://\(filePath)"
        
        guard let document = openDocuments[uri] else {
            return []
        }
        
        guard let client = activeClients[document.languageId] else {
            return []
        }
        
        let position = Position(line: line, character: character)
        let completionList = try await client.requestCompletion(uri: uri, position: position)
        
        return completionList.items.map { lspItem in
            // Convert LSP completion item to our completion item format
            let documentationText: String? = {
                switch lspItem.documentation {
                case .string(let text):
                    return text

                case .markupContent(let content):
                    return content.value

                case .none:
                    return nil
                }
            }()
            
            let convertedItem = CompletionItemAdapter(
                CompletionItemModel(
                    label: lspItem.label,
                    insertText: lspItem.insertText ?? lspItem.label,
                    kind: .text, // Simplified for now
                    detail: lspItem.detail,
                    documentation: documentationText
                )
            )
            return LSPCompletionItem(item: convertedItem, languageId: document.languageId, client: client)
        } as [LSPCompletionItem]
    }
    
    /// Request hover information
    /// - Parameters:
    ///   - filePath: Path to the file
    ///   - line: Line number (zero-based)
    ///   - character: Character offset (zero-based)
    /// - Returns: Hover information
    public func requestHover(
        filePath: String,
        line: Int,
        character: Int
    ) async throws -> Hover? {
        let uri = "file://\(filePath)"
        
        guard let document = openDocuments[uri] else {
            return nil
        }
        
        guard let client = activeClients[document.languageId] else {
            return nil
        }
        
        let position = Position(line: line, character: character)
        return try await client.requestHover(uri: uri, position: position)
    }
    
    /// Request symbol definition
    /// - Parameters:
    ///   - filePath: Path to the file
    ///   - line: Line number (zero-based)
    ///   - character: Character offset (zero-based)
    /// - Returns: Definition locations
    public func requestDefinition(
        filePath: String,
        line: Int,
        character: Int
    ) async throws -> [Location] {
        let uri = "file://\(filePath)"
        
        guard let document = openDocuments[uri] else {
            return []
        }
        
        guard let client = activeClients[document.languageId] else {
            return []
        }
        
        let position = Position(line: line, character: character)
        return try await client.requestDefinition(uri: uri, position: position)
    }
    
    /// Get diagnostics for a file
    /// - Parameter filePath: Path to the file
    /// - Returns: Diagnostics for the file
    public func getDiagnostics(for filePath: String) -> [Diagnostic] {
        let uri = "file://\(filePath)"
        
        guard let document = openDocuments[uri] else {
            return []
        }
        
        guard let client = activeClients[document.languageId] else {
            return []
        }
        
        return client.diagnostics[uri] ?? []
    }
    
    // MARK: - Language Server Availability
    
    /// Check if a language server is available for the given configuration
    /// - Parameter config: Language server configuration to check
    /// - Returns: True if the server executable can be found
    public func isLanguageServerAvailable(_ config: LanguageServerConfig) -> Bool {
        if config.enablePathResolution {
            return pathResolver.isAvailable(config.serverPath)
        } else {
            return FileManager.default.fileExists(atPath: config.serverPath)
        }
    }
    
    /// Get all available paths for a language server executable
    /// - Parameter executableName: Name of the executable (e.g., "typescript-language-server")
    /// - Returns: Array of absolute paths where the executable was found
    public func findLanguageServerPaths(for executableName: String) -> [String] {
        pathResolver.findAllPaths(for: executableName)
    }
    
    /// Get availability status for all configured language servers
    /// - Returns: Dictionary mapping language IDs to availability status
    public func getLanguageServerAvailability() -> [String: Bool] {
        var availability: [String: Bool] = [:]
        
        for (languageId, config) in serverConfigurations {
            availability[languageId] = isLanguageServerAvailable(config)
        }
        
        return availability
    }
    
    /// Resolve the actual path that would be used for a language server
    /// - Parameter config: Language server configuration
    /// - Returns: The resolved absolute path, or nil if not found
    public func resolveLanguageServerPath(_ config: LanguageServerConfig) -> String? {
        if config.enablePathResolution {
            return pathResolver.resolvePath(config.serverPath)
        } else {
            return FileManager.default.fileExists(atPath: config.serverPath) ? config.serverPath : nil
        }
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
    
    private func languageIdFromFilePath(_ filePath: String) -> String? {
        let url = URL(fileURLWithPath: filePath)
        let fileExtension = url.pathExtension
        return languageId(for: fileExtension)
    }
    
    private func restartAllClients() async {
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
    
    private func reopenDocuments(for languageId: String) async {
        guard let client = activeClients[languageId] else { return }
        
        for document in openDocuments.values where document.languageId == languageId {
            do {
                // Read current file content
                let content = try String(contentsOfFile: document.filePath, encoding: .utf8)
                
                try await client.openDocument(
                        uri: document.uri,
                        languageId: document.languageId,
                        version: document.version,
                        text: content
                    )
                } catch {
                    logger.error("Failed to reopen document \(document.filePath): \(error.localizedDescription)")
                }
            }
        }
    }

#endif // canImport(AppKit) && !targetEnvironment(macCatalyst)
    
