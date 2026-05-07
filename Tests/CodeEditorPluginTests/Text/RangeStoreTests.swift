@testable import CodeEditorPlugin
import Foundation
import Testing

// MARK: - Test element

private struct TestElement: RangeStoreElement {
    let name: String
    var isEmpty: Bool { false }
}

// MARK: - Tests

@Suite("RangeStore basic operations")
struct RangeStoreTests {
    @Test("init with positive length stores single gap run")
    func initPositiveLength() {
        let store = RangeStore<TestElement>(documentLength: 100)
        #expect(store.documentLength == 100)
    }

    @Test("init with zero length creates empty store")
    func initZeroLength() {
        let store = RangeStore<TestElement>(documentLength: 0)
        #expect(store.documentLength == 0)
        #expect(store.runs(in: 0..<0).isEmpty)
    }

    @Test("runs on empty range returns empty")
    func runsEmptyRange() {
        let store = RangeStore<TestElement>(documentLength: 100)
        #expect(store.runs(in: 5..<5).isEmpty)
    }

    @Test("runs on initial gap returns single empty run")
    func runsInitialGap() {
        let store = RangeStore<TestElement>(documentLength: 100)
        let runs = store.runs(in: 0..<100)
        #expect(runs.count == 1)
        #expect(runs[0].length == 100)
        #expect(runs[0].value == nil)
    }

    @Test("runs partial range returns clipped gap")
    func runsPartialRange() {
        let store = RangeStore<TestElement>(documentLength: 100)
        let runs = store.runs(in: 10..<30)
        #expect(runs.count == 1)
        #expect(runs[0].length == 20)
    }

    @Test("runs returns correct values after set")
    func runsAfterSet() {
        var store = RangeStore<TestElement>(documentLength: 100)
        store.set(value: TestElement(name: "A"), for: 10..<30)
        let runs = store.runs(in: 0..<100)
        #expect(runs.count == 3)
        #expect(runs[0].length == 10)
        #expect(runs[0].value == nil)
        #expect(runs[1].length == 20)
        #expect(runs[1].value?.name == "A")
        #expect(runs[2].length == 70)
        #expect(runs[2].value == nil)
    }

    @Test("set value inserts into gap")
    func setValueInserts() {
        var store = RangeStore<TestElement>(documentLength: 100)
        store.set(value: TestElement(name: "X"), for: 20..<40)
        let runs = store.runs(in: 20..<40)
        #expect(runs.count == 1)
        #expect(runs[0].value?.name == "X")
        #expect(runs[0].length == 20)
    }

    @Test("set nil clears previous value")
    func setNilClears() {
        var store = RangeStore<TestElement>(documentLength: 100)
        store.set(value: TestElement(name: "X"), for: 20..<40)
        store.set(value: nil, for: 20..<40)
        let runs = store.runs(in: 0..<100)
        #expect(runs.count == 1)
        #expect(runs[0].value == nil)
    }

    @Test("set runs replaces range with sequence")
    func setRunsReplaces() {
        var store = RangeStore<TestElement>(documentLength: 100)
        let newRuns: [RangeStoreRun<TestElement>] = [
            .init(length: 5, value: TestElement(name: "A")),
            .init(length: 5, value: TestElement(name: "B"))
        ]
        store.set(runs: newRuns, for: 20..<30)
        let runs = store.runs(in: 20..<30)
        #expect(runs.count == 2)
        #expect(runs[0].value?.name == "A")
        #expect(runs[1].value?.name == "B")
    }

    @Test("adjacent identical values coalesce")
    func adjacentCoalesce() {
        var store = RangeStore<TestElement>(documentLength: 100)
        store.set(value: TestElement(name: "A"), for: 10..<30)
        store.set(value: TestElement(name: "A"), for: 30..<50)
        let runs = store.runs(in: 10..<50)
        #expect(runs.count == 1)
        #expect(runs[0].length == 40)
        #expect(runs[0].value?.name == "A")
    }

    @Test("adjacent gaps coalesce")
    func adjacentGapsCoalesce() {
        var store = RangeStore<TestElement>(documentLength: 100)
        store.set(value: TestElement(name: "A"), for: 10..<20)
        store.set(value: nil, for: 10..<20)
        let runs = store.runs(in: 0..<100)
        #expect(runs.count == 1)
        #expect(runs[0].value == nil)
        #expect(runs[0].length == 100)
    }

    @Test("storageUpdated insertion shrinks empty region and shifts")
    func storageUpdatedInsertion() {
        var store = RangeStore<TestElement>(documentLength: 100)
        store.set(value: TestElement(name: "A"), for: 10..<30)
        store.storageUpdated(replacedCharactersIn: 5..<5, withCount: 5)
        #expect(store.documentLength == 105)
        let runs = store.runs(in: 0..<105)
        let aRuns = runs.filter { $0.value?.name == "A" }
        #expect(aRuns.count == 1)
    }

    @Test("storageUpdated deletion removes range")
    func storageUpdatedDeletion() {
        var store = RangeStore<TestElement>(documentLength: 100)
        store.set(value: TestElement(name: "A"), for: 10..<30)
        store.storageUpdated(replacedCharactersIn: 5..<15, withCount: 0)
        #expect(store.documentLength == 90)
        let allRuns = store.runs(in: 0..<90)
        let aRuns = allRuns.filter { $0.value?.name == "A" }
        #expect(!aRuns.isEmpty)
        #expect(aRuns[0].length == 15)
    }

    @Test("storageUpdated replacement replaces with gap")
    func storageUpdatedReplacement() {
        var store = RangeStore<TestElement>(documentLength: 100)
        store.set(value: TestElement(name: "A"), for: 10..<30)
        store.storageUpdated(replacedCharactersIn: 15..<20, withCount: 3)
        #expect(store.documentLength == 98)
        let allRuns = store.runs(in: 0..<98)
        #expect(allRuns.contains { $0.value?.name == "A" })
    }

    @Test("many operations on large document")
    func stressTest() {
        let docLength = 100_000
        var store = RangeStore<TestElement>(documentLength: docLength)
        for offset in stride(from: 0, to: docLength, by: 1_000) {
            store.set(value: TestElement(name: "X"), for: offset..<min(offset + 10, docLength))
        }
        #expect(store.documentLength == docLength)
        let runs = store.runs(in: 0..<docLength)
        #expect(!runs.isEmpty)
    }

    @Test("repeated queries return consistent results")
    func repeatedQueries() {
        var store = RangeStore<TestElement>(documentLength: 100)
        store.set(value: TestElement(name: "A"), for: 10..<30)
        store.set(value: TestElement(name: "B"), for: 50..<70)

        let run1 = store.runs(in: 0..<100)
        let run2 = store.runs(in: 0..<100)
        #expect(run1.count == run2.count)
        for (first, second) in zip(run1, run2) {
            #expect(first == second)
        }
    }

    @Test("clamped range beyond document")
    func clampedRange() {
        var store = RangeStore<TestElement>(documentLength: 100)
        store.set(value: TestElement(name: "A"), for: 90..<200)
        let runs = store.runs(in: 85..<100)
        #expect(runs.contains { $0.value?.name == "A" })
        let aRun = runs.first { $0.value?.name == "A" }
        #expect(aRun?.length == 10)
    }

    @Test("clipped at zero lower bound")
    func clippedLowerBound() {
        var store = RangeStore<TestElement>(documentLength: 100)
        store.set(value: TestElement(name: "A"), for: -5..<10)
        let runs = store.runs(in: 0..<100)
        let aRun = runs.first { $0.value?.name == "A" }
        #expect(aRun?.length == 10)
    }
}
