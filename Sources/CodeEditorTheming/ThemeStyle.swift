import CodeEditorDesignTokens
import Foundation

/// The full visual surface of a theme. Decoded from Zed's flat dotted
/// `style` object via custom Codable; each sub-struct receives a slice of
/// the flat dictionary scoped to its prefix.
public struct ThemeStyle: Hashable, Sendable, Codable {
    /// Top-level window/canvas background.
    public let background: Tokens.Color
    /// Optional `background.appearance` Zed key — `"opaque"` or `"blurred"`.
    public let backgroundAppearance: String?
    /// Editor canvas colors.
    public let editor: EditorColors
    /// Window-chrome colors.
    public let chrome: ChromeColors
    /// Element-state colors (element.* and ghost_element.*).
    public let elements: ElementStates
    /// Border colors.
    public let borders: BorderColors
    /// Text colors at five emphasis levels.
    public let text: TextLevels
    /// Icon colors at five emphasis levels.
    public let icon: IconLevels
    /// Status palette (info/success/warning/error/conflict).
    public let status: StatusPalette
    /// VCS palette (created/modified/deleted/renamed/ignored/hidden/unreachable).
    public let vcs: VCSPalette
    /// Scrollbar colors.
    public let scrollbar: ScrollbarColors
    /// Search-result colors.
    public let search: SearchColors
    /// Predictive (inline-suggestion) colors.
    public let predictive: PredictiveColors
    /// Inlay-hint colors.
    public let hint: HintColors
    /// Drop-target overlay color.
    public let dropTarget: Tokens.Color
    /// Hovered-link text color.
    public let linkTextHover: Tokens.Color
    /// Players array — `[0]` is the local user, others reserved.
    public let players: [Player]
    /// Accent palette (1+ colors used by the chrome).
    public let accents: [Tokens.Color]
    /// Per-token syntax styles, keyed verbatim by Zed token name.
    public let syntax: [String: SyntaxStyle]
    /// Optional terminal palette (future-compat).
    public let terminal: TerminalColors?
    /// Unknown dotted keys preserved for roundtrip fidelity.
    public let extras: [String: Tokens.Color]

    /// Memberwise builder.
    public init(
        background: Tokens.Color,
        backgroundAppearance: String?,
        editor: EditorColors,
        chrome: ChromeColors,
        elements: ElementStates,
        borders: BorderColors,
        text: TextLevels,
        icon: IconLevels,
        status: StatusPalette,
        vcs: VCSPalette,
        scrollbar: ScrollbarColors,
        search: SearchColors,
        predictive: PredictiveColors,
        hint: HintColors,
        dropTarget: Tokens.Color,
        linkTextHover: Tokens.Color,
        players: [Player],
        accents: [Tokens.Color],
        syntax: [String: SyntaxStyle],
        terminal: TerminalColors?,
        extras: [String: Tokens.Color] = [:]
    ) {
        self.background = background
        self.backgroundAppearance = backgroundAppearance
        self.editor = editor
        self.chrome = chrome
        self.elements = elements
        self.borders = borders
        self.text = text
        self.icon = icon
        self.status = status
        self.vcs = vcs
        self.scrollbar = scrollbar
        self.search = search
        self.predictive = predictive
        self.hint = hint
        self.dropTarget = dropTarget
        self.linkTextHover = linkTextHover
        self.players = players
        self.accents = accents
        self.syntax = syntax
        self.terminal = terminal
        self.extras = extras
    }

    /// Top-level keys that carry structured (non-color-string) values.
    private static let structuredKeys: Set<String> = [
        "syntax", "players", "accents", "platform", "terminal"
    ]
    /// Top-level keys that carry plain-string values (not hex colors).
    private static let stringValueKeys: Set<String> = ["background.appearance"]

