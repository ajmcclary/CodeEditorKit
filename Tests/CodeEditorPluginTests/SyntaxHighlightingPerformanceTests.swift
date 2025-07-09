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
    // MARK: - Test Data Generation
    
    private func generateSwiftCode(lines: Int) -> String {
        var code = """
        // Large Swift file for performance testing
        import Foundation
        import SwiftUI
        
        """
        
        // Add various Swift constructs
        for index in 0..<(lines / 20) {
            code += """
            
            // MARK: - Section \(index)
            
            /// Documentation for MyClass\(index)
            /// This class demonstrates various Swift features
            @available(iOS 15.0, *)
            class MyClass\(index): ObservableObject {
                @Published var counter = 0
                private let queue = DispatchQueue(label: "com.test.queue\(index)")
                
                func performAction() async throws -> String {
                    try await withCheckedThrowingContinuation { continuation in
                        queue.async {
                            // Simulate some work
                            Thread.sleep(forTimeInterval: 0.1)
                            continuation.resume(returning: "Result \(index)")
                        }
                    }
                }
                
                private func helperMethod(param: String, count: Int = 10) -> [String] {
                    (0..<count).map { "\\(param)-\\($0)" }
                }
            }
            
            """
        }
        
        return code
    }
    
    private func generateJavaScriptCode(lines: Int) -> String {
        var code = """
        // Large JavaScript file for performance testing
        const lodash = require('lodash');
        const express = require('express');
        
        """
        
        for index in 0..<(lines / 15) {
            code += """
            
            // Section \(index)
            class Component\(index) extends React.Component {
                constructor(props) {
                    super(props);
                    this.state = { count: 0, data: [] };
                }
                
                async fetchData() {
                    try {
                        const response = await fetch(`/api/data/\(index)`);
                        const data = await response.json();
                        this.setState({ data });
                    } catch (error) {
                        console.error('Error fetching data:', error);
                    }
                }
                
                render() {
                    return (
                        <div className="component-\(index)">
                            <h1>Component \(index)</h1>
                            <p>Count: {this.state.count}</p>
                        </div>
                    );
                }
            }
            
            """
        }
        
        return code
    }
    
    private func generatePythonCode(lines: Int) -> String {
        var code = """
        # Large Python file for performance testing
        import asyncio
        import json
        from typing import List, Dict, Optional
        
        """
        
        for index in 0..<(lines / 12) {
            code += """
            
            # Section \(index)
            class DataProcessor\(index):
                '''A class for processing data with async support'''
                
                def __init__(self, config: Dict[str, Any]):
                    self.config = config
                    self._cache = {}
                    
                async def process_batch(self, items: List[str]) -> List[Dict]:
                    results = []
                    for item in items:
                        processed = await self._process_single(item)
                        results.append(processed)
                    return results
                    
                @staticmethod
                def validate_input(data: str) -> bool:
                    try:
                        json.loads(data)
                        return True
                    except json.JSONDecodeError:
                        return False
            
            """
        }
        
        return code
    }
    
    // MARK: - Swift Performance Tests
    
    func testSwiftHighlightingSmallFile() async {
        let editorView = CodeEditorView()
        let code = generateSwiftCode(lines: 100)
        
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
        
        // Small files should highlight quickly (under 0.5 seconds)
        XCTAssertLessThan(duration, 0.5, "Small file highlighting took \(duration) seconds")
    }
    
    func testSwiftHighlightingMediumFile() async {
        let editorView = CodeEditorView()
        let code = generateSwiftCode(lines: 1_000)
        
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
        
        // Medium files should highlight reasonably fast (under 2 seconds)
        XCTAssertLessThan(duration, 2.0, "Medium file highlighting took \(duration) seconds")
    }
    
    func testSwiftHighlightingLargeFile() async {
        let editorView = CodeEditorView()
        let code = generateSwiftCode(lines: 10_000)
        
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
        
        // Large files should still complete in reasonable time (under 10 seconds)
        XCTAssertLessThan(duration, 10.0, "Large file highlighting took \(duration) seconds")
    }
    
    // MARK: - JavaScript Performance Tests
    
    func testJavaScriptHighlightingMediumFile() async {
        let editorView = CodeEditorView()
        let code = generateJavaScriptCode(lines: 1_000)
        
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
        let code = generatePythonCode(lines: 1_000)
        
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
        
        XCTAssertLessThan(duration, 2.0, "Python highlighting took \(duration) seconds")
    }
    
    // MARK: - Incremental Highlighting Tests
    
    func testIncrementalHighlightingPerformance() async {
        let editorView = CodeEditorView()
        let initialCode = generateSwiftCode(lines: 1_000)
        
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
        
        // Incremental updates should be fast
        XCTAssertLessThan(duration, 0.5, "Incremental highlighting took \(duration) seconds")
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageWithLargeFile() async {
        let editorView = CodeEditorView()
        let memoryMonitor = MemoryMonitor()
        let code = generateSwiftCode(lines: 50_000)
        
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
        let swiftCode = generateSwiftCode(lines: 500)
        let jsCode = generateJavaScriptCode(lines: 500)
        let pythonCode = generatePythonCode(lines: 500)
        
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
        XCTAssertLessThan(duration, 20.0, "Rapid language switching took \(duration) seconds")
    }
    
    // MARK: - Regex Highlighter Performance
    
    func testRegexHighlighterPerformance() {
        let highlighter = RegexSyntaxHighlighter()
        let code = generateJavaScriptCode(lines: 1_000)
        
        measure {
            // Test regex-based highlighting performance
            if let languageDefinition = highlighter.languageDefinition(for: .javascript) {
                _ = highlighter.highlight(source: code, language: languageDefinition)
            }
        }
    }
    
    // MARK: - Visible Range Performance
    
    func testVisibleRangeHighlighting() async {
        let editorView = CodeEditorView()
        let code = generateSwiftCode(lines: 10_000)
        
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
        XCTAssertLessThan(duration, 2.0, "Visible range highlighting took \(duration) seconds")
    }
    
    // MARK: - Benchmark Comparison
    
    func testHighlightingBenchmark() {
        // This test provides a benchmark using XCTest's measure
        // Only test with 1000 lines to avoid multiple metric recordings
        let code = generateSwiftCode(lines: 1_000)
        
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
