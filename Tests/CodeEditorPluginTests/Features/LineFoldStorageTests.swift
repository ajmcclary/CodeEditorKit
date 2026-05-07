@testable import CodeEditorPlugin
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
