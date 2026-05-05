import Foundation

extension Tokens {
    /// Cubic-bezier easing expressed as four control points.
    ///
    /// Bridging to `SwiftUI.Animation.timingCurve(...)` lives in
    /// `CodeEditorPlugin`, not here.
    public struct Easing: Hashable, Sendable, Codable {
        public let x1: Double
        public let y1: Double
        public let x2: Double
        public let y2: Double

        public init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
            self.x1 = x1
            self.y1 = y1
            self.x2 = x2
            self.y2 = y2
        }
    }
}
