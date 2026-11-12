import CodeEditorConfiguration
@testable import CodeEditorView
import XCTest

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
final class ScrollPositionPreservationTests: XCTestCase {
    #if canImport(AppKit)
    /// With `autoScrollToCursor` on, scrolling (trackpad, scroll bar) must not
    /// be pulled back to the caret: the setting reacts to selection changes,
    /// not to scrolling.
    func testScrollingAwayFromTheCaretStaysPutWithAutoScrollToCursor() async throws {
        let containerView = CodeEditorContainerView()
        containerView.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        var config = EditorConfiguration()
        config.behavior.autoScrollToCursor = true
        containerView.configuration = config
        let textView = containerView.textView
        textView.string = String(repeating: "    let value = editor.selectedRange.location + offset\n", count: 3_000)
        containerView.layoutSubtreeIfNeeded()
        textView.setSelectedRange(NSRange(location: 10, length: 0))
        try await Task.sleep(nanoseconds: 300_000_000)

        let scrollView = try XCTUnwrap(textView.enclosingScrollView)
        let clipView = scrollView.contentView
        clipView.scroll(to: NSPoint(x: 0, y: 20_000))
        scrollView.reflectScrolledClipView(clipView)
        let scrolledTo = clipView.bounds.origin.y
        XCTAssertGreaterThan(scrolledTo, 1_000)

        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(clipView.bounds.origin.y, scrolledTo, accuracy: 1)
    }

    func testScrollPositionPreservedWhenTogglingWordWrap() async {
        // Create a container view which provides the scroll view
        let containerView = CodeEditorContainerView()
        containerView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)

        // Get the text view from the container
        let textView = containerView.textView
        let longText = (1...100).map { "Line \($0): This is a long line of text that might wrap when word wrapping is enabled." }.joined(separator: "\n")
        textView.string = longText

        // Configure without word wrap initially
        var config = EditorConfiguration()
        config.layout.wrapLines = false
        containerView.configuration = config

        // Force layout
        containerView.layout()

        // Simulate scrolling to a specific position
        if let scrollView = textView.enclosingScrollView {
            let targetPoint = NSPoint(x: 0, y: 500)
            scrollView.contentView.scroll(to: targetPoint)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        // Give the scroll view time to update
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Save the visible rect before toggling wrap
        let visibleRectBeforeToggle = textView.visibleRect
        XCTAssertGreaterThan(visibleRectBeforeToggle.origin.y, 0, "Should have scrolled down from top")

        // Toggle word wrap on
        config.layout.wrapLines = true
        containerView.configuration = config

        // Give time for async scroll restoration
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        // Check that we're still showing approximately the same content
        let visibleRectAfterToggle = textView.visibleRect

        // The Y position should be approximately the same (allowing for some difference due to text reflow)
        let yDifference = abs(visibleRectAfterToggle.origin.y - visibleRectBeforeToggle.origin.y)

        // Allow for some variance due to text reflow, but it shouldn't jump to top (0)
        XCTAssertLessThan(yDifference, 200, "Scroll position should be approximately preserved")
        XCTAssertGreaterThan(visibleRectAfterToggle.origin.y, 50, "View should not scroll to top")
    }

    func testScrollPositionPreservedWhenTogglingWordWrapOff() async {
        // Create a container view which provides the scroll view
        let containerView = CodeEditorContainerView()
        containerView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)

        // Get the text view from the container
        let textView = containerView.textView
        let longText = (1...100).map { "Line \($0): This is a long line of text that might wrap when word wrapping is enabled." }.joined(separator: "\n")
        textView.string = longText

        // Configure with word wrap initially on
        var config = EditorConfiguration()
        config.layout.wrapLines = true
        containerView.configuration = config

        // Force layout
        containerView.layout()

        // Simulate scrolling to a specific position
        if let scrollView = textView.enclosingScrollView {
            let targetPoint = NSPoint(x: 0, y: 500)
            scrollView.contentView.scroll(to: targetPoint)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        // Give the scroll view time to update
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Save the visible rect before toggling wrap
        let visibleRectBeforeToggle = textView.visibleRect
        XCTAssertGreaterThan(visibleRectBeforeToggle.origin.y, 0, "Should have scrolled down from top")

        // Toggle word wrap off
        config.layout.wrapLines = false
        containerView.configuration = config

        // Give time for async scroll restoration
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        // Check that we're still showing approximately the same content
        let visibleRectAfterToggle = textView.visibleRect

        // The Y position should be approximately the same
        let yDifference = abs(visibleRectAfterToggle.origin.y - visibleRectBeforeToggle.origin.y)

        // Allow for some variance, but it shouldn't jump to top (0)
        XCTAssertLessThan(yDifference, 200, "Scroll position should be approximately preserved")
        XCTAssertGreaterThan(visibleRectAfterToggle.origin.y, 50, "View should not scroll to top")
    }
    #endif

    #if canImport(UIKit)
    func testScrollPositionPreservedWhenTogglingWordWrapIOS() async {
        // iOS version of the test
        let textView = CodeEditorView()
        let longText = (1...100).map { "Line \($0): This is a long line of text that might wrap when word wrapping is enabled." }.joined(separator: "\n")
        textView.text = longText

        // Set initial frame
        textView.frame = CGRect(x: 0, y: 0, width: 400, height: 300)

        // Configure without word wrap initially
        var config = EditorConfiguration()
        config.layout.wrapLines = false
        textView.configuration = config

        // Simulate scrolling to a specific position
        textView.setContentOffset(CGPoint(x: 0, y: 500), animated: false)

        // Give the scroll view time to update
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Save the content offset before toggling wrap
        let contentOffsetBeforeToggle = textView.contentOffset

        // Toggle word wrap on
        config.layout.wrapLines = true
        textView.configuration = config

        // Give time for async scroll restoration
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Check that we're still showing approximately the same content
        let contentOffsetAfterToggle = textView.contentOffset

        // The Y position should be approximately the same (allowing for some difference due to text reflow)
        let yDifference = abs(contentOffsetAfterToggle.y - contentOffsetBeforeToggle.y)

        // Allow for some variance due to text reflow, but it shouldn't jump to top (0)
        XCTAssertLessThan(yDifference, 100, "Scroll position should be approximately preserved")
        XCTAssertGreaterThan(contentOffsetAfterToggle.y, 100, "View should not scroll to top")
    }
    #endif
}
