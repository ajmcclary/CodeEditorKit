import Foundation

extension Tokens {
    /// Spacing scale (points). Mirrors the spacing section of `Design/tokens.css`.
    public enum Spacing {
        /// 2pt.
        public static let xxxs: Double = 2
        /// 4pt.
        public static let xxs: Double = 4
        /// 6pt.
        public static let xs: Double = 6
        /// 8pt.
        public static let sm: Double = 8
        /// 10pt.
        public static let smMd: Double = 10
        /// 12pt.
        public static let md: Double = 12
        /// 16pt.
        public static let lg: Double = 16
        /// 20pt.
        public static let xl: Double = 20
        /// 24pt.
        public static let xxl: Double = 24
        /// 32pt.
        public static let xxxl: Double = 32

        /// 16pt — default card padding.
        public static let cardPadding: Double = lg
        /// 20pt — between sections.
        public static let section: Double = xl
        /// 24pt — content padding.
        public static let content: Double = xxl
    }
}
