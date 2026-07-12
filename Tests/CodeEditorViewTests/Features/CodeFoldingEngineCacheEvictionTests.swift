@testable import CodeEditorView
import Foundation
import XCTest

/// Regression coverage for `CodeFoldingEngine.maintainCacheSize`.
///
/// The previous implementation's comment promised "simple FIFO" but
/// evicted whichever entries had the lowest hash values (it sorted
/// `foldRegionCache.keys`). Hash order has no relationship to
/// insertion order, so hot/recent entries could be discarded
/// arbitrarily. The fix tracks insertion order in a parallel array
/// and evicts from the front; these tests pin that contract by
/// driving the cache through an internal test seam.
@MainActor
final class CodeFoldingEngineCacheEvictionTests: XCTestCase {
    func testEvictionDropsOldestInsertedKeyNotLowestHash() {
        let engine = CodeFoldingEngine()

        // Insert 12 entries with intentionally non-monotonic keys.
        // Under the BUGGY hash-sort eviction (`keys.sorted()`), the
        // 12th insert would evict the lowest-valued key — `50` —
        // and leave `999` (inserted first) untouched. Under the
        // FIXED FIFO eviction, the oldest insertion — `999` — is
        // evicted instead.
        let insertions = [999, 100, 200, 300, 400, 500, 600, 700, 800, 50, 150, 250]
        for key in insertions {
            engine.setCachedFoldRegionsForTesting([], forKey: key)
        }

        let remaining = Set(engine.foldRegionCacheKeysInInsertionOrderForTesting)
        XCTAssertEqual(
            remaining.count,
            11,
            "Cache cap is 10; the production write order (maintain → insert) settles to 11 entries"
        )
        XCTAssertFalse(
            remaining.contains(999),
            "Oldest-inserted key (999) must be evicted under FIFO. Buggy hash-sort would have kept it and dropped 50 instead."
        )
        XCTAssertTrue(
            remaining.contains(50),
            "Lowest-hash key (50) must remain — its hash value is irrelevant to eviction under FIFO"
        )
    }

    func testReinsertingAnExistingKeyMovesItToTheEnd() {
        let engine = CodeFoldingEngine()

        // Establish a baseline order.
        engine.setCachedFoldRegionsForTesting([], forKey: 1)
        engine.setCachedFoldRegionsForTesting([], forKey: 2)
        engine.setCachedFoldRegionsForTesting([], forKey: 3)

        // Touch key 1 again — it should now be considered "newest"
        // so a subsequent eviction would target 2 before 1.
        engine.setCachedFoldRegionsForTesting([], forKey: 1)

        let order = engine.foldRegionCacheKeysInInsertionOrderForTesting
        XCTAssertEqual(
            order,
            [2, 3, 1],
            "Re-inserting an existing key must move it to the end of the FIFO order"
        )
    }

    func testClearCacheResetsInsertionOrder() {
        let engine = CodeFoldingEngine()
        engine.setCachedFoldRegionsForTesting([], forKey: 1)
        engine.setCachedFoldRegionsForTesting([], forKey: 2)
        engine.setCachedFoldRegionsForTesting([], forKey: 3)
        XCTAssertEqual(engine.foldRegionCacheKeysInInsertionOrderForTesting.count, 3)

        engine.clearCache()
        XCTAssertTrue(
            engine.foldRegionCacheKeysInInsertionOrderForTesting.isEmpty,
            "clearCache() must also drop the FIFO order array — otherwise stale keys could mislead a future eviction"
        )
    }
}
