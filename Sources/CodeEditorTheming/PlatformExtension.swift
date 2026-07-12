import CodeEditorDesignTokens
import Foundation

/// Platform-specific extension key on Zed JSON. Vanilla Zed doesn't model
/// Liquid Glass / shadows / fields, so this lives under `platform.*` in our
/// JSONs and is synthesized from the rest of the style when absent.
public struct PlatformExtension: Hashable, Sendable, Codable {
    /// Liquid Glass tint + opacity.
    public struct Glass: Hashable, Sendable, Codable {
        /// Tint color blended into the glass material.
        public let tint: Tokens.Color
        /// Glass opacity (0–1).
        public let opacity: Double

        /// Memberwise builder.
        public init(tint: Tokens.Color, opacity: Double) {
            self.tint = tint
            self.opacity = opacity
        }
    }

    /// One drop-shadow specification (color + offset + blur).
    public struct Shadow: Hashable, Sendable, Codable {
        /// Shadow color (typically translucent black).
        public let color: Tokens.Color
        /// Gaussian blur radius in points.
        public let blur: Double
        /// Horizontal offset in points.
        public let xOffset: Double
        /// Vertical offset in points.
        public let yOffset: Double

        /// Memberwise builder.
        public init(color: Tokens.Color, blur: Double, xOffset: Double, yOffset: Double) {
            self.color = color
            self.blur = blur
            self.xOffset = xOffset
            self.yOffset = yOffset
        }

        private enum CodingKeys: String, CodingKey {
            case color, blur
            case xOffset = "x"
            case yOffset = "y"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector
                ?? WarningCollector()
            let hex = try container.decode(String.self, forKey: .color)
            self.color = ZedColorBridge.parse(
                hex, path: "platform.shadows.popover.color", warnings: warnings
            ) ?? Tokens.Color(hex: 0x00_00_00, alpha: 0.5)
            self.blur = try container.decode(Double.self, forKey: .blur)
            self.xOffset = try container.decode(Double.self, forKey: .xOffset)
            self.yOffset = try container.decode(Double.self, forKey: .yOffset)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(ZedColorBridge.encode(color), forKey: .color)
            try container.encode(blur, forKey: .blur)
            try container.encode(xOffset, forKey: .xOffset)
            try container.encode(yOffset, forKey: .yOffset)
        }
    }

    /// Container holding the named shadows the chrome consumes.
    public struct Shadows: Hashable, Sendable, Codable {
        /// Popover-class drop shadow used for completion menus, command
        /// palette, tooltips.
        public let popover: Shadow

        /// Memberwise builder.
        public init(popover: Shadow) { self.popover = popover }
    }

    /// Field-style colors for the chrome's text inputs.
    public struct Field: Hashable, Sendable, Codable {
        /// Resting fill.
        public let fill: Tokens.Color
        /// Resting border.
        public let border: Tokens.Color
        /// Border when the field has focus.
        public let focusedBorder: Tokens.Color

        /// Memberwise builder.
        public init(fill: Tokens.Color, border: Tokens.Color, focusedBorder: Tokens.Color) {
            self.fill = fill
            self.border = border
            self.focusedBorder = focusedBorder
        }

        private enum CodingKeys: String, CodingKey {
            case fill, border
            case focusedBorder = "focused_border"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector
                ?? WarningCollector()
            let fillHex = try container.decode(String.self, forKey: .fill)
            let borderHex = try container.decode(String.self, forKey: .border)
            let focusedHex = try container.decode(String.self, forKey: .focusedBorder)
            self.fill = ZedColorBridge.parse(fillHex, path: "platform.field.fill", warnings: warnings)
                ?? Tokens.Color(hex: 0x10_10_10)
            self.border = ZedColorBridge.parse(
                borderHex, path: "platform.field.border", warnings: warnings
            ) ?? Tokens.Color(hex: 0x20_20_20)
            self.focusedBorder = ZedColorBridge.parse(
                focusedHex, path: "platform.field.focused_border", warnings: warnings
            ) ?? Tokens.Palette.Accent.dark
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(ZedColorBridge.encode(fill), forKey: .fill)
            try container.encode(ZedColorBridge.encode(border), forKey: .border)
            try container.encode(ZedColorBridge.encode(focusedBorder), forKey: .focusedBorder)
        }
    }

