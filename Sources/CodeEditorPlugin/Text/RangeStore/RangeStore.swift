import Foundation

/// Array-backed interval store for generic range-based data.
///
/// Stores a sorted list of `(offset, run)` pairs. Gap runs (where
/// `run.value == nil` or `value.isEmpty`) are automatically coalesced
/// with adjacent gaps when ranges are set or removed.
///
/// Backend: sorted array (see `RangeStoreDecision.md` Gate A for rationale).
/// O(n) edits are acceptable because the number of runs is bounded by the
/// visible viewport producing them.
package struct RangeStore<Element: RangeStoreElement>: Sendable {
    // MARK: - Stored representation

    private struct StoredRun: Sendable {
        var offset: Int
        var run: RangeStoreRun<Element>
    }

    private var _runs: [StoredRun]
    private var _documentLength: Int

    // MARK: - Lifecycle

    package init(documentLength: Int) {
        self._documentLength = documentLength
        if documentLength > 0 {
            self._runs = [StoredRun(offset: 0, run: .empty(length: documentLength))]
        } else {
            self._runs = []
        }
    }

    package var documentLength: Int { _documentLength }

    // MARK: - Query

    /// Returns all runs that intersect the given character range.
    package func runs(in range: Range<Int>) -> [RangeStoreRun<Element>] {
        guard !range.isEmpty else { return [] }
        let clampedLower = max(0, min(range.lowerBound, _documentLength))
        let clampedUpper = max(clampedLower, min(_documentLength, range.upperBound))
        guard clampedLower < clampedUpper else { return [] }

        var result: [RangeStoreRun<Element>] = []
        var cursor = clampedLower

        for stored in _runs {
            let runEnd = stored.offset + stored.run.length
            if runEnd <= cursor { continue }
            if stored.offset >= clampedUpper { break }

            let overlapStart = max(cursor, stored.offset)
            let overlapEnd = min(clampedUpper, runEnd)
            let overlapLength = overlapEnd - overlapStart
            if overlapLength > 0 {
                result.append(.init(length: overlapLength, value: stored.run.value))
                cursor = overlapEnd
            }
        }

        return result
    }

    // MARK: - Mutation

    /// Set a single value over a character range.
    package mutating func set(value: Element?, for range: Range<Int>) {
        let clamped = clamped(range)
        guard !clamped.isEmpty else { return }
        let run = RangeStoreRun<Element>(length: clamped.count, value: value)
        set(runs: [run], for: range)
    }

    /// Replace a character range with a sequence of runs.
    package mutating func set(runs newRuns: [RangeStoreRun<Element>], for range: Range<Int>) {
        let clampedLower = max(0, min(range.lowerBound, _documentLength))
        let clampedUpper = max(clampedLower, min(_documentLength, range.upperBound))
        guard clampedLower < clampedUpper else { return }
        let replacementLength = newRuns.reduce(0) { $0 + $1.length }
        precondition(replacementLength == clampedUpper - clampedLower, "RangeStore replacement runs must exactly cover the target range")

        _runs = replaceSubrange(clampedLower ..< clampedUpper, with: newRuns)
        coalesceNearby(around: clampedLower ..< (clampedLower + replacementLength))
    }

    /// Notify the store that the underlying document was edited.
    ///
    /// - Parameter range: The character range that was replaced.
    /// - Parameter newLength: The length of the replacement text (0 for deletions).
    package mutating func storageUpdated(replacedCharactersIn range: Range<Int>, withCount newLength: Int) {
        let clampedLower = max(0, min(range.lowerBound, _documentLength))
        let clampedUpper = max(clampedLower, min(_documentLength, range.upperBound))
        let oldLength = clampedUpper - clampedLower
        let replacementLength = max(0, newLength)
        let delta = replacementLength - oldLength
        _documentLength += delta

        if replacementLength == 0 {
            // Deletion: remove the range.
            _runs = replaceSubrange(clampedLower ..< clampedUpper, with: [])
        } else {
            // Insertion or replacement: put an empty gap of `replacementLength`.
            _runs = replaceSubrange(clampedLower ..< clampedUpper, with: [.empty(length: replacementLength)])
        }
        coalesceNearby(around: clampedLower ..< (clampedLower + replacementLength))
    }

    // MARK: - Internals

    private func clamped(_ range: Range<Int>) -> Range<Int> {
        let lower = max(0, min(range.lowerBound, _documentLength))
        let upper = max(lower, min(_documentLength, range.upperBound))
        return lower..<upper
    }

    /// Replace the character subrange with new runs, adjusting offsets.
    private func replaceSubrange(_ range: Range<Int>, with newRuns: [RangeStoreRun<Element>]) -> [StoredRun] {
        let editStart = range.lowerBound
        let editEnd = range.upperBound
        let newTotalLength = newRuns.reduce(0) { $0 + $1.length }
        let shift = newTotalLength - (editEnd - editStart)

        var result: [StoredRun] = []

        for stored in _runs {
            let runStart = stored.offset
            let runEnd = stored.offset + stored.run.length

            if runEnd <= editStart {
                // Entirely before the edit — keep as-is.
                result.append(stored)
            } else if runStart >= editEnd {
                // Entirely after the edit — shift by delta.
                result.append(StoredRun(offset: runStart + shift, run: stored.run))
            } else {
                // Run overlaps the edit region — preserve non-overlapping portions.
                let beforeLen = max(0, editStart - runStart)
                let afterLen = max(0, runEnd - editEnd)

                if beforeLen > 0 {
                    result.append(StoredRun(
                        offset: runStart,
                        run: .init(length: beforeLen, value: stored.run.value)
                    ))
                }
                if afterLen > 0 {
                    result.append(StoredRun(
                        offset: editStart + newTotalLength,
                        run: .init(length: afterLen, value: stored.run.value)
                    ))
                }
            }
        }

        // Insert the new runs between before/after fragments.
        // Find the insertion point: the first result whose offset >= editStart.
        if let insertIndex = result.firstIndex(where: { $0.offset >= editStart }) {
            var offset = editStart
            let mapped: [StoredRun] = newRuns.map { run in
                let stored = StoredRun(offset: offset, run: run)
                offset += run.length
                return stored
            }
            result.insert(contentsOf: mapped, at: insertIndex)
        } else {
            // No runs at or after edit start — append at end.
            var offset = editStart
            for run in newRuns {
                result.append(StoredRun(offset: offset, run: run))
                offset += run.length
            }
        }

        return result
    }

    /// Coalesce adjacent runs with compatible values around the edited region.
    private mutating func coalesceNearby(around _: Range<Int>) {
        guard _runs.count > 1 else { return }

        var idx = 1
        while idx < _runs.count {
            let prev = _runs[idx - 1]
            let curr = _runs[idx]
            let prevEnd = prev.offset + prev.run.length

            if prevEnd == curr.offset {
                let canCoalesce = prev.run.value == curr.run.value
                    || (prev.run.value?.isEmpty != false && curr.run.value?.isEmpty != false)
                if canCoalesce {
                    let combinedLength = prev.run.length + curr.run.length
                    _runs[idx - 1] = StoredRun(offset: prev.offset, run: .init(length: combinedLength, value: prev.run.value ?? curr.run.value))
                    _runs.remove(at: idx)
                    continue
                }
            }
            idx += 1
        }

        // Trim trailing gap.
        if let last = _runs.last, last.offset + last.run.length > _documentLength {
            let excess = last.offset + last.run.length - _documentLength
            if excess >= last.run.length {
                _runs.removeLast()
            } else {
                _runs[_runs.count - 1] = StoredRun(offset: last.offset, run: .init(length: last.run.length - excess, value: last.run.value))
            }
        }
    }
}
