import CodeEditorLanguages
import Foundation

/// A single open tab in the chrome's tab strip.
///
/// Tabs are host-owned. The package provides this shape so chrome
/// (`EditorTabStrip`) can render uniformly across hosts. `id` is stable
/// across name and dirty-flag changes; mutate `name`/`url`/`language`/
/// `isDirty` on the same instance rather than replacing the model.
public struct TabModel: Hashable, Identifiable, Sendable, Codable {
    /// Stable identifier; preserved across in-place mutations.
    public let id: UUID
    /// Display name shown on the tab.
    public var name: String
    /// File URL backing the tab, if any. Optional for unsaved/scratch tabs.
    public var url: URL?
    /// Detected/explicit language for the tab's content, if any.
    public var language: Language?
    /// True when the tab's content has unsaved changes.
    public var isDirty: Bool

    /// Creates a new tab model.
    /// - Parameters:
    ///   - name: display name.
    ///   - url: file URL backing the tab; defaults to nil.
    ///   - language: language for the tab's content; defaults to nil.
    ///   - isDirty: dirty-flag; defaults to false.
    ///   - id: stable identifier; defaults to a fresh UUID.
    public init(
        name: String,
        url: URL? = nil,
        language: Language? = nil,
        isDirty: Bool = false,
        id: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.language = language
        self.isDirty = isDirty
    }
}
