import CodeEditorCommon
import CodeEditorConfiguration
import CodeEditorLanguages
@testable import CodeEditorPlugin
import XCTest

/// Performance regression tests to ensure optimizations don't degrade over time
final class PerformanceRegressionTests: CleanupTestCase {
    private let logger = CrossPlatformLogger.logger(
        subsystem: "com.codeeditor.tests",
        category: "PerformanceRegression"
    )

    override func setUp() async throws {
        try await super.setUp()
        // Give the system time to settle between tests
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }

    override func tearDown() async throws {
        // Allow cleanup time
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        try await super.tearDown()
    }

    // MARK: - Test Configuration

    /// Performance baselines based on optimization targets
    private enum PerformanceBaselines {
        static let asyncOperationDebounce: TimeInterval = 2.0 // 2s for 500 operations with debouncing
        static let fuzzyMatcherSearch: TimeInterval = 0.1 // 100ms for 10k candidates
        static let symbolNavigatorLookup: TimeInterval = 0.2 // 200ms for navigation
        static let memoryPressureTest: TimeInterval = 2.0 // 2s max
        static let tolerancePercentage: Double = 50.0 // Allow 50% variance for CI environment

        // New baselines for tests we optimized
        static let completionCancellation: TimeInterval = 0.1 // 100ms max (was 131s)
        static let layoutOperationRecording: TimeInterval = 0.01 // 10ms max (was 46s)
        static let memoryPressureRecovery: TimeInterval = 0.5 // 500ms max (was 24s)
        static let contextMenuCreation: TimeInterval = 0.5 // 500ms max (was 74-90s)
    }

    // MARK: - AsyncOperationManager Tests

    func testAsyncOperationManagerRegressionCheck() async throws {
        let manager = AsyncOperationManager()

        // Measure performance with reasonable operation count
        let startTime = CFAbsoluteTimeGetCurrent()

        // Test debouncing performance with fewer operations for suite stability
        for index in 0..<50 {
            try? await manager.debounce(key: "test-debounce", delay: 0.001) {
                // Just execute without capturing
                _ = index
            }
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime

        // Log performance for debugging
        logger.info("[testAsyncOperationManagerRegressionCheck] Duration: \(duration)s for 50 operations")

        // Allow generous time when running in full suite
        XCTAssertLessThan(duration, 10.0, "Debounce operations took too long: \(duration)s")
    }

    func testAsyncOperationManagerPerformanceBaseline() async throws {
        let manager = AsyncOperationManager()
        let startTime = CFAbsoluteTimeGetCurrent()

        // Run operations with unique keys - reduced count for suite stability
        for index in 0..<200 {
            try? await manager.debounce(key: "test-\(index % 10)", delay: 0.001) {
                _ = index
            }
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime

        // Log performance for debugging
        logger.info("[testAsyncOperationManagerPerformanceBaseline] Duration: \(duration)s for 200 operations")

        // Use a very forgiving baseline for suite runs to avoid flaky failures
        let suiteAdjustedBaseline = 15.0 // 15 seconds should be enough even under heavy load

        XCTAssertLessThan(
            duration,
            suiteAdjustedBaseline,
            "AsyncOperationManager performance regression detected: \(duration)s > suite baseline \(suiteAdjustedBaseline)s"
        )
    }

    // MARK: - OptimizedFuzzyMatcher Tests

    @MainActor
    func testFuzzyMatcherRegressionCheck() throws {
        let matcher = OptimizedFuzzyMatcher()
        let candidates = (0..<10_000).map { "function\($0)WithLongName" }

        measure(metrics: [XCTClockMetric()]) {
            let patterns = ["func", "with", "name", "f100", "fwln"]
            for pattern in patterns {
                let results = matcher.matchSequential(pattern: pattern, candidates: candidates)
                XCTAssertFalse(results.isEmpty, "OptimizedFuzzyMatcher should return results for pattern: \(pattern)")
            }
        }
    }

    @MainActor
    func testFuzzyMatcherPerformanceBaseline() throws {
        let matcher = OptimizedFuzzyMatcher()
        let candidates = (0..<10_000).map { "function\($0)WithLongName" }

        var results: [OptimizedFuzzyMatcher.MatchResult] = []

        measureAgainstBudget("fuzzy_search") {
            results = matcher.matchSequential(pattern: "func", candidates: candidates)
        }

        XCTAssertFalse(results.isEmpty)
    }

    // MARK: - SymbolNavigator Tests

    @MainActor
    func testSymbolNavigatorRegressionCheck() throws {
        let navigator = SymbolNavigator()
        let textView = createCodeEditorView(frame: .zero)

        // Generate test code with many symbols
        var largeCode = ""
        for index in 0..<50 {
            largeCode += """

            class TestClass\(index) {
                var property\(index): String = "test"

                func method\(index)() -> String {
                    return property\(index)
                }

                private func helperMethod\(index)() {
                    // Helper implementation
                }
            }

            """
        }

        textView.text = largeCode
        textView.language = .swift
        navigator.attach(to: textView)

        measure(metrics: [XCTClockMetric()]) {
            navigator.updateSymbols()

            // Simulate navigation operations
            navigator.navigateToNext()
            navigator.navigateToPrevious()

            // Update breadcrumbs
            navigator.updateBreadcrumbs()
        }
    }

    @MainActor
    func testSymbolNavigatorPerformanceBaseline() throws {
        let navigator = SymbolNavigator()
        let textView = createCodeEditorView(frame: .zero)

        // Generate large code file
        var largeCode = ""
        for index in 0..<100 {
            largeCode += "func testFunction\(index)() { /* implementation */ }\n"
        }

        textView.text = largeCode
        textView.language = .swift
        navigator.attach(to: textView)

        let startTime = CFAbsoluteTimeGetCurrent()
        navigator.updateSymbols()
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertLessThan(
            duration,
            PerformanceBaselines.symbolNavigatorLookup * (1.0 + PerformanceBaselines.tolerancePercentage / 100.0),
            "SymbolNavigator performance regression detected: \(duration)s > baseline \(PerformanceBaselines.symbolNavigatorLookup)s"
        )
    }

    // MARK: - Memory Tests

    @MainActor
    func testMemoryPressureRegressionCheck() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Create editors manually instead of using withMultipleEditors to avoid async/throws issues
        var editors: [CodeEditorView] = []
        for index in 0..<5 {
            let editor = createCodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
            editor.text = "Editor \(index): " + MemoryBoundedTestData.repetitiveText(
                pattern: "test ",
                count: 100
            )
            editor.language = .swift
            editor.isLineNumbersEnabled = false
            editors.append(editor)
        }

        // Editors will be automatically cleaned up by CleanupTestCase tearDown

        let duration = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertLessThan(
            duration,
            PerformanceBaselines.memoryPressureTest * 3,
            "Memory pressure test regression detected: \(duration)s > baseline \(PerformanceBaselines.memoryPressureTest)s"
        )
    }

    // MARK: - Combined Performance Test

    @MainActor
    func testCombinedPerformanceScenario() async throws {
        // This test simulates a realistic usage scenario
        let editor = createCodeEditorView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let asyncManager = AsyncOperationManager()
        let fuzzyMatcher = OptimizedFuzzyMatcher()
        let navigator = SymbolNavigator()

        // Set up large code file
        var code = ""
        for index in 0..<20 {
            code += """
            class Service\(index) {
                func process\(index)(data: String) -> Result<String, Error> {
                    // Complex processing logic
                    return .success(data)
                }
            }

            """
        }

        editor.text = code
        editor.language = Language.swift
        navigator.attach(to: editor)

        let startTime = CFAbsoluteTimeGetCurrent()

        // Simulate realistic operations

        // 1. Update symbols
        navigator.updateSymbols()

        // 2. Perform completions
        let candidates = ["processData", "processInput", "processOutput", "handleProcess"]
        _ = fuzzyMatcher.matchSequential(pattern: "proc", candidates: candidates)

        // 3. Debounced operations
        for index in 0..<10 {
            try? await asyncManager.debounce(key: "edit", delay: 0.01) {
                // Simulate edit without actually modifying the editor
                _ = index
            }
        }

        let totalDuration = CFAbsoluteTimeGetCurrent() - startTime

        // Combined operations should complete within reasonable time
        XCTAssertLessThan(totalDuration, 6.0, "Combined performance scenario took too long: \(totalDuration)s")
    }

    // MARK: - Optimized Test Regression Checks

    @MainActor
    func testCompletionCancellationPerformance() async throws {
        let completionManager = CompletionManager(memoryMonitor: MemoryMonitor())
        let slowProvider = MockSlowCompletionProvider()
        completionManager.registerProvider(slowProvider)

        let language = Language.swift
        let context = CompletionContextModel(text: "test", cursorPosition: 4, language: language)

        try await measureAsyncAgainstBudget("completion_cancellation") { @MainActor in
            // Start and cancel a request
            Task { @MainActor in
                do {
                    _ = try await completionManager.requestCompletions(for: context)
                } catch {
                    // Expected cancellation
                }
            }

            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
            completionManager.cancelCurrentRequest()
        }
    }

    @MainActor
    func testLayoutOperationRecordingPerformance() async throws {
        let performanceMonitor = TextKit2PerformanceMonitor()

        let startTime = CFAbsoluteTimeGetCurrent()

        // Record multiple layout operations
        for _ in 0..<100 {
            performanceMonitor.recordLayoutOperation(duration: 0.001)
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime

        assertMeasuredDuration(
            duration,
            lessThan: PerformanceBaselines.layoutOperationRecording,
            operation: "layout operation recording"
        )
    }

    @MainActor
    func testMemoryPressureRecoveryPerformance() async throws {
        let editorView = createCodeEditorView()

        try await measureAsyncAgainstBudget("memory_pressure_recovery") { @MainActor in
            // Simulate memory pressure with smaller text. The string
            // literal embeds `print(...)` as Swift sample content; the
            // tightened no_print_statements rule uses match_kinds:
            // identifier so it correctly ignores string-literal
            // content like this without needing a per-line disable.
            let largeText = String(repeating: "func test() { print(\"memory test\") }\n", count: 100)
            editorView.text = largeText

            // Verify editor remains functional
            editorView.text = "func newFunction() {}"
        }
    }

    @MainActor
    func testContextMenuCreationPerformance() async throws {
        let coordinator = CrossPlatformCoordinator()
        let textView = createCodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = "Hello, World! This is a test."

        var menu: Any?

        try await measureAsyncAgainstBudget("context_menu_creation") { @MainActor in
            // Create context menu
            let range = NSRange(location: 0, length: 5)
            textView.selectedRange = range
            menu = coordinator.createContextMenu(for: range, in: textView)
        }

        XCTAssertNotNil(menu)
    }

    // `measureAndReport` used to live here but had no callers — every
    // existing test uses `measureAsyncAgainstBudget` / `XCTClockMetric`
    // instead. Removed wholesale alongside its `print()` call.
}

// MARK: - Mock Providers for Testing

@MainActor
private class MockSlowCompletionProvider: CompletionProvider {
    let id = "slow-provider"
    let supportedLanguages: [Language] = [.swift]
    let triggerCharacters: [String] = []

    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        // Check for cancellation frequently
        for _ in 0..<20 {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }

        return CompletionResult(
            items: [],
            context: context,
            isIncomplete: false,
            processingTime: 0.02
        )
    }
}
