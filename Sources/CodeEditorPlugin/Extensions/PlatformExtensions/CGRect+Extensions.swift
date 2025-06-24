//  Created by Claude Code
//  CGRect extensions for consolidated package

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension CGRect {
    /// Returns a pixel-aligned rect
    var pixelAligned: CGRect {
        #if os(macOS)
        return NSIntegralRectWithOptions(self, .alignAllEdgesNearest)
        #else
        return self.integral
        #endif
    }
    
    /// Check if two rects are almost equal (within a small epsilon)
    func isAlmostEqual(to other: CGRect, epsilon: CGFloat = 0.001) -> Bool {
        return abs(self.origin.x - other.origin.x) < epsilon &&
               abs(self.origin.y - other.origin.y) < epsilon &&
               abs(self.size.width - other.size.width) < epsilon &&
               abs(self.size.height - other.size.height) < epsilon
    }
}