@testable import CodeEditorPlugin
import XCTest

/// Isolated test to verify performance issue
final class IsolatedPerformanceTest: XCTestCase {
    @MainActor
    func testLayoutOperationRecordingStandalone() async throws {
        let start = CFAbsoluteTimeGetCurrent()
        
        // Create a fresh monitor instance
        let performanceMonitor = TextKit2PerformanceMonitor()
        
        // Run the test logic
        performanceMonitor.recordLayoutOperation(duration: 0.1)
        
        XCTAssertEqual(performanceMonitor.layoutOperations, 1)
        XCTAssertEqual(performanceMonitor.averageLayoutTime, 0.1)
        XCTAssertEqual(performanceMonitor.peakLayoutTime, 0.1)
        XCTAssertEqual(performanceMonitor.totalRenderingTime, 0.1)
        
        performanceMonitor.recordLayoutOperation(duration: 0.2)
        
        XCTAssertEqual(performanceMonitor.layoutOperations, 2)
        XCTAssertEqual(performanceMonitor.averageLayoutTime, 0.15, accuracy: 0.001)
        XCTAssertEqual(performanceMonitor.peakLayoutTime, 0.2)
        XCTAssertEqual(performanceMonitor.totalRenderingTime, 0.3, accuracy: 0.001)
        
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        // Test completed in \(elapsed)s
        
        // This test should complete in milliseconds
        XCTAssertLessThan(elapsed, 0.1, "Test took too long: \(elapsed)s")
    }
    
    @MainActor
    func testLayoutOperationRecordingWithSharedState() async throws {
        let start = CFAbsoluteTimeGetCurrent()
        
        // Simulate shared state by creating a PerformanceMonitor instance
        let sharedMonitor = PerformanceMonitor()
        _ = await sharedMonitor.getAllMetrics()
        
        // Create a fresh monitor instance
        let performanceMonitor = TextKit2PerformanceMonitor()
        
        // Run the test logic
        performanceMonitor.recordLayoutOperation(duration: 0.1)
        performanceMonitor.recordLayoutOperation(duration: 0.2)
        
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        // Test completed in \(elapsed)s
        
        // This test should also complete quickly
        XCTAssertLessThan(elapsed, 0.1, "Test took too long: \(elapsed)s")
    }
}
