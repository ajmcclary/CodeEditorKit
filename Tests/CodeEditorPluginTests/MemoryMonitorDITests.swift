@testable import CodeEditorPlugin
import XCTest

final class MemoryMonitorDITests: XCTestCase {
    @MainActor
    func testMemoryMonitorConfigurationInjection() {
        // Create a custom memory monitor
        let customMonitor = MemoryMonitor()
        
        // Create configuration with custom memory monitor
        var config = EditorConfiguration()
        config.performance.memoryMonitor = customMonitor
        
        // Create editor view
        let editor = CodeEditorView()
        
        // Apply configuration
        config.apply(to: editor)
        
        // Verify the custom monitor was injected
        XCTAssertTrue(editor.memoryMonitor === customMonitor, "Memory monitor should be injected from configuration")
    }
    
    @MainActor
    func testMemoryMonitorBuilderInjection() {
        // Create a custom memory monitor
        let customMonitor = MemoryMonitor()
        
        // Create configuration using builder
        let config = EditorConfigurationBuilder()
            .memoryMonitor(customMonitor)
            .build()
        
        // Create editor view
        let editor = CodeEditorView()
        
        // Apply configuration
        config.apply(to: editor)
        
        // Verify the custom monitor was injected
        XCTAssertTrue(editor.memoryMonitor === customMonitor, "Memory monitor should be injected from builder configuration")
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
        var config = EditorConfiguration()
        config.performance.memoryMonitor = monitor1
        config.apply(to: editor)
        
        XCTAssertTrue(editor.memoryMonitor === monitor1, "First monitor should be applied")
        
        // Create and apply second monitor
        let monitor2 = MemoryMonitor()
        config.performance.memoryMonitor = monitor2
        config.apply(to: editor)
        
        XCTAssertTrue(editor.memoryMonitor === monitor2, "Second monitor should replace the first")
    }
}
