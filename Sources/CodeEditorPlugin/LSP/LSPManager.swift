#if canImport(AppKit)
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
/// let swiftConfig = LanguageServerConfig(
///     languageId: "swift",
///     serverPath: "/usr/bin/sourcekit-lsp",
///     fileExtensions: ["swift"]
/// )
/// lspManager.registerLanguageServer(swiftConfig)
///
/// // Open a document
/// try await lspManager.openDocument(filePath: "/path/to/file.swift", content: sourceCode)
///
/// // Request code completion
/// let completions = try await lspManager.requestCompletion(
///     filePath: "/path/to/file.swift",
///     line: 10,
///     character: 15
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
    // MARK: - State

    /// Client registry for managing LSP servers
    private let clientRegistry: LSPClientRegistry

    /// Document manager for handling document synchronization
    private let documentManager: LSPDocumentManager

    /// Active LSP clients (delegated to client registry)
    @Published public private(set) var activeClients: [String: LSPClient] = [:]

    /// Registered language server configurations (delegated to client registry)
    @Published public private(set) var serverConfigurations: [String: LanguageServerConfig] = [:]

    /// Current workspace root
    public var workspaceRoot: URL? {
        didSet {
            if workspaceRoot != oldValue {
                clientRegistry.workspaceRoot = workspaceRoot
                // Restart all clients with new workspace root
                Task {
                    await clientRegistry.restartAllClients()
                }
            }
        }
    }

    // MARK: - Initialization

    private let memoryMonitor: MemoryMonitor

    public init(memoryMonitor: MemoryMonitor, workspaceRoot: URL? = nil) {
        self.clientRegistry = LSPClientRegistry()
        self.documentManager = LSPDocumentManager(clientRegistry: clientRegistry)
        self.memoryMonitor = memoryMonitor

        // Set workspace root on client registry
        self.workspaceRoot = workspaceRoot
        self.clientRegistry.workspaceRoot = workspaceRoot

        // Sync published properties with client registry
        syncPublishedProperties()

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
                let beforeDocumentCount = self.documentManager.getAllDocuments().count

                // Cleanup through components
                self.clientRegistry.cleanup()
                self.documentManager.cleanup()

                // Clear published state
                self.activeClients.removeAll()
                self.serverConfigurations.removeAll()

                // Estimate memory freed (rough estimate)
                let estimatedMemoryMB = Double(beforeClientCount) * 5.0 + Double(beforeDocumentCount) * 0.1

                return CleanupResult(
                    memoryFreedMB: estimatedMemoryMB,
                    description: "Disconnected \(beforeClientCount) LSP clients and cleared \(beforeDocumentCount) documents"
                )
            }
        }
    }

    deinit {
        // Note: Cannot access @MainActor isolated properties in deinit
        // Components will be automatically cleaned up by ARC
    }

    // MARK: - Configuration Management

    /// Register a language server configuration
    /// - Parameter config: Server configuration
    public func registerLanguageServer(_ config: LanguageServerConfig) {
        clientRegistry.registerLanguageServer(config)
        syncPublishedProperties()
    }

    /// Unregister a language server configuration
    /// - Parameter languageId: Language identifier
    public func unregisterLanguageServer(for languageId: String) {
        clientRegistry.unregisterLanguageServer(for: languageId)
        syncPublishedProperties()
    }

    /// Get language ID for a file extension
    /// - Parameter fileExtension: File extension (with or without dot)
    /// - Returns: Language ID if found
    public func languageId(for fileExtension: String) -> String? {
        clientRegistry.languageId(for: fileExtension)
    }

    // MARK: - Client Management

    /// Start a language server for the given language
    /// - Parameters:
    ///   - languageId: Language identifier
    ///   - retryConfig: Retry configuration (defaults to nil, which uses the server's configured retry settings)
    public func startLanguageServer(
        for languageId: String,
        retryConfig: LSPRetryConfiguration? = nil
    ) async throws {
        try await clientRegistry.startLanguageServer(for: languageId, retryConfig: retryConfig)

        // Reopen any documents for this language
        await documentManager.reopenDocuments(for: languageId)

        syncPublishedProperties()
    }

    /// Stop a language server
    /// - Parameter languageId: Language identifier
    public func stopLanguageServer(for languageId: String) {
        clientRegistry.stopLanguageServer(for: languageId)
        syncPublishedProperties()
    }

    /// Stop all running language servers
    public func stopAllServers() {
        clientRegistry.stopAllServers()
        syncPublishedProperties()
    }

    /// Get LSP client for a language
    /// - Parameter languageId: Language identifier
    /// - Returns: LSP client if available
    public func client(for languageId: String) -> LSPClient? {
        clientRegistry.client(for: languageId)
    }

    /// Returns the `TextDocumentSyncKind` advertised by the server for
    /// the given language. Defaults to `.full` when no server is connected
    /// or the capability is absent.
    public func syncKind(for languageId: String) -> TextDocumentSyncKind {
        clientRegistry.client(for: languageId)?
            .serverCapabilities?
            .textDocumentSync?
            .change ?? .full
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
        try await documentManager.openDocument(
            filePath: filePath,
            content: content,
            languageId: languageId
        )
        syncPublishedProperties()
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
        try await documentManager.updateDocument(
            filePath: filePath,
            content: content,
            changes: changes
        )
    }

    /// Close a document
    /// - Parameter filePath: Path to the file
    public func closeDocument(filePath: String) async throws {
        try await documentManager.closeDocument(filePath: filePath)
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
    ) async throws -> [LSPManagerCompletionItem] {
        let uri = "file://\(filePath)"

        guard let document = documentManager.getDocument(for: filePath) else {
            return []
        }

        guard let client = clientRegistry.client(for: document.languageId) else {
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
            return LSPManagerCompletionItem(item: convertedItem, languageId: document.languageId, client: client)
        } as [LSPManagerCompletionItem]
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

        guard let document = documentManager.getDocument(for: filePath) else {
            return nil
        }

        guard let client = clientRegistry.client(for: document.languageId) else {
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

        guard let document = documentManager.getDocument(for: filePath) else {
            return []
        }

        guard let client = clientRegistry.client(for: document.languageId) else {
            return []
        }

        let position = Position(line: line, character: character)
        return try await client.requestDefinition(uri: uri, position: position)
    }

    /// Get diagnostics for a file
    /// - Parameter filePath: Path to the file
    /// - Returns: Diagnostics for the file
    public func getDiagnostics(for filePath: String) -> [LSPDiagnostic] {
        let uri = "file://\(filePath)"

        guard let document = documentManager.getDocument(for: filePath) else {
            return []
        }

        guard let client = clientRegistry.client(for: document.languageId) else {
            return []
        }

        return client.diagnostics[uri] ?? []
    }

    // MARK: - Language Server Availability

    /// Check if a language server is available for the given configuration
    /// - Parameter config: Language server configuration to check
    /// - Returns: True if the server executable can be found
    public func isLanguageServerAvailable(_ config: LanguageServerConfig) -> Bool {
        clientRegistry.isLanguageServerAvailable(config)
    }

    /// Get all available paths for a language server executable
    /// - Parameter executableName: Name of the executable (e.g., "typescript-language-server")
    /// - Returns: Array of absolute paths where the executable was found
    public func findLanguageServerPaths(for executableName: String) -> [String] {
        clientRegistry.findLanguageServerPaths(for: executableName)
    }

    /// Get availability status for all configured language servers
    /// - Returns: Dictionary mapping language IDs to availability status
    public func getLanguageServerAvailability() -> [String: Bool] {
        clientRegistry.getLanguageServerAvailability()
    }

    /// Resolve the actual path that would be used for a language server
    /// - Parameter config: Language server configuration
    /// - Returns: The resolved absolute path, or nil if not found
    public func resolveLanguageServerPath(_ config: LanguageServerConfig) -> String? {
        clientRegistry.resolveLanguageServerPath(config)
    }

    // MARK: - Private Methods

    /// Sync published properties with client registry state
    private func syncPublishedProperties() {
        activeClients = clientRegistry.activeClients
        serverConfigurations = clientRegistry.serverConfigurations
    }
}

#endif // canImport(AppKit)
