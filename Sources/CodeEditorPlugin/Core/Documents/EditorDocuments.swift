import CodeEditorLanguages
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

    // MARK: - Bindings

    /// Text `Binding` for the document with the given id.
    ///
    /// Reads return the document's stored text, or `""` if `id` is not
    /// present (defensive default for stale bindings after a `close`).
    /// Writes update the stored text and, when the new value differs
    /// from the previous stored value, flip `isDirty` to `true`. Writing
    /// the same value through the binding is a no-op for the dirty bit.
    public func textBinding(for id: EditorDocument.ID) -> Binding<String> {
        Binding(
            get: { [weak self] in
                self?.documents.first { $0.id == id }?.text ?? ""
            },
            set: { [weak self] newValue in
                guard let self,
                      let index = self.documents.firstIndex(where: { $0.id == id }) else {
                    return
                }
                let previous = self.documents[index].text
                self.documents[index].text = newValue
                if previous != newValue {
                    self.documents[index].tab.isDirty = true
                }
            }
        )
    }

    /// `EditorInteractionState` `Binding` for the document with the given id.
    ///
    /// Reads return the stored state, or a default `EditorInteractionState()`
    /// if `id` is not present. Writes update the stored state.
    public func interactionBinding(for id: EditorDocument.ID) -> Binding<EditorInteractionState> {
        Binding(
            get: { [weak self] in
                self?.documents.first { $0.id == id }?.interactionState
                    ?? EditorInteractionState()
            },
            set: { [weak self] newValue in
                guard let self,
                      let index = self.documents.firstIndex(where: { $0.id == id }) else {
                    return
                }
                self.documents[index].interactionState = newValue
            }
        )
    }

    /// Reset `isDirty` on the document with the given id. No-op if `id`
    /// is not present. Typically called by hosts after a successful save.
    public func markClean(_ id: EditorDocument.ID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[index].tab.isDirty = false
    }

    // MARK: - Chrome integration

    /// Mutable `Binding<[TabModel]>` for chrome (e.g., `EditorTabStrip`).
    ///
    /// The getter returns the `tabs` projection. The setter diffs the
    /// incoming array against the current one by id:
    /// - Any id missing from the new array dispatches `close(_:)`.
    /// - Indices that have moved cause `documents` to be reordered.
    /// - Ids in the new array that aren't already present in `documents`
    ///   are ignored — the strip can only remove or reorder, never
    ///   invent a document.
    public var tabsBinding: Binding<[TabModel]> {
        Binding(
            get: { [weak self] in self?.tabs ?? [] },
            set: { [weak self] newTabs in
                guard let self else { return }
                let newIDs = Set(newTabs.map(\.id))
                let toClose = self.documents.filter { !newIDs.contains($0.id) }.map(\.id)
                for id in toClose {
                    self.close(id)
                }
                let documentsByID = Dictionary(
                    uniqueKeysWithValues: self.documents.map { ($0.id, $0) }
                )
                self.documents = newTabs.compactMap { documentsByID[$0.id] }
            }
        )
    }
}
