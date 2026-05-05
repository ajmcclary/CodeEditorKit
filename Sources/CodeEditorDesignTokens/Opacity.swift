import Foundation

extension Tokens {
    /// Opacity scale, monotonically increasing. Mirrors the opacity section
    /// of `Design/tokens.css`.
    public enum Opacity {
        /// 0.03 — barely visible.
        public static let faint: Double = 0.03
        /// 0.04.
        public static let dim: Double = 0.04
        /// 0.05.
        public static let subtle: Double = 0.05
        /// 0.06.
        public static let mist: Double = 0.06
        /// 0.08.
        public static let soft: Double = 0.08
        /// 0.10.
        public static let tint: Double = 0.10
        /// 0.12 — Liquid Glass fill.
        public static let glassFill: Double = 0.12
        /// 0.14 — Liquid Glass border.
        public static let glassBorder: Double = 0.14
        /// 0.15 — Liquid Glass inner highlight.
        public static let glassHighlight: Double = 0.15
        /// 0.20.
        public static let light: Double = 0.20
        /// 0.30 — disabled-control standard.
        public static let disabled: Double = 0.30
        /// 0.50.
        public static let medium: Double = 0.50
        /// 0.70.
        public static let strong: Double = 0.70
        /// 0.80.
        public static let heavy: Double = 0.80
        /// 0.85 — near full opacity.
        public static let near: Double = 0.85
    }
}
