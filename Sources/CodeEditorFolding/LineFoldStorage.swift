import CodeEditorLanguages
import CodeEditorTextModel
import Foundation

/// Range-store-backed fold storage that separates fold metadata from
/// text attributes and fold presentation.
///
/// Folds are stored as `RangeStore<FoldStoreElement>` runs. Query methods
/// return fold ranges and collapse state. Edit sync is handled by
/// `storageUpdated(replacedCharactersIn:withCount:)`.
package struct LineFoldStorage: Sendable {
    private struct StoredFold: Sendable, Equatable {
        var range: NSRange
        var element: FoldStoreElement
    }

    private var store: RangeStore<FoldStoreElement>
    private var foldsByID: [String: StoredFold]

    package init(documentLength: Int) {
        self.store = RangeStore<FoldStoreElement>(documentLength: documentLength)
        self.foldsByID = [:]
    }

    package var documentLength: Int { store.documentLength }

    // MARK: - Build from foldable regions

    /// Rebuild storage from detected fold regions, preserving collapse state
    /// of folds that still exist after recalculation.
    package mutating func updateFolds(from regions: [FoldableRegion], collapsedIDs: Set<String>) {
        let previous = foldsByID
        foldsByID = [:]

        for region in regions.sorted(by: { $0.range.location < $1.range.location }) {
            let id = region.id.uuidString
            let collapsed = previous[id]?.element.isCollapsed ?? collapsedIDs.contains(id)
            let element = FoldStoreElement(
                id: id,
                depth: region.level,
                isCollapsed: collapsed,
                kind: region.type
            )
            let clampedStart = max(0, region.range.location)
            let clampedEnd = min(store.documentLength, region.range.location + region.range.length)
            guard clampedStart < clampedEnd else { continue }
            foldsByID[id] = StoredFold(
                range: NSRange(location: clampedStart, length: clampedEnd - clampedStart),
                element: element
            )
        }

        rebuildStoreFromIndex()
    }

    /// Preserve collapse state across edits by applying a delta to the store.
    package mutating func storageUpdated(replacedCharactersIn range: Range<Int>, withCount newLength: Int) {
        let replacementLength = max(0, newLength)
        let oldDocumentLength = store.documentLength
        let editStart = max(0, min(range.lowerBound, oldDocumentLength))
        let editEnd = max(editStart, min(range.upperBound, oldDocumentLength))
        let oldLength = editEnd - editStart
        let newDocumentLength = max(0, oldDocumentLength + replacementLength - oldLength)
        let editRange = editStart..<editEnd

        foldsByID = foldsByID.compactMapValues { stored in
            guard let transformed = transform(stored.range, editRange: editRange, newLength: replacementLength) else {
                return nil
            }
            let location = max(0, min(transformed.location, newDocumentLength))
            let end = max(location, min(newDocumentLength, transformed.location + transformed.length))
            guard location < end else { return nil }
            return StoredFold(
                range: NSRange(location: location, length: end - location),
                element: stored.element
            )
        }

        store = RangeStore<FoldStoreElement>(documentLength: newDocumentLength)
        rebuildStoreFromIndex()
    }

    // MARK: - Query

    /// Returns all folds intersecting the given character range.
    package func folds(in queryRange: NSRange) -> [FoldInfo] {
        guard queryRange.length > 0 else { return [] }
        return foldsByID.values
            .filter { intersects($0.range, queryRange) }
            .sorted {
                if $0.range.location == $1.range.location {
                    return $0.element.depth < $1.element.depth
                }
                return $0.range.location < $1.range.location
            }
            .compactMap { stored in
                guard let id = stored.element.id else { return nil }
                return FoldInfo(
                    id: id,
                    range: stored.range,
                    depth: stored.element.depth,
                    isCollapsed: stored.element.isCollapsed,
                    kind: stored.element.kind
                )
            }
    }

    /// Toggle collapse state for a fold by ID.
    package mutating func toggleCollapse(foldID: String, range: NSRange) {
        if let stored = foldsByID[foldID] {
            setCollapsed(foldID: foldID, collapsed: !stored.element.isCollapsed)
            return
        }

        let element = FoldStoreElement(
            id: foldID,
            depth: 0,
            isCollapsed: true,
            kind: .region
        )
        let clampedStart = max(0, min(range.location, store.documentLength))
        let clampedEnd = max(clampedStart, min(NSMaxRange(range), store.documentLength))
        guard clampedStart < clampedEnd else { return }
        foldsByID[foldID] = StoredFold(
            range: NSRange(location: clampedStart, length: clampedEnd - clampedStart),
            element: element
        )
        rebuildStoreFromIndex()
    }

    /// Set collapse state for a fold by ID while preserving range and metadata.
    package mutating func setCollapsed(foldID: String, collapsed: Bool) {
        guard var stored = foldsByID[foldID] else { return }
        stored.element.isCollapsed = collapsed
        foldsByID[foldID] = stored
        rebuildStoreFromIndex()
    }

    /// Set several folds' collapse state with one store rebuild (calling
    /// `setCollapsed(foldID:collapsed:)` per fold rebuilds once per call).
    package mutating func setCollapsed(_ states: [(foldID: String, collapsed: Bool)]) {
        var changed = false
        for (foldID, collapsed) in states {
            guard var stored = foldsByID[foldID], stored.element.isCollapsed != collapsed else { continue }
            stored.element.isCollapsed = collapsed
            foldsByID[foldID] = stored
            changed = true
        }
        if changed { rebuildStoreFromIndex() }
    }

    // MARK: - Helpers

    /// Rebuilds the run store from `foldsByID` in one sweep. Later folds in
    /// (location ascending, length descending) order win where folds overlap,
    /// which for nested folds is the innermost — the same result as setting
    /// each fold in that order, without the O(folds × runs) cost of doing so.
    private mutating func rebuildStoreFromIndex() {
        let length = store.documentLength
        store = RangeStore<FoldStoreElement>(documentLength: length)
        guard length > 0 else { return }

        var sorted: [SweptFold] = []
        for stored in foldsByID.values {
            let start = max(0, min(stored.range.location, length))
            let end = max(start, min(NSMaxRange(stored.range), length))
            if start < end {
                sorted.append(SweptFold(start: start, end: end, element: stored.element))
            }
        }
        sorted.sort { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return (lhs.end - lhs.start) > (rhs.end - rhs.start)
        }
        guard !sorted.isEmpty else { return }

        var boundaries = Set<Int>([0, length])
        for fold in sorted {
            boundaries.insert(fold.start)
            boundaries.insert(fold.end)
        }
        let points = boundaries.sorted()

        var runs: [RangeStoreRun<FoldStoreElement>] = []
        // Active folds by sort index; the winner is the highest live index.
        var active: [Int] = []
        var next = 0
        for (point, nextPoint) in zip(points, points.dropFirst()) {
            while next < sorted.count, sorted[next].start <= point {
                active.append(next)
                next += 1
            }
            while let top = active.last, sorted[top].end <= point {
                active.removeLast()
            }
            let value = active.last.map { sorted[$0].element }
            let runLength = nextPoint - point
            if let last = runs.last, last.value == value {
                runs[runs.count - 1].length += runLength
            } else {
                runs.append(RangeStoreRun(length: runLength, value: value))
            }
        }
        store.set(runs: runs, for: 0..<length)
    }

    private struct SweptFold {
        let start: Int
        let end: Int
        let element: FoldStoreElement
    }

    /// The run store's runs over the whole document (test seam).
    package var storeRunsForTesting: [RangeStoreRun<FoldStoreElement>] {
        store.runs(in: 0..<store.documentLength)
    }

    private func transform(_ range: NSRange, editRange: Range<Int>, newLength: Int) -> NSRange? {
        let start = range.location
        let end = NSMaxRange(range)
        let editStart = editRange.lowerBound
        let editEnd = editRange.upperBound
        let oldLength = editEnd - editStart
        let delta = newLength - oldLength

        if editEnd <= start {
            return NSRange(location: start + delta, length: range.length)
        }

        if editStart >= end {
            return range
        }

        if editStart <= start && editEnd >= end && newLength == 0 {
            return nil
        }

        let newStart = start < editStart ? start : editStart + newLength
        let newEnd = end > editEnd ? end + delta : editStart + newLength
        let boundedStart = max(0, newStart)
        let boundedEnd = max(boundedStart, newEnd)
        guard boundedStart < boundedEnd else { return nil }
        return NSRange(location: boundedStart, length: boundedEnd - boundedStart)
    }

    private func intersects(_ lhs: NSRange, _ rhs: NSRange) -> Bool {
        let lhsEnd = NSMaxRange(lhs)
        let rhsEnd = NSMaxRange(rhs)
        return lhs.location < rhsEnd && rhs.location < lhsEnd
    }
}

/// Lightweight fold query result.
package struct FoldInfo: Sendable, Equatable {
    package var id: String
    package var range: NSRange
    package var depth: Int
    package var isCollapsed: Bool
    package var kind: FoldingType
}
