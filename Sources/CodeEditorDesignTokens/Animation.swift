import Foundation

extension Tokens {
    /// Animation durations and easings. Mirrors the animation section of
    /// `Design/tokens.css`.
    public enum Animation {
        /// 100ms — instant micro-feedback.
        public static let durInstant: Duration = .milliseconds(100)
        /// 150ms — fast tap responses.
        public static let durFast: Duration = .milliseconds(150)
        /// 200ms — quick UI changes.
        public static let durQuick: Duration = .milliseconds(200)
        /// 250ms — drawer slide.
        public static let durDrawer: Duration = .milliseconds(250)
        /// 300ms — control state changes.
        public static let durControl: Duration = .milliseconds(300)
        /// 350ms — page transitions.
        public static let durPage: Duration = .milliseconds(350)
        /// 400ms — section transitions.
        public static let durSection: Duration = .milliseconds(400)
        /// 500ms — full-screen transitions.
        public static let durScreen: Duration = .milliseconds(500)
        /// 600ms — slowest standard duration.
        public static let durVerySlow: Duration = .milliseconds(600)

        /// `cubic-bezier(0.16, 1, 0.30, 1)` — soft ease-out.
        public static let easeOutSoft = Easing(0.16, 1.00, 0.30, 1.00)
        /// `cubic-bezier(0.25, 0.80, 0.25, 1)` — soft ease-in-out.
        public static let easeInOutSoft = Easing(0.25, 0.80, 0.25, 1.00)
        /// `cubic-bezier(0.22, 1, 0.36, 1)` — snappy spring-like.
        public static let easeSpringSnappy = Easing(0.22, 1.00, 0.36, 1.00)
    }
}
