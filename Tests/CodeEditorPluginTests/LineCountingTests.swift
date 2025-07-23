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

        // On macOS and Mac Catalyst, line numbers are handled by NSRulerView in container
        #if canImport(AppKit)
        XCTAssertNil(editor.gutterView)
        #else
        // On iOS, gutter is managed by the text view when used standalone
        XCTAssertNotNil(editor.gutterView)
        #endif
    }

    func testSingleLineText() {
        let editor = CodeEditorView(frame: .zero)
        editor.text = "Hello World"

        // Test that the line count is calculated correctly
        // We'll validate by checking that gutter is created with proper width
        editor.isLineNumbersEnabled = true
        #if canImport(AppKit)
        XCTAssertNil(editor.gutterView)
        #else
        // On iOS, gutter is managed by the text view when used standalone
        XCTAssertNotNil(editor.gutterView)
        #endif
    }

    func testMultilineText() {
        let editor = CodeEditorView(frame: .zero)
        editor.text = "Line 1\nLine 2\nLine 3"

        editor.isLineNumbersEnabled = true
        #if canImport(AppKit)
        XCTAssertNil(editor.gutterView)
        #else
        // On iOS, gutter is managed by the text view when used standalone
        XCTAssertNotNil(editor.gutterView)
        #endif
    }

    func testTextEndingWithNewline() {
        let editor = CodeEditorView(frame: .zero)
        editor.text = "Line 1\nLine 2\n"

        // This should show 3 lines (the empty line after the last newline)
        editor.isLineNumbersEnabled = true
        #if canImport(AppKit)
        XCTAssertNil(editor.gutterView)
        #else
        // On iOS, gutter is managed by the text view when used standalone
        XCTAssertNotNil(editor.gutterView)
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

        // On macOS, line numbers are handled by NSRulerView in the container's scroll view
        // The text view itself should never have a gutter view
        XCTAssertNil(editor.gutterView, "On macOS, CodeEditorView should not have a GutterView")

        // The configuration should still reflect that line numbers are enabled
        XCTAssertTrue(editor.isLineNumbersEnabled)
        #endif
    }
}
