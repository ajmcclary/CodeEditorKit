import Foundation

extension Tokens {
    /// Fallback Apple system colors — used as defaults when no theme is
    /// active. The active palette comes from a loaded `Theme` (sub-project 2).
    /// Mirrors the accent / status / ANSI sections of `Design/tokens.css`.
    public enum Palette {

        /// Apple `systemBlue` reference colors with derived hover/pressed/tint
        /// variants. Variants are pre-computed via linear sRGB blend (channel
        /// × X/100) for darker forms, alpha for tints.
        public enum Accent {
            /// `#0A84FF` — systemBlue dark.
            public static let dark = Color(hex: 0x0A84FF)
            /// `#007AFF` — systemBlue light.
            public static let light = Color(hex: 0x007AFF)
            /// White on accent.
            public static let contrast = Color(hex: 0xFFFFFF)

            /// `#0977E6` — 90% accent + 10% black (linear sRGB blend).
            public static let hoverDark = Color(hex: 0x0977E6)
            /// `#086ACC` — 80% accent + 20% black (linear sRGB blend).
            public static let pressedDark = Color(hex: 0x086ACC)

            /// `#006EE6` — 90% accent + 10% black (linear sRGB blend).
            public static let hoverLight = Color(hex: 0x006EE6)
            /// `#0062CC` — 80% accent + 20% black (linear sRGB blend).
            public static let pressedLight = Color(hex: 0x0062CC)

            /// Accent (dark) at 10% alpha — for hover / row-selected fills.
            public static let tint10Dark = Color(hex: 0x0A84FF, alpha: 0.10)
            public static let tint15Dark = Color(hex: 0x0A84FF, alpha: 0.15)
            public static let tint20Dark = Color(hex: 0x0A84FF, alpha: 0.20)
            public static let tint25Dark = Color(hex: 0x0A84FF, alpha: 0.25)

            public static let tint10Light = Color(hex: 0x007AFF, alpha: 0.10)
            public static let tint15Light = Color(hex: 0x007AFF, alpha: 0.15)
            public static let tint20Light = Color(hex: 0x007AFF, alpha: 0.20)
            public static let tint25Light = Color(hex: 0x007AFF, alpha: 0.25)
        }

        /// Status palette in dark and light variants.
        public enum Status {
            /// `#30D158` — systemGreen dark.
            public static let successDark = Color(hex: 0x30D158)
            /// `#FF9F0A` — systemOrange dark.
            public static let warningDark = Color(hex: 0xFF9F0A)
            /// `#FF453A` — systemRed dark.
            public static let errorDark = Color(hex: 0xFF453A)
            /// `#0A84FF` — systemBlue dark.
            public static let infoDark = Color(hex: 0x0A84FF)
            /// `#FFD60A` — systemYellow dark.
            public static let cautionDark = Color(hex: 0xFFD60A)

            /// `#34C759` — systemGreen light.
            public static let successLight = Color(hex: 0x34C759)
            /// `#FF9500` — systemOrange light.
            public static let warningLight = Color(hex: 0xFF9500)
            /// `#FF3B30` — systemRed light.
            public static let errorLight = Color(hex: 0xFF3B30)
            /// `#007AFF` — systemBlue light.
            public static let infoLight = Color(hex: 0x007AFF)
        }

        /// ANSI terminal palette (dark variant — VS Code Bridge terminal).
        public enum ANSI {
            public static let black = Color(hex: 0x1E1E1E)
            public static let red = Color(hex: 0xF44747)
            public static let green = Color(hex: 0x6A9955)
            public static let yellow = Color(hex: 0xD7BA7D)
            public static let blue = Color(hex: 0x569CD6)
            public static let magenta = Color(hex: 0xC39BD3)
            public static let cyan = Color(hex: 0x4DD0E1)
            public static let white = Color(hex: 0xD4D4D4)
        }
    }
}
