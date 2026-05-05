import Foundation

extension Tokens {
    /// Corner radii and stroke widths. Mirrors the shape section of `Design/tokens.css`.
    public enum Shape {
        /// 4pt — badge corner radius.
        public static let radiusXS: Double = 4
        /// 6pt — button corner radius.
        public static let radiusSM: Double = 6
        /// 10pt — control / card-ish corner radius.
        public static let radiusMD: Double = 10
        /// 12pt — card corner radius.
        public static let radiusLG: Double = 12
        /// 16pt — panel corner radius.
        public static let radiusXL: Double = 16
        /// 20pt — state panel / modal corner radius.
        public static let radiusXXL: Double = 20
        /// 8pt — chip corner radius.
        public static let radiusChip: Double = 8
        /// 40pt — Tahoe window corner radius.
        public static let radiusWindow: Double = 40
        /// 9999pt — fully rounded (pill).
        public static let radiusFull: Double = 9_999

        /// 0.5pt — hairline (system separator).
        public static let strokeHairline: Double = 0.5
        /// 1pt — thin stroke.
        public static let strokeThin: Double = 1
        /// 1.5pt — between thin and medium.
        public static let strokeMedLight: Double = 1.5
        /// 2pt — medium stroke.
        public static let strokeMedium: Double = 2
        /// 3pt — thick stroke.
        public static let strokeThick: Double = 3
        /// 8pt — focus ring / state ring.
        public static let strokeRing: Double = 8
    }
}
