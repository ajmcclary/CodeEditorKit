import CodeEditorDesignTokens
import Foundation

/// Search-result colors mapped to Zed's `search.*` keys.
public struct SearchColors: Hashable, Sendable, Codable {
    /// Background fill behind matched text.
    public let matchBackground: Tokens.Color
    /// Unknown `search.*` keys preserved on decode.
    public let extras: [String: Tokens.Color]

    /// Memberwise builder.
    public init(matchBackground: Tokens.Color, extras: [String: Tokens.Color] = [:]) {
        self.matchBackground = matchBackground
        self.extras = extras
    }

    /// Build from a flat dictionary keyed by Zed dotted names.
    init(flat: [String: Tokens.Color], warnings: WarningCollector, path: String) {
        self.matchBackground = flat["search.match_background"]
            ?? warnings.missing(
                path: path,
                key: "search.match_background",
                fallback: Tokens.Palette.Accent.tint20Dark
            )
        self.extras = Dictionary(uniqueKeysWithValues:
            flat.filter { $0.key.hasPrefix("search.") && !Self.knownKeys.contains($0.key) }
                .map { ($0.key, $0.value) })
    }

    /// Emit own keys back into a flat dictionary.
    func flatten(into dict: inout [String: Tokens.Color]) {
        dict["search.match_background"] = matchBackground
        for (key, value) in extras { dict[key] = value }
    }

    static let knownKeys: Set<String> = ["search.match_background"]
}
