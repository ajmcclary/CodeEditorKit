import Foundation

/// Range-store-backed fold storage that separates fold metadata from
/// text attributes and fold presentation.
///
/// Folds are stored as `RangeStore<FoldStoreElement>` runs. Query methods
/// return fold ranges and collapse state. Edit sync is handled by
/// `storageUpdated(replacedCharactersIn:withCount:)`.
internal struct LineFoldStorage: Sendable {
    private var store: RangeStore<FoldStoreElement>

    internal init(documentLength: Int) {
        self.store = RangeStore<FoldStoreElement>(documentLength: documentLength)
    }

    var documentLength: Int { store.documentLength }

    // MARK: - Build from foldable regions

    /// Rebuild storage from detected fold regions, preserving collapse state
    /// of folds that still exist after recalculation.
    internal mutating func updateFolds(from regions: [FoldableRegion], collapsedIDs: Set<String>) {
        // Preserve collapse state from existing storage.
        var savedCollapse: [String: Bool] = [:]
        for region in regions {
            let key = foldKey(for: region)
            if let existing = findExisting(id: region.id) {
                savedCollapse[key] = existing.isCollapsed
            } else if collapsedIDs.contains(region.id.uuidString) {
                savedCollapse[key] = true
            }
        }

        // Rebuild from scratch.
        store = RangeStore<FoldStoreElement>(documentLength: store.documentLength)

        for region in regions.sorted(by: { $0.range.location < $1.range.location }) {
            let key = foldKey(for: region)
            let collapsed = savedCollapse[key] ?? false
            let element = FoldStoreElement(
                id: region.id.uuidString,
                depth: region.level,
                isCollapsed: collapsed,
                kind: region.type
            )
            let clampedStart = max(0, region.range.location)
            let clampedEnd = min(store.documentLength, region.range.location + region.range.length)
            guard clampedStart < clampedEnd else { continue }
            store.set(value: element, for: clampedStart..<clampedEnd)
        }
    }

    /// Preserve collapse state across edits by applying a delta to the store.
    internal mutating func storageUpdated(replacedCharactersIn range: Range<Int>, withCount newLength: Int) {
        store.storageUpdated(replacedCharactersIn: range, withCount: newLength)
    }

    // MARK: - Query

    /// Returns all folds intersecting the given character range.
    internal func folds(in queryRange: NSRange) -> [FoldInfo] {
        guard queryRange.length > 0 else { return [] }
        let runs = store.runs(in: queryRange.lowerBound..<queryRange.upperBound)
        var seen: Set<String> = []
        var result: [FoldInfo] = []

        var cursor = queryRange.lowerBound
        for run in runs {
            defer { cursor += run.length }
            guard let value = run.value, let id = value.id, !seen.contains(id) else { continue }
            seen.insert(id)
            result.append(FoldInfo(
                id: id,
                range: NSRange(location: cursor, length: run.length),
                depth: value.depth,
                isCollapsed: value.isCollapsed,
                kind: value.kind
            ))
        }
        return result
    }

    /// Toggle collapse state for a fold by ID.
    internal mutating func toggleCollapse(foldID: String, range: NSRange) {
        let element = FoldStoreElement(
            id: foldID,
            depth: 0,
            isCollapsed: true,
            kind: .region
        )
        store.set(value: element, for: range.lowerBound..<range.upperBound)
    }

    // MARK: - Helpers

    private func foldKey(for region: FoldableRegion) -> String {
        "\(region.level):\(region.range.location)"
    }

    private func findExisting(id: UUID) -> FoldStoreElement? {
        let runs = store.runs(in: 0..<store.documentLength)
        for run in runs where run.value?.id == id.uuidString {
            return run.value
        }
        return nil
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
