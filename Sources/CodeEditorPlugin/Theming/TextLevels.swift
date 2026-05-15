import CodeEditorDesignTokens
import Foundation

/// Text colors at five emphasis levels, mapped to Zed's `text` / `text.*`
/// keys. `extras` preserves any unknown `text.*` keys so a roundtrip never
/// loses data.
public struct TextLevels: Hashable, Sendable, Codable {
    /// Base text color (Zed `text`).
    public let base: Tokens.Color
    /// Muted/secondary text.
    public let muted: Tokens.Color
    /// Placeholder text in fields.
    public let placeholder: Tokens.Color
    /// Disabled text.
    public let disabled: Tokens.Color
    /// Accent-tinted text (Zed `text.accent`).
    public let accent: Tokens.Color
    /// Unknown `text.*` keys preserved on decode for roundtrip fidelity.
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

    /// Build from a flat dictionary keyed by Zed dotted names, recording
    /// `.missingKey` warnings as we go. `appearance` selects between light
    /// and dark fallback colors when a key is missing.
    init(
        flat: [String: Tokens.Color],
        warnings: WarningCollector,
        path: String,
        appearance: Theme.Appearance
    ) {
        self.base = flat["text"]
            ?? warnings.missing(
                path: path, key: "text", fallback: ThemeFallbackPalette.textBase(appearance)
            )
        self.muted = flat["text.muted"]
            ?? warnings.missing(
                path: path,
                key: "text.muted",
                fallback: ThemeFallbackPalette.textMuted(appearance)
            )
        self.placeholder = flat["text.placeholder"]
            ?? warnings.missing(
                path: path,
                key: "text.placeholder",
                fallback: ThemeFallbackPalette.textPlaceholder(appearance)
            )
        self.disabled = flat["text.disabled"]
            ?? warnings.missing(
                path: path,
                key: "text.disabled",
                fallback: ThemeFallbackPalette.textDisabled(appearance)
            )
        self.accent = flat["text.accent"]
            ?? warnings.missing(
                path: path,
                key: "text.accent",
                fallback: ThemeFallbackPalette.textAccent(appearance)
            )
        self.extras = Dictionary(uniqueKeysWithValues:
            flat.filter { $0.key.hasPrefix("text.") && !Self.knownKeys.contains($0.key) }
                .map { ($0.key, $0.value) })
    }

    /// Emit own keys back into a flat dictionary.
    func flatten(into dict: inout [String: Tokens.Color]) {
        dict["text"] = base
        dict["text.muted"] = muted
        dict["text.placeholder"] = placeholder
        dict["text.disabled"] = disabled
        dict["text.accent"] = accent
        for (key, value) in extras { dict[key] = value }
    }

    static let knownKeys: Set<String> = [
        "text", "text.muted", "text.placeholder", "text.disabled", "text.accent"
    ]
}
