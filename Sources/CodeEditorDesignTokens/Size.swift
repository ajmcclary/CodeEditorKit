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
