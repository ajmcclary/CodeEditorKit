import Foundation

extension IndexSet {
    /// Apply mutations to the index set.
    mutating func applying(_ mutations: [RangeMutation]) {
        self = RangeMutationEngine.transform(self, applying: mutations, policy: .preserveSurvivingSegments)
    }
}
