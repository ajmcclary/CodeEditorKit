import CodeEditorDesignTokens
import Foundation

/// Per-token syntax styling, keyed under `style.syntax` in Zed JSON.
///
/// Zed allows entries that have only `font_style` or only `font_weight`
/// (e.g., `emphasis: { font_style: italic }`), so `color` is optional.
/// Weights follow the CSS scale (100–900).
public struct SyntaxStyle: Hashable, Sendable, Codable {
    /// CSS-style font style names supported by Zed.
    public enum FontStyle: String, Sendable, Hashable, Codable {
        case normal
        case italic
    }

    /// Foreground color, or nil for entries that only override style/weight.
    public let color: Tokens.Color?
    /// Optional background highlight (rare in Zed JSONs).
    public let backgroundColor: Tokens.Color?
    /// CSS-style numeric weight (100–900) or nil to inherit.
    public let fontWeight: Int?
    /// Italic vs. normal, or nil to inherit.
    public let fontStyle: FontStyle?

    /// Memberwise builder.
    public init(
        color: Tokens.Color? = nil,
        backgroundColor: Tokens.Color? = nil,
        fontWeight: Int? = nil,
        fontStyle: FontStyle? = nil
    ) {
        self.color = color
        self.backgroundColor = backgroundColor
        self.fontWeight = fontWeight
        self.fontStyle = fontStyle
    }

    private enum CodingKeys: String, CodingKey {
        case color
        case backgroundColor = "background_color"
        case fontWeight = "font_weight"
        case fontStyle = "font_style"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector
            ?? WarningCollector()
        if let hex = try container.decodeIfPresent(String.self, forKey: .color) {
            self.color = ZedColorBridge.parse(hex, path: "syntax.color", warnings: warnings)
        } else {
            self.color = nil
        }
        if let hex = try container.decodeIfPresent(String.self, forKey: .backgroundColor) {
            self.backgroundColor = ZedColorBridge.parse(
                hex, path: "syntax.background_color", warnings: warnings
            )
        } else {
            self.backgroundColor = nil
        }
        self.fontWeight = try container.decodeIfPresent(Int.self, forKey: .fontWeight)
        self.fontStyle = try container.decodeIfPresent(FontStyle.self, forKey: .fontStyle)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(color.map(ZedColorBridge.encode), forKey: .color)
        try container.encodeIfPresent(
            backgroundColor.map(ZedColorBridge.encode), forKey: .backgroundColor
        )
        try container.encodeIfPresent(fontWeight, forKey: .fontWeight)
        try container.encodeIfPresent(fontStyle, forKey: .fontStyle)
    }
}
