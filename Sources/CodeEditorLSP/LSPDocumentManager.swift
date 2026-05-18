import CodeEditorCommon
import CodeEditorLanguages
import Foundation

/// Manages document synchronization with LSP servers
@MainActor
final class LSPDocumentManager {
    // MARK: - State

    /// Open documents by URI
    private var openDocuments: [String: OpenDocument] = [:]

    /// Logger for debugging
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.lsp", category: "LSPDocumentManager")

    /// Reference to client registry for accessing clients
    private weak var clientRegistry: LSPClientRegistry?

    // MARK: - Initialization

    init(clientRegistry: LSPClientRegistry) {
        self.clientRegistry = clientRegistry
    }

    // MARK: - Document Management

    /// Open a document in the appropriate LSP server
    /// - Parameters:
    ///   - filePath: Path to the file
    ///   - content: File content
    ///   - languageId: Optional language ID (will be inferred from file extension if not provided)
    func openDocument(
        filePath: String,
        content: String,
        languageId: String? = nil
    ) async throws {
        guard let clientRegistry else {
            throw LSPError.invalidResponse("Client registry not available")
        }

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
        if clientRegistry.client(for: finalLanguageId) == nil {
            do {
                try await clientRegistry.startLanguageServer(for: finalLanguageId)
            } catch {
                logger.error("Failed to start language server for \(finalLanguageId): \(error.localizedDescription)")
                return
            }
        }

        // Open document in LSP server
        if let client = clientRegistry.client(for: finalLanguageId) {
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
    func updateDocument(
        filePath: String,
        content: String,
        changes: [TextDocumentContentChangeEvent] = []
    ) async throws {
        guard let clientRegistry else {
            throw LSPError.invalidResponse("Client registry not available")
        }

        let uri = "file://\(filePath)"

        guard var document = openDocuments[uri] else {
            logger.debug("Document not open: \(filePath)")
            return
        }

        document.incrementVersion()
        openDocuments[uri] = document

        guard let client = clientRegistry.client(for: document.languageId) else {
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
    func closeDocument(filePath: String) async throws {
        guard let clientRegistry else {
            throw LSPError.invalidResponse("Client registry not available")
        }

        let uri = "file://\(filePath)"

        guard let document = openDocuments.removeValue(forKey: uri) else {
            return
        }

        guard let client = clientRegistry.client(for: document.languageId) else {
            return
        }

        try await client.closeDocument(uri: uri)
        logger.debug("Closed document in LSP: \(filePath)")
    }

    /// Reopen documents for a specific language after client restart
    /// - Parameter languageId: Language identifier
    func reopenDocuments(for languageId: String) async {
        guard let clientRegistry else { return }
        guard let client = clientRegistry.client(for: languageId) else { return }

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

    /// Get document info for a file path
    /// - Parameter filePath: Path to the file
    /// - Returns: Open document info if available
    func getDocument(for filePath: String) -> OpenDocument? {
        let uri = "file://\(filePath)"
        return openDocuments[uri]
    }

    /// Get all open documents
    /// - Returns: Array of open documents
    func getAllDocuments() -> [OpenDocument] {
        Array(openDocuments.values)
    }

    /// Cleanup all documents
    func cleanup() {
        openDocuments.removeAll()
    }

    // MARK: - Private Methods

    private func languageIdFromFilePath(_ filePath: String) -> String? {
        let url = URL(fileURLWithPath: filePath)
        let fileExtension = url.pathExtension
        return clientRegistry?.languageId(for: fileExtension)
    }
}
