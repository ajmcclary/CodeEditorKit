import CodeEditorCommon
import XCTest

final class LinkedLRUTests: XCTestCase {
    func testEmptyCacheHasNoEntries() {
        let cache = LinkedLRU<String, Int>(capacity: 3)
        XCTAssertEqual(cache.count, 0)
        XCTAssertTrue(cache.isEmpty)
        XCTAssertNil(cache.value(forKey: "missing"))
    }

    func testSetThenGetReturnsValue() {
        let cache = LinkedLRU<String, Int>(capacity: 3)
        cache.setValue(1, forKey: "a")
        XCTAssertEqual(cache.value(forKey: "a"), 1)
        XCTAssertEqual(cache.count, 1)
    }

    func testGetMissReturnsNilWithoutMutating() {
        let cache = LinkedLRU<String, Int>(capacity: 3)
        cache.setValue(1, forKey: "a")
        XCTAssertNil(cache.value(forKey: "missing"))
        XCTAssertEqual(cache.count, 1)
    }

    func testSetUpdateOverwritesAndPromotes() {
        let cache = LinkedLRU<String, Int>(capacity: 3)
        cache.setValue(1, forKey: "a")
        cache.setValue(2, forKey: "b")
        cache.setValue(3, forKey: "c")

        // Re-set "a" — it's now most-recently-used and value should be the new one.
        cache.setValue(10, forKey: "a")
        XCTAssertEqual(cache.value(forKey: "a"), 10)
        XCTAssertEqual(cache.count, 3, "update must not grow the cache")

        // Inserting "d" evicts the LRU — which after the promotion is "b".
        cache.setValue(4, forKey: "d")
        XCTAssertEqual(cache.value(forKey: "a"), 10, "promoted entry must survive eviction")
        XCTAssertNil(cache.value(forKey: "b"), "least-recent entry must be evicted")
        XCTAssertEqual(cache.value(forKey: "c"), 3)
        XCTAssertEqual(cache.value(forKey: "d"), 4)
    }

    func testGetPromotesAccessOrder() {
        let cache = LinkedLRU<String, Int>(capacity: 3)
        cache.setValue(1, forKey: "a")
        cache.setValue(2, forKey: "b")
        cache.setValue(3, forKey: "c")

        // Touch "a" via get — now "b" is LRU.
        _ = cache.value(forKey: "a")

        cache.setValue(4, forKey: "d")
        XCTAssertNotNil(cache.value(forKey: "a"), "touched-via-get entry must survive eviction")
        XCTAssertNil(cache.value(forKey: "b"), "untouched LRU must be evicted")
    }

    func testEvictionAtCapacity() {
        let cache = LinkedLRU<Int, String>(capacity: 2)
        cache.setValue("a", forKey: 1)
        cache.setValue("b", forKey: 2)
        cache.setValue("c", forKey: 3)

        XCTAssertEqual(cache.count, 2)
        XCTAssertNil(cache.value(forKey: 1))
        XCTAssertEqual(cache.value(forKey: 2), "b")
        XCTAssertEqual(cache.value(forKey: 3), "c")
    }

    func testRemoveValue() {
        let cache = LinkedLRU<String, Int>(capacity: 3)
        cache.setValue(1, forKey: "a")
        cache.setValue(2, forKey: "b")

        XCTAssertEqual(cache.removeValue(forKey: "a"), 1)
        XCTAssertNil(cache.value(forKey: "a"))
        XCTAssertEqual(cache.count, 1)
        XCTAssertNil(cache.removeValue(forKey: "missing"))
    }

    func testRemoveValueFromMiddleLeavesListIntact() {
        // Regression: removing the middle node must keep head/tail wired so the
        // next insertion's eviction picks the right tail.
        let cache = LinkedLRU<String, Int>(capacity: 3)
        cache.setValue(1, forKey: "a")
        cache.setValue(2, forKey: "b")
        cache.setValue(3, forKey: "c")

        cache.removeValue(forKey: "b")

        cache.setValue(4, forKey: "d")
        // Cache now: a, c, d. Inserting "e" evicts the LRU, which is "a".
        cache.setValue(5, forKey: "e")
        XCTAssertNil(cache.value(forKey: "a"))
        XCTAssertEqual(cache.value(forKey: "c"), 3)
        XCTAssertEqual(cache.value(forKey: "d"), 4)
        XCTAssertEqual(cache.value(forKey: "e"), 5)
    }

    func testRemoveAll() {
        let cache = LinkedLRU<String, Int>(capacity: 3)
        cache.setValue(1, forKey: "a")
        cache.setValue(2, forKey: "b")
        cache.removeAll()
        XCTAssertTrue(cache.isEmpty)
        XCTAssertNil(cache.value(forKey: "a"))

        // Inserting after removeAll must still work — head/tail were nilled.
        cache.setValue(3, forKey: "c")
        XCTAssertEqual(cache.value(forKey: "c"), 3)
    }

    func testRemoveAllWherePredicate() {
        let cache = LinkedLRU<String, Int>(capacity: 5)
        cache.setValue(1, forKey: "config-a")
        cache.setValue(2, forKey: "config-b")
        cache.setValue(3, forKey: "layout-a")
        cache.setValue(4, forKey: "config-c")

        cache.removeAll { $0.hasPrefix("config-") }

        XCTAssertEqual(cache.count, 1)
        XCTAssertEqual(cache.value(forKey: "layout-a"), 3)
        XCTAssertNil(cache.value(forKey: "config-a"))
        XCTAssertNil(cache.value(forKey: "config-b"))
        XCTAssertNil(cache.value(forKey: "config-c"))
    }
}
