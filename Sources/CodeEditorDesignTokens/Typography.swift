import Foundation

extension Tokens {
    /// Type stacks, scale, weights, line heights, and tracking.
    /// Mirrors the typography section of `Design/tokens.css`.
    public enum Typography {

        /// SF / system sans stack with Helvetica Neue / Arial fallback.
        public static let fontSansStack: [String] = [
            "-apple-system", "BlinkMacSystemFont", "SF Pro Text", "SF Pro Display",
            "Inter", "system-ui", "Helvetica Neue", "Arial", "sans-serif"
        ]

        /// Display variant of the system sans stack.
        public static let fontDisplayStack: [String] = [
            "-apple-system", "BlinkMacSystemFont", "SF Pro Display",
            "Inter", "system-ui", "sans-serif"
        ]

        /// Rounded variant (SF Pro Rounded). Used for hero/display moments.
        public static let fontRoundedStack: [String] = [
            "ui-rounded", "SF Pro Rounded", "-apple-system",
            "Nunito", "system-ui", "sans-serif"
        ]

        /// Monospace stack for code.
        public static let fontMonoStack: [String] = [
            "ui-monospace", "SF Mono", "JetBrains Mono", "Menlo",
            "Roboto Mono", "Consolas", "monospace"
        ]

        /// Type scale in points. Names mirror Apple typography roles.
        public enum Size {
            /// 80pt — onboarding hero.
            public static let displayXL: Double = 80
            public static let displayLG: Double = 60
            public static let displayMD: Double = 48
            public static let displaySM: Double = 44
            /// 34pt — Apple `.largeTitle`.
            public static let titleXL: Double = 34
            /// 28pt — Apple `.title`.
            public static let titleLG: Double = 28
            /// 22pt — Apple `.title2`.
            public static let titleMD: Double = 22
            /// 20pt — Apple `.title3`.
            public static let titleSM: Double = 20
            /// 17pt — Apple `.headline`.
            public static let headingLG: Double = 17
            /// 15pt — Apple `.subheadline`.
            public static let headingMD: Double = 15
            /// 17pt — Apple `.body`.
            public static let bodyLG: Double = 17
            /// 16pt — Apple `.callout`.
            public static let bodyMD: Double = 16
            /// 13pt — Apple `.footnote`.
            public static let bodySM: Double = 13
            /// 12pt — Apple `.caption`.
            public static let captionLG: Double = 12
            /// 11pt — Apple `.caption2`.
            public static let captionMD: Double = 11
            /// 11pt — uppercase overline.
            public static let overline: Double = 11
        }

        /// Numeric font weights matching the SwiftUI/CSS convention.
        public enum Weight {
            public static let regular = 400
            public static let medium = 500
            public static let semibold = 600
            public static let bold = 700
        }

        /// Line-height multipliers.
        public enum LineHeight {
            public static let tight: Double = 1.0
            public static let normal: Double = 1.2
            public static let relaxed: Double = 1.5
        }

        /// Letter-spacing tokens.
        public enum Tracking {
            /// 0.5px — used for uppercase overlines and small caps.
            public static let caps: Double = 0.5
        }
    }
}
