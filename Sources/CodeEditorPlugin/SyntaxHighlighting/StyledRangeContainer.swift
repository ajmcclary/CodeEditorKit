import CodeEditorCommon
import Foundation

/// Stores and merges style runs from multiple highlight providers.
///
/// Each provider writes into its own `RangeStore<StyleElement>`
/// keyed by a `ProviderID`. When queried via `mergedRuns(in:)`,
/// results are coalesced by priority (lower ID = higher priority).
@MainActor
internal final class StyledRangeContainer {
    private typealias Entry = (store: RangeStore<StyleElement>, priority: Int)

    private struct ProviderCursor {
        var runs: [RangeStoreRun<StyleElement>]
        var index: Int
        var remaining: Int

        init(runs: [RangeStoreRun<StyleElement>]) {
            self.runs = runs
            self.index = 0
            self.remaining = runs.first?.length ?? 0
        }

        var isExhausted: Bool {
            index >= runs.count
        }

        var currentValue: StyleElement? {
            guard !isExhausted else { return nil }
            return runs[index].value
        }

        mutating func consume(_ length: Int) {
            var remainingToConsume = length
            while remainingToConsume > 0, !isExhausted {
                let consumed = min(remaining, remainingToConsume)
                remaining -= consumed
                remainingToConsume -= consumed

                if remaining == 0 {
                    index += 1
                    if !isExhausted {
                        remaining = runs[index].length
                    }
                }
            }
        }
    }

    private var entries: [Int: Entry] = [:]
    private var nextID = 0
    private var _documentLength: Int

    init(documentLength: Int) {
        self._documentLength = documentLength
    }

    /// Register a provider and return its ID.
    func registerProvider(priority: Int) -> Int {
        let id = nextID
        nextID += 1
        entries[id] = (store: RangeStore<StyleElement>(documentLength: _documentLength), priority: priority)
        return id
    }

    /// Remove a provider.
    func removeProvider(id: Int) {
        entries.removeValue(forKey: id)
    }

    // MARK: - Writing

    /// Store highlight results for a provider.
    func applyHighlightResult(providerID: Int, highlights: [HighlightedToken], range: NSRange) {
        guard var entry = entries[providerID] else { return }

        // Clear the query range first, then insert each token's range individually.
        entry.store.set(value: nil, for: range.lowerBound..<range.upperBound)
        for token in highlights {
            let capture = captureName(for: token.type)
            let tokenRange = token.range.lowerBound..<token.range.upperBound
            entry.store.set(
                value: StyleElement(capture: capture),
                for: tokenRange
            )
        }
        entries[providerID] = entry
    }

    /// Notify all stores of a document edit.
    func storageUpdated(editedRange: NSRange, changeInLength: Int) {
        _documentLength += changeInLength
        for key in entries.keys {
            entries[key]?.store.storageUpdated(
                replacedCharactersIn: editedRange.location..<(editedRange.location + editedRange.length),
                withCount: editedRange.length + changeInLength
            )
        }
    }

    // MARK: - Reading

    /// Returns merged style runs for a character range, coalesced by provider priority.
    func mergedRuns(in range: NSRange) -> [RangeStoreRun<StyleElement>] {
        guard !range.isEmpty else { return [] }
        guard !entries.isEmpty else { return [] }
        let queryRange = range.lowerBound..<range.upperBound

        // Collect runs from all providers sorted by priority (lowest = highest priority).
        let sorted = entries.sorted { $0.value.priority < $1.value.priority }
        var cursors = sorted.map {
            ProviderCursor(runs: $0.value.store.runs(in: queryRange))
        }

        var result: [RangeStoreRun<StyleElement>] = []
        var cursor = queryRange.lowerBound

        while cursor < queryRange.upperBound {
            var bestValue: StyleElement?
            let activeRemaining = cursors
                .filter { !$0.isExhausted }
                .map(\.remaining)
            let minLen = min(activeRemaining.min() ?? Int.max, queryRange.upperBound - cursor)

            guard minLen < Int.max else { break }

            // Determine the merged value at this segment. Cursors are already
            // sorted highest-to-lowest priority, so lower-priority values only
            // fill gaps left by higher-priority providers.
            for providerCursor in cursors {
                guard let value = providerCursor.currentValue, !value.isEmpty else { continue }
                if let current = bestValue {
                    bestValue = current.combineLowerPriority(value)
                } else {
                    bestValue = value
                }
            }

            if let last = result.last, last.value == bestValue {
                result[result.count - 1] = RangeStoreRun(length: last.length + minLen, value: last.value)
            } else {
                result.append(RangeStoreRun(length: minLen, value: bestValue))
            }
            cursor += minLen

            for idx in cursors.indices {
                cursors[idx].consume(minLen)
            }
        }

        return result
    }
}

/// Converts a `TokenType` to a capture name string.
private func captureName(for type: TokenType) -> String {
    type.rawValue
}
