import Foundation

/// Protocol for content that has version tracking
public protocol VersionedContent: Sendable {
    associatedtype Version: Comparable, Sendable, Hashable

    var version: Version { get }
    var currentVersion: Version { get }
    var currentLength: Int { get }
}
