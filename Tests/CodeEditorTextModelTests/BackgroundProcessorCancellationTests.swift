@testable import CodeEditorTextModel
import Foundation
import Testing

/// `cancelPendingOperations()` used to zero the pending count while the
/// operations were still suspended, so each one's end tripped
/// `precondition(pendingCount >= 0)`; it also cancelled only a wrapper task,
/// never the operation itself.
@Suite("BackgroundProcessor cancellation")
struct BackgroundProcessorCancellationTests {
    @Test("cancelling while operations are suspended keeps the count consistent")
    func cancelWhileSuspended() async throws {
        let processor = BackgroundProcessor(value: 1)
        let slow = Task {
            try await processor.processValue { value -> Int in
                try await Task.sleep(nanoseconds: 2_000_000_000)
                return value
            }
        }
        let accessing = Task {
            try await processor.accessValue { value -> Int in
                try? await Task.sleep(nanoseconds: 200_000_000)
                return value
            }
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(await processor.hasPendingWork)

        await processor.cancelPendingOperations()

        let slowResult = await slow.result
        #expect(throws: CancellationError.self) { try slowResult.get() }
        #expect(try await accessing.value == 1)
        #expect(await processor.hasPendingWork == false)
    }
}
