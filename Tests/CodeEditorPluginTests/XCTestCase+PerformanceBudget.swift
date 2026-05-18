import CodeEditorCommon
import CodeEditorDiagnostics
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import XCTest

/// Extension to add performance budget support to tests
extension XCTestCase {
    /// Global performance budget reporter for tests
    static let budgetReporter = PerformanceBudgetReporter()

    /// Measure operation against performance budget
    func measureAgainstBudget(
        _ operation: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () throws -> Void
    ) rethrows {
        let startTime = CFAbsoluteTimeGetCurrent()
        try block()
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        Task { @MainActor in
            await Self.budgetReporter.record(operation: operation, duration: duration)
        }

        // Check budget immediately for test failure
        if let budget = PerformanceBudget.budget(for: operation) {
            // Apply simulator multiplier for performance budgets
            #if targetEnvironment(simulator)
            let simulatorMultiplier = 6.0 // Simulators can be much slower
            let adjustedBudget = PerformanceBudget.Budget(
                operation: budget.operation,
                targetTime: budget.targetTime * simulatorMultiplier,
                warningTime: budget.warningTime * simulatorMultiplier,
                criticalTime: budget.criticalTime * simulatorMultiplier
            )
            let status = adjustedBudget.check(duration)
            #else
            let status = budget.check(duration)
            #endif

            switch status {
            case .withinBudget:
                // Pass
                break

            case .warning:
                // Log warning but don't fail
                let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "PerformanceBudget")
                logger.warning("Performance warning for \(operation): \(String(format: "%.3f", duration))s (budget: \(String(format: "%.3f", budget.targetTime))s)")

            case .critical, .exceeded:
                if Self.enforcesPerformanceBudgets {
                    XCTFail(
                        "\(status.rawValue) Performance budget exceeded for \(operation): \(String(format: "%.3f", duration))s (budget: \(String(format: "%.3f", budget.targetTime))s)",
                        file: file,
                        line: line
                    )
                }
            }
        }
    }

    /// Measure async operation against performance budget
    func measureAsyncAgainstBudget(
        _ operation: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        isolation _: isolated (any Actor)? = #isolation,
        block: @Sendable () async throws -> Void
    ) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        try await block()
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        await Self.budgetReporter.record(operation: operation, duration: duration)

        // Check budget immediately for test failure
        if let budget = PerformanceBudget.budget(for: operation) {
            // Apply simulator multiplier for performance budgets
            #if targetEnvironment(simulator)
            let simulatorMultiplier = 6.0 // Simulators can be much slower
            let adjustedBudget = PerformanceBudget.Budget(
                operation: budget.operation,
                targetTime: budget.targetTime * simulatorMultiplier,
                warningTime: budget.warningTime * simulatorMultiplier,
                criticalTime: budget.criticalTime * simulatorMultiplier
            )
            let status = adjustedBudget.check(duration)
            #else
            let status = budget.check(duration)
            #endif

            switch status {
            case .withinBudget:
                // Pass
                break

            case .warning:
                // Log warning but don't fail
                let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "PerformanceBudget")
                logger.warning("Performance warning for \(operation): \(String(format: "%.3f", duration))s (budget: \(String(format: "%.3f", budget.targetTime))s)")

            case .critical, .exceeded:
                if Self.enforcesPerformanceBudgets {
                    XCTFail(
                        "\(status.rawValue) Performance budget exceeded for \(operation): \(String(format: "%.3f", duration))s (budget: \(String(format: "%.3f", budget.targetTime))s)",
                        file: file,
                        line: line
                    )
                }
            }
        }
    }

    /// Assert that a file size operation meets its budget
    func assertFileSizePerformance(
        fileSize: Int,
        operation: () throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) rethrows {
        let budgetKey: String
        if fileSize < 10_000 {
            budgetKey = "file_open_small"
        } else if fileSize < 1_000_000 {
            budgetKey = "file_open_medium"
        } else {
            budgetKey = "file_open_large"
        }

        try measureAgainstBudget(budgetKey, file: file, line: line, block: operation)
    }

    /// Generate performance report at end of test suite
    static func generatePerformanceReport() async {
        let report = await budgetReporter.generateReport()
        let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "PerformanceBudget")
        logger.info("\n\(report.summary)\n")

        // Reset for next test run
        await budgetReporter.reset()
    }

    /// Performance budgets are noisy in parallel SwiftPM test runs, so regular test runs collect
    /// measurements without failing. CI jobs that pin hardware/load can opt into enforcement.
    static var enforcesPerformanceBudgets: Bool {
        ProcessInfo.processInfo.environment["CODEEDITOR_ENFORCE_PERFORMANCE_BUDGETS"] == "1"
    }

    /// Assert a raw stopwatch measurement only when performance budgets are explicitly enforced.
    func assertMeasuredDuration(
        _ duration: TimeInterval,
        lessThan baseline: TimeInterval,
        operation: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard duration >= baseline else { return }

        let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "PerformanceBudget")
        logger.warning("Performance warning for \(operation): \(String(format: "%.3f", duration))s (baseline: \(String(format: "%.3f", baseline))s)")

        if Self.enforcesPerformanceBudgets {
            XCTFail(
                "\(operation) exceeded baseline: \(duration)s vs \(baseline)s",
                file: file,
                line: line
            )
        }
    }
}

/// Performance budget test observer
final class PerformanceBudgetTestObserver: NSObject, XCTestObservation {
    nonisolated func testBundleDidFinish(_: Bundle) {
        // Generate report when all tests finish
        Task {
            await XCTestCase.generatePerformanceReport()
        }
    }
}

// Register the observer
nonisolated(unsafe) private let kPerformanceObserver = PerformanceBudgetTestObserver()
private let kRegisterPerformanceObserver: Void = {
    XCTestObservationCenter.shared.addTestObserver(kPerformanceObserver)
}()
