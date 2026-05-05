import CodeEditorDesignTokens
import Foundation

/// Inline-completion-suggestion colors mapped to Zed's `predictive` /
/// `predictive.*` keys.
public struct PredictiveColors: Hashable, Sendable, Codable {
    /// Foreground color of the suggestion text.
    public let base: Tokens.Color
    /// Optional background fill behind the suggestion.
    public let background: Tokens.Color
    /// Border around the suggestion region.
    public let border: Tokens.Color
    /// Unknown `predictive.*` keys preserved on decode.
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
        let baseFallback = ThemeFallbackPalette.textMuted(appearance)
        let bgFallback = Tokens.Color(
            red: baseFallback.red, green: baseFallback.green, blue: baseFallback.blue, alpha: 0.10
        )
        let borderFallback = Tokens.Color(
            red: baseFallback.red, green: baseFallback.green, blue: baseFallback.blue, alpha: 0.40
        )
        self.base = flat["predictive"]
            ?? warnings.missing(path: path, key: "predictive", fallback: baseFallback)
        self.background = flat["predictive.background"]
            ?? warnings.missing(path: path, key: "predictive.background", fallback: bgFallback)
        self.border = flat["predictive.border"]
            ?? warnings.missing(path: path, key: "predictive.border", fallback: borderFallback)
        self.extras = Dictionary(uniqueKeysWithValues:
            flat.filter { $0.key.hasPrefix("predictive.") && !Self.knownKeys.contains($0.key) }
                .map { ($0.key, $0.value) })
    }

    /// Emit own keys back into a flat dictionary.
    func flatten(into dict: inout [String: Tokens.Color]) {
        dict["predictive"] = base
        dict["predictive.background"] = background
        dict["predictive.border"] = border
        for (key, value) in extras { dict[key] = value }
    }

    static let knownKeys: Set<String> = [
        "predictive.background", "predictive.border"
    ]
}
