@testable import CodeEditorView
import XCTest

/// Extension to add timeout support for tests
extension XCTestCase {
    /// Default timeout for regular tests
    static let defaultTimeout: TimeInterval = 10.0

    /// Timeout for performance tests
    static let performanceTimeout: TimeInterval = 30.0

    /// Timeout for integration tests
    static let integrationTimeout: TimeInterval = 60.0

    /// Timeout for stress tests
    static let stressTestTimeout: TimeInterval = 120.0

    /// Execute an async test with a timeout
    /// - Parameters:
    ///   - timeout: The maximum time to wait
    ///   - description: Description of what's being tested
    ///   - block: The async test block
    func runAsyncTest(
        timeout: TimeInterval = defaultTimeout,
        description: String = "Async test",
        _ block: @escaping @Sendable () async throws -> Void
    ) async throws {
        let expectation = XCTestExpectation(description: description)

        Task {
            do {
                try await block()
                expectation.fulfill()
            } catch {
                XCTFail("Test failed with error: \(error)")
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: timeout)
    }

    /// Execute a test with a timeout using a continuation
    /// - Parameters:
    ///   - timeout: The maximum time to wait
    ///   - description: Description of what's being tested
    ///   - block: The test block that takes a completion handler
    func runWithTimeout(
        timeout: TimeInterval = defaultTimeout,
        description: String = "Test with timeout",
        _ block: @escaping (@escaping () -> Void) -> Void
    ) {
        let expectation = XCTestExpectation(description: description)

        block {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout)
    }

    /// Assert that an async operation completes within a timeout
    /// - Parameters:
    ///   - timeout: The maximum time to wait
    ///   - operation: The async operation to test
    func assertCompletesWithin(
        _ timeout: TimeInterval,
        operation: @escaping () async throws -> Void
    ) async {
        let start = Date()

        do {
            try await operation()
            let elapsed = Date().timeIntervalSince(start)

            XCTAssertLessThanOrEqual(
                elapsed,
                timeout,
                "Operation took \(elapsed)s, expected less than \(timeout)s"
            )
        } catch {
            XCTFail("Operation failed with error: \(error)")
        }
    }

    /// Assert that a MainActor async operation completes within a timeout
    /// - Parameters:
    ///   - timeout: The maximum time to wait
    ///   - operation: The async operation to test
    @MainActor
    func assertCompletesWithin(
        _ timeout: TimeInterval,
        operation: @escaping @MainActor () async throws -> Void
    ) async {
        let start = Date()

        do {
            try await operation()
            let elapsed = Date().timeIntervalSince(start)

            XCTAssertLessThanOrEqual(
                elapsed,
                timeout,
                "Operation took \(elapsed)s, expected less than \(timeout)s"
            )
        } catch {
            XCTFail("Operation failed with error: \(error)")
        }
    }

    /// Create a timeout expectation that fails if not fulfilled
    /// - Parameters:
    ///   - timeout: The timeout duration
    ///   - description: Description of the expectation
    /// - Returns: An expectation that must be fulfilled within the timeout
    func timeoutExpectation(
        timeout: TimeInterval = defaultTimeout,
        description: String = "Timeout expectation"
    ) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: description)
        expectation.isInverted = false
        expectation.assertForOverFulfill = true

        // Schedule a timeout failure
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            if expectation.expectedFulfillmentCount > 0 {
                XCTFail("Test timed out after \(timeout) seconds: \(description)")
            }
        }

        return expectation
    }

    /// Measure performance with a timeout
    /// - Parameters:
    ///   - timeout: Maximum time for the performance test
    ///   - block: The performance test block
    func measureWithTimeout(
        timeout: TimeInterval = performanceTimeout,
        block: @escaping @Sendable () throws -> Void
    ) {
        measure {
            let expectation = XCTestExpectation(description: "Performance measurement")

            DispatchQueue.global().async {
                do {
                    try block()
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                    expectation.fulfill()
                }
            }

            wait(for: [expectation], timeout: timeout)
        }
    }
}

/// Test timeout configuration
enum TestTimeoutConfiguration {
    /// Timeout multiplier for CI environments
    static let ciMultiplier: Double = 2.0

    /// Check if running in CI environment
    static var isCI: Bool {
        ProcessInfo.processInfo.environment["CI"] != nil ||
        ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||
        ProcessInfo.processInfo.environment["JENKINS"] != nil
    }

    /// Get adjusted timeout for current environment
    static func adjustedTimeout(_ base: TimeInterval) -> TimeInterval {
        isCI ? base * ciMultiplier : base
    }
}

/// Protocol for tests that need custom timeout configuration
protocol TimeoutConfigurable {
    /// The timeout duration for this test class
    static var testTimeout: TimeInterval { get }

    /// The timeout for individual test methods
    var methodTimeout: TimeInterval { get }
}

/// Default implementation
extension TimeoutConfigurable {
    static var testTimeout: TimeInterval {
        TestTimeoutConfiguration.adjustedTimeout(60.0)
    }

    var methodTimeout: TimeInterval {
        TestTimeoutConfiguration.adjustedTimeout(10.0)
    }
}
