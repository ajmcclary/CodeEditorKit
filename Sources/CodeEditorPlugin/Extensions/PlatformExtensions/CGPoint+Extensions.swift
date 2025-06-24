//  Created by Claude Code
//  CGPoint extensions for consolidated package

import Foundation
import CoreGraphics

extension CGPoint {
    /// Returns a new point moved by the given deltas
    func moved(dx: CGFloat, dy: CGFloat) -> CGPoint {
        return CGPoint(x: self.x + dx, y: self.y + dy)
    }
}