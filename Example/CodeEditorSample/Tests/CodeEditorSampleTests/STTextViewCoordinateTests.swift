import XCTest
import AppKit
@testable import CodeEditorPlugin
@testable import CodeEditorSample

@MainActor
final class STTextViewCoordinateTests: XCTestCase {
    
    var textView: STTextView!
    
    override func setUp() async throws {
        try await super.setUp()
        textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    }
    
    override func tearDown() async throws {
        textView = nil
        try await super.tearDown()
    }
    
    // MARK: - Coordinate System Tests
    
    func testSTTextViewIsFlipped() {
        // STTextView should use flipped coordinates for proper text rendering
        XCTAssertTrue(textView.isFlipped, "STTextView must use flipped coordinate system for text to render correctly")
    }
    
    func testContentViewIsFlipped() {
        // Access the content view
        let contentView = textView.contentView
        XCTAssertTrue(contentView.isFlipped, "Content view must use flipped coordinate system")
    }
    
    func testGutterViewIsFlipped() {
        // Enable line numbers to ensure gutter view is created
        textView.showsLineNumbers = true
        
        // Find the gutter view
        let gutterView = textView.subviews.first { $0 is STGutterView }
        XCTAssertNotNil(gutterView, "Gutter view should exist when line numbers are enabled")
        XCTAssertTrue(gutterView?.isFlipped ?? false, "Gutter view must use flipped coordinate system")
    }
    
    func testTextLayoutFragmentViewsAreFlipped() {
        // Add some text to ensure layout fragments are created
        textView.text = "Hello\nWorld\nTest"
        
        // Force layout
        textView.layoutSubtreeIfNeeded()
        
        // Check if any text layout fragment views exist and are flipped
        let fragmentViews = findSubviews(of: textView, matching: { $0.className.contains("STTextLayoutFragmentView") })
        
        for fragmentView in fragmentViews {
            XCTAssertTrue(fragmentView.isFlipped, "Text layout fragment views must use flipped coordinate system")
        }
    }
    
    func testTextRenderingOrientation() {
        // Set up text content
        let testText = "Line 1\nLine 2\nLine 3"
        textView.text = testText
        
        // Force layout
        textView.layoutSubtreeIfNeeded()
        
        // Get text layout manager
        let layoutManager = textView.textLayoutManager
        
        // Enumerate text layout fragments
        var fragments: [NSTextLayoutFragment] = []
        layoutManager.enumerateTextLayoutFragments(from: layoutManager.documentRange.location, 
                                                   options: [.ensuresLayout]) { fragment in
            fragments.append(fragment)
            return true
        }
        
        // Verify fragments are ordered top to bottom
        XCTAssertGreaterThan(fragments.count, 0, "Should have layout fragments for text")
        
        // Check that Y coordinates increase (in flipped coordinate system)
        for i in 1..<fragments.count {
            let prevY = fragments[i-1].layoutFragmentFrame.origin.y
            let currY = fragments[i].layoutFragmentFrame.origin.y
            XCTAssertGreaterThan(currY, prevY, "Text fragments should be laid out top to bottom")
        }
    }
    
    func testLineNumbersAlignment() {
        // Enable line numbers
        textView.showsLineNumbers = true
        textView.text = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
        
        // Force layout
        textView.layoutSubtreeIfNeeded()
        
        // Verify gutter view exists and has proper size
        let gutterView = textView.subviews.first { $0 is STGutterView } as? STGutterView
        XCTAssertNotNil(gutterView, "Gutter view should exist")
        XCTAssertGreaterThan(gutterView?.frame.width ?? 0, 0, "Gutter view should have width")
        XCTAssertEqual(gutterView?.frame.height ?? 0, textView.frame.height, "Gutter view height should match text view")
    }
    
    // MARK: - Helper Methods
    
    private func findSubviews(of view: NSView, matching predicate: (NSView) -> Bool) -> [NSView] {
        var results: [NSView] = []
        
        if predicate(view) {
            results.append(view)
        }
        
        for subview in view.subviews {
            results.append(contentsOf: findSubviews(of: subview, matching: predicate))
        }
        
        return results
    }
}