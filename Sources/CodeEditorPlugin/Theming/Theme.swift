import CodeEditorDesignTokens
import Foundation

/// A complete theme — the unit applied to the editor via `.codeTheme(_:)`.
/// Decoded from Zed v0.2.0 JSON. Always has a non-optional `platform`
/// extension; if the source JSON omits the `platform` key, defaults are
/// synthesized via `PlatformExtension.derived(from:appearance:)`.
public struct Theme: Hashable, Sendable, Codable, Identifiable {
    /// Whether a theme is intended for dark or light environments.
    public enum Appearance: String, Sendable, Hashable, Codable {
        /// Dark-environment theme.
        case dark
        /// Light-environment theme.
        case light
    }

    /// Stable identifier — currently the theme name.
    public var id: String { name }
    /// Display name (e.g., `"LCARS Dark"`).
    public let name: String
    /// Dark vs. light environment.
    public let appearance: Appearance
    /// Visual surface mapped from Zed's `style` object.
    public let style: ThemeStyle
    /// Liquid Glass / shadow / field knobs. Always present; derived from
    /// `style` if absent in JSON.
    public let platform: PlatformExtension

    /// Memberwise builder.
    public init(name: String, appearance: Appearance, style: ThemeStyle, platform: PlatformExtension) {
        self.name = name
        self.appearance = appearance
        self.style = style
        self.platform = platform
    }

    private enum CodingKeys: String, CodingKey {
        case name, appearance, style, platform
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.appearance = try container.decode(Appearance.self, forKey: .appearance)
        self.style = try container.decode(ThemeStyle.self, forKey: .style)
        if let explicit = try? container.decode(PlatformExtension.self, forKey: .platform) {
            self.platform = explicit
        } else {
            self.platform = PlatformExtension.derived(from: style, appearance: appearance)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(style, forKey: .style)
        try container.encode(platform, forKey: .platform)
    }

    /// Hard-coded minimum theme assembled from internal fallback colors.
    /// Used when both the bundled themes and user-supplied JSON are
    /// unavailable. Never fails; always returns a usable theme.
    public static func fallback(appearance: Appearance) -> Self {
        let collector = WarningCollector()
        let style = ThemeStyle(
            background: ThemeFallbackPalette.background(appearance),
            backgroundAppearance: "opaque",
            editor: EditorColors(flat: [:], warnings: collector, path: "fallback"),
            chrome: ChromeColors(flat: [:], warnings: collector, path: "fallback"),
            elements: ElementStates(flat: [:], warnings: collector, path: "fallback"),
            borders: BorderColors(flat: [:], warnings: collector, path: "fallback"),
            text: TextLevels(flat: [:], warnings: collector, path: "fallback"),
            icon: IconLevels(flat: [:], warnings: collector, path: "fallback"),
            status: StatusPalette(flat: [:], warnings: collector, path: "fallback"),
            vcs: VCSPalette(flat: [:], warnings: collector, path: "fallback"),
            scrollbar: ScrollbarColors(flat: [:], warnings: collector, path: "fallback"),
            search: SearchColors(flat: [:], warnings: collector, path: "fallback"),
            predictive: PredictiveColors(flat: [:], warnings: collector, path: "fallback"),
            hint: HintColors(flat: [:], warnings: collector, path: "fallback"),
            dropTarget: ThemeFallbackPalette.dropTarget(appearance),
            linkTextHover: ThemeFallbackPalette.textAccent(appearance),
            players: [
                Player(
                    cursor: ThemeFallbackPalette.textAccent(appearance),
                    selection: Tokens.Color(red: 0x7E, green: 0xC8, blue: 0xDE, alpha: 0.15),
                    background: nil
                )
            ],
            accents: [],
            syntax: [:],
            terminal: nil
        )
        return Self(
            name: "Fallback \(appearance.rawValue.capitalized)",
            appearance: appearance,
            style: style,
            platform: PlatformExtension.derived(from: style, appearance: appearance)
        )
    }
}
