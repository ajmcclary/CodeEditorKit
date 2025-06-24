//  Created by Claude Code
//  Missing type for versioned range tracking

import Foundation

/// A range that includes version information
public struct VersionedRange<Version: Comparable & Sendable & Hashable>: Sendable, Equatable, Hashable {
    public let range: NSRange
    public let version: Version
    
    public init(range: NSRange, version: Version) {
        self.range = range
        self.version = version
    }
    
    public init(_ range: NSRange, version: Version) {
        self.range = range
        self.version = version
    }
    
    /// Alias for range property for backward compatibility
    public var value: NSRange {
        return range
    }
}