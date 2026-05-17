import Foundation

extension IndexSet {
    /// Apply mutations to the index set.
    package mutating func applying(_ mutations: [RangeMutation]) {
        self = RangeMutationEngine.transform(self, applying: mutations, policy: .preserveSurvivingSegments)
    }
}
