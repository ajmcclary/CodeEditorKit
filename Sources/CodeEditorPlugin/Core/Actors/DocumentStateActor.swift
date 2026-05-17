import CodeEditorLanguages
import Foundation

// MARK: - Document State Actor

/// Actor responsible for managing document state
@available(macOS 13.0, iOS 16.0, *)
public actor DocumentStateActor {
    private var documents: [UUID: DocumentState] = [:]
    private var documentURLs: [URL: UUID] = [:]

    public struct DocumentState: Sendable {
        public let id: UUID
        public let url: URL?
        public var content: String
        public var isDirty: Bool
        public var version: Int
        public var language: Language
        public var lastModified: Date
        public var metadata: [String: String]

        public init(
            content: String,
            url: URL? = nil,
            language: Language = .plainText,
            metadata: [String: String] = [:]
        ) {
            self.id = UUID()
            self.url = url
            self.content = content
            self.isDirty = false
            self.version = 0
            self.language = language
            self.lastModified = Date()
            self.metadata = metadata
        }
    }

    /// Create a new document
    public func createDocument(
        content: String,
        url: URL? = nil,
        language: Language = .plainText
    ) -> UUID {
        let state = DocumentState(content: content, url: url, language: language)
        documents[state.id] = state

        if let url {
            documentURLs[url] = state.id
        }

        return state.id
    }

    /// Update document content
    public func updateContent(for documentId: UUID, content: String) {
        guard var state = documents[documentId] else { return }

        state.content = content
        state.isDirty = true
        state.version += 1
        state.lastModified = Date()

        documents[documentId] = state
    }

    /// Get document state
    public func getDocument(_ documentId: UUID) -> DocumentState? {
        documents[documentId]
    }

    /// Get document by URL
    public func getDocument(at url: URL) -> DocumentState? {
        guard let id = documentURLs[url] else { return nil }
        return documents[id]
    }

    /// Mark document as saved
    public func markSaved(_ documentId: UUID) {
        guard var state = documents[documentId] else { return }
        state.isDirty = false
        documents[documentId] = state
    }

    /// Close document
    public func closeDocument(_ documentId: UUID) {
        if let state = documents[documentId], let url = state.url {
            documentURLs.removeValue(forKey: url)
        }
        documents.removeValue(forKey: documentId)
    }
}
