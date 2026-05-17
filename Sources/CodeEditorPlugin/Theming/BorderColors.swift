import CodeEditorDesignTokens
import Foundation

/// Border colors mapped to Zed's `border` / `border.*` keys.
public struct BorderColors: Hashable, Sendable, Codable {
    /// Default border (Zed `border`).
    public let base: Tokens.Color
    /// Disabled-state border.
    public let disabled: Tokens.Color
    /// Focused border.
    public let focused: Tokens.Color
    /// Selected border.
    public let selected: Tokens.Color
    /// Transparent placeholder border (Zed `border.transparent`).
    public let transparent: Tokens.Color
    /// Variant border for subtle separators.
    public let variant: Tokens.Color
    /// Unknown `border.*` keys preserved on decode.
    public let extras: [String: Tokens.Color]

    /// Memberwise builder.
    public init(
        base: Tokens.Color,
        disabled: Tokens.Color,
        focused: Tokens.Color,
        selected: Tokens.Color,
        transparent: Tokens.Color,
        variant: Tokens.Color,
        extras: [String: Tokens.Color] = [:]
    ) {
        self.base = base
        self.disabled = disabled
        self.focused = focused
        self.selected = selected
        self.transparent = transparent
        self.variant = variant
        self.extras = extras
    }

    /// Build from a flat dictionary keyed by Zed dotted names. `appearance`
    /// selects between light and dark fallback colors when a key is missing.
    init(
        flat: [String: Tokens.Color],
        warnings: WarningCollector,
        path: String,
        appearance: Theme.Appearance
    ) {
        let baseFallback = ThemeFallbackPalette.border(appearance)
        let transparentFallback = ThemeFallbackPalette.clear()
        self.base = flat["border"]
            ?? warnings.missing(path: path, key: "border", fallback: baseFallback)
        self.disabled = flat["border.disabled"]
            ?? warnings.missing(path: path, key: "border.disabled", fallback: baseFallback)
        self.focused = flat["border.focused"]
            ?? warnings.missing(
                path: path,
                key: "border.focused",
                fallback: ThemeFallbackPalette.textAccent(appearance)
            )
        self.selected = flat["border.selected"]
            ?? warnings.missing(
                path: path,
                key: "border.selected",
                fallback: ThemeFallbackPalette.textAccent(appearance)
            )
        self.transparent = flat["border.transparent"]
            ?? warnings.missing(path: path, key: "border.transparent", fallback: transparentFallback)
        self.variant = flat["border.variant"]
            ?? warnings.missing(path: path, key: "border.variant", fallback: baseFallback)
        self.extras = Dictionary(uniqueKeysWithValues:
            flat.filter { $0.key.hasPrefix("border.") && !Self.knownKeys.contains($0.key) }
                .map { ($0.key, $0.value) })
    }

    /// Emit own keys back into a flat dictionary.
    package func flatten(into dict: inout [String: Tokens.Color]) {
        dict["border"] = base
        dict["border.disabled"] = disabled
        dict["border.focused"] = focused
        dict["border.selected"] = selected
        dict["border.transparent"] = transparent
        dict["border.variant"] = variant
        for (key, value) in extras { dict[key] = value }
    }

    static let knownKeys: Set<String> = [
        "border", "border.disabled", "border.focused",
        "border.selected", "border.transparent", "border.variant"
    ]
}
