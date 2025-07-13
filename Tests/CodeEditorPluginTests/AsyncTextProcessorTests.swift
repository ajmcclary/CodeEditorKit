@testable import CodeEditorPlugin
import XCTest

final class AsyncTextProcessorTests: XCTestCase {
    // MARK: - Concurrency Tests
    
    @MainActor func testDefaultConcurrencyLimit() async throws {
        // Test that default concurrency is capped at 4
        let processor = AsyncTextProcessor(memoryMonitor: MemoryMonitor())
        
        // Get the status to check active tasks limit
        _ = await processor.getStatus()
        
        // The cap should be applied, so even on systems with more than 4 cores,
        // we should not exceed 4 concurrent operations
        let expectedMax = min(4, ProcessInfo.processInfo.activeProcessorCount)
        
        // Create a slow operation to test concurrency
        struct SlowOperation: ProcessingOperation {
            let name = "slow-operation"
            let delay: TimeInterval
            
            func process(_ text: String, _: NSRange) async throws -> Any {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return text.count
            }
        }
        
        // Submit multiple tasks
        let taskCount = 10
        let text = "Test text"
        let range = NSRange(location: 0, length: text.count)
        
        // Submit tasks that will take time to complete
        var taskHandles: [ProcessingTaskHandle] = []
        for _ in 0..<taskCount {
            let handle = await processor.submit(
                text: text,
                range: range,
                operation: SlowOperation(delay: 0.1),
                priority: .normal
            ) { _ in
                // Empty completion handler for this test
            }
            taskHandles.append(handle)
        }
        
        // Give tasks a moment to start
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Check that we don't exceed the concurrency limit
        let statusDuringProcessing = await processor.getStatus()
        XCTAssertLessThanOrEqual(
            statusDuringProcessing.activeTasks,
            expectedMax,
            "Active tasks should not exceed \(expectedMax)"
        )
        
        // Clean up
        await processor.clearQueue()
    }
    
    @MainActor func testCustomConcurrencyLimit() async throws {
        // Test that custom concurrency limit is respected
        let customLimit = 2
        let memoryMonitor = MemoryMonitor()
        let processor = AsyncTextProcessor(memoryMonitor: memoryMonitor, maxConcurrentOperations: customLimit)
        
        struct SlowOperation: ProcessingOperation {
            let name = "slow-operation"
            
            func process(_ text: String, _: NSRange) async throws -> Any {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                return text.count
            }
        }
        
        // Submit more tasks than the limit
        let text = "Test"
        let range = NSRange(location: 0, length: text.count)
        
        var taskHandles: [ProcessingTaskHandle] = []
        for _ in 0..<5 {
            let handle = await processor.submit(
                text: text,
                range: range,
                operation: SlowOperation(),
                priority: .normal
            ) { _ in
                // Empty completion handler for this test
            }
            taskHandles.append(handle)
        }
        
        // Give tasks a moment to start
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Check active tasks
        let status = await processor.getStatus()
        XCTAssertLessThanOrEqual(
            status.activeTasks,
            customLimit,
            "Active tasks should not exceed custom limit of \(customLimit)"
        )
        
        // Clean up
        await processor.clearQueue()
    }
    
    @MainActor func testHighConcurrencySystemsCapped() async throws {
        // This test verifies that even if we explicitly try to set a high concurrency,
        // the default cap of 4 is applied when using default initialization
        
        // First, verify the system has multiple cores (test is more meaningful on multi-core systems)
        let coreCount = ProcessInfo.processInfo.activeProcessorCount
        print("System has \(coreCount) cores")
        
        // Create processor with default settings
        let processor = AsyncTextProcessor(memoryMonitor: MemoryMonitor())
        
        // The expected max should be capped at 4
        let expectedMax = min(4, coreCount)
        
        // Submit many tasks to try to saturate the processor
        struct QuickOperation: ProcessingOperation {
            let name = "quick-operation"
            let id: Int
            
            func process(_: String, _: NSRange) async throws -> Any {
                // Simulate some work
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                return id
            }
        }
        
        let taskCount = 20
        let text = "Test"
        let range = NSRange(location: 0, length: text.count)
        
        var maxConcurrentObserved = 0
        
        // Submit tasks and monitor max concurrent
        for index in 0..<taskCount {
            await processor.submit(
                text: text,
                range: range,
                operation: QuickOperation(id: index),
                priority: .normal
            ) { _ in }
            
            // Check current active tasks
            let status = await processor.getStatus()
            maxConcurrentObserved = max(maxConcurrentObserved, status.activeTasks)
            
            // Small delay to allow task scheduling
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        
        // Verify the cap was enforced
        XCTAssertLessThanOrEqual(
            maxConcurrentObserved,
            expectedMax,
            "Maximum concurrent tasks (\(maxConcurrentObserved)) should not exceed cap of \(expectedMax)"
        )
        
        // If system has more than 4 cores, verify the cap is actually limiting concurrency
        if coreCount > 4 {
            print("System has \(coreCount) cores, verifying cap of 4 is enforced")
            XCTAssertLessThanOrEqual(
                maxConcurrentObserved,
                4,
                "On high-core systems, concurrency should be capped at 4"
            )
        }
        
        // Clean up
        await processor.clearQueue()
    }
}
