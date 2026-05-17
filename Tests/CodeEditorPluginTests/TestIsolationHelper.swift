import CodeEditorCommon
import CodeEditorDiagnostics
@testable import CodeEditorPlugin
import XCTest

/// Helper to isolate tests that may have shared state issues
enum TestIsolationHelper {
    /// Reset all shared/static state that might affect test isolation
    static func resetSharedState() {
        // Reset performance monitor instance
        Task {
            let monitor = PerformanceMonitor()
            await monitor.clearMetrics()
        }

        // Reset EditorConfiguration validation cache  
        // Note: clearValidationCache is public but may not be visible in tests
        // TODO: Add a test-specific reset method if needed

        // Note: SyntaxHighlightingCoordinator and MemoryMonitor don't have
        // static clearCache methods. They manage their own instance-level state.

        // Force garbage collection (best effort)
        for _ in 0..<3 {
            autoreleasepool { }
        }
    }

    /// Run a test in isolation with state reset
    static func runInIsolation<T: Sendable>(
        _: String = #function,
        timeout: TimeInterval = 60,
        block: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        // Reset before test
        resetSharedState()

        // Small delay to ensure cleanup completes
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Run the test with timeout using XCTest extension
        let testCase = XCTestCase()
        let result = try await testCase.withTimeout(seconds: timeout) {
            try await block()
        }

        // Reset after test
        resetSharedState()

        return result
    }

    /// Measure time taken by a block and log if it exceeds threshold
    @MainActor
    static func measureTime<T>(
        operation: String,
        warningThreshold: TimeInterval = 1.0,
        block: @MainActor () async throws -> T
    ) async throws -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        if elapsed > warningThreshold {
            let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "TestIsolation")
            logger.warning("⚠️ SLOW TEST: \(operation) took \(String(format: "%.3f", elapsed))s")
        }

        return result
    }
}

/// Base class for tests that need better isolation
@MainActor
open class IsolatedTestCase: XCTestCase {
    override open func setUp() {
        super.setUp()
        TestIsolationHelper.resetSharedState()
    }

    override open func tearDown() {
        TestIsolationHelper.resetSharedState()
        super.tearDown()
    }

    /// Run an isolated async test
    func runIsolatedTest<T: Sendable>(
        timeout: TimeInterval = 60,
        _ block: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await TestIsolationHelper.runInIsolation(
            String(describing: self),
            timeout: timeout,
            block: block
        )
    }
}

// MARK: - Timeout Helper

extension XCTestCase {
    /// Run an async operation with timeout
    func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T where T: Sendable {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            group.cancelAll()
            return result
        }
    }
}

struct TimeoutError: Error {
    let message = "Test timed out"
}
