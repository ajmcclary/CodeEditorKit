//  Created by Claude Code
//  IndexSet extensions for range processing

import Foundation

extension IndexSet {
    /// Initialize from an array of NSRanges
    public init(ranges: [NSRange]) {
        self.init()
        for range in ranges {
            self.insert(integersIn: range.location..<(range.location + range.length))
        }
    }
    
    /// Insert a range into the index set
    public mutating func insert(range: NSRange) {
        self.insert(integersIn: range.location..<(range.location + range.length))
    }
    
    /// Apply mutations to the index set
    public mutating func applying(_ mutations: [RangeMutation]) {
        // Apply each mutation in order
        for mutation in mutations {
            let range = mutation.range
            let delta = mutation.delta
            
            if delta > 0 {
                // Insertion - shift indices after the range
                let indicesToShift = self.filter { $0 >= range.location }
                for index in indicesToShift.reversed() {
                    self.remove(index)
                    self.insert(index + delta)
                }
            } else if delta < 0 {
                // Deletion - shift indices after the range and remove deleted indices
                let indicesToRemove = self.filter { 
                    $0 >= range.location && $0 < range.location + range.length 
                }
                for index in indicesToRemove {
                    self.remove(index)
                }
                
                let indicesToShift = self.filter { $0 >= range.location + range.length }
                for index in indicesToShift.reversed() {
                    self.remove(index)
                    self.insert(index + delta)
                }
            }
        }
    }
    
    /// Get NSRange view of the index set
    public var nsRangeView: [NSRange] {
        var ranges: [NSRange] = []
        self.rangeView.forEach { range in
            ranges.append(NSRange(location: range.lowerBound, length: range.count))
        }
        return ranges
    }
}