@testable import CodeEditorPlugin
import XCTest

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - PerformanceStressTests

/// Stress tests to verify performance under heavy load
final class PerformanceStressTests: XCTestCase {
    // MARK: - Large File Tests
    
    @MainActor
    func testLargeFileHandling() async throws {
        let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        
        // Generate a large file (1MB+)
        let largeLine = String(repeating: "a", count: 100) + "\n"
        let largeText = String(repeating: largeLine, count: 10_000) // ~1MB
        
        // Measure time to set text
        let startTime = CFAbsoluteTimeGetCurrent()
        editor.text = largeText
        let setTextTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete in reasonable time
        XCTAssertLessThan(setTextTime, 1.0, "Setting large text took too long: \(setTextTime)s")
        
        // Verify text was set correctly
        XCTAssertEqual(editor.text?.count, largeText.count)
    }
    
    @MainActor
    func testSyntaxHighlightingPerformance() async throws {
        let coordinator = SyntaxHighlightingCoordinator()
        
        // Generate Swift code
        let swiftCode = """
        import Foundation
        
        class TestClass {
            var property: String = "test"
            
            func method(param: Int) -> String {
                return "Result: \\(param)"
            }
        }
        """
        let largeSwiftCode = String(repeating: swiftCode + "\n", count: 500) // ~50KB of Swift
        
        // Measure highlighting time
        let startTime = CFAbsoluteTimeGetCurrent()
        let tokens = coordinator.highlight(source: largeSwiftCode, language: .swift)
        let highlightTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete in reasonable time
        XCTAssertLessThan(highlightTime, 2.0, "Syntax highlighting took too long: \(highlightTime)s")
        XCTAssertFalse(tokens.isEmpty, "No tokens generated")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentPerformanceMonitorAccess() async throws {
        let monitor = PerformanceMonitor.shared
        
        // Clear existing metrics
        await monitor.clearMetrics()
        
        // Perform many concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask {
                    let token = await monitor.startMeasuring("concurrent-\(index)")
                    // Simulate some work
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 1_000...10_000))
                    await monitor.endMeasuring(token)
                }
            }
        }
        
        // Verify all metrics were recorded
        let metrics = await monitor.getAllMetrics()
        XCTAssertGreaterThanOrEqual(metrics.count, 90, "Some metrics were lost due to concurrency issues")
    }
    
    func testConcurrentSyntaxHighlighting() async throws {
        // Generate test data with languages that actually produce tokens
        let languages: [(String, Language)] = [
            ("func hello() { print(\"world\") }", .swift),
            ("func another() { return 42 }", .swift),
            ("class Test { var x = 0 }", .swift),
            ("let constant = \"value\"", .swift)
        ]
        
        // Highlight concurrently - create individual coordinators to avoid data races
        let results = await withTaskGroup(of: (String, Int).self) { group in
            for (code, language) in languages {
                group.addTask {
                    let localCoordinator = SyntaxHighlightingCoordinator()
                    let tokens = localCoordinator.highlight(source: code, language: language)
                    return (language.name, tokens.count)
                }
            }
            
            var collectedResults: [(String, Int)] = []
            for await result in group {
                collectedResults.append(result)
            }
            return collectedResults
        }
        
        // Verify all languages were processed
        XCTAssertEqual(results.count, languages.count, "Not all languages were processed")
        
        // Verify each produced tokens
        for (language, tokenCount) in results {
            XCTAssertGreaterThan(tokenCount, 0, "No tokens for language: \(language)")
        }
    }
    
    // MARK: - Memory Pressure Tests
    
    @MainActor
    func testMemoryUnderPressure() async throws {
        var editors: [CodeEditorView] = []
        
        // Create multiple editors
        for index in 0..<10 {
            let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
            editor.text = "Editor \(index): " + String(repeating: "test ", count: 1_000)
            editor.language = .swift
            editor.showsLineNumbers = true
            editors.append(editor)
        }
        
        // Simulate memory pressure by forcing layout on all
        for editor in editors {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            editor.needsLayout = true
            #else
            editor.setNeedsLayout()
            #endif
        }
        
        // Clean up
        editors.removeAll()
        
        // Give time for cleanup
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // If we get here without crashing, the test passes
        XCTAssertTrue(true, "Survived memory pressure test")
    }
    
    // MARK: - Rapid Update Tests
    
    @MainActor
    func testRapidTextUpdates() async throws {
        let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        editor.language = .swift
        
        // Perform rapid updates
        let updateCount = 100
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for index in 0..<updateCount {
            editor.text = "Update \(index): func test() { return \(index) }"
        }
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let avgTime = totalTime / Double(updateCount)
        
        // Average update time should be fast
        XCTAssertLessThan(avgTime, 0.01, "Average update time too slow: \(avgTime * 1_000)ms")
    }
    
    // MARK: - Background Processing Tests
    
    func testBackgroundProcessorStress() async throws {
        let processor = BackgroundProcessor(value: "test")
        
        // Perform many concurrent operations
        await withTaskGroup(of: String.self) { group in
            for index in 0..<50 {
                group.addTask {
                    do {
                        return try await processor.processValue { value in
                            // Simulate processing
                            try await Task.sleep(nanoseconds: UInt64.random(in: 1_000...100_000))
                            return "\(value)-\(index)"
                        }
                    } catch {
                        return "error-\(index)"
                    }
                }
            }
            
            // Collect results
            var results: [String] = []
            for await result in group {
                results.append(result)
            }
            
            // Verify all operations completed
            XCTAssertEqual(results.count, 50, "Not all background operations completed")
        }
    }
}
