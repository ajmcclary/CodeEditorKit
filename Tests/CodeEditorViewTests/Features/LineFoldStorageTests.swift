import CodeEditorFolding
import CodeEditorLanguages
import CodeEditorTextModel
@testable import CodeEditorView
import Foundation
import Testing

// MARK: - FoldStoreElement tests

@Suite("FoldStoreElement")
struct FoldStoreElementTests {
    @Test("empty element has isEmpty = true")
    func emptyElement() {
        let el = FoldStoreElement.empty
        #expect(el.isEmpty)
        #expect(el.id == nil)
    }

    @Test("non-empty element has isEmpty = false")
    func nonEmptyElement() {
        let el = FoldStoreElement(id: "fold-1", depth: 0, isCollapsed: false, kind: .block)
        #expect(!el.isEmpty)
        #expect(el.id == "fold-1")
    }

    @Test("Equatable conformance")
    func equatable() {
        let el1 = FoldStoreElement(id: "a", depth: 1, isCollapsed: true, kind: .function)
        let el2 = FoldStoreElement(id: "a", depth: 1, isCollapsed: true, kind: .function)
        let el3 = FoldStoreElement(id: "b", depth: 1, isCollapsed: true, kind: .function)
        #expect(el1 == el2)
        #expect(el1 != el3)
    }
}

// MARK: - LineFoldStorage tests

@Suite("LineFoldStorage")
struct LineFoldStorageTests {
    @Test("init with document length")
    func initLength() {
        let storage = LineFoldStorage(documentLength: 100)
        #expect(storage.documentLength == 100)
    }

    @Test("folds returns empty for untouched storage")
    func foldsEmpty() {
        let storage = LineFoldStorage(documentLength: 100)
        let result = storage.folds(in: NSRange(location: 0, length: 100))
        #expect(result.isEmpty)
    }

    @Test("updateFolds populates storage correctly")
    func updateFoldsPopulates() {
        var storage = LineFoldStorage(documentLength: 100)
        var region = FoldableRegion(
            range: NSRange(location: 10, length: 20),
            title: "func",
            type: .function
        )
        region.level = 0
        storage.updateFolds(from: [region], collapsedIDs: [])

        let folds = storage.folds(in: NSRange(location: 0, length: 100))
        #expect(folds.count == 1)
        #expect(folds[0].kind == .function)
        #expect(folds[0].depth == 0)
        #expect(!folds[0].isCollapsed)
    }

    @Test("folds returns canonical fold range for a clipped query")
    func foldsReturnCanonicalRangeForPartialQuery() {
        var storage = LineFoldStorage(documentLength: 100)
        var region = FoldableRegion(
            range: NSRange(location: 10, length: 40),
            title: "func",
            type: .function
        )
        region.level = 2
        storage.updateFolds(from: [region], collapsedIDs: [])

        let folds = storage.folds(in: NSRange(location: 20, length: 5))

        #expect(folds.count == 1)
        #expect(folds[0].range == NSRange(location: 10, length: 40))
        #expect(folds[0].depth == 2)
        #expect(folds[0].kind == .function)
    }

    @Test("updateFolds preserves collapse state")
    func preserveCollapse() {
        var storage = LineFoldStorage(documentLength: 100)
        var region = FoldableRegion(
            range: NSRange(location: 10, length: 20),
            title: "func",
            type: .function
        )
        region.level = 0
        storage.updateFolds(from: [region], collapsedIDs: [region.id.uuidString])

        let folds = storage.folds(in: NSRange(location: 0, length: 100))
        #expect(folds.count == 1)
        #expect(folds[0].isCollapsed)
    }

    @Test("storageUpdated shifts fold ranges on insertion")
    func storageUpdatedShift() {
        var storage = LineFoldStorage(documentLength: 100)
        var region = FoldableRegion(
            range: NSRange(location: 10, length: 20),
            title: "func",
            type: .function
        )
        region.level = 0
        storage.updateFolds(from: [region], collapsedIDs: [])

        // Insert 5 chars at position 5
        storage.storageUpdated(replacedCharactersIn: 5..<5, withCount: 5)

        let folds = storage.folds(in: NSRange(location: 0, length: 105))
        #expect(folds.count == 1)
        // Fold should have shifted from 10..<30 to 15..<35
        #expect(folds[0].range.location == 15)
        #expect(folds[0].range.length == 20)
    }

