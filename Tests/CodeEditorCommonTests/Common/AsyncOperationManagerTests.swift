import CodeEditorCommon
import Foundation
import Testing

private actor Counter {
    private(set) var value = 0

    func increment() { value += 1 }
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
        async let first: Int = manager.throttle(key: "k", interval: 10) {
            await runs.increment()
            try await Task.sleep(for: .milliseconds(200))
            return 1
        }
        try await Task.sleep(for: .milliseconds(50))
        async let second: Int = manager.throttle(key: "k", interval: 10) {
            await runs.increment()
            return 2
        }
        let values = try await [first, second]
        #expect(values == [1, 1])
        #expect(await runs.value == 1)
    }

    @Test func debouncedAsyncFiresOnceForABurst() async {
        let fired = Counter()
        let debounced: @Sendable (Int) async -> Void = debouncedAsync(delay: 0.05) { (_: Int) in
            Task { await fired.increment() }
        }
        await withTaskGroup(of: Void.self) { group in
            for value in 0..<50 {
                group.addTask { await debounced(value) }
            }
        }
        try? await Task.sleep(for: .milliseconds(100))
        #expect(await fired.value == 1)
    }
}
