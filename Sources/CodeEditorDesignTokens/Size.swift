import Foundation

extension Tokens {
    /// Icon, touch-target, and avatar sizes. Mirrors the size section of
    /// `Design/tokens.css`.
    public enum Size {

        public enum Icon {
            /// 10pt — small status indicator.
            public static let indicator: Double = 10
            public static let micro: Double = 12
            public static let xs: Double = 16
            public static let sm: Double = 18
            public static let md: Double = 24
            public static let lg: Double = 32
            public static let xl: Double = 44
            public static let xxl: Double = 48
        }

        public enum Touch {
            /// 44pt — Apple HIG minimum tappable target.
            public static let min: Double = 44
            public static let comfortable: Double = 48
            /// 52pt — list-row standard.
            public static let row: Double = 52
            public static let large: Double = 56
        }

        public enum Avatar {
            public static let xs: Double = 24
            public static let sm: Double = 32
            public static let md: Double = 40
            public static let lg: Double = 48
            public static let xl: Double = 64
        }
    }
}
