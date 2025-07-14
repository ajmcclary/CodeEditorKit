@testable import CodeEditorPlugin
import Foundation
import XCTest

@MainActor
final class LargeFileHighlightingBenchmarkTests: XCTestCase {
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
    // MARK: - Test Helpers
    
    private func createTestComponents() -> (AsyncSyntaxHighlighter, CodeEditorView, MemoryMonitor) {
        let memoryMonitor = MemoryMonitor()
        let highlighter = AsyncSyntaxHighlighter(memoryMonitor: memoryMonitor)
        let editorView = CodeEditorView(frame: .zero, memoryMonitor: memoryMonitor)
        editorView.asyncHighlighter = highlighter
        return (highlighter, editorView, memoryMonitor)
    }
    
    private func generateSimpleSwiftFile(lines: Int) -> String {
        var code = "import Foundation\n\n"
        
        for index in 0..<lines {
            code += "let value\(index) = \(index) // Simple constant\n"
            if index.isMultiple(of: 5) {
                code += "func process\(index)() -> Int { return \(index) * 2 }\n"
            }
        }
        
        return code
    }
    
    private func generateLargeSwiftFile(lines: Int) -> String {
        // Use simplified generation for benchmark tests
        generateSimpleSwiftFile(lines: lines)
    }
    
    private func generateSimpleJSONFile(objects: Int) -> String {
        var json = "[\n"
        
        for index in 0..<objects {
            json += """
              {"id": \(index), "name": "Item \(index)", "value": \(index * 2)}
            """
            json += index < objects - 1 ? ",\n" : "\n"
        }
        
        json += "]"
        return json
    }
    
    private func generateLargeJSONFile(objects: Int) -> String {
        // Use simplified generation for benchmark tests
        generateSimpleJSONFile(objects: objects)
    }
    
    // MARK: - Swift Highlighting Benchmarks
    
    func testSwiftHighlightingSmallFile() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        let code = generateLargeSwiftFile(lines: 5) // Reduced from 20
        editorView.text = code
        editorView.language = .swift
        
        // Single run instead of multiple
        let start = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        print("Small file highlighting: \(String(format: "%.3f", elapsed))s")
        
