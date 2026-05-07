import Foundation

/// Stores and merges style runs from multiple highlight providers.
///
/// Each provider writes into its own `RangeStore<StyleElement>`
/// keyed by a `ProviderID`. When queried via `mergedRuns(in:)`,
/// results are coalesced by priority (lower ID = higher priority).
@MainActor
internal final class StyledRangeContainer {
    private typealias Entry = (store: RangeStore<StyleElement>, priority: Int)

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
        let queryRange = range.lowerBound..<range.upperBound

        // Collect runs from all providers sorted by priority (lowest = highest priority).
        let sorted = entries.sorted { $0.value.priority < $1.value.priority }
        var allRuns: [(runs: [RangeStoreRun<StyleElement>], index: Int)] = sorted.map {
            ($0.value.store.runs(in: queryRange), 0)
        }

        var result: [RangeStoreRun<StyleElement>] = []
        var cursor = queryRange.lowerBound

        while cursor < queryRange.upperBound {
            var bestValue: StyleElement?
            var minLen = Int.max

            // Find the smallest run segment across all providers at this cursor.
            for idx in allRuns.indices {
                let runs = allRuns[idx].runs
                var runIdx = allRuns[idx].index
                while runIdx < runs.count {
                    let run = runs[runIdx]
                    let runLen = cursor - queryRange.lowerBound + run.length
                    if runLen > 0 {
                        let effectiveLen = min(run.length, queryRange.upperBound - cursor)
                        minLen = min(minLen, effectiveLen)
                        break
                    }
                    runIdx += 1
                }
            }

            guard minLen < Int.max else { break }

            // Determine the merged value at this segment.
            for idx in allRuns.indices {
                let runs = allRuns[idx].runs
                var runIdx = allRuns[idx].index
                while runIdx < runs.count, runIdx < runs.count {
                    let run = runs[runIdx]
                    let runStart = queryRange.lowerBound + (allRuns[idx].index > 0 ? 0 : 0)
                    if let value = run.value {
                        if let current = bestValue {
                            bestValue = current.combineHigherPriority(value)
                        } else {
                            bestValue = value
                        }
                    }
                    break
                }
            }

            result.append(RangeStoreRun(length: minLen, value: bestValue))
            cursor += minLen

            // Advance indices.
            for idx in allRuns.indices {
                var consumed = 0
                while allRuns[idx].index < allRuns[idx].runs.count, consumed < minLen {
                    let run = allRuns[idx].runs[allRuns[idx].index]
                    let available = min(run.length, minLen - consumed)
                    consumed += available
                    if available >= run.length {
                        allRuns[idx].index += 1
                    }
                }
            }
        }

        return result
    }
}

/// Converts a `TokenType` to a capture name string.
private func captureName(for type: TokenType) -> String {
    type.rawValue
}