    @Test("storageUpdated removes folds fully consumed by deletion")
    func storageUpdatedRemovesConsumedFold() {
        var storage = LineFoldStorage(documentLength: 100)
        var region = FoldableRegion(
            range: NSRange(location: 10, length: 20),
            title: "func",
            type: .function
        )
        region.level = 0
        storage.updateFolds(from: [region], collapsedIDs: [])

        storage.storageUpdated(replacedCharactersIn: 0..<100, withCount: 0)

        #expect(storage.documentLength == 0)
        #expect(storage.folds(in: NSRange(location: 0, length: 100)).isEmpty)
    }

    @Test("toggleCollapse flips state and preserves existing metadata")
    func toggleCollapsePreservesMetadata() {
        var storage = LineFoldStorage(documentLength: 100)
        var region = FoldableRegion(
            range: NSRange(location: 10, length: 20),
            title: "func",
            type: .function
        )
        region.level = 3
        storage.updateFolds(from: [region], collapsedIDs: [])

        storage.toggleCollapse(foldID: region.id.uuidString, range: region.range)
        var folds = storage.folds(in: NSRange(location: 0, length: 100))
        #expect(folds.count == 1)
        #expect(folds[0].isCollapsed)
        #expect(folds[0].depth == 3)
        #expect(folds[0].kind == .function)

        storage.toggleCollapse(foldID: region.id.uuidString, range: region.range)
        folds = storage.folds(in: NSRange(location: 0, length: 100))
        #expect(folds.count == 1)
        #expect(!folds[0].isCollapsed)
        #expect(folds[0].depth == 3)
        #expect(folds[0].kind == .function)
    }

    @Test("setCollapsed sets explicit state and preserves metadata")
    func setCollapsedPreservesMetadata() {
        var storage = LineFoldStorage(documentLength: 100)
        var region = FoldableRegion(
            range: NSRange(location: 10, length: 20),
            title: "block",
            type: .block
        )
        region.level = 1
        storage.updateFolds(from: [region], collapsedIDs: [])

        storage.setCollapsed(foldID: region.id.uuidString, collapsed: true)
        var folds = storage.folds(in: NSRange(location: 0, length: 100))
        #expect(folds.count == 1)
        #expect(folds[0].isCollapsed)
        #expect(folds[0].depth == 1)
        #expect(folds[0].kind == .block)

        storage.setCollapsed(foldID: region.id.uuidString, collapsed: false)
        folds = storage.folds(in: NSRange(location: 0, length: 100))
        #expect(folds.count == 1)
        #expect(!folds[0].isCollapsed)
        #expect(folds[0].depth == 1)
        #expect(folds[0].kind == .block)
    }

    @Test("the swept store matches setting each fold in order")
    func sweptStoreMatchesSequentialSets() {
        let ranges = [
            NSRange(location: 0, length: 60), NSRange(location: 5, length: 20),
            NSRange(location: 10, length: 5), NSRange(location: 30, length: 40),
            NSRange(location: 30, length: 10), NSRange(location: 80, length: 15)
        ]
        let regions = ranges.map { FoldableRegion(range: $0, title: "r", type: .block) }
        var storage = LineFoldStorage(documentLength: 100)
        storage.updateFolds(from: regions, collapsedIDs: [])

        var expected = RangeStore<FoldStoreElement>(documentLength: 100)
        let ordered = regions.sorted {
            $0.range.location != $1.range.location
                ? $0.range.location < $1.range.location
                : $0.range.length > $1.range.length
        }
        for region in ordered {
            expected.set(
                value: FoldStoreElement(id: region.id.uuidString, depth: region.level, isCollapsed: false, kind: region.type),
                for: region.range.location..<min(100, NSMaxRange(region.range))
            )
        }

        #expect(storage.storeRunsForTesting == expected.runs(in: 0..<100))
    }

