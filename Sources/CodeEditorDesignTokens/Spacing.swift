import Foundation

extension Tokens {
    /// Spacing scale (points). Mirrors the spacing section of `Design/tokens.css`.
    public enum Spacing {
        public static let xxxs: Double = 2
        public static let xxs: Double = 4
        public static let xs: Double = 6
        public static let sm: Double = 8
        public static let smMd: Double = 10
        public static let md: Double = 12
        public static let lg: Double = 16
        public static let xl: Double = 20
        public static let xxl: Double = 24
        public static let xxxl: Double = 32

        /// 16pt — default card padding.
        public static let cardPadding: Double = lg
        /// 20pt — between sections.
        public static let section: Double = xl
        /// 24pt — content padding.
        public static let content: Double = xxl
    }
}
