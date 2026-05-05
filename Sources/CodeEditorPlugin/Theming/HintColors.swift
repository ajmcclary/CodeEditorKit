import CodeEditorDesignTokens
import Foundation

/// Inlay-hint colors mapped to Zed's `hint` / `hint.*` keys.
public struct HintColors: Hashable, Sendable, Codable {
    /// Foreground color of inlay hints.
    public let base: Tokens.Color
    /// Background fill behind hints.
    public let background: Tokens.Color
    /// Border around hint region.
    public let border: Tokens.Color
    /// Unknown `hint.*` keys preserved on decode.
    public let extras: [String: Tokens.Color]

    /// Memberwise builder.
    public init(
        base: Tokens.Color,
        background: Tokens.Color,
        border: Tokens.Color,
        extras: [String: Tokens.Color] = [:]
    ) {
        self.base = base
        self.background = background
        self.border = border
        self.extras = extras
    }

    /// Build from a flat dictionary keyed by Zed dotted names.
    init(flat: [String: Tokens.Color], warnings: WarningCollector, path: String) {
        let appearance: Theme.Appearance = .dark
        let baseFallback = ThemeFallbackPalette.textAccent(appearance)
        let bgFallback = Tokens.Color(
            red: baseFallback.red, green: baseFallback.green, blue: baseFallback.blue, alpha: 0.15
        )
        let borderFallback = Tokens.Color(
            red: baseFallback.red, green: baseFallback.green, blue: baseFallback.blue, alpha: 0.50
        )
        self.base = flat["hint"]
            ?? warnings.missing(path: path, key: "hint", fallback: baseFallback)
        self.background = flat["hint.background"]
            ?? warnings.missing(path: path, key: "hint.background", fallback: bgFallback)
        self.border = flat["hint.border"]
            ?? warnings.missing(path: path, key: "hint.border", fallback: borderFallback)
        self.extras = Dictionary(uniqueKeysWithValues:
            flat.filter { $0.key.hasPrefix("hint.") && !Self.knownKeys.contains($0.key) }
                .map { ($0.key, $0.value) })
    }

    /// Emit own keys back into a flat dictionary.
    func flatten(into dict: inout [String: Tokens.Color]) {
        dict["hint"] = base
        dict["hint.background"] = background
        dict["hint.border"] = border
        for (key, value) in extras { dict[key] = value }
    }

    static let knownKeys: Set<String> = ["hint.background", "hint.border"]
}