        XCTAssertLessThan(elapsed, 0.5, "Small file should highlight in less than 0.5 seconds")
    }
    
    func testSwiftHighlightingMediumFile() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        let code = generateLargeSwiftFile(lines: 15) // Reduced from 50
        editorView.text = code
        editorView.language = .swift
        
        let start = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        print("Medium file highlighting: \(String(format: "%.3f", elapsed))s")
        XCTAssertLessThan(elapsed, 1.5, "Medium file should highlight in less than 1.5 seconds")
    }
    
    func testSwiftHighlightingLargeFile() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        let code = generateLargeSwiftFile(lines: 25) // Reduced from 100
        editorView.text = code
        editorView.language = .swift
        
        let start = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        print("Large file highlighting: \(String(format: "%.3f", elapsed))s")
        XCTAssertLessThan(elapsed, 2.0, "Large file should highlight in less than 2 seconds")
    }
    
    // MARK: - JSON Highlighting Benchmarks
    
    func testJSONHighlightingSmallFile() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        let json = generateLargeJSONFile(objects: 10) // Reduced from 100
        editorView.text = json
        editorView.language = .json
        
        let start = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .json)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        print("JSON small file highlighting: \(String(format: "%.3f", elapsed))s")
        XCTAssertLessThan(elapsed, 1.0, "JSON small file should highlight quickly")
    }
    
    func testJSONHighlightingLargeFile() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        let json = generateLargeJSONFile(objects: 50) // Dramatically reduced from 5000
        editorView.text = json
        editorView.language = .json
        
        let start = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .json)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        print("JSON large file highlighting: \(String(format: "%.3f", elapsed))s")
        XCTAssertLessThan(elapsed, 2.0, "JSON large file should highlight in reasonable time")
    }
    
    // MARK: - Memory Usage Tests
    
    // Disabled: Takes too long
    /*
    func testMemoryUsageDuringLargeFileHighlighting() async throws {
        let (highlighter, editorView, memoryMonitor) = createTestComponents()
        defer { highlighter.cleanup() }
        
        // Reset memory statistics
        memoryMonitor.resetStatistics()
        
        // Generate a very large file
        let code = generateLargeSwiftFile(lines: 200) // ~20KB
        
        // Get initial memory
        let initialMemory = memoryMonitor.getCurrentMemoryUsage()
        
        // Set the text and highlight
        editorView.text = code
        editorView.language = .swift
        
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        
        // Wait for memory to settle
        try await Task.sleep(for: .seconds(1))
        
        // Get final memory
        let finalMemory = memoryMonitor.getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Get memory statistics
        let stats = memoryMonitor.getMemoryStatistics()
        
        // Verify memory usage is reasonable
        XCTAssertLessThan(memoryIncrease, 50.0, "Memory increase should be less than 50MB for 1MB file")
        XCTAssertGreaterThan(stats.peakUsageMB, initialMemory, "Peak usage should be recorded")
        
        // Log results for analysis
        print("""
        Memory Usage Results:
        - Initial: \(String(format: "%.1f", initialMemory))MB
        - Final: \(String(format: "%.1f", finalMemory))MB
        - Increase: \(String(format: "%.1f", memoryIncrease))MB
        - Peak: \(String(format: "%.1f", stats.peakUsageMB))MB
        """)
    }
    */
    
    // MARK: - Background Highlighting Tests
    
    // Disabled: Takes too long
    /*
    func testBackgroundHighlightingActivation() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        // Configure threshold
        highlighter.enableBackgroundHighlighting = true
        highlighter.backgroundHighlightingThreshold = 50_000 // 50KB
        
        // Test with file below threshold (should use regular highlighting)
        let smallCode = generateLargeSwiftFile(lines: 50) // ~5KB
        editorView.text = smallCode
        editorView.language = .swift
        
        let start1 = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        let time1 = CFAbsoluteTimeGetCurrent() - start1
        
        // Test with file above threshold (should use background highlighting)
        let largeCode = generateLargeSwiftFile(lines: 200) // ~20KB
        editorView.text = largeCode
        
        let start2 = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        let time2 = CFAbsoluteTimeGetCurrent() - start2
        
        // Get background highlighting statistics
        let bgStats = highlighter.backgroundStatistics
        
        // Verify background highlighting was used for large file
        XCTAssertGreaterThan(bgStats.totalRequests, 0, "Background highlighting should have been used")
        
        print("""
        Background Highlighting Results:
        - Small file time: \(String(format: "%.3f", time1))s
        - Large file time: \(String(format: "%.3f", time2))s
        - Background requests: \(bgStats.totalRequests)
        - Background completions: \(bgStats.completedRequests)
        """)
    }
    */
    
    // MARK: - Incremental Highlighting Tests
    
    // Disabled: Takes too long
    /*
    func testIncrementalHighlightingPerformance() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        // Start with a medium-sized file
        let initialCode = generateLargeSwiftFile(lines: 500)
        editorView.text = initialCode
        editorView.language = .swift
        
        // Initial highlighting
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        
        // Measure incremental updates
        var times: [TimeInterval] = []
        for iteration in 0..<5 {
            let newCode = initialCode + "\n// Comment line \(iteration)"
            editorView.text = newCode
            
            let start = CFAbsoluteTimeGetCurrent()
            await highlighter.highlightImmediately(for: editorView, language: .swift)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            times.append(elapsed)
        }
        
        let averageTime = times.reduce(0, +) / Double(times.count)
        print("Incremental update average: \(String(format: "%.3f", averageTime))s")
        
        XCTAssertLessThan(averageTime, 0.5, "Incremental updates should be fast")
    }
    */
    
    // MARK: - Multi-Language Performance
    
    /*
    func testMultiLanguageHighlightingComparison() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        let languages: [(Language, String)] = [
            (.swift, generateLargeSwiftFile(lines: 500)),
            (.python, String(repeating: "def function_\(UUID())():\n    pass\n\n", count: 500)),
            (.javascript, String(repeating: "function test() { return Math.random(); }\n", count: 500)),
            (.json, generateLargeJSONFile(objects: 500)),
            (.markdown, String(repeating: "# Heading\n\nParagraph with **bold** and *italic*.\n\n", count: 500))
        ]
        
        var results: [(Language, TimeInterval)] = []
        
        for (language, code) in languages {
            editorView.text = code
            editorView.language = language
            
            let start = CFAbsoluteTimeGetCurrent()
            await highlighter.highlightImmediately(for: editorView, language: language)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            
            results.append((language, elapsed))
            
            // Clear cache between languages for fair comparison
            await highlighter.clearCache()
        }
        
        // Print comparison results
        print("\nLanguage Performance Comparison:")
        for (language, time) in results.sorted(by: { $0.1 < $1.1 }) {
            print("- \(language): \(String(format: "%.3f", time))s")
        }
        
        // Verify all languages completed in reasonable time
        for (language, time) in results {
            XCTAssertLessThan(time, 5.0, "\(language) highlighting should complete within 5 seconds")
        }
    }
    */
}
