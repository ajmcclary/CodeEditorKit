@testable import CodeEditorCompletion
import CodeEditorDiagnostics
import CodeEditorLanguages
import Foundation
import Testing

@MainActor
@Suite("Completion cache, learning, and ranking components")
struct CompletionComponentTests {
    private func context(_ language: Language = .swift) -> CompletionContextModel {
        CompletionContextModel(text: "", cursorPosition: 0, language: language)
    }

    private func item(_ label: String, priority: Int = 0) -> CompletionItemModel {
        CompletionItemModel(label: label, kind: .text, priority: priority)
    }

    @Test("ranker applies learning without owning mutable state")
    func pureRankingWithLearningSnapshot() {
        let ranker = CompletionRanker()
        let learning = CompletionLearningSnapshot(
            usageCounts: ["beta": 2],
            lastUsed: ["beta": Date()]
        )

        let result = ranker.rank(
            [item("alpha"), item("beta")],
            context: context(),
            learning: learning,
            maxCount: 50
        )

        #expect(result.map(\.label) == ["beta", "alpha"])
    }

    @Test("response cache and learning clear independently")
    func cacheAndLearningIsolation() {
        let monitor = MemoryMonitor()
        let cache = CompletionResponseCache(
            capacity: 10,
            expirationTime: 60,
            isEnabled: true,
            memoryMonitor: monitor
        )
        let learning = CompletionLearningStore(
            capacity: 10,
            memoryMonitor: monitor
        )
        let context = context()
        let cachedResult = CompletionResult(
            items: [item("alpha")],
            context: context
        )

        cache.store(cachedResult, for: context)
        learning.noteContext(context)
        learning.recordSelection(item("beta"))

        learning.clear()
        #expect(cache.result(for: context)?.items.map(\.label) == ["alpha"])

        learning.noteContext(context)
        learning.recordSelection(item("beta"))
        cache.clear()

        #expect(cache.result(for: context) == nil)
        #expect(learning.snapshot(for: .swift).usageCounts["beta"] == 1)
    }

    @Test("an edit elsewhere in the document misses the response cache")
    func cacheKeyCoversTheWholeDocument() {
        let cache = CompletionResponseCache(
            capacity: 10,
            expirationTime: 60,
            isEnabled: true,
            memoryMonitor: MemoryMonitor()
        )
        let tail = String(repeating: " ", count: 200) + "value."
        let before = CompletionContextModel(text: "let a = 1\n" + tail, cursorPosition: 210 + 6, language: .swift)
        let after = CompletionContextModel(text: "let b = 1\n" + tail, cursorPosition: 210 + 6, language: .swift)
        cache.store(CompletionResult(items: [item("a")], context: before), for: before)

        #expect(cache.result(for: before)?.items.map(\.label) == ["a"])
        #expect(cache.result(for: after) == nil)
    }
}
