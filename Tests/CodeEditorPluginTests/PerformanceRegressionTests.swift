@testable import CodeEditorPlugin
import XCTest

/// Performance regression tests to ensure optimizations don't degrade over time
final class PerformanceRegressionTests: XCTestCase {
    // MARK: - Test Configuration
    
    /// Performance baselines based on optimization targets
    private enum PerformanceBaselines {
        static let asyncOperationDebounce: TimeInterval = 2.0 // 2s for 500 operations with debouncing
        static let fuzzyMatcherSearch: TimeInterval = 0.1 // 100ms for 10k candidates
        static let symbolNavigatorLookup: TimeInterval = 0.2 // 200ms for navigation
        static let memoryPressureTest: TimeInterval = 2.0 // 2s max
        static let tolerancePercentage: Double = 50.0 // Allow 50% variance for CI environment
    }
    
    // MARK: - AsyncOperationManager Tests
    
    @MainActor
    func testAsyncOperationManagerRegressionCheck() throws {
        let manager = AsyncOperationManager()
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = self.expectation(description: "Debounce operations")
            
            Task { @MainActor in
                // Test debouncing performance
                for index in 0..<500 {
                    try? await manager.debounce(key: "test-debounce", delay: 0.001) {
                        // Just execute without capturing
                        _ = index
                    }
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    @MainActor
    func testAsyncOperationManagerPerformanceBaseline() throws {
        let manager = AsyncOperationManager()
        let startTime = CFAbsoluteTimeGetCurrent()
        let expectation = self.expectation(description: "Performance baseline")
        
        Task {
            for index in 0..<500 {
                try? await manager.debounce(key: "test-\(index % 10)", delay: 0.001) {
                    _ = index
                }
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(
            duration,
            PerformanceBaselines.asyncOperationDebounce * (1.0 + PerformanceBaselines.tolerancePercentage / 100.0),
            "AsyncOperationManager performance regression detected: \(duration)s > baseline \(PerformanceBaselines.asyncOperationDebounce)s"
        )
    }
    
    // MARK: - FuzzyMatcher Tests
    
    @MainActor
    func testFuzzyMatcherRegressionCheck() throws {
        let matcher = FuzzyMatcher()
        let candidates = (0..<10_000).map { "function\($0)WithLongName" }
        
        measure(metrics: [XCTClockMetric()]) {
            let patterns = ["func", "with", "name", "f100", "fwln"]
            for pattern in patterns {
                let results = matcher.match(pattern: pattern, candidates: candidates)
                XCTAssertFalse(results.isEmpty, "FuzzyMatcher should return results for pattern: \(pattern)")
            }
        }
    }
    
    @MainActor
    func testFuzzyMatcherPerformanceBaseline() throws {
        let matcher = FuzzyMatcher()
        let candidates = (0..<10_000).map { "function\($0)WithLongName" }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let results = matcher.match(pattern: "func", candidates: candidates)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertFalse(results.isEmpty)
        XCTAssertLessThan(
            duration,
            PerformanceBaselines.fuzzyMatcherSearch * (1.0 + PerformanceBaselines.tolerancePercentage / 100.0),
            "FuzzyMatcher performance regression detected: \(duration)s > baseline \(PerformanceBaselines.fuzzyMatcherSearch)s"
        )
    }
    
    // MARK: - SymbolNavigator Tests
    
    @MainActor
    func testSymbolNavigatorRegressionCheck() throws {
        let navigator = SymbolNavigator()
        let textView = CodeEditorView(frame: .zero)
        
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
        let textView = CodeEditorView(frame: .zero)
        
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
        
        var editors: [CodeEditorView] = []
        
        // Create editors
        for index in 0..<5 {
            let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
            editor.text = "Editor \(index): " + String(repeating: "test ", count: 100)
            editor.language = .swift
            editor.isLineNumbersEnabled = false
            editors.append(editor)
        }
        
        // Clean up
        editors.removeAll()
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(
            duration,
            PerformanceBaselines.memoryPressureTest,
            "Memory pressure test regression detected: \(duration)s > baseline \(PerformanceBaselines.memoryPressureTest)s"
        )
    }
    
    // MARK: - Combined Performance Test
    
    @MainActor
    func testCombinedPerformanceScenario() async throws {
        // This test simulates a realistic usage scenario
        let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let asyncManager = AsyncOperationManager()
        let fuzzyMatcher = FuzzyMatcher()
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
        editor.language = .swift
        navigator.attach(to: editor)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate realistic operations
        
        // 1. Update symbols
        navigator.updateSymbols()
        
        // 2. Perform completions
        let candidates = ["processData", "processInput", "processOutput", "handleProcess"]
        _ = fuzzyMatcher.match(pattern: "proc", candidates: candidates)
        
        // 3. Debounced operations
        for index in 0..<10 {
            try? await asyncManager.debounce(key: "edit", delay: 0.01) { @MainActor in
                // Simulate edit without actually modifying the editor
                _ = index
            }
        }
        
        let totalDuration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Combined operations should complete within reasonable time
        XCTAssertLessThan(totalDuration, 2.0, "Combined performance scenario took too long: \(totalDuration)s")
    }
    
    // MARK: - Performance Monitoring Helpers
    
    private func measureAndReport<T>(
        operation: String,
        baseline: TimeInterval,
        block: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        let percentageOfBaseline = (duration / baseline) * 100.0
        print("[\(operation)] Duration: \(String(format: "%.3f", duration))s (\(String(format: "%.1f", percentageOfBaseline))% of baseline)")
        
        if duration > baseline * 1.2 {
            XCTFail("\(operation) exceeded baseline by >20%: \(duration)s vs \(baseline)s")
        }
        
        return result
    }
}
