import Foundation

/// Represents a mutation operation on a text range
public struct RangeMutation: Equatable, Sendable {
    public let range: NSRange
    public let delta: Int
    public let version: Int

    public init(range: NSRange, delta: Int, version: Int = 0) {
        self.range = range
        self.delta = delta
        self.version = version
    }

    // MARK: - Transform Operations

    /// Transform an IndexSet based on this mutation
    public func transform(set: IndexSet) -> IndexSet {
        RangeMutationEngine.transform(set, applying: self, policy: .preserveSurvivingSegments)
    }
}
