import CodeEditorCommon
import CodeEditorDiagnostics
import Testing

@MainActor
@Suite("Monitored LRU cache")
struct MonitoredLRUCacheTests {
    @Test("monitored cache uses linked storage semantics")
    func monitoredCacheSemantics() {
        let cache = LRUCache<String, Int>(
            capacity: 2,
            memoryMonitor: MemoryMonitor()
        )
        cache.set(1, forKey: "a")
        cache.set(2, forKey: "b")
        #expect(cache.get("a") == 1)
        cache.set(3, forKey: "c")
        #expect(cache.get("b") == nil)
        #expect(cache.allKeys == ["c", "a"])
    }

    @Test("both cache layers clamp invalid capacity to one")
    func invalidCapacityClamping() {
        let linked = LinkedLRU<String, Int>(capacity: 0)
        linked.setValue(1, forKey: "a")
        linked.setValue(2, forKey: "b")
        #expect(linked.capacity == 1)
        #expect(linked.keysMostRecentFirst == ["b"])

        let monitored = LRUCache<String, Int>(
            capacity: 0,
            memoryMonitor: MemoryMonitor()
        )
        monitored.set(1, forKey: "a")
        monitored.set(2, forKey: "b")
        #expect(monitored.maxCapacity == 1)
        #expect(monitored.allKeys == ["b"])
    }
}
