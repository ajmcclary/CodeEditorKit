import CodeEditorLanguages
import Foundation

/// A single open document in an `EditorDocuments` collection.
///
/// Owns the text, interaction state (cursor/scroll/folds/find), and the
/// chrome-facing `TabModel` projection. Designed as a `Codable` value so
/// hosts can snapshot a workspace to disk and restore it.
///
/// Identity is `tab.id`. A document and its tab share the same UUID; the
/// computed `id` property forwards to `tab.id`. Forwarding accessors
/// (`name`, `url`, `language`, `isDirty`) read and write through `tab`.
///
/// `Hashable` is auto-synthesized over the three stored properties (`tab`,
/// `text`, `interactionState`) so two documents with the same id but
/// different content are not equal. Use `id` for collection-keying.
public struct EditorDocument: Hashable, Identifiable, Sendable, Codable {
    /// The chrome-facing tab projection (id, name, url, language, isDirty).
    /// Mutate through the document's forwarding accessors rather than
    /// `tab` directly; the manager uses `tab.id` as the canonical identity.
    public var tab: TabModel

    /// Document text.
    public var text: String

    /// Cursor positions, scroll offset, find/replace state, collapsed folds.
    /// Preserved across tab switches so the editor restores them on
    /// activation.
    public var interactionState: EditorInteractionState

    public var id: TabModel.ID { tab.id }

    public var name: String {
        get { tab.name }
        set { tab.name = newValue }
    }

    public var url: URL? {
        get { tab.url }
        set { tab.url = newValue }
    }

    public var language: Language? {
        get { tab.language }
        set { tab.language = newValue }
    }

    public var isDirty: Bool {
        get { tab.isDirty }
        set { tab.isDirty = newValue }
    }

    public init(
        name: String,
        text: String = "",
        url: URL? = nil,
        language: Language? = nil,
        interactionState: EditorInteractionState = EditorInteractionState(),
        isDirty: Bool = false,
        id: TabModel.ID = UUID()
    ) {
        self.tab = TabModel(name: name, url: url, language: language, isDirty: isDirty, id: id)
        self.text = text
        self.interactionState = interactionState
    }
}