    @Test("collapsing many folds at once is one rebuild, not one per fold")
    func batchCollapseScales() {
        let count = 4_000
        var storage = LineFoldStorage(documentLength: count * 10)
        let regions = (0..<count).map {
            FoldableRegion(range: NSRange(location: $0 * 10, length: 8), title: "f", type: .block)
        }
        storage.updateFolds(from: regions, collapsedIDs: [])

        let start = Date()
        storage.setCollapsed(regions.map { ($0.id.uuidString, true) })
        let elapsed = Date().timeIntervalSince(start)

        let folds = storage.folds(in: NSRange(location: 0, length: count * 10))
        #expect(folds.count == count)
        let collapsedCount = folds.filter(\.isCollapsed).count
        #expect(collapsedCount == count)
        // Per-fold setCollapsed rebuilds the store each time: O(folds²).
        let withinCeiling = elapsed < 2
        #expect(withinCeiling)
    }

    @Test("updateFolds preserves indexed collapse state by fold ID")
    func updateFoldsPreservesIndexedCollapseState() {
        var storage = LineFoldStorage(documentLength: 100)
        var region = FoldableRegion(
            range: NSRange(location: 10, length: 20),
            title: "func",
            type: .function
        )
        region.level = 1
        storage.updateFolds(from: [region], collapsedIDs: [])
        storage.setCollapsed(foldID: region.id.uuidString, collapsed: true)

        region.range = NSRange(location: 12, length: 25)
        region.level = 2
        storage.updateFolds(from: [region], collapsedIDs: [])

        let folds = storage.folds(in: NSRange(location: 0, length: 100))
        #expect(folds.count == 1)
        #expect(folds[0].range == NSRange(location: 12, length: 25))
        #expect(folds[0].depth == 2)
        #expect(folds[0].isCollapsed)
    }

    @Test("folds partial query returns only intersecting folds")
    func foldsPartialQuery() {
        var storage = LineFoldStorage(documentLength: 100)
        var region1 = FoldableRegion(
            range: NSRange(location: 10, length: 20),
            title: "first",
            type: .function
        )
        region1.level = 0
        var region2 = FoldableRegion(
            range: NSRange(location: 50, length: 20),
            title: "second",
            type: .block
        )
        region2.level = 0
        storage.updateFolds(from: [region1, region2], collapsedIDs: [])

        // Query only the second half
        let folds = storage.folds(in: NSRange(location: 40, length: 40))
        #expect(folds.count == 1)
        #expect(folds[0].kind == .block)
    }
}

// MARK: - FoldRegionAdapter tests

@MainActor
private final class MockFoldProvider: CodeFoldingProvider {
    var regions: [FoldableRegion] = []

    func detectFoldableRegions(in _: String) async -> [FoldableRegion] {
        regions
    }
}

@Suite("FoldRegionAdapter")
struct FoldRegionAdapterTests {
    @Test("buildStorage from empty provider returns empty storage")
    @MainActor
    func buildEmptyStorage() async {
        let provider = MockFoldProvider()
        let adapter = FoldRegionAdapter(provider: provider)
        let storage = await adapter.buildStorage(from: "test")
        let folds = storage.folds(in: NSRange(location: 0, length: 4))
        #expect(folds.isEmpty)
    }

    @Test("buildStorage with regions populates storage")
    @MainActor
    func buildWithRegions() async {
        let provider = MockFoldProvider()
        var region = FoldableRegion(
            range: NSRange(location: 0, length: 4),
            title: "test",
            type: .block
        )
        region.level = 0
        provider.regions = [region]

        let adapter = FoldRegionAdapter(provider: provider)
        let storage = await adapter.buildStorage(from: "test")
        let folds = storage.folds(in: NSRange(location: 0, length: 4))
        #expect(folds.count == 1)
    }
}

// MARK: - FoldPresentationStrategy tests

@Suite("FoldPresentationStrategy")
struct FoldPresentationStrategyTests {
    @Test("AttributeFoldPresentationStrategy creates without crash")
    @MainActor
    func createStrategy() {
        let strategy = AttributeFoldPresentationStrategy()
        _ = strategy
    }
}
