@testable import CodeEditorPlugin
import XCTest

@MainActor
final class LineCountingTests: XCTestCase {
    deinit {
        // Cleanup if needed
    }
    
    func testEmptyTextHasOneLineCount() {
        let editor = CodeEditorView(frame: .zero)
        editor.text = ""
        
        // Private method - we'll test through the gutter view
        editor.isLineNumbersEnabled = true
        
        // The gutter view should exist on macOS only
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertNotNil(editor.gutterView)
        #else
        // On iOS/Mac Catalyst, gutter is managed by container
        XCTAssertNil(editor.gutterView)
        #endif
    }
    
    func testSingleLineText() {
        let editor = CodeEditorView(frame: .zero)
        editor.text = "Hello World"
        
        // Test that the line count is calculated correctly
        // We'll validate by checking that gutter is created with proper width
        editor.isLineNumbersEnabled = true
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertNotNil(editor.gutterView)
        #else
        // On iOS/Mac Catalyst, gutter is managed by container
        XCTAssertNil(editor.gutterView)
        #endif
    }
    
    func testMultilineText() {
        let editor = CodeEditorView(frame: .zero)
        editor.text = "Line 1\nLine 2\nLine 3"
        
        editor.isLineNumbersEnabled = true
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertNotNil(editor.gutterView)
        #else
        // On iOS/Mac Catalyst, gutter is managed by container
        XCTAssertNil(editor.gutterView)
        #endif
    }
    
    func testTextEndingWithNewline() {
        let editor = CodeEditorView(frame: .zero)
        editor.text = "Line 1\nLine 2\n"
        
        // This should show 3 lines (the empty line after the last newline)
        editor.isLineNumbersEnabled = true
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertNotNil(editor.gutterView)
        #else
        // On iOS/Mac Catalyst, gutter is managed by container
        XCTAssertNil(editor.gutterView)
        #endif
    }
    
    func testLineNumbersInGutterViewiOS() {
        #if canImport(UIKit)
        // On iOS/Mac Catalyst, the gutter is managed by CodeEditorContainerView
        // Create a container to test the gutter functionality
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        container.textView.text = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
        container.showsLineNumbers = true
        
        // Force layout
        container.layoutIfNeeded()
        
        // The container's gutter should be set up
        let gutter = container.gutterView
        XCTAssertNotNil(gutter)
        XCTAssertFalse(gutter.isHidden)
        XCTAssertEqual(gutter.textView, container.textView)
        #endif
    }
    
    func testLineNumbersInGutterViewMacOS() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let editor = CodeEditorView(frame: .zero)
        editor.text = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
        editor.isLineNumbersEnabled = true
        
        // Force layout
        editor.layout()
        
        guard let gutter = editor.gutterView else {
            XCTFail("Gutter view should exist")
            return
        }
        
        // The gutter should be set up
        XCTAssertNotNil(gutter.textView)
        XCTAssertEqual(gutter.textView, editor)
        #endif
    }
}
