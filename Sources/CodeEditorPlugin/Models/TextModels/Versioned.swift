//  Created by Claude Code  
//  Missing type stub for consolidated package

import Foundation

/// A versioned wrapper for data with associated version tracking
public struct Versioned<Version: Comparable, Value> {
    public let value: Value
    public let version: Version
    
    public init(_ value: Value, version: Version) {
        self.value = value
        self.version = version
    }
}