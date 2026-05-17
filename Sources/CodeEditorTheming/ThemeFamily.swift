import Foundation

/// A named collection of themes. Zed JSONs are family files — even
/// "single-theme" files have a one-element `themes` array.
public struct ThemeFamily: Hashable, Sendable, Codable {
    /// Optional `$schema` value identifying the Zed schema version.
    public let schema: String?
    /// Display name (e.g., `"Zed Trek"`).
    public let name: String
    /// Optional author attribution string.
    public let author: String?
    /// Variants in this family.
    public let themes: [Theme]

    /// Memberwise builder.
    public init(name: String, themes: [Theme], schema: String? = nil, author: String? = nil) {
        self.schema = schema
        self.name = name
        self.author = author
        self.themes = themes
    }

    private enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case name, author, themes
    }

    /// Look up a variant by display name. Returns nil if no variant matches.
    public func theme(named: String) -> Theme? {
        themes.first { $0.name == named }
    }
}
