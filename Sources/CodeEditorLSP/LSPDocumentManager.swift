import CodeEditorCommon
import CodeEditorLanguages
import Foundation

/// Manages document synchronization with LSP servers
@MainActor
final class LSPDocumentManager {
    // MARK: - State

    /// Open documents by URI
    private var openDocuments: [String: OpenDocument] = [:]

    /// Opens in flight by URI. A second open (or an update) of a document
    /// that is still opening waits for that open instead of sending its own
    /// `didOpen`: the document is recorded only after the server accepted it
    /// (finding services-28), so without this two callers both saw it closed.
    private var openingDocuments: [String: Task<Void, any Error>] = [:]

    /// Logger for debugging
    private let logger = CodeEditorLog.lsp(category: "LSPDocumentManager")

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
        // Already open, or opening: never a second didOpen without a close.
        let uri = try await uriAfterPendingOpen(of: filePath)
        if let open = openDocuments[uri] {
            if open.content != content {
                try await updateDocument(filePath: filePath, content: content)
            }
            return
        }

        let task = Task<Void, any Error> { @MainActor [weak self] in
            guard let self else { return }
            try await self.performOpen(filePath: filePath, uri: uri, content: content, languageId: languageId)
        }
        openingDocuments[uri] = task
        defer { openingDocuments[uri] = nil }
        try await task.value
    }

    /// The document's URI, once any open of it in flight has finished.
    private func uriAfterPendingOpen(of filePath: String) async throws -> String {
        guard clientRegistry != nil else {
            throw LSPError.invalidResponse("Client registry not available")
        }
        let uri = LSPDocumentURI.uri(forFilePath: filePath)
        if let opening = openingDocuments[uri] {
            try await opening.value
        }
        return uri
    }

    private func performOpen(
        filePath: String,
        uri: String,
        content: String,
        languageId: String?
    ) async throws {
        guard let clientRegistry else {
            throw LSPError.invalidResponse("Client registry not available")
        }
        let inferredLanguageId = languageId ?? languageIdFromFilePath(filePath)

        guard let finalLanguageId = inferredLanguageId else {
            logger.debug("No language server configured for file: \(filePath)")
            return
        }

        let document = OpenDocument(
            uri: uri,
            languageId: finalLanguageId,
            version: 1,
            filePath: filePath,
            content: content
        )

        // Start language server if not running
        if clientRegistry.client(for: finalLanguageId) == nil {
            do {
                try await clientRegistry.startLanguageServer(for: finalLanguageId)
            } catch {
                logger.error("Failed to start language server for \(finalLanguageId): \(error.localizedDescription)")
                return
            }
        }

        // Record the document only once the server has opened it: recording
        // it first sent later didChanges for a document the server never saw.
        if let client = clientRegistry.client(for: finalLanguageId) {
            try await client.openDocument(
                uri: uri,
                languageId: finalLanguageId,
                version: document.version,
                text: content
            )
            openDocuments[uri] = document

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
        // An update racing the document's open goes after it.
        let uri = try await uriAfterPendingOpen(of: filePath)
        guard let clientRegistry else {
            throw LSPError.invalidResponse("Client registry not available")
        }

        guard var document = openDocuments[uri] else {
            logger.debug("Document not open: \(filePath)")
            return
        }

        document.incrementVersion()
        document.content = content
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
        // A close racing the document's open goes after it, so the server
        // is not left with a document nobody closes.
        let uri = try await uriAfterPendingOpen(of: filePath)
        guard let clientRegistry else {
            throw LSPError.invalidResponse("Client registry not available")
        }

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

        for var document in openDocuments.values where document.languageId == languageId {
            do {
                // The editor's buffer, not the file on disk (which lacks
                // unsaved edits), under a new version.
                document.incrementVersion()
                openDocuments[document.uri] = document
                try await client.openDocument(
                    uri: document.uri,
                    languageId: document.languageId,
                    version: document.version,
                    text: document.content
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
        let uri = LSPDocumentURI.uri(forFilePath: filePath)
        return openDocuments[uri]
    }

    /// Whether the document is open or its open is in flight.
    func isOpenOrOpening(filePath: String) -> Bool {
        let uri = LSPDocumentURI.uri(forFilePath: filePath)
        return openDocuments[uri] != nil || openingDocuments[uri] != nil
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
