@testable import CodeEditorPlugin
import XCTest

final class MemoryMonitorDITests: XCTestCase {
    @MainActor
    func testMemoryMonitorConfigurationInjection() {
        // Create a custom memory monitor
        let customMonitor = MemoryMonitor()
        customMonitor.memoryThresholdMB = 200.0 // Set a distinctive value
        
        // Create configuration with custom memory monitor
        var config = EditorConfiguration()
        config.performance.memoryMonitor = customMonitor
        
        // Create editor view using initializer with memory monitor
        let editor = CodeEditorView(frame: .zero, memoryMonitor: customMonitor)
        
        // Verify the custom monitor was injected via initializer
        XCTAssertEqual(editor.memoryMonitor.memoryThresholdMB, 200.0, "Memory monitor should be injected via initializer")
        
        // Apply configuration with a different monitor
        let anotherMonitor = MemoryMonitor()
        anotherMonitor.memoryThresholdMB = 300.0
        config.performance.memoryMonitor = anotherMonitor
        config.apply(to: editor)
        
        // Verify the monitor was updated from configuration
        XCTAssertEqual(editor.memoryMonitor.memoryThresholdMB, 300.0, "Memory monitor should be updated from configuration")
    }
    
    @MainActor
    func testMemoryMonitorBuilderInjection() {
        // Create a custom memory monitor
        let customMonitor = MemoryMonitor()
        customMonitor.memoryThresholdMB = 250.0
        
        // Create configuration using builder
        let config = EditorConfigurationBuilder()
            .memoryMonitor(customMonitor)
            .build()
        
        // Create editor view
        let editor = CodeEditorView()
        
        // Apply configuration
        config.apply(to: editor)
        
        // Verify the custom monitor was injected via configuration
        XCTAssertEqual(editor.memoryMonitor.memoryThresholdMB, 250.0, "Memory monitor should be injected from builder configuration")
    }
    
    @MainActor
    func testMemoryMonitorDefaultWhenNilInConfiguration() {
        // Create configuration without memory monitor
        let config = EditorConfiguration()
        XCTAssertNil(config.performance.memoryMonitor, "Default configuration should have nil memory monitor")
        
        // Create editor view with its own monitor
        let editor = CodeEditorView()
        let originalMonitor = editor.memoryMonitor
        
        // Apply configuration
        config.apply(to: editor)
        
        // Verify the original monitor is still used
        XCTAssertTrue(editor.memoryMonitor === originalMonitor, "Editor should keep its original monitor when config has nil")
    }
    
    @MainActor
    func testMemoryMonitorUpdatePropagation() {
        // Create editor view
        let editor = CodeEditorView()
        
        // Create and apply first monitor
        let monitor1 = MemoryMonitor()
        monitor1.memoryThresholdMB = 150.0
        var config = EditorConfiguration()
        config.performance.memoryMonitor = monitor1
        config.apply(to: editor)
        
        XCTAssertEqual(editor.memoryMonitor.memoryThresholdMB, 150.0, "First monitor should be applied")
        
        // Create and apply second monitor
        let monitor2 = MemoryMonitor()
        monitor2.memoryThresholdMB = 175.0
        config.performance.memoryMonitor = monitor2
        config.apply(to: editor)
        
        XCTAssertEqual(editor.memoryMonitor.memoryThresholdMB, 175.0, "Second monitor should replace the first")
    }
}
