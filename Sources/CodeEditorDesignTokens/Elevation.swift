import Foundation

extension Tokens {
    /// Elevation tokens. Shadow + focus-ring values are constant per color
    /// scheme (every dark theme shares them; every light theme shares them),
    /// so they live here rather than duplicated across per-theme palettes.
    /// Mirror the `--shadow-*` / `--focus-ring` tokens of the CSS source.
    public enum Elevation {
        /// Color scheme selector, local so this target stays free of any
        /// dependency on `CodeEditorTheming.Theme.Appearance`.
        public enum Scheme: Sendable, Hashable { case dark, light }

        /// One drop-shadow spec: color + blur + offset (x always 0 here).
        public struct Shadow: Sendable, Hashable {
            /// Shadow color (translucent black).
            public let color: Tokens.Color
            /// Gaussian blur radius in points.
            public let blur: Double
            /// Horizontal offset in points.
            public let x: Double
            /// Vertical offset in points.
            public let y: Double

            /// Memberwise builder.
            public init(color: Tokens.Color, blur: Double, x: Double, y: Double) {
                self.color = color
                self.blur = blur
                self.x = x
                self.y = y
            }
        }

        private static func shadow(_ alpha: Double, _ blur: Double, _ y: Double) -> Shadow {
            Shadow(color: Tokens.Color(hex: 0x00_00_00, alpha: alpha), blur: blur, x: 0, y: y)
        }

        /// Popover / menu / command-palette drop shadow.
        public static func popover(_ scheme: Scheme) -> Shadow {
            scheme == .dark ? shadow(0.30, 36, 10) : shadow(0.12, 32, 12)
        }

        /// Card / raised-surface drop shadow.
        public static func card(_ scheme: Scheme) -> Shadow {
            scheme == .dark ? shadow(0.18, 12, 4) : shadow(0.10, 12, 4)
        }

        /// Window-class drop shadow (floating windows, large popovers).
        public static func window(_ scheme: Scheme) -> Shadow {
            scheme == .dark ? shadow(0.55, 80, 24) : shadow(0.18, 70, 24)
        }

        /// Focus-ring stroke width in points.
        public static let focusRingWidth: Double = 3

        /// Focus ring in the live accent at 28% alpha
        /// (CSS `color-mix(in srgb, accent 28%, transparent)`).
        public static func focusRing(accent: Tokens.Color) -> Tokens.Color {
            Tokens.Color(red: accent.red, green: accent.green, blue: accent.blue, alpha: 0.28)
        }
    }
}
