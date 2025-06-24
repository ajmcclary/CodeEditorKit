//  Created by Claude Code
//  NSRange extension for applying mutations

import Foundation

extension NSRange {
    /// Apply a range mutation to this range
    public func apply(_ mutation: RangeMutation) -> NSRange? {
        let mutationRange = mutation.range
        let delta = mutation.delta
        
        // If mutation is before this range, shift the range
        if mutationRange.upperBound <= self.location {
            return NSRange(location: self.location + delta, length: self.length)
        }
        
        // If mutation is after this range, no change
        if mutationRange.location >= self.upperBound {
            return self
        }
        
        // If mutation overlaps with this range, it's more complex
        // For now, return nil to indicate the range is invalidated
        return nil
    }
}