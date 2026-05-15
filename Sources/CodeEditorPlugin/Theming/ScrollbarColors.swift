import CodeEditorDesignTokens
import Foundation

/// Scrollbar colors mapped to Zed's `scrollbar.*` keys.
public struct ScrollbarColors: Hashable, Sendable, Codable {
    /// Track fill color.
    public let trackBackground: Tokens.Color
    /// Track border color.
    public let trackBorder: Tokens.Color
    /// Thumb fill color.
    public let thumbBackground: Tokens.Color
    /// Thumb border color.
    public let thumbBorder: Tokens.Color
    /// Thumb fill on hover.
    public let thumbHoverBackground: Tokens.Color
    /// Unknown `scrollbar.*` keys preserved on decode.
    public let extras: [String: Tokens.Color]

    /// Memberwise builder.
    public init(
        trackBackground: Tokens.Color,
        trackBorder: Tokens.Color,
        thumbBackground: Tokens.Color,
        thumbBorder: Tokens.Color,
        thumbHoverBackground: Tokens.Color,
        extras: [String: Tokens.Color] = [:]
    ) {
        self.trackBackground = trackBackground
        self.trackBorder = trackBorder
        self.thumbBackground = thumbBackground
        self.thumbBorder = thumbBorder
        self.thumbHoverBackground = thumbHoverBackground
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
        let bgFallback = ThemeFallbackPalette.background(appearance)
        let borderFallback = ThemeFallbackPalette.border(appearance)
        let accent = ThemeFallbackPalette.textAccent(appearance)
        self.trackBackground = flat["scrollbar.track.background"]
            ?? warnings.missing(
                path: path, key: "scrollbar.track.background", fallback: bgFallback
            )
        self.trackBorder = flat["scrollbar.track.border"]
            ?? warnings.missing(
                path: path, key: "scrollbar.track.border", fallback: borderFallback
            )
        self.thumbBackground = flat["scrollbar.thumb.background"]
            ?? warnings.missing(
                path: path, key: "scrollbar.thumb.background", fallback: accent
            )
        self.thumbBorder = flat["scrollbar.thumb.border"]
            ?? warnings.missing(
                path: path, key: "scrollbar.thumb.border", fallback: accent
            )
        self.thumbHoverBackground = flat["scrollbar.thumb.hover_background"]
            ?? warnings.missing(
                path: path, key: "scrollbar.thumb.hover_background", fallback: accent
            )
        self.extras = Dictionary(uniqueKeysWithValues:
            flat.filter { $0.key.hasPrefix("scrollbar.") && !Self.knownKeys.contains($0.key) }
                .map { ($0.key, $0.value) })
    }

    /// Emit own keys back into a flat dictionary.
    func flatten(into dict: inout [String: Tokens.Color]) {
        dict["scrollbar.track.background"] = trackBackground
        dict["scrollbar.track.border"] = trackBorder
        dict["scrollbar.thumb.background"] = thumbBackground
        dict["scrollbar.thumb.border"] = thumbBorder
        dict["scrollbar.thumb.hover_background"] = thumbHoverBackground
        for (key, value) in extras { dict[key] = value }
    }

    static let knownKeys: Set<String> = [
        "scrollbar.track.background",
        "scrollbar.track.border",
        "scrollbar.thumb.background",
        "scrollbar.thumb.border",
        "scrollbar.thumb.hover_background"
    ]
}
