import XCTest
@testable import CodeEditorPlugin

class SimpleTest: XCTestCase {
    @MainActor
    func testSimpleCreation() async {
        // Just try to create the basic objects
        let memoryMonitor = MemoryMonitor()
        print("Created MemoryMonitor")
        
        let processor = AsyncTextProcessor(memoryMonitor: memoryMonitor)
        print("Created AsyncTextProcessor")
        
        let status = await processor.getStatus()
        print("Got status: \(status)")
        
        XCTAssertEqual(status.queuedTasks, 0)
    }
}