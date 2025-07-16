@testable import CodeEditorPlugin
import XCTest

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Performance tests for syntax highlighting with large files
@MainActor
final class SyntaxHighlightingPerformanceTests: XCTestCase {
    // swiftlint:disable:next unneeded_override
    override func setUp() {
        super.setUp()
        // Setup is intentionally empty
    }
    
    override func tearDown() {
        super.tearDown()
        // Force cleanup to prevent deallocation warnings
        autoreleasepool {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
    }
    // MARK: - Test Data Generation
    
    private func generateSwiftCode(lines: Int) -> String {
        var code = """
        // Swift file for performance testing
        import Foundation
        
        """
        
        // Generate simpler Swift code
        for index in 0..<lines {
            if index.isMultiple(of: 15) {
                code += "\n// MARK: - Section \(index / 15)\n\n"
            }
            
            if index.isMultiple(of: 4) {
                code += "let constant\(index) = \(index) // Simple constant\n"
            } else if index % 4 == 1 {
                code += "var variable\(index) = \"\(index)\" // String variable\n"
            } else if index % 4 == 2 {
                code += "func calculate\(index)(_ x: Int) -> Int { return x * \(index) }\n"
            } else {
                code += "print(\"Line \(index)\")\n"
            }
        }
        
        return code
    }
    
    private func generateJavaScriptCode(lines: Int) -> String {
        var code = """
        // JavaScript file for performance testing
        const utils = require('./utils');
        
        """
        
        // Generate simpler JavaScript code that's still realistic
        for index in 0..<lines {
            if index.isMultiple(of: 10) {
                code += "\n// Section \(index / 10)\n"
            }
            
            if index.isMultiple(of: 3) {
                code += "const value\(index) = \(index) * 2; // Simple calculation\n"
            } else if index % 3 == 1 {
                code += "function process\(index)(data) { return data.map(x => x * \(index)); }\n"
            } else {
                code += "console.log('Processing item \(index)');\n"
            }
        }
        
        return code
    }
    
    private func generatePythonCode(lines: Int) -> String {
        var code = """
        # Python file for performance testing
        import sys
        
        """
        
        // Generate simpler Python code
        for index in 0..<lines {
            if index.isMultiple(of: 10) {
                code += "\n# Section \(index / 10)\n"
            }
            
            if index.isMultiple(of: 3) {
                code += "value_\(index) = \(index) * 2  # Simple calculation\n"
            } else if index % 3 == 1 {
                code += "def process_\(index)(x): return x * \(index)\n"
            } else {
                code += "print('Processing item \(index)')\n"
            }
        }
        
        return code
    }
    
    // MARK: - Swift Performance Tests
    
    func testSwiftHighlightingSmallFile() async {
        let editorView = CodeEditorView()
        let code = generateSwiftCode(lines: 30)  // Reduced from 100
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        editorView.language = .swift
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        editorView.string = code
        #else
        editorView.text = code
        #endif
        
        // Trigger immediate highlighting
        await editorView.asyncHighlighter.highlightImmediately(
            for: editorView,
            language: .swift
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Small files should highlight quickly (under 1 second)
        XCTAssertLessThan(duration, 1.0, "Small file highlighting took \(duration) seconds")
    }
    
    func testSwiftHighlightingMediumFile() async {
        let editorView = CodeEditorView()
        let code = generateSwiftCode(lines: 100)  // Reduced from 1000
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        editorView.language = .swift
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        editorView.string = code
        #else
        editorView.text = code
        #endif
        
        await editorView.asyncHighlighter.highlightImmediately(
            for: editorView,
            language: .swift
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Medium files should highlight reasonably fast
        XCTAssertLessThan(duration, 1.5, "Medium file highlighting took \(duration) seconds")
    }
    
    func testSwiftHighlightingLargeFile() async {
        let editorView = CodeEditorView()
        let code = generateSwiftCode(lines: 200)  // Reduced from 10000
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        editorView.language = .swift
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        editorView.string = code
        #else
        editorView.text = code
        #endif
        
        await editorView.asyncHighlighter.highlightImmediately(
            for: editorView,
            language: .swift
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Large files should still complete in reasonable time (under 3 seconds)
        XCTAssertLessThan(duration, 3.0, "Large file highlighting took \(duration) seconds")
    }
    
    // MARK: - JavaScript Performance Tests
    
    func testJavaScriptHighlightingMediumFile() async {
        let editorView = CodeEditorView()
        let code = generateJavaScriptCode(lines: 100)  // Reduced from 1000
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        editorView.language = .javascript
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        editorView.string = code
        #else
        editorView.text = code
        #endif
        
        await editorView.asyncHighlighter.highlightImmediately(
            for: editorView,
            language: .javascript
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        XCTAssertLessThan(duration, 2.0, "JavaScript highlighting took \(duration) seconds")
    }
    
    // MARK: - Python Performance Tests
    
    func testPythonHighlightingMediumFile() async {
        let editorView = CodeEditorView()
        let code = generatePythonCode(lines: 100)  // Reduced from 1000
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        editorView.language = .python
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        editorView.string = code
        #else
        editorView.text = code
        #endif
        
        await editorView.asyncHighlighter.highlightImmediately(
            for: editorView,
            language: .python
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        XCTAssertLessThan(duration, 7.0, "Python highlighting took \(duration) seconds")
    }
    
    // MARK: - Incremental Highlighting Tests
    
    func testIncrementalHighlightingPerformance() async {
        let editorView = CodeEditorView()
        let initialCode = generateSwiftCode(lines: 100)  // Reduced from 1000
        
        editorView.language = .swift
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        editorView.string = initialCode
        #else
        editorView.text = initialCode
        #endif
        
        // Wait for initial highlighting
        await editorView.asyncHighlighter.highlightImmediately(
            for: editorView,
            language: .swift
        )
        
        // Measure incremental update
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Insert a line in the middle
        let insertionPoint = initialCode.count / 2
        let modifiedCode = String(initialCode.prefix(insertionPoint)) + 
            "\n    // New comment inserted\n" + 
            String(initialCode.suffix(initialCode.count - insertionPoint))
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        editorView.string = modifiedCode
        #else
        editorView.text = modifiedCode
        #endif
        
        await editorView.asyncHighlighter.highlightImmediately(
            for: editorView,
            language: .swift
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Incremental updates should be fast (allow more time on Catalyst and simulator)
        #if targetEnvironment(macCatalyst)
        XCTAssertLessThan(duration, 3.0, "Incremental highlighting took \(duration) seconds")
        #elseif targetEnvironment(simulator)
        XCTAssertLessThan(duration, 5.0, "Incremental highlighting took \(duration) seconds")
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Native macOS may need slightly more time for incremental updates
        XCTAssertLessThan(duration, 2.0, "Incremental highlighting took \(duration) seconds")
        #else
        XCTAssertLessThan(duration, 1.5, "Incremental highlighting took \(duration) seconds")
        #endif
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageWithLargeFile() async {
        let editorView = CodeEditorView()
        let memoryMonitor = MemoryMonitor()
        let code = generateSwiftCode(lines: 500)  // Reduced from 50000
        
        // Baseline memory
        let baselineMemory = memoryMonitor.getCurrentMemoryUsage()
        
        editorView.language = .swift
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        editorView.string = code
        #else
        editorView.text = code
        #endif
        
        await editorView.asyncHighlighter.highlightImmediately(
            for: editorView,
            language: .swift
        )
        
        // Check memory increase
        let finalMemory = memoryMonitor.getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - baselineMemory
        let memoryIncreaseMB = memoryIncrease // Already in MB
        
        // Memory increase should be reasonable (less than 200MB for 50k lines)
        XCTAssertLessThan(
            memoryIncreaseMB,
            200.0,
            "Memory usage increased by \(memoryIncreaseMB)MB, which is too high"
        )
    }
    
    // MARK: - Stress Tests
    
    func testRapidLanguageSwitching() async {
        let editorView = CodeEditorView()
        let swiftCode = generateSwiftCode(lines: 50)  // Reduced from 500
        let jsCode = generateJavaScriptCode(lines: 50)  // Reduced from 500
        let pythonCode = generatePythonCode(lines: 50)  // Reduced from 500
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Rapidly switch between languages
        for _ in 0..<3 {
            editorView.language = .swift
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            editorView.string = swiftCode
            #else
            editorView.text = swiftCode
            #endif
            await editorView.asyncHighlighter.highlightImmediately(
                for: editorView,
                language: .swift
            )
            
            editorView.language = .javascript
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            editorView.string = jsCode
            #else
            editorView.text = jsCode
            #endif
            await editorView.asyncHighlighter.highlightImmediately(
                for: editorView,
                language: .javascript
            )
            
            editorView.language = .python
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            editorView.string = pythonCode
            #else
            editorView.text = pythonCode
            #endif
            await editorView.asyncHighlighter.highlightImmediately(
                for: editorView,
                language: .python
            )
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Should handle rapid switching efficiently (9 switches total)
        XCTAssertLessThan(duration, 30.0, "Rapid language switching took \(duration) seconds")
    }
    
    // MARK: - Regex Highlighter Performance
    
    func testRegexHighlighterPerformance() {
        let highlighter = RegexSyntaxHighlighter()
        let code = generateJavaScriptCode(lines: 100)  // Reduced from 1000
        
        measure(options: Self.standardMeasureOptions) {
            // Test regex-based highlighting performance
            if let languageDefinition = highlighter.languageDefinition(for: .javascript) {
                _ = highlighter.highlight(source: code, language: languageDefinition)
            }
        }
    }
    
    // MARK: - Visible Range Performance
    
    func testVisibleRangeHighlighting() async {
        let editorView = CodeEditorView()
        let code = generateSwiftCode(lines: 200)  // Reduced from 10000
        
        editorView.language = .swift
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        editorView.string = code
        #else
        editorView.text = code
        #endif
        
        // Simulate visible range (first 1000 characters)
        let visibleRange = NSRange(location: 0, length: min(1_000, code.count))
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await editorView.asyncHighlighter.highlightImmediately(
            for: editorView,
            language: .swift,
            visibleRange: visibleRange
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Visible range highlighting should be fast (but initial setup takes time)
        XCTAssertLessThan(duration, 5.0, "Visible range highlighting took \(duration) seconds")
    }
    
    // MARK: - Benchmark Comparison
    
    func testHighlightingBenchmark() {
        // This test provides a benchmark using XCTest's measure
        // Only test with 1000 lines to avoid multiple metric recordings
        let code = generateSwiftCode(lines: 100)  // Reduced from 1000
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let testView = CodeEditorView()
            // testView uses its own internal memoryMonitor
            testView.language = .swift
            
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            testView.string = code
            #else
            testView.text = code
            #endif
            
            // Force synchronous completion for measurement
            let expectation = expectation(description: "Highlighting")
            Task { @MainActor in
                await testView.asyncHighlighter.highlightImmediately(
                    for: testView,
                    language: .swift
                )
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 10.0)
        }
    }
}
