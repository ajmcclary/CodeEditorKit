//  Created by Claude Code
//  NSRange extension for clamping

import Foundation

extension NSRange {
    /// Returns a range clamped to the given limiting range
    public func clamped(to limit: NSRange) -> NSRange {
        let start = max(self.location, limit.location)
        let end = min(self.upperBound, limit.upperBound)
        
        if start > end {
            return NSRange(location: limit.location, length: 0)
        }
        
        return NSRange(location: start, length: end - start)
    }
}