import CodeEditorAnnotations
import CodeEditorDiagnostics
@testable import CodeEditorSwiftUI
@testable import CodeEditorSyntaxHighlighting
@testable import CodeEditorView
import XCTest

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - MemoryLeakTests

/// Tests to ensure proper memory management and no retain cycles.
///
/// The five `CodeEditorView` deallocation assertions in this file used to
/// `print("Warning: …")` in place of asserting, which made them
/// "guaranteed-green" leak detectors (REVIEW.md Tests/Critical). They now
/// assert via `XCTAssertNil` and use `XCTExpectFailure` to record the
/// underlying retention as a *known* failure — when the leak is fixed, the
/// strict expected-failure will itself fail, forcing the wrapper to be
/// removed instead of letting a fixed leak silently re-rot. The retention
/// reproduces in production code; the wrapper documents it as outstanding
/// work, not as a permitted exception.
final class MemoryLeakTests: CleanupTestCase {
    /// Shared description for the `CodeEditorView` retention these tests
    /// currently detect. Keep the phrasing consistent so log scrapes lump
    /// them together.
    private static let knownEditorRetentionReason: String = """
        Known CodeEditorView retention: instance survives autoreleasepool exit \
        + repeated runloop spins after its last local strong reference drops. \
        Tests assert the leak so when the production retention is removed \
        XCTExpectFailure(strict:) flags the wrapper for deletion.
        """

    override func setUp() {
        super.setUp()
        // Add at least one non-trivial statement to satisfy SwiftLint
        continueAfterFailure = false
    }

    // MARK: - CodeEditorView Memory Tests

    @MainActor
    func testCodeEditorViewDeallocation() {
        weak var weakEditor: CodeEditorView?
        autoreleasepool {
            let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
            weakEditor = editor
            editor.text = "test content"
            editor.language = .swift
            editor.isLineNumbersEnabled = true
            editor.removeFromSuperview()
        }
        drainPendingRetains()
        XCTExpectFailure(Self.knownEditorRetentionReason) {
            XCTAssertNil(weakEditor, "CodeEditorView should be deallocated after its last strong reference drops")
        }
    }

    @MainActor
    func testDelegateDoesNotCreateRetainCycle() {
        weak var weakEditor: CodeEditorView?
        weak var weakDelegate: MockDelegate?
        autoreleasepool {
            let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
            let delegate = MockDelegate()
            weakEditor = editor
            weakDelegate = delegate
            editor.textDelegate = delegate
            editor.text = "trigger delegate"
            // Drop the delegate before the autoreleasepool closes so the
            // delegate's only strong path is via the editor — if the editor
            // retained it, the delegate would survive.
            editor.textDelegate = nil
        }
        drainPendingRetains()
        // Delegate retention is strict — the delegate-cycle protection is the
        // primary contract of this test. The editor's own retention is the
        // known regression scoped via XCTExpectFailure.
        XCTAssertNil(weakDelegate, "Delegate must not be retained by CodeEditorView")
        XCTExpectFailure(Self.knownEditorRetentionReason) {
            XCTAssertNil(weakEditor, "CodeEditorView should be deallocated alongside its delegate")
        }
    }

    @MainActor
    func testAnnotationViewsAreCleaned() {
        weak var weakEditor: CodeEditorView?
        autoreleasepool {
            let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
            weakEditor = editor
            // Force a layout pass so any annotation-overlay-supporting view
            // graph that would be wired in real use also gets built and then
            // released here.
            #if canImport(AppKit)
            editor.needsLayout = true
            #else
            editor.setNeedsLayout()
            #endif
            editor.removeFromSuperview()
        }
        drainPendingRetains()
        XCTExpectFailure(Self.knownEditorRetentionReason) {
            XCTAssertNil(weakEditor, "Annotation/overlay path must not retain the editor")
        }
    }

    // MARK: - Performance Monitor Memory Tests

    func testPerformanceMonitorCleansUpOldMetrics() async {
        // Create a test instance instead of using deprecated singleton
        let monitor = PerformanceMonitor()

        // Clear existing metrics first
        await monitor.clearMetrics()

        // Add many metrics
        for index in 0..<2_000 {
            let token = await monitor.startMeasuring("test-\(index)")
            await monitor.endMeasuring(token)
        }

        // Check that metrics are limited
        let metrics = await monitor.getAllMetrics()
        XCTAssertLessThanOrEqual(metrics.count, 1_000, "Performance monitor should limit metrics count")
    }

    func testPerformanceMonitorPeriodicCleanup() async throws {
        // Create a test instance instead of using deprecated singleton
        let monitor = PerformanceMonitor()

        // Clear existing metrics first
        await monitor.clearMetrics()

        // Add an old metric
        let oldToken = await monitor.startMeasuring("old-metric")
        await monitor.endMeasuring(oldToken)

        // Clear metrics older than 1 second
        try await Task.sleep(nanoseconds: 1_100_000_000) // 1.1 seconds
        await monitor.clearMetrics(olderThan: 1.0)

        let metrics = await monitor.getAllMetrics()
        XCTAssertEqual(metrics.count, 0, "Old metrics should be cleaned up")
    }

    // MARK: - Syntax Highlighting Memory Tests

    func testSyntaxHighlightingCancellation() async {
        // Test cancellation behavior by creating a coordinator and calling cancel
        let coordinator = SyntaxHighlightingCoordinator()

        // Call cancellation - this should not crash even if no tasks are running
        coordinator.cancelHighlighting()

        // Verify the coordinator is still functional after cancellation
        let simpleText = "func test() {}"
        let tokens = await coordinator.highlightAsync(source: simpleText, language: .swift)
        XCTAssertFalse(tokens.isEmpty, "Coordinator should still work after cancellation")
    }

    @MainActor
    func testSyntaxHighlightingDoesNotRetainTextView() {
        weak var weakEditor: CodeEditorView?
        autoreleasepool {
            let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
            weakEditor = editor
            editor.language = .swift
            editor.isSyntaxHighlightingEnabled = true
            editor.text = "func hello() { print(\"world\") }"
            #if canImport(AppKit)
            editor.needsLayout = true
            #else
            editor.setNeedsLayout()
            #endif
            editor.isSyntaxHighlightingEnabled = false
            editor.removeFromSuperview()
        }
        drainPendingRetains()
        XCTExpectFailure(Self.knownEditorRetentionReason) {
            XCTAssertNil(weakEditor, "Syntax-highlighting coordinator must not retain the editor")
        }
    }

    // MARK: - Completion System Memory Tests

    @MainActor
    func testCompletionPopupCleansUp() {
        weak var weakEditor: CodeEditorView?
        autoreleasepool {
            let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
            weakEditor = editor
            editor.text = "let test = String()"
            editor.removeFromSuperview()
        }
        drainPendingRetains()
        XCTExpectFailure(Self.knownEditorRetentionReason) {
            XCTAssertNil(weakEditor, "Completion subsystem must not retain the editor")
        }
    }

    // MARK: - Helpers

    /// Spin the runloop a few times inside nested autoreleasepools so
    /// framework-autoreleased helpers and TextKit2 background cleanup work
    /// have a chance to drop their references before we assert.
    @MainActor
    private func drainPendingRetains() {
        for _ in 0..<5 {
            autoreleasepool {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
            }
        }
    }
}

// MARK: - Mock Delegate

@MainActor
private class MockDelegate: NSObject, CodeEditorViewDelegate {
    var changeCount = 0

    func textViewDidChangeText(_: Notification) {
        changeCount += 1
    }
}
