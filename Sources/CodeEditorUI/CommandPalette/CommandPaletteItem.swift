import Foundation

/// One item in the command palette.
///
/// Items are host-supplied. The package provides the shape so the
/// palette's filter and renderer behave uniformly.
public struct CommandPaletteItem: Hashable, Identifiable, Sendable {
    /// Item kind — drives the leading glyph.
    public enum Kind: Hashable, Sendable {
        case file
        case symbol
        case action
        case setting
    }

    /// Stable identifier.
    public let id: UUID
    /// Primary label.
    public let title: String
    /// Secondary label (e.g., file path, command source).
    public let subtitle: String?
    /// Item kind.
    public let kind: Kind
    /// Display-only shortcut hint (e.g., `"⌘O"`); not bound to a real key.
    public let shortcut: String?

    /// Memberwise builder.
    public init(
        title: String,
        kind: Kind,
        subtitle: String? = nil,
        shortcut: String? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.shortcut = shortcut
    }
}

/// Internal helper that filters items by a query string. Lives in the
/// same module so unit tests can exercise it without touching SwiftUI.
enum CommandPaletteFilter {
    static func filter(items: [CommandPaletteItem], query: String) -> [CommandPaletteItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        let needle = trimmed.lowercased()
        return items.filter { $0.title.lowercased().contains(needle) }
    }
}
