import CodeEditorDesignTokens
import Foundation

/// Window-chrome colors — title bar, tab bar, status bar, toolbar, panels.
/// Mapped to Zed's `title_bar.*` / `tab_bar.*` / `tab.*` / `status_bar.*` /
/// `toolbar.*` / `surface.*` / `elevated_surface.*` / `panel.*` / `pane.*`
/// / `pane_group.*` keys.
public struct ChromeColors: Hashable, Sendable, Codable {
    /// Title bar background (active window).
    public let titleBarBackground: Tokens.Color
    /// Title bar background (inactive window).
    public let titleBarInactiveBackground: Tokens.Color
    /// Tab strip background.
    public let tabBarBackground: Tokens.Color
    /// Active tab background.
    public let tabActiveBackground: Tokens.Color
    /// Inactive tab background.
    public let tabInactiveBackground: Tokens.Color
    /// Status bar background.
    public let statusBarBackground: Tokens.Color
    /// Toolbar background.
    public let toolbarBackground: Tokens.Color
    /// Generic surface background.
    public let surfaceBackground: Tokens.Color
    /// Elevated surface background (popovers, sheets).
    public let elevatedSurfaceBackground: Tokens.Color
    /// Side panel background.
    public let panelBackground: Tokens.Color
    /// Border color when a panel has focus.
    public let panelFocusedBorder: Tokens.Color
    /// Indent-guide line in panel views.
    public let panelIndentGuide: Tokens.Color
    /// Indent-guide line in panel views, active state.
    public let panelIndentGuideActive: Tokens.Color
    /// Indent-guide line in panel views, hover state.
    public let panelIndentGuideHover: Tokens.Color
    /// Border color when a pane has focus.
    public let paneFocusedBorder: Tokens.Color
    /// Border color around pane groups.
    public let paneGroupBorder: Tokens.Color
    /// Unknown chrome.* keys preserved on decode.
    public let extras: [String: Tokens.Color]

    /// Memberwise builder.
    public init(
        titleBarBackground: Tokens.Color,
        titleBarInactiveBackground: Tokens.Color,
        tabBarBackground: Tokens.Color,
        tabActiveBackground: Tokens.Color,
        tabInactiveBackground: Tokens.Color,
        statusBarBackground: Tokens.Color,
        toolbarBackground: Tokens.Color,
        surfaceBackground: Tokens.Color,
        elevatedSurfaceBackground: Tokens.Color,
        panelBackground: Tokens.Color,
        panelFocusedBorder: Tokens.Color,
        panelIndentGuide: Tokens.Color,
        panelIndentGuideActive: Tokens.Color,
        panelIndentGuideHover: Tokens.Color,
        paneFocusedBorder: Tokens.Color,
        paneGroupBorder: Tokens.Color,
        extras: [String: Tokens.Color] = [:]
    ) {
        self.titleBarBackground = titleBarBackground
        self.titleBarInactiveBackground = titleBarInactiveBackground
        self.tabBarBackground = tabBarBackground
        self.tabActiveBackground = tabActiveBackground
        self.tabInactiveBackground = tabInactiveBackground
        self.statusBarBackground = statusBarBackground
        self.toolbarBackground = toolbarBackground
        self.surfaceBackground = surfaceBackground
        self.elevatedSurfaceBackground = elevatedSurfaceBackground
        self.panelBackground = panelBackground
        self.panelFocusedBorder = panelFocusedBorder
        self.panelIndentGuide = panelIndentGuide
        self.panelIndentGuideActive = panelIndentGuideActive
        self.panelIndentGuideHover = panelIndentGuideHover
        self.paneFocusedBorder = paneFocusedBorder
        self.paneGroupBorder = paneGroupBorder
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
        let surface = ThemeFallbackPalette.surface(appearance)
        let bg = ThemeFallbackPalette.background(appearance)
        let border = ThemeFallbackPalette.border(appearance)
        let accent = ThemeFallbackPalette.textAccent(appearance)
        self.titleBarBackground = flat["title_bar.background"]
            ?? warnings.missing(path: path, key: "title_bar.background", fallback: surface)
        self.titleBarInactiveBackground = flat["title_bar.inactive_background"]
            ?? warnings.missing(path: path, key: "title_bar.inactive_background", fallback: bg)
        self.tabBarBackground = flat["tab_bar.background"]
            ?? warnings.missing(path: path, key: "tab_bar.background", fallback: bg)
        self.tabActiveBackground = flat["tab.active_background"]
            ?? warnings.missing(path: path, key: "tab.active_background", fallback: surface)
        self.tabInactiveBackground = flat["tab.inactive_background"]
            ?? warnings.missing(path: path, key: "tab.inactive_background", fallback: bg)
        self.statusBarBackground = flat["status_bar.background"]
            ?? warnings.missing(path: path, key: "status_bar.background", fallback: surface)
        self.toolbarBackground = flat["toolbar.background"]
            ?? warnings.missing(path: path, key: "toolbar.background", fallback: surface)
        self.surfaceBackground = flat["surface.background"]
            ?? warnings.missing(path: path, key: "surface.background", fallback: surface)
        self.elevatedSurfaceBackground = flat["elevated_surface.background"]
            ?? warnings.missing(
                path: path, key: "elevated_surface.background", fallback: surface
            )
        self.panelBackground = flat["panel.background"]
            ?? warnings.missing(path: path, key: "panel.background", fallback: surface)
        self.panelFocusedBorder = flat["panel.focused_border"]
            ?? warnings.missing(path: path, key: "panel.focused_border", fallback: accent)
        self.panelIndentGuide = flat["panel.indent_guide"]
            ?? warnings.missing(path: path, key: "panel.indent_guide", fallback: border)
        self.panelIndentGuideActive = flat["panel.indent_guide_active"]
            ?? warnings.missing(
                path: path, key: "panel.indent_guide_active", fallback: accent
            )
        self.panelIndentGuideHover = flat["panel.indent_guide_hover"]
            ?? warnings.missing(
                path: path, key: "panel.indent_guide_hover", fallback: accent
            )
        self.paneFocusedBorder = flat["pane.focused_border"]
            ?? warnings.missing(path: path, key: "pane.focused_border", fallback: accent)
        self.paneGroupBorder = flat["pane_group.border"]
            ?? warnings.missing(path: path, key: "pane_group.border", fallback: border)
        self.extras = Dictionary(uniqueKeysWithValues:
            flat.filter { Self.consumes($0.key) && !Self.knownKeys.contains($0.key) }
                .map { ($0.key, $0.value) })
    }

