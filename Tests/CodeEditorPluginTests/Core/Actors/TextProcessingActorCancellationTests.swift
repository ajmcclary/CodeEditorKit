@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import Foundation
import XCTest

/// Regression coverage for `TextProcessingActor.cancelAllProcessing()`.
///
/// The previous implementation set `isCancelled = true` on every entry
/// in `activeProcessors`, but the processing methods only called
/// `Task.checkCancellation()` and never read the actor-owned flag —
/// so `cancelAllProcessing()` silently no-op'd unless the caller also
/// cancelled its own `Task`. The fix routes the processor ID through
/// each method and polls the actor-owned flag at every cancellation
/// boundary.
///
/// The public processor stubs run synchronously today (the source
/// comments label them "Simplified implementation"), so we can't race
/// against them through the public API alone. Tests exercise the
/// cancellation contract via `processForCancellationTesting`, an
/// `internal` seam that simulates a real long-running processor by
/// inserting a brief sleep between two `checkCancellation(id:)`
/// boundaries.
@available(macOS 13.0, iOS 16.0, *)
final class TextProcessingActorCancellationTests: XCTestCase {
    func testCancelAllProcessingAbortsInflightWorkWithoutCancellingCallerTask() async throws {
        let actor = TextProcessingActor()

        let inflight = Task {
            try await actor.processForCancellationTesting(text: "hello")
        }

        // Give the actor a moment to enter the test seam, register
        // its processor, and reach the simulated sleep window.
        try await Task.sleep(nanoseconds: 10_000_000)

        await actor.cancelAllProcessing()

        do {
            _ = try await inflight.value
            XCTFail("Expected CancellationError once cancelAllProcessing flipped the actor-owned flag")
        } catch is CancellationError {
            // Expected — the actor-owned cancellation flag is now read
            // at the next checkCancellation boundary.
        }
    }

    func testCancelAllProcessingDoesNotAffectSubsequentCalls() async throws {
        let actor = TextProcessingActor()

        // Cancel before any work is in flight — there's nothing to
        // mark, and the flag lives per-processor on activeProcessors,
        // so a fresh process() call gets a fresh UUID and flag.
        await actor.cancelAllProcessing()

        let result = try await actor.process(text: "after cancel", with: .indentation)
        XCTAssertEqual(
            result,
            "after cancel",
            "cancelAllProcessing must be scoped to inflight processors — a follow-up call should run normally"
        )
    }

    func testCancelAllProcessingHandlesMultipleConcurrentProcessors() async throws {
        let actor = TextProcessingActor()

        let inflightA = Task { try await actor.processForCancellationTesting(text: "a") }
        let inflightB = Task { try await actor.processForCancellationTesting(text: "b") }
        let inflightC = Task { try await actor.processForCancellationTesting(text: "c") }

        try await Task.sleep(nanoseconds: 10_000_000)

        await actor.cancelAllProcessing()

        for task in [inflightA, inflightB, inflightC] {
            do {
                _ = try await task.value
                XCTFail("All inflight processors must observe the cancellation flag")
            } catch is CancellationError {
                // Expected
            }
        }
    }
}
