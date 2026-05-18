import Foundation

/// One segment of a breadcrumb trail (workspace › folder › file › symbol).
///
/// Breadcrumb data lives next to the rest of `EditorState`'s host-driven
/// fields; the chrome's visual rendering of separators, kind glyphs, and
/// hover lives in `CodeEditorUI/Breadcrumb/EditorBreadcrumbView.swift`.
public struct BreadcrumbComponent: Hashable, Identifiable, Sendable {
    /// Kind of segment — drives the leading glyph and tap behavior in the
    /// breadcrumb view.
    public enum Kind: Hashable, Sendable {
        case workspace
        case folder
        case file
        case symbol
    }

    /// Stable identifier; preserved across name changes.
    public let id: UUID
    /// Display name.
    public let name: String
    /// Segment kind.
    public let kind: Kind

    /// Creates a new breadcrumb component.
    /// - Parameters:
    ///   - name: display name.
    ///   - kind: segment kind.
    ///   - id: stable identifier; defaults to a fresh UUID.
    public init(name: String, kind: Kind, id: UUID = UUID()) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}
