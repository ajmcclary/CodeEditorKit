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
        // `second` must reach the actor after `first` registered; one
        // `Task.yield()` does not guarantee that under load.
        while await !debouncer.activeKeys.contains("search") {
            await Task.yield()
        }
        let second = Task {
            try await debouncer.run(key: "search", delay: .zero) { 2 }
        }

        await #expect(throws: CancellationError.self) {
            try await first.value
        }
        #expect(try await second.value == 2)
    }

    @Test("cancelling the caller cancels its pending operation")
    func callerCancellation() async throws {
        let debouncer = KeyedDebouncer<String, Int>()
        let caller = Task {
            try await debouncer.run(key: "search", delay: .seconds(30)) { 1 }
        }
        while await !debouncer.activeKeys.contains("search") {
            await Task.yield()
        }
        let start = ContinuousClock.now
        caller.cancel()

        await #expect(throws: CancellationError.self) {
            try await caller.value
        }
        // Wall time on purpose: the regression is waiting out the 30 s delay.
        // Half the delay tells the two apart however loaded the machine is.
        #expect(ContinuousClock.now - start < .seconds(15))
        #expect(await debouncer.activeKeys.isEmpty)
    }

    @Test("different keys execute independently")
    func independentKeys() async throws {
        let debouncer = KeyedDebouncer<String, Int>()
        async let first = debouncer.run(key: "one", delay: .zero) { 1 }
        async let second = debouncer.run(key: "two", delay: .zero) { 2 }
        #expect(try await [first, second] == [1, 2])
    }
}
