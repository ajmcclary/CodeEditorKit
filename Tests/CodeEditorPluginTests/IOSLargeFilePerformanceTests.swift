@testable import CodeEditorPlugin
import XCTest

#if canImport(UIKit) && !targetEnvironment(macCatalyst)
import UIKit

@available(iOS 13.0, *)
final class IOSLargeFilePerformanceTests: XCTestCase {
    func testLargeFileOptimizationThresholds() async throws {
        let textView = UITextView()
        let memoryMonitor = MemoryMonitor()
        let performanceMonitor = UnifiedPerformanceSystem()
        
        let optimizer = IOSLargeFileOptimizer(
            textView: textView,
            memoryMonitor: memoryMonitor,
            performanceMonitor: performanceMonitor
        )
        
        // Test with different file sizes
        
        // 1. Normal file (< 1MB)
        textView.text = String(repeating: "a", count: 500_000)
        optimizer.enableOptimizations()
        XCTAssertEqual(optimizer.currentMode, .normal)
        XCTAssertFalse(optimizer.isOptimizing)
        
        // 2. Large file (1-10MB)
        textView.text = String(repeating: "b", count: 2_000_000)
        optimizer.enableOptimizations()
        XCTAssertEqual(optimizer.currentMode, .largeFile)
        XCTAssertTrue(optimizer.isOptimizing)
        
        // 3. Extreme file (> 10MB)
        textView.text = String(repeating: "c", count: 15_000_000)
        optimizer.enableOptimizations()
        XCTAssertEqual(optimizer.currentMode, .extremeOptimization)
        XCTAssertTrue(optimizer.isOptimizing)
    }
    
    func testViewportHighlightingPerformance() async throws {
        let textView = UITextView()
        let memoryMonitor = MemoryMonitor()
        let performanceMonitor = UnifiedPerformanceSystem()
        
        let optimizer = IOSLargeFileOptimizer(
            textView: textView,
            memoryMonitor: memoryMonitor,
            performanceMonitor: performanceMonitor
        )
        
        // Create a large file
        textView.text = String(repeating: "func test() { print(\"hello\") }\n", count: 50_000)
        
        optimizer.enableOptimizations()
        
        // Wait for some chunks to be processed
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Check metrics
        XCTAssertGreaterThan(optimizer.metrics.chunksProcessed, 0)
        XCTAssertGreaterThan(optimizer.metrics.averageChunkTime, 0)
        
        // Cleanup
        optimizer.disableOptimizations()
    }
    
    func testMemoryPressureResponse() async throws {
        let textView = UITextView()
        let memoryMonitor = MemoryMonitor()
        let performanceMonitor = UnifiedPerformanceSystem()
        
        let optimizer = IOSLargeFileOptimizer(
            textView: textView,
            memoryMonitor: memoryMonitor,
            performanceMonitor: performanceMonitor
        )
        
        // Large text
        textView.text = String(repeating: "x", count: 5_000_000)
        optimizer.enableOptimizations()
        
        // Simulate memory pressure
        memoryMonitor.startMonitoring()
        let result = await memoryMonitor.performCleanup()
        
        // Should have freed some memory
        XCTAssertTrue(result > 0)
        XCTAssertGreaterThan(optimizer.metrics.memoryReclaimed, 0)
        
        memoryMonitor.stopMonitoring()
    }
    
    func testOptimizationModeTransitions() throws {
        let textView = UITextView()
        let memoryMonitor = MemoryMonitor()
        let performanceMonitor = UnifiedPerformanceSystem()
        
        let optimizer = IOSLargeFileOptimizer(
            textView: textView,
            memoryMonitor: memoryMonitor,
            performanceMonitor: performanceMonitor
        )
        
        // Start with normal mode
        textView.text = "Small text"
        optimizer.enableOptimizations()
        XCTAssertEqual(optimizer.currentMode, .normal)
        
        // Transition to large file mode
        textView.text = String(repeating: "a", count: 2_000_000)
        optimizer.enableOptimizations()
        XCTAssertEqual(optimizer.currentMode, .largeFile)
        
        // Disable and check restoration
        optimizer.disableOptimizations()
        XCTAssertEqual(optimizer.currentMode, .normal)
        XCTAssertFalse(optimizer.isOptimizing)
    }
    
    func testConfigurationIntegration() throws {
        let config = EditorConfiguration()
        let textView = CodeEditorView(configuration: config)
        let memoryMonitor = MemoryMonitor()
        let performanceMonitor = UnifiedPerformanceSystem()
        
        let optimizer = IOSLargeFileOptimizer(
            textView: textView,
            memoryMonitor: memoryMonitor,
            performanceMonitor: performanceMonitor
        )
        
        // Set large text
        textView.text = String(repeating: "test\n", count: 500_000)
        
        // Enable optimizations
        optimizer.enableOptimizations()
        
        // Check that configuration was modified
        XCTAssertFalse(config.display.syntaxHighlighting)
        XCTAssertEqual(config.performance.maxSyntaxHighlightingLength, 100_000)
        
        // Disable and check restoration
        optimizer.disableOptimizations()
        XCTAssertTrue(config.display.syntaxHighlighting)
        XCTAssertEqual(config.performance.maxSyntaxHighlightingLength, 0)
    }
}

// MARK: - Performance Benchmarks

@available(iOS 13.0, *)
extension IOSLargeFilePerformanceTests {
    func testLargeFileScrollingPerformance() throws {
        measure {
            let textView = UITextView()
            let optimizer = IOSLargeFileOptimizer(
                textView: textView,
                memoryMonitor: MemoryMonitor(),
                performanceMonitor: UnifiedPerformanceSystem()
            )
            
            // 5MB file
            textView.text = String(repeating: "let x = 42\n", count: 500_000)
            optimizer.enableOptimizations()
            
            // Simulate scrolling
            for offset in stride(from: 0, to: textView.contentSize.height, by: 100) {
                textView.contentOffset = CGPoint(x: 0, y: offset)
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            }
        }
    }
    
    func testMemoryUsageWithOptimization() throws {
        let textView = UITextView()
        let memoryBefore = getMemoryUsage()
        
        // Create optimizer
        let optimizer = IOSLargeFileOptimizer(
            textView: textView,
            memoryMonitor: MemoryMonitor(),
            performanceMonitor: UnifiedPerformanceSystem()
        )
        
        // Large file
        textView.text = String(repeating: "a", count: 10_000_000)
        optimizer.enableOptimizations()
        
        let memoryAfter = getMemoryUsage()
        let memoryIncrease = memoryAfter - memoryBefore
        
        // With optimization, memory increase should be reasonable
        XCTAssertLessThan(memoryIncrease, 100 * 1_048_576) // Less than 100MB
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}
#endif
