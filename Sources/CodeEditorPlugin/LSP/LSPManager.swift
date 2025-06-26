import Foundation
import os.log

/// Manages LSP clients for different languages and provides unified access
@MainActor
public final class LSPManager: ObservableObject {
    // MARK: - Configuration
    
    /// LSP server configuration for a specific language
    public struct LanguageServerConfig: Sendable {
        public let languageId: String
        public let serverPath: String
        public let serverArguments: [String]
        public let fileExtensions: [String]
        public let capabilities: ClientCapabilities
        public let autoStart: Bool
        
        public init(
            languageId: String,
            serverPath: String,
            serverArguments: [String] = [],
            fileExtensions: [String],
            capabilities: ClientCapabilities = .default,
            autoStart: Bool = true
        ) {
            self.languageId = languageId
            self.serverPath = serverPath
            self.serverArguments = serverArguments
            self.fileExtensions = fileExtensions
            self.capabilities = capabilities
            self.autoStart = autoStart
        }
    }
    
    // MARK: - State
    
    /// Active LSP clients by language ID
    @Published public private(set) var activeClients: [String: LSPClient] = [:]
    
    /// Registered language server configurations
    @Published public private(set) var serverConfigurations: [String: LanguageServerConfig] = [:]
    
    /// Open documents by URI
    private var openDocuments: [String: OpenDocument] = [:]
    
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
    private let logger = Logger(subsystem: "com.codeeditor.lsp", category: "LSPManager")
    
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
    
    public struct LSPCompletionItem {
        public let item: CompletionItem
        public let languageId: String
        public let client: LSPClient
        
        public init(item: CompletionItem, languageId: String, client: LSPClient) {
            self.item = item
            self.languageId = languageId
            self.client = client
        }
    }
    
    // MARK: - Initialization
    
    public init(workspaceRoot: URL? = nil) {
        self.workspaceRoot = workspaceRoot
        setupDefaultConfigurations()
        
        // Register with memory monitor
        registerWithMemoryMonitor()
    }
    
    deinit {
        // Disconnect all clients
        for client in activeClients.values {
            client.disconnect()
        }
    }
    
    // MARK: - Configuration Management
    
    /// Register a language server configuration
    /// - Parameter config: Server configuration
    public func registerLanguageServer(_ config: LanguageServerConfig) {
        serverConfigurations[config.languageId] = config
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
        logger.info("Unregistered LSP server for \(languageId)")
    }
    
    /// Get language ID for a file extension
    /// - Parameter fileExtension: File extension (with or without dot)
    /// - Returns: Language ID if found
    public func languageId(for fileExtension: String) -> String? {
        let ext = fileExtension.hasPrefix(".") ? fileExtension : ".\(fileExtension)"
        
        for (languageId, config) in serverConfigurations {
            if config.fileExtensions.contains(ext) {
                return languageId
            }
        }
        
        return nil
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
        
        let client = LSPClient()
        let serverConfig = LSPClient.ServerConfiguration(
            languageId: languageId,
            serverPath: config.serverPath,
            serverArguments: config.serverArguments,
            workspaceRoot: workspaceRoot,
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
        changes: [TextDocumentContentChangeEvent]? = nil
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
        
        let finalChanges = changes ?? [
            TextDocumentContentChangeEvent(text: content)
        ]
        
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
        
        return completionList.items.map { item in
            LSPCompletionItem(item: item, languageId: document.languageId, client: client)
        }
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
    
    // MARK: - Private Methods
    
    private func setupDefaultConfigurations() {
        // Add common language server configurations
        // These can be overridden by users or plugins
        
        // TypeScript/JavaScript (requires typescript-language-server)
        registerLanguageServer(LanguageServerConfig(
            languageId: "typescript",
            serverPath: "/usr/local/bin/typescript-language-server",
            serverArguments: ["--stdio"],
            fileExtensions: [".ts", ".tsx", ".js", ".jsx"]
        ))
        
        // Python (requires pylsp)
        registerLanguageServer(LanguageServerConfig(
            languageId: "python",
            serverPath: "/usr/local/bin/pylsp",
            serverArguments: [],
            fileExtensions: [".py"]
        ))
        
        // Rust (requires rust-analyzer)
        registerLanguageServer(LanguageServerConfig(
            languageId: "rust",
            serverPath: "/usr/local/bin/rust-analyzer",
            serverArguments: [],
            fileExtensions: [".rs"]
        ))
        
        // Go (requires gopls)
        registerLanguageServer(LanguageServerConfig(
            languageId: "go",
            serverPath: "/usr/local/bin/gopls",
            serverArguments: [],
            fileExtensions: [".go"]
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
        
        for document in openDocuments.values {
            if document.languageId == languageId {
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
    
    /// Register with memory monitor for cleanup
    private func registerWithMemoryMonitor() {
        Task { @MainActor in
            MemoryMonitor.shared.registerCleanupHandler(
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
                
                // Estimate memory freed (rough estimate)
                let estimatedMemoryMB = Double(beforeClientCount) * 5.0 + Double(beforeDocumentCount) * 0.1
                
                return CleanupResult(
                    memoryFreedMB: estimatedMemoryMB,
                    description: "Disconnected \(beforeClientCount) LSP clients and cleared \(beforeDocumentCount) documents"
                )
            }
        }
    }
}
