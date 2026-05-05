import CodeEditorDesignTokens
import Foundation

/// UI-element state colors — five interaction states (background/hover/
/// active/selected/disabled), exposed twice: once for `element.*` and once
/// for `ghost_element.*` (transparent variants).
public struct ElementStates: Hashable, Sendable, Codable {
    /// Five interaction states for an element-class surface.
    public struct States: Hashable, Sendable, Codable {
        /// Default fill.
        public let background: Tokens.Color
        /// Hover fill.
        public let hover: Tokens.Color
        /// Active (pressed) fill.
        public let active: Tokens.Color
        /// Selected fill.
        public let selected: Tokens.Color
        /// Disabled fill.
        public let disabled: Tokens.Color

        /// Memberwise builder.
        public init(
            background: Tokens.Color,
            hover: Tokens.Color,
            active: Tokens.Color,
            selected: Tokens.Color,
            disabled: Tokens.Color
        ) {
            self.background = background
            self.hover = hover
            self.active = active
            self.selected = selected
            self.disabled = disabled
        }
    }

    /// Solid `element.*` states.
    public let element: States
    /// Translucent `ghost_element.*` states.
    public let ghostElement: States

    /// Memberwise builder.
    public init(element: States, ghostElement: States) {
        self.element = element
        self.ghostElement = ghostElement
    }

    /// Build from a flat dictionary keyed by Zed dotted names.
    init(flat: [String: Tokens.Color], warnings: WarningCollector, path: String) {
        let appearance: Theme.Appearance = .dark
        let surface = ThemeFallbackPalette.surface(appearance)
        let accent = ThemeFallbackPalette.textAccent(appearance)
        let translucent = Tokens.Color(red: accent.red, green: accent.green, blue: accent.blue, alpha: 0.10)
        func makeStates(prefix: String, baseFallback: Tokens.Color, hoverFallback: Tokens.Color) -> States {
            let bg = flat["\(prefix).background"]
                ?? warnings.missing(
                    path: path, key: "\(prefix).background", fallback: baseFallback
                )
            let hover = flat["\(prefix).hover"]
                ?? warnings.missing(
                    path: path, key: "\(prefix).hover", fallback: hoverFallback
                )
            let active = flat["\(prefix).active"]
                ?? warnings.missing(
                    path: path, key: "\(prefix).active", fallback: hoverFallback
                )
            let selected = flat["\(prefix).selected"]
                ?? warnings.missing(
                    path: path, key: "\(prefix).selected", fallback: hoverFallback
                )
            let disabled = flat["\(prefix).disabled"]
                ?? warnings.missing(
                    path: path, key: "\(prefix).disabled", fallback: baseFallback
                )
            return States(
                background: bg,
                hover: hover,
                active: active,
                selected: selected,
                disabled: disabled
            )
        }
        self.element = makeStates(
            prefix: "element", baseFallback: surface, hoverFallback: translucent
        )
        self.ghostElement = makeStates(
            prefix: "ghost_element",
            baseFallback: ThemeFallbackPalette.clear(),
            hoverFallback: translucent
        )
    }

    /// Emit own keys back into a flat dictionary.
    func flatten(into dict: inout [String: Tokens.Color]) {
        dict["element.background"] = element.background
        dict["element.hover"] = element.hover
        dict["element.active"] = element.active
        dict["element.selected"] = element.selected
        dict["element.disabled"] = element.disabled
        dict["ghost_element.background"] = ghostElement.background
        dict["ghost_element.hover"] = ghostElement.hover
        dict["ghost_element.active"] = ghostElement.active
        dict["ghost_element.selected"] = ghostElement.selected
        dict["ghost_element.disabled"] = ghostElement.disabled
    }
}
