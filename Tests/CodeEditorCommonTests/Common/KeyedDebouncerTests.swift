import CodeEditorCommon
import Testing

@Suite("KeyedDebouncer")
struct KeyedDebouncerTests {
    @Test("replaced keyed operation throws cancellation")
    func replacementCancellation() async throws {
        let debouncer = KeyedDebouncer<String, Int>()
        let first = Task {
            try await debouncer.run(key: "search", delay: .seconds(30)) { 1 }
        }
        await Task.yield()
        let second = Task {
            try await debouncer.run(key: "search", delay: .zero) { 2 }
        }

        await #expect(throws: CancellationError.self) {
            try await first.value
        }
        #expect(try await second.value == 2)
    }

    @Test("different keys execute independently")
    func independentKeys() async throws {
        let debouncer = KeyedDebouncer<String, Int>()
        async let first = debouncer.run(key: "one", delay: .zero) { 1 }
        async let second = debouncer.run(key: "two", delay: .zero) { 2 }
        #expect(try await [first, second] == [1, 2])
    }
}