    public init(from decoder: Decoder) throws {
        let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector
            ?? WarningCollector()
        let appearance = (decoder.userInfo[.themeAppearance] as? AppearanceHolder)?.appearance
            ?? .dark
        let dyn = try decoder.container(keyedBy: DynamicCodingKey.self)

        // Pass 1: separate structured keys from flat color keys.
        var flat: [String: Tokens.Color] = [:]
        var bgAppearance: String?
        for key in dyn.allKeys {
            if Self.structuredKeys.contains(key.stringValue) { continue }
            if Self.stringValueKeys.contains(key.stringValue) {
                bgAppearance = try? dyn.decode(String.self, forKey: key)
                continue
            }
            // Color-valued key; bridge through ZedColorBridge.
            if let hex = try? dyn.decode(String.self, forKey: key),
               let color = ZedColorBridge.parse(hex, path: key.stringValue, warnings: warnings) {
                flat[key.stringValue] = color
            }
        }

        self.background = flat["background"]
            ?? warnings.missing(
                path: "style",
                key: "background",
                fallback: ThemeFallbackPalette.background(appearance)
            )
        self.backgroundAppearance = bgAppearance
        self.dropTarget = flat["drop_target.background"]
            ?? warnings.missing(
                path: "style",
                key: "drop_target.background",
                fallback: ThemeFallbackPalette.dropTarget(appearance)
            )
        self.linkTextHover = flat["link_text.hover"]
            ?? warnings.missing(
                path: "style",
                key: "link_text.hover",
                fallback: ThemeFallbackPalette.textAccent(appearance)
            )

        let editor = EditorColors(
            flat: flat, warnings: warnings, path: "style", appearance: appearance
        )
        let chrome = ChromeColors(
            flat: flat, warnings: warnings, path: "style", appearance: appearance
        )
        let elements = ElementStates(
            flat: flat, warnings: warnings, path: "style", appearance: appearance
        )
        let borders = BorderColors(
            flat: flat, warnings: warnings, path: "style", appearance: appearance
        )
        let text = TextLevels(
            flat: flat, warnings: warnings, path: "style", appearance: appearance
        )
        let icon = IconLevels(
            flat: flat, warnings: warnings, path: "style", appearance: appearance
        )
        let status = StatusPalette(
            flat: flat, warnings: warnings, path: "style", appearance: appearance
        )
        let vcs = VCSPalette(
            flat: flat, warnings: warnings, path: "style", appearance: appearance
        )
        let scrollbar = ScrollbarColors(
            flat: flat, warnings: warnings, path: "style", appearance: appearance
        )
        let search = SearchColors(flat: flat, warnings: warnings, path: "style")
        let predictive = PredictiveColors(
            flat: flat, warnings: warnings, path: "style", appearance: appearance
        )
        let hint = HintColors(
            flat: flat, warnings: warnings, path: "style", appearance: appearance
        )
        self.editor = editor
        self.chrome = chrome
        self.elements = elements
        self.borders = borders
        self.text = text
        self.icon = icon
        self.status = status
        self.vcs = vcs
        self.scrollbar = scrollbar
        self.search = search
        self.predictive = predictive
        self.hint = hint

        // Pass 2: structured maps and arrays.
        self.syntax = (try? dyn.decode(
            [String: SyntaxStyle].self,
            forKey: DynamicCodingKey(stringValue: "syntax")
        )) ?? [:]
        self.players = (try? dyn.decode(
            [Player].self,
            forKey: DynamicCodingKey(stringValue: "players")
        )) ?? []
        let accentsHex = (try? dyn.decode(
            [String].self,
            forKey: DynamicCodingKey(stringValue: "accents")
        )) ?? []
        self.accents = accentsHex.compactMap {
            ZedColorBridge.parse($0, path: "style.accents", warnings: warnings)
        }
        self.terminal = try? dyn.decode(
            TerminalColors.self, forKey: DynamicCodingKey(stringValue: "terminal")
        )

        // Pass 3: collect any flat keys that didn't land in a known sub-struct.
        var consumedKeys: Set<String> = ["background", "drop_target.background", "link_text.hover"]
        var probe: [String: Tokens.Color] = [:]
        editor.flatten(into: &probe)
        chrome.flatten(into: &probe)
        elements.flatten(into: &probe)
        borders.flatten(into: &probe)
        text.flatten(into: &probe)
        icon.flatten(into: &probe)
        status.flatten(into: &probe)
        vcs.flatten(into: &probe)
        scrollbar.flatten(into: &probe)
        search.flatten(into: &probe)
        predictive.flatten(into: &probe)
        hint.flatten(into: &probe)
        consumedKeys.formUnion(probe.keys)
        self.extras = Dictionary(uniqueKeysWithValues:
            flat.filter { !consumedKeys.contains($0.key) }.map { ($0.key, $0.value) })
    }

