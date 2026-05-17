import Foundation

extension NSRange {
    /// Apply a range mutation to this range.
    package func apply(_ mutation: RangeMutation) -> NSRange? {
        RangeMutationEngine.transformSingle(self, applying: mutation, policy: .invalidateOnOverlap)
    }
}
