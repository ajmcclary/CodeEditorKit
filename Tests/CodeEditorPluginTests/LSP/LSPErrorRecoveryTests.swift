import CodeEditorCommon
@testable import CodeEditorLSP
import Foundation
import XCTest

/// Verifies `LSPError`'s `RecoverableAsyncError` conformance threads through
/// `ErrorRecoveryCoordinator.recover(from:operation:)` correctly. The catches
/// inside `LSPClient` log-then-rethrow on purpose; the structural fix the
/// reviewer asked for is making the recovery surface *reachable* from typed
/// LSPError values, not adding recovery loops inside the client (the registry
/// already drives connect retries via `LSPRetryConfiguration` — a second
/// recovery layer would compound retries).
final class LSPErrorRecoveryTests: XCTestCase {
    actor AttemptCounter {
        private(set) var count = 0

        func increment() { count += 1 }
    }

    func testConnectionFailedIsRetryableWithBackoff() async throws {
        let error = LSPError.connectionFailed("transient")
        XCTAssertTrue(error.isRetryable)
        XCTAssertNotNil(error.retryDelay)

        let strategies = error.recoveryStrategies
        XCTAssertEqual(strategies.count, 2, "Retryable case offers retry + reportToUser fallback")

        guard case .retry(let maxAttempts, _) = strategies.first?.action else {
            XCTFail("Highest-priority strategy must be .retry, got \(String(describing: strategies.first?.action))")
            return
        }
        XCTAssertGreaterThan(maxAttempts, 1, "Retry must allow more than a single attempt")
    }

    func testTimeoutIsRetryable() {
        let error = LSPError.timeout
        XCTAssertTrue(error.isRetryable)
    }

    func testInternalServerErrorIsRetryable() {
        // -32603 is JSON-RPC's "internal error"; -32099…-32000 is reserved
        // for server-defined errors. Both should be retryable.
        XCTAssertTrue(LSPError.serverError(code: -32_603, message: "internal", data: nil).isRetryable)
        XCTAssertTrue(LSPError.serverError(code: -32_050, message: "server-defined", data: nil).isRetryable)
    }

    func testProtocolViolationsAreNotRetryable() {
        XCTAssertFalse(LSPError.notConnected.isRetryable)
        XCTAssertFalse(LSPError.alreadyConnected.isRetryable)
        XCTAssertFalse(LSPError.transportNotConfigured.isRetryable)
        XCTAssertFalse(LSPError.invalidResponse("bad").isRetryable)
        XCTAssertFalse(LSPError.decodingError("bad").isRetryable)
        // Application-level server errors (e.g., method not found, parse error)
        // outside the JSON-RPC reserved internal band must not retry.
        XCTAssertFalse(LSPError.serverError(code: -32_601, message: "method not found", data: nil).isRetryable)
    }

    func testRecoveryCoordinatorRetriesTransientFailureThenSucceeds() async throws {
        let counter = AttemptCounter()
        let coordinator = ErrorRecoveryCoordinator()

        // Operation fails twice with a transient LSPError, then succeeds on
        // the third attempt. The exponential backoff in the recovery
        // strategy uses `initial: .seconds(1)` — override that here would
        // make the test slow, but the conformance ships with sane defaults,
        // so we accept the ~3s test runtime to exercise the real path.
        let result: String = try await coordinator.recover(
            from: LSPError.connectionFailed("transient")
        ) {
            await counter.increment()
            let count = await counter.count
            if count < 3 {
                throw LSPError.connectionFailed("still flapping")
            }
            return "recovered"
        }

        let finalCount = await counter.count
        XCTAssertEqual(finalCount, 3, "Coordinator must invoke the operation three times")
        XCTAssertEqual(result, "recovered")
    }

    func testRecoveryCoordinatorDoesNotRetryNonRetryableError() async {
        let counter = AttemptCounter()
        let coordinator = ErrorRecoveryCoordinator()

        do {
            _ = try await coordinator.recover(
                from: LSPError.invalidResponse("malformed")
            ) {
                await counter.increment()
                throw LSPError.invalidResponse("still malformed")
            }
            XCTFail("Expected non-retryable LSPError to propagate without retry success")
        } catch {
            // Expected: all strategies exhausted (reportToUser rethrows).
        }

        let finalCount = await counter.count
        XCTAssertEqual(
            finalCount,
            0,
            "Non-retryable error's only strategy is .reportToUser, which never invokes the operation"
        )
    }
}
