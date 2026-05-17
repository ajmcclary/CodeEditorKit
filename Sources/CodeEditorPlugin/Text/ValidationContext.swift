import CodeEditorCommon
import Foundation

/// Protocol for providing version and content information in an actor-safe manner
public protocol ValidationContext: Sendable {
    associatedtype Version: Comparable, Sendable, Hashable

    /// Get the current version of the content
    func getCurrentVersion() async -> Version

    /// Get the current length of the content
    func getCurrentLength() async -> Int
}

/// Concrete implementation that wraps a VersionedContent
public actor ValidationContextWrapper<Content: VersionedContent>: ValidationContext {
    public typealias Version = Content.Version

    private let content: Content

    public init(content: Content) {
        self.content = content
    }

    public func getCurrentVersion() async -> Version {
        content.currentVersion
    }

    public func getCurrentLength() async -> Int {
        content.currentLength
    }
}
