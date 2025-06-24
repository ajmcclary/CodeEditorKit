//  Created by Claude Code
//  Missing type stub for consolidated package

import Foundation

/// Represents a mutation operation on a text range
public struct RangeMutation: Equatable {
    public let range: NSRange
    public let delta: Int
    public let version: Int
    
    public init(range: NSRange, delta: Int, version: Int = 0) {
        self.range = range
        self.delta = delta
        self.version = version
    }
}