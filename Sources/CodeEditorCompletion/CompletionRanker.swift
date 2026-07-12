import CodeEditorLanguages
import Foundation

/// Applies deterministic completion deduplication and six-tier ranking.
@MainActor
struct CompletionRanker: Sendable {
    func rank(
        _ items: [CompletionItemModel],
        context: CompletionContextModel,
        learning: CompletionLearningSnapshot,
        maxCount: Int
    ) -> [CompletionItemModel] {
        var seen = Set<String>()
        let unique = items.filter { item in
            seen.insert("\(item.label):\(item.kind.rawValue)").inserted
        }

        let sorted = unique.sorted { lhs, rhs in
            switch (lhs.sortText, rhs.sortText) {
            case let (lhsText?, rhsText?) where lhsText != rhsText:
                return lhsText < rhsText

            case (.some, .none):
                return true

            case (.none, .some):
                return false

            default:
                break
            }

            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }

            let lhsFrequency = learning.usageCounts[lhs.label] ?? 0
            let rhsFrequency = learning.usageCounts[rhs.label] ?? 0
            if lhsFrequency != rhsFrequency {
                return lhsFrequency > rhsFrequency
            }

            if let lhsDate = learning.lastUsed[lhs.label],
               let rhsDate = learning.lastUsed[rhs.label],
               lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            if learning.lastUsed[lhs.label] != nil && learning.lastUsed[rhs.label] == nil {
                return true
            }
            if learning.lastUsed[lhs.label] == nil && learning.lastUsed[rhs.label] != nil {
                return false
            }

            let lhsRelevance = CompletionRankingModel.calculateRelevance(
                item: lhs,
                context: context
            )
            let rhsRelevance = CompletionRankingModel.calculateRelevance(
                item: rhs,
                context: context
            )
            if lhsRelevance != rhsRelevance {
                return lhsRelevance > rhsRelevance
            }

            if lhs.kind.defaultPriority != rhs.kind.defaultPriority {
                return lhs.kind.defaultPriority > rhs.kind.defaultPriority
            }

            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }

        return Array(sorted.prefix(max(0, maxCount)))
    }
}
