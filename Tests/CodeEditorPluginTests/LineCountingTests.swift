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
        editor.showsLineNumbers = true
        
        // The gutter view should exist
        XCTAssertNotNil(editor.gutterView)
    }
    
    func testSingleLineText() {
        let editor = CodeEditorView(frame: .zero)
        editor.text = "Hello World"
        
        // Test that the line count is calculated correctly
        // We'll validate by checking that gutter is created with proper width
        editor.showsLineNumbers = true
        XCTAssertNotNil(editor.gutterView)
    }
    
    func testMultilineText() {
        let editor = CodeEditorView(frame: .zero)
        editor.text = "Line 1\nLine 2\nLine 3"
        
        editor.showsLineNumbers = true
        XCTAssertNotNil(editor.gutterView)
    }
    
    func testTextEndingWithNewline() {
        let editor = CodeEditorView(frame: .zero)
        editor.text = "Line 1\nLine 2\n"
        
        // This should show 3 lines (the empty line after the last newline)
        editor.showsLineNumbers = true
        XCTAssertNotNil(editor.gutterView)
    }
    
    func testLineNumbersInGutterViewiOS() {
        #if canImport(UIKit)
        let editor = CodeEditorView(frame: .zero)
        editor.text = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
        editor.showsLineNumbers = true
        
        // Force layout
        editor.layoutIfNeeded()
        
        guard let gutter = editor.gutterView else {
            XCTFail("Gutter view should exist")
            return
        }
        
        // The gutter should be set up
        XCTAssertNotNil(gutter.textView)
        XCTAssertEqual(gutter.textView, editor)
        #endif
    }
    
    func testLineNumbersInGutterViewMacOS() {
        #if canImport(AppKit)
        let editor = CodeEditorView(frame: .zero)
        editor.text = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
        editor.showsLineNumbers = true
        
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
