import Foundation

extension Tokens {
    /// Cubic-bezier easing expressed as four control points.
    ///
    /// Bridging to `SwiftUI.Animation.timingCurve(...)` lives in
    /// `CodeEditorPlugin`, not here.
    public struct Easing: Hashable, Sendable, Codable {
        /// First control-point x coordinate.
        public let x1: Double
        /// First control-point y coordinate.
        public let y1: Double
        /// Second control-point x coordinate.
        public let x2: Double
        /// Second control-point y coordinate.
        public let y2: Double

        /// Build a cubic-bezier easing from its four control-point coordinates,
        /// matching the CSS `cubic-bezier(x1, y1, x2, y2)` ordering.
        public init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
            self.x1 = x1
            self.y1 = y1
            self.x2 = x2
            self.y2 = y2
        }
    }
}