    public func encode(to encoder: Encoder) throws {
        var dyn = encoder.container(keyedBy: DynamicCodingKey.self)
        var flat: [String: Tokens.Color] = [:]
        flat["background"] = background
        flat["drop_target.background"] = dropTarget
        flat["link_text.hover"] = linkTextHover
        editor.flatten(into: &flat)
        chrome.flatten(into: &flat)
        elements.flatten(into: &flat)
        borders.flatten(into: &flat)
        text.flatten(into: &flat)
        icon.flatten(into: &flat)
        status.flatten(into: &flat)
        vcs.flatten(into: &flat)
        scrollbar.flatten(into: &flat)
        search.flatten(into: &flat)
        predictive.flatten(into: &flat)
        hint.flatten(into: &flat)
        for (key, value) in extras { flat[key] = value }

        for (key, value) in flat {
            try dyn.encode(
                ZedColorBridge.encode(value),
                forKey: DynamicCodingKey(stringValue: key)
            )
        }
        if let bgAppearance = backgroundAppearance {
            try dyn.encode(
                bgAppearance,
                forKey: DynamicCodingKey(stringValue: "background.appearance")
            )
        }
        try dyn.encode(syntax, forKey: DynamicCodingKey(stringValue: "syntax"))
        try dyn.encode(players, forKey: DynamicCodingKey(stringValue: "players"))
        try dyn.encode(
            accents.map(ZedColorBridge.encode),
            forKey: DynamicCodingKey(stringValue: "accents")
        )
        if let terminal {
            try dyn.encode(terminal, forKey: DynamicCodingKey(stringValue: "terminal"))
        }
    }
}

extension PlatformExtension {
    /// Synthesize a `PlatformExtension` from a `ThemeStyle` when the JSON
    /// omits the `platform` key. Glass tint = editor.background at 12%
    /// alpha; popover shadow = soft drop tuned to appearance; field colors
    /// derived from element states + borders.
    public static func derived(from style: ThemeStyle, appearance: Theme.Appearance) -> PlatformExtension {
        let bg = style.editor.background
        let glassTint = Tokens.Color(red: bg.red, green: bg.green, blue: bg.blue, alpha: 0.12)
        let scheme: Tokens.Elevation.Scheme = appearance == .dark ? .dark : .light
        let elevation = Tokens.Elevation.popover(scheme)
        let popover = PlatformExtension.Shadow(
            color: elevation.color, blur: elevation.blur, xOffset: elevation.x, yOffset: elevation.y
        )
        let field = PlatformExtension.Field(
            fill: style.elements.element.background,
            border: style.borders.base,
            focusedBorder: style.borders.focused
        )
        let onRole = appearance == .light
            ? Tokens.Color(hex: 0xFF_FF_FF) : Tokens.Color(hex: 0x05_06_0A)
        return PlatformExtension(
            glass: PlatformExtension.Glass(tint: glassTint, opacity: 0.12),
            shadows: PlatformExtension.Shadows(popover: popover),
            field: field,
            onAccent: onRole,
            onDanger: onRole
        )
    }
}
