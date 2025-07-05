import CoreGraphics
import Foundation

extension CGPoint {
    /// Returns a new point moved by the given deltas
    func moved(dx: CGFloat, dy: CGFloat) -> CGPoint {
        CGPoint(x: x + dx, y: y + dy)
    }
}
