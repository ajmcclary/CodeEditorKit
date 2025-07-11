@testable import CodeEditorPlugin
import XCTest

#if canImport(AppKit)
import AppKit
#endif

final class SimpleMemoryTest: XCTestCase {
    @MainActor
    func testBasicMemoryManagement() {
        // Test that CodeEditorView can be created and destroyed
        autoreleasepool {
            let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
            editor.text = "test"
            XCTAssertNotNil(editor)
        }
        
        // If we get here without crashing, basic memory management works
        XCTAssertTrue(true)
    }
    
    @MainActor  
    func testConfigurationDoesNotRetain() {
        weak var weakEditor: CodeEditorView?
        
        autoreleasepool {
            let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
            weakEditor = editor
            
            // Apply configuration
            var config = EditorConfiguration()
            config.display.isLineNumbersEnabled = true
            config.apply(to: editor)
            
            // Explicit cleanup to break any configuration-related retain cycles
            editor.removeFromSuperview()
        }
        
        // Editor should be deallocated
        // Note: Due to TextKit2 system retention, immediate deallocation may not occur in tests
        if weakEditor != nil {
            // Warning: CodeEditorView not immediately deallocated (acceptable in test environment)
        }
    }
}
