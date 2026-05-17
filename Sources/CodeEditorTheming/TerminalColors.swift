import CodeEditorDesignTokens
import Foundation

/// Reserved for future terminal pane support. Every field optional; absent
/// from most Zed JSONs in the wild. Sub-project 2 only models the shape so
/// roundtrip preserves any values that are present.
public struct TerminalColors: Hashable, Sendable, Codable {
    /// Sixteen ANSI terminal colors (8 base + 8 bright). All optional.
    public struct ANSI: Hashable, Sendable, Codable {
        /// Black (ANSI 0).
        public let black: Tokens.Color?
        /// Red (ANSI 1).
        public let red: Tokens.Color?
        /// Green (ANSI 2).
        public let green: Tokens.Color?
        /// Yellow (ANSI 3).
        public let yellow: Tokens.Color?
        /// Blue (ANSI 4).
        public let blue: Tokens.Color?
        /// Magenta (ANSI 5).
        public let magenta: Tokens.Color?
        /// Cyan (ANSI 6).
        public let cyan: Tokens.Color?
        /// White (ANSI 7).
        public let white: Tokens.Color?
        /// Bright black (ANSI 8).
        public let brightBlack: Tokens.Color?
        /// Bright red (ANSI 9).
        public let brightRed: Tokens.Color?
        /// Bright green (ANSI 10).
        public let brightGreen: Tokens.Color?
        /// Bright yellow (ANSI 11).
        public let brightYellow: Tokens.Color?
        /// Bright blue (ANSI 12).
        public let brightBlue: Tokens.Color?
        /// Bright magenta (ANSI 13).
        public let brightMagenta: Tokens.Color?
        /// Bright cyan (ANSI 14).
        public let brightCyan: Tokens.Color?
        /// Bright white (ANSI 15).
        public let brightWhite: Tokens.Color?

        /// Memberwise builder; every parameter defaults to nil.
        public init(
            black: Tokens.Color? = nil,
            red: Tokens.Color? = nil,
            green: Tokens.Color? = nil,
            yellow: Tokens.Color? = nil,
            blue: Tokens.Color? = nil,
            magenta: Tokens.Color? = nil,
            cyan: Tokens.Color? = nil,
            white: Tokens.Color? = nil,
            brightBlack: Tokens.Color? = nil,
            brightRed: Tokens.Color? = nil,
            brightGreen: Tokens.Color? = nil,
            brightYellow: Tokens.Color? = nil,
            brightBlue: Tokens.Color? = nil,
            brightMagenta: Tokens.Color? = nil,
            brightCyan: Tokens.Color? = nil,
            brightWhite: Tokens.Color? = nil
        ) {
            self.black = black; self.red = red; self.green = green; self.yellow = yellow
            self.blue = blue; self.magenta = magenta; self.cyan = cyan; self.white = white
            self.brightBlack = brightBlack; self.brightRed = brightRed
            self.brightGreen = brightGreen; self.brightYellow = brightYellow
            self.brightBlue = brightBlue; self.brightMagenta = brightMagenta
            self.brightCyan = brightCyan; self.brightWhite = brightWhite
        }

        private enum CodingKeys: String, CodingKey {
            case black, red, green, yellow, blue, magenta, cyan, white
            case brightBlack = "bright_black"
            case brightRed = "bright_red"
            case brightGreen = "bright_green"
            case brightYellow = "bright_yellow"
            case brightBlue = "bright_blue"
            case brightMagenta = "bright_magenta"
            case brightCyan = "bright_cyan"
            case brightWhite = "bright_white"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector
                ?? WarningCollector()
            func parseIfPresent(_ key: CodingKeys) throws -> Tokens.Color? {
                guard let hex = try container.decodeIfPresent(String.self, forKey: key)
                else { return nil }
                return ZedColorBridge.parse(
                    hex, path: "terminal.ansi.\(key.rawValue)", warnings: warnings
                )
            }
            self.black = try parseIfPresent(.black); self.red = try parseIfPresent(.red)
            self.green = try parseIfPresent(.green); self.yellow = try parseIfPresent(.yellow)
            self.blue = try parseIfPresent(.blue); self.magenta = try parseIfPresent(.magenta)
            self.cyan = try parseIfPresent(.cyan); self.white = try parseIfPresent(.white)
            self.brightBlack = try parseIfPresent(.brightBlack)
            self.brightRed = try parseIfPresent(.brightRed)
            self.brightGreen = try parseIfPresent(.brightGreen)
            self.brightYellow = try parseIfPresent(.brightYellow)
            self.brightBlue = try parseIfPresent(.brightBlue)
            self.brightMagenta = try parseIfPresent(.brightMagenta)
            self.brightCyan = try parseIfPresent(.brightCyan)
            self.brightWhite = try parseIfPresent(.brightWhite)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            func emit(_ color: Tokens.Color?, forKey key: CodingKeys) throws {
                try container.encodeIfPresent(color.map(ZedColorBridge.encode), forKey: key)
            }
            try emit(black, forKey: .black)
            try emit(red, forKey: .red)
            try emit(green, forKey: .green)
            try emit(yellow, forKey: .yellow)
            try emit(blue, forKey: .blue)
            try emit(magenta, forKey: .magenta)
            try emit(cyan, forKey: .cyan)
            try emit(white, forKey: .white)
            try emit(brightBlack, forKey: .brightBlack)
            try emit(brightRed, forKey: .brightRed)
            try emit(brightGreen, forKey: .brightGreen)
            try emit(brightYellow, forKey: .brightYellow)
            try emit(brightBlue, forKey: .brightBlue)
            try emit(brightMagenta, forKey: .brightMagenta)
            try emit(brightCyan, forKey: .brightCyan)
            try emit(brightWhite, forKey: .brightWhite)
        }
    }

    /// Terminal foreground color (ANSI default text).
    public let foreground: Tokens.Color?
    /// Terminal background color (ANSI default fill).
    public let background: Tokens.Color?
    /// Sixteen ANSI palette colors.
    public let ansi: ANSI?

    /// Memberwise builder; every parameter defaults to nil.
    public init(
        foreground: Tokens.Color? = nil,
        background: Tokens.Color? = nil,
        ansi: ANSI? = nil
    ) {
        self.foreground = foreground
        self.background = background
        self.ansi = ansi
    }

    private enum CodingKeys: String, CodingKey {
        case foreground, background, ansi
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector
            ?? WarningCollector()
        if let hex = try container.decodeIfPresent(String.self, forKey: .foreground) {
            self.foreground = ZedColorBridge.parse(hex, path: "terminal.foreground", warnings: warnings)
        } else {
            self.foreground = nil
        }
        if let hex = try container.decodeIfPresent(String.self, forKey: .background) {
            self.background = ZedColorBridge.parse(hex, path: "terminal.background", warnings: warnings)
        } else {
            self.background = nil
        }
        self.ansi = try container.decodeIfPresent(ANSI.self, forKey: .ansi)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(
            foreground.map(ZedColorBridge.encode), forKey: .foreground
        )
        try container.encodeIfPresent(
            background.map(ZedColorBridge.encode), forKey: .background
        )
        try container.encodeIfPresent(ansi, forKey: .ansi)
    }
}
