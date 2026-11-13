import CodeEditorCommon
import Foundation
import Testing

private actor Counter {
    private(set) var value = 0

    func increment() { value += 1 }
}

/// Holds an operation until the test opens it, so the test controls what
/// overlaps instead of guessing with sleeps.
private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

@Suite("AsyncOperationManager edge cases")
struct AsyncOperationManagerTests {
    @Test func batchSizeZeroRunsEveryOperation() async throws {
        let manager = AsyncOperationManager(maxConcurrentOperations: 2)
        let operations: [@Sendable () async throws -> Int] = [{ 1 }, { 2 }, { 3 }]
        let results = try await manager.batch(operations: operations, batchSize: 0)
        #expect(results == [1, 2, 3])
    }

    @Test func cancelledScheduleDoesNotLeaveAnEntry() async throws {
        let manager = AsyncOperationManager(maxConcurrentOperations: 1)
        let blocker = Task { try await manager.schedule { try await Task.sleep(for: .seconds(5)) } }
        while await manager.getStatus().activeCount == 0 {
            await Task.yield()
        }
        let waiting = Task { try await manager.schedule { 1 } }
        while await manager.getStatus().scheduledCount < 2 {
            await Task.yield()
        }
        waiting.cancel()
        _ = try? await waiting.value
        #expect(await manager.getStatus().scheduledCount == 1)
        blocker.cancel()
        _ = try? await blocker.value
        #expect(await manager.getStatus().scheduledCount == 0)
    }

    @Test func throttleSharesARunThatIsStillGoing() async throws {
        let manager = AsyncOperationManager()
        let runs = Counter()
        let gate = Gate()
        // The first run is held open by the gate rather than a 200 ms sleep
        // with the second call 50 ms in: on a loaded machine the second call
        // could land after the first had finished.
        async let first: Int = manager.throttle(key: "k", interval: 10) {
            await runs.increment()
            await gate.wait()
            return 1
        }
        while await runs.value == 0 {
            await Task.yield()
        }
        defer { Task { await gate.open() } }
        async let second: Int = manager.throttle(key: "k", interval: 10) {
            await runs.increment()
            return 2
        }
        await Task.yield()
        await gate.open()
        let values = try await [first, second]
        #expect(values == [1, 1])
        #expect(await runs.value == 1)
    }

    @Test func debouncedAsyncFiresOnceForABurst() async {
        let fired = Counter()
        // The delay is ten times the old 50 ms so the burst of calls fits in
        // it on a loaded machine; the firing is waited for, not slept past.
        let delay = 0.5
        let debounced: @Sendable (Int) async -> Void = debouncedAsync(delay: delay) { (_: Int) in
            Task { await fired.increment() }
        }
        await withTaskGroup(of: Void.self) { group in
            for value in 0..<50 {
                group.addTask { await debounced(value) }
            }
        }
        let deadline = Date().addingTimeInterval(30)
        while await fired.value == 0, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        // A second firing would come one delay later.
        try? await Task.sleep(for: .seconds(delay * 1.5))
        #expect(await fired.value == 1)
    }
}