    /// Liquid Glass settings.
    public let glass: Glass
    /// Named drop-shadow specifications.
    public let shadows: Shadows
    /// Text-field styling.
    public let field: Field
    /// Text/icon color on an `accent-1` fill (primary button). CSS `--on-accent`.
    public let onAccent: Tokens.Color
    /// Text/icon color on a `diag-error` fill (destructive button). CSS `--on-danger`.
    public let onDanger: Tokens.Color
    /// Unknown `platform.*` keys preserved for forward-compat. Each is a
    /// `Tokens.Color` since most Zed-style extension values are colors;
    /// non-color values aren't preserved by this overflow bag.
    public let extras: [String: Tokens.Color]

    /// Memberwise builder.
    public init(
        glass: Glass,
        shadows: Shadows,
        field: Field,
        onAccent: Tokens.Color,
        onDanger: Tokens.Color,
        extras: [String: Tokens.Color] = [:]
    ) {
        self.glass = glass
        self.shadows = shadows
        self.field = field
        self.onAccent = onAccent
        self.onDanger = onDanger
        self.extras = extras
    }

    private enum CodingKeys: String, CodingKey {
        case glass, shadows, field
        case onAccent = "on_accent"
        case onDanger = "on_danger"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let glassContainer = try container.nestedContainer(keyedBy: GlassCodingKeys.self, forKey: .glass)
        let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector
            ?? WarningCollector()
        let tintHex = try glassContainer.decode(String.self, forKey: .tint)
        let opacity = try glassContainer.decode(Double.self, forKey: .opacity)
        let tint = ZedColorBridge.parse(tintHex, path: "platform.glass.tint", warnings: warnings)
            ?? Tokens.Color(hex: 0x7E_C8_DE)
        self.glass = Glass(tint: tint, opacity: opacity)
        self.shadows = try container.decode(Shadows.self, forKey: .shadows)
        self.field = try container.decode(Field.self, forKey: .field)

        // On-fill roles: dark themes place near-black text/icons on accent
        // fills, light themes place white. Fall back accordingly when absent.
        let appearance = (decoder.userInfo[.themeAppearance] as? AppearanceHolder)?.appearance
            ?? .dark
        let onFallback = appearance == .light
            ? Tokens.Color(hex: 0xFF_FF_FF) : Tokens.Color(hex: 0x05_06_0A)
        if let hex = try container.decodeIfPresent(String.self, forKey: .onAccent),
           let color = ZedColorBridge.parse(hex, path: "platform.on_accent", warnings: warnings) {
            self.onAccent = color
        } else {
            self.onAccent = onFallback
        }
        if let hex = try container.decodeIfPresent(String.self, forKey: .onDanger),
           let color = ZedColorBridge.parse(hex, path: "platform.on_danger", warnings: warnings) {
            self.onDanger = color
        } else {
            self.onDanger = onFallback
        }

        // Pass 2: walk all top-level keys, anything not in `known` lands in
        // `extras` and emits an `.unknownPlatformKey` warning.
        let dynContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        var extras: [String: Tokens.Color] = [:]
        let known: Set<String> = ["glass", "shadows", "field", "on_accent", "on_danger"]
        for key in dynContainer.allKeys where !known.contains(key.stringValue) {
            if let hex = try? dynContainer.decode(String.self, forKey: key),
               let color = ZedColorBridge.parse(hex, path: "platform.\(key.stringValue)", warnings: warnings) {
                warnings.record(.init(
                    kind: .unknownPlatformKey,
                    keyPath: "platform.\(key.stringValue)",
                    detail: nil
                ))
                extras[key.stringValue] = color
            }
        }
        self.extras = extras
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(glass, forKey: .glass)
        try container.encode(shadows, forKey: .shadows)
        try container.encode(field, forKey: .field)
        try container.encode(ZedColorBridge.encode(onAccent), forKey: .onAccent)
        try container.encode(ZedColorBridge.encode(onDanger), forKey: .onDanger)
        if !extras.isEmpty {
            var dyn = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in extras {
                try dyn.encode(
                    ZedColorBridge.encode(value),
                    forKey: DynamicCodingKey(stringValue: key)
                )
            }
        }
    }

    private enum GlassCodingKeys: String, CodingKey { case tint, opacity }
}
