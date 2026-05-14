import Foundation
import Observation
import SwiftUI

/// An ordered, observable collection of open `EditorDocument`s.
///
/// Owns the `[EditorDocument]` source of truth, tracks the active id, and
/// (in later commits) hands out per-document text and interaction-state
/// `Binding`s with automatic dirty tracking. No file I/O — hosts read
/// and write through their own storage; the manager just owns the
/// in-memory shape.
@MainActor
@Observable
public final class EditorDocuments {
    /// Documents in display order. Mutate through the CRUD methods below
    /// (`open`, `close`, `closeAll`, `setActive`) or `update(_:with:)`
    /// rather than reassigning the array; the CRUD methods keep
    /// `activeID` consistent.
    public private(set) var documents: [EditorDocument]

    /// Active document id; nil when `documents.isEmpty`.
    public var activeID: EditorDocument.ID?

    /// Convenience: the currently active document, or nil.
    public var active: EditorDocument? {
        guard let activeID else { return nil }
        return documents.first { $0.id == activeID }
    }

    /// Chrome-facing projection. `EditorTabStrip` binds to `tabsBinding`
    /// (added in a later commit); this read-only computed property is
    /// the natural starting point for `.onChange(of: documents.tabs)`-
    /// style host wiring.
    public var tabs: [TabModel] { documents.map(\.tab) }

    /// Creates a new manager.
    /// - Parameters:
    ///   - documents: Initial documents in display order.
    ///   - activeID: Initial active id; defaults to the first document's
    ///     id (or nil when `documents` is empty).
    public init(documents: [EditorDocument] = [], activeID: EditorDocument.ID? = nil) {
        self.documents = documents
        if let activeID, documents.contains(where: { $0.id == activeID }) {
            self.activeID = activeID
        } else {
            self.activeID = documents.first?.id
        }
    }

    // MARK: - CRUD

    /// Append a document and activate it. Returns the inserted id.
    @discardableResult
    public func open(_ document: EditorDocument) -> EditorDocument.ID {
        documents.append(document)
        activeID = document.id
        return document.id
    }

    /// Close a document. If the closed document was active, activates the
    /// previous document in the list (or nil when the list becomes empty).
    /// No-op if `id` is not present.
    public func close(_ id: EditorDocument.ID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents.remove(at: index)
        if activeID == id {
            if index > 0 {
                activeID = documents[index - 1].id
            } else {
                activeID = documents.first?.id
            }
        }
    }

    /// Close every document.
    public func closeAll() {
        documents.removeAll()
        activeID = nil
    }

    /// Activate a document by id. No-op if `id` is not present.
    public func setActive(_ id: EditorDocument.ID) {
        guard documents.contains(where: { $0.id == id }) else { return }
        activeID = id
    }

    // MARK: - Per-document mutation

    /// Set the language of a document. Does not rename — hosts that want
    /// the file extension to follow the language change should do that
    /// on their side. No-op if `id` is not present.
    public func setLanguage(_ language: Language, of id: EditorDocument.ID) {
        update(id) { $0.tab.language = language }
    }

    /// Mutate the document with the given id in place. The closure
    /// receives an `inout` reference; any mutations propagate through
    /// the manager's `@Observable` storage. No-op if `id` is not present.
    ///
    /// Hosts that need to change multiple fields atomically (e.g., the
    /// sample's `resetToSample`) reach for this method. Use the focused
    /// helpers (`setLanguage(_:of:)`, `markClean(_:)`) for single-field
    /// changes.
    public func update(_ id: EditorDocument.ID, with mutate: (inout EditorDocument) -> Void) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        mutate(&documents[index])
    }
}
