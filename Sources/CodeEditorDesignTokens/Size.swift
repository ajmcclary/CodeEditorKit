import Foundation

extension Tokens {
    /// Icon, touch-target, and avatar sizes. Mirrors the size section of
    /// `Design/tokens.css`.
    public enum Size {
        /// Icon-glyph standard sizes.
        public enum Icon {
            /// 10pt — small status indicator.
            public static let indicator: Double = 10
            /// 12pt — micro icon.
            public static let micro: Double = 12
            /// 16pt — extra-small icon.
            public static let xs: Double = 16
            /// 18pt — small icon.
            public static let sm: Double = 18
            /// 24pt — medium icon.
            public static let md: Double = 24
            /// 32pt — large icon.
            public static let lg: Double = 32
            /// 44pt — extra-large icon.
            public static let xl: Double = 44
            /// 48pt — XXL icon.
            public static let xxl: Double = 48
        }

        /// Tappable-target heights.
        public enum Touch {
            /// 44pt — Apple HIG minimum tappable target.
            public static let min: Double = 44
            /// 48pt — comfortable target.
            public static let comfortable: Double = 48
            /// 52pt — list-row standard.
            public static let row: Double = 52
            /// 56pt — large/primary target.
            public static let large: Double = 56
        }

        /// Control / chrome heights that recur verbatim across surfaces built
        /// on this system. Mirror the control-sizing section of the CSS source.
        public enum Control {
            /// 32pt — default button / control height.
            public static let height: Double = 32
            /// 27pt — compact button / inline control.
            public static let heightCompact: Double = 27
            /// 24pt — chip-height control.
            public static let heightSmall: Double = 24
            /// 34pt — settings / list row.
            public static let row: Double = 34
            /// 28pt — dense list row.
            public static let rowCompact: Double = 28
            /// 26pt — chip / badge pill.
            public static let chip: Double = 26
            /// 38pt — toggle track width.
            public static let switchWidth: Double = 38
            /// 22pt — toggle track height.
            public static let switchHeight: Double = 22
            /// 18pt — toggle knob diameter.
            public static let switchKnob: Double = 18
            /// 2pt — active tab / active row accent bar.
            public static let accentBar: Double = 2
            /// 38pt — macOS title bar.
            public static let titleBar: Double = 38
            /// 36pt — tab strip (28pt compact).
            public static let tabStrip: Double = 36
            /// 28pt — status bar.
            public static let statusBar: Double = 28
        }

        /// Avatar / profile circle sizes.
        public enum Avatar {
            /// 24pt — extra-small avatar.
            public static let xs: Double = 24
            /// 32pt — small avatar.
            public static let sm: Double = 32
            /// 40pt — medium avatar.
            public static let md: Double = 40
            /// 48pt — large avatar.
            public static let lg: Double = 48
            /// 64pt — extra-large avatar.
            public static let xl: Double = 64
        }
    }
}
