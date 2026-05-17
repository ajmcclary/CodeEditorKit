import CodeEditorTextModel
import Foundation

/// Range-store-backed fold storage that separates fold metadata from
/// text attributes and fold presentation.
///
/// Folds are stored as `RangeStore<FoldStoreElement>` runs. Query methods
/// return fold ranges and collapse state. Edit sync is handled by
/// `storageUpdated(replacedCharactersIn:withCount:)`.
internal struct LineFoldStorage: Sendable {
    private struct StoredFold: Sendable, Equatable {
        var range: NSRange
        var element: FoldStoreElement
    }

    private var store: RangeStore<FoldStoreElement>
    private var foldsByID: [String: StoredFold]

    internal init(documentLength: Int) {
        self.store = RangeStore<FoldStoreElement>(documentLength: documentLength)
        self.foldsByID = [:]
    }

    var documentLength: Int { store.documentLength }

    // MARK: - Build from foldable regions

    /// Rebuild storage from detected fold regions, preserving collapse state
    /// of folds that still exist after recalculation.
    internal mutating func updateFolds(from regions: [FoldableRegion], collapsedIDs: Set<String>) {
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
    internal mutating func storageUpdated(replacedCharactersIn range: Range<Int>, withCount newLength: Int) {
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
    internal func folds(in queryRange: NSRange) -> [FoldInfo] {
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
    internal mutating func toggleCollapse(foldID: String, range: NSRange) {
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
    internal mutating func setCollapsed(foldID: String, collapsed: Bool) {
        guard var stored = foldsByID[foldID] else { return }
        stored.element.isCollapsed = collapsed
        foldsByID[foldID] = stored
        rebuildStoreFromIndex()
    }

    // MARK: - Helpers

    private mutating func rebuildStoreFromIndex() {
        store = RangeStore<FoldStoreElement>(documentLength: store.documentLength)
        let sorted = foldsByID.values.sorted {
            if $0.range.location == $1.range.location {
                return $0.range.length > $1.range.length
            }
            return $0.range.location < $1.range.location
        }
        for stored in sorted {
            let start = max(0, min(stored.range.location, store.documentLength))
            let end = max(start, min(NSMaxRange(stored.range), store.documentLength))
            guard start < end else { continue }
            store.set(
                value: stored.element,
                for: start..<end
            )
        }
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
internal struct FoldInfo: Sendable, Equatable {
    internal var id: String
    internal var range: NSRange
    internal var depth: Int
    internal var isCollapsed: Bool
    internal var kind: FoldingType
}
