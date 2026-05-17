import CodeEditorDesignTokens
import Foundation

/// Icon colors at five emphasis levels, mirroring `TextLevels`.
/// Maps to Zed's `icon` / `icon.*` keys.
public struct IconLevels: Hashable, Sendable, Codable {
    /// Base icon color (Zed `icon`).
    public let base: Tokens.Color
    /// Muted icon color.
    public let muted: Tokens.Color
    /// Placeholder icon color.
    public let placeholder: Tokens.Color
    /// Disabled icon color.
    public let disabled: Tokens.Color
    /// Accent-tinted icon color.
    public let accent: Tokens.Color
    /// Unknown `icon.*` keys preserved on decode for roundtrip fidelity.
    public let extras: [String: Tokens.Color]

    /// Memberwise builder.
    public init(
        base: Tokens.Color,
        muted: Tokens.Color,
        placeholder: Tokens.Color,
        disabled: Tokens.Color,
        accent: Tokens.Color,
        extras: [String: Tokens.Color] = [:]
    ) {
        self.base = base
        self.muted = muted
        self.placeholder = placeholder
        self.disabled = disabled
        self.accent = accent
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
        self.base = flat["icon"]
            ?? warnings.missing(
                path: path, key: "icon", fallback: ThemeFallbackPalette.iconBase(appearance)
            )
        self.muted = flat["icon.muted"]
            ?? warnings.missing(
                path: path,
                key: "icon.muted",
                fallback: ThemeFallbackPalette.iconMuted(appearance)
            )
        self.placeholder = flat["icon.placeholder"]
            ?? warnings.missing(
                path: path,
                key: "icon.placeholder",
                fallback: ThemeFallbackPalette.iconPlaceholder(appearance)
            )
        self.disabled = flat["icon.disabled"]
            ?? warnings.missing(
                path: path,
                key: "icon.disabled",
                fallback: ThemeFallbackPalette.iconDisabled(appearance)
            )
        self.accent = flat["icon.accent"]
            ?? warnings.missing(
                path: path,
                key: "icon.accent",
                fallback: ThemeFallbackPalette.iconAccent(appearance)
            )
        self.extras = Dictionary(uniqueKeysWithValues:
            flat.filter { $0.key.hasPrefix("icon.") && !Self.knownKeys.contains($0.key) }
                .map { ($0.key, $0.value) })
    }

    /// Emit own keys back into a flat dictionary.
    package func flatten(into dict: inout [String: Tokens.Color]) {
        dict["icon"] = base
        dict["icon.muted"] = muted
        dict["icon.placeholder"] = placeholder
        dict["icon.disabled"] = disabled
        dict["icon.accent"] = accent
        for (key, value) in extras { dict[key] = value }
    }

    static let knownKeys: Set<String> = [
        "icon", "icon.muted", "icon.placeholder", "icon.disabled", "icon.accent"
    ]
}
