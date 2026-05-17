import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension CGRect {
    /// Returns a pixel-aligned rect
    public var pixelAligned: CGRect {
        #if canImport(AppKit)
        return NSIntegralRectWithOptions(self, .alignAllEdgesNearest)
        #else
        return integral
        #endif
    }

    /// Check if two rects are almost equal (within a small epsilon)
    public func isAlmostEqual(to other: CGRect, epsilon: CGFloat = 0.001) -> Bool {
        abs(origin.x - other.origin.x) < epsilon &&
            abs(origin.y - other.origin.y) < epsilon &&
            abs(size.width - other.size.width) < epsilon &&
            abs(size.height - other.size.height) < epsilon
    }
}