    /// Emit own keys back into a flat dictionary.
    package func flatten(into dict: inout [String: Tokens.Color]) {
        dict["title_bar.background"] = titleBarBackground
        dict["title_bar.inactive_background"] = titleBarInactiveBackground
        dict["tab_bar.background"] = tabBarBackground
        dict["tab.active_background"] = tabActiveBackground
        dict["tab.inactive_background"] = tabInactiveBackground
        dict["status_bar.background"] = statusBarBackground
        dict["toolbar.background"] = toolbarBackground
        dict["surface.background"] = surfaceBackground
        dict["elevated_surface.background"] = elevatedSurfaceBackground
        dict["panel.background"] = panelBackground
        dict["panel.focused_border"] = panelFocusedBorder
        dict["panel.indent_guide"] = panelIndentGuide
        dict["panel.indent_guide_active"] = panelIndentGuideActive
        dict["panel.indent_guide_hover"] = panelIndentGuideHover
        dict["pane.focused_border"] = paneFocusedBorder
        dict["pane_group.border"] = paneGroupBorder
        for (key, value) in extras { dict[key] = value }
    }

    /// Returns true if a flat key falls inside one of the prefixes this
    /// sub-struct owns.
    package static func consumes(_ key: String) -> Bool {
        key.hasPrefix("title_bar.") || key.hasPrefix("tab_bar.")
            || key.hasPrefix("tab.") || key.hasPrefix("status_bar.")
            || key.hasPrefix("toolbar.") || key.hasPrefix("surface.")
            || key.hasPrefix("elevated_surface.") || key.hasPrefix("panel.")
            || key.hasPrefix("pane.") || key.hasPrefix("pane_group.")
    }

    static let knownKeys: Set<String> = [
        "title_bar.background",
        "title_bar.inactive_background",
        "tab_bar.background",
        "tab.active_background",
        "tab.inactive_background",
        "status_bar.background",
        "toolbar.background",
        "surface.background",
        "elevated_surface.background",
        "panel.background",
        "panel.focused_border",
        "panel.indent_guide",
        "panel.indent_guide_active",
        "panel.indent_guide_hover",
        "pane.focused_border",
        "pane_group.border"
    ]
}
