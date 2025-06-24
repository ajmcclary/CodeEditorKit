import XCTest
import AppKit
@testable import CodeEditorPlugin

// Simple test to verify isFlipped behavior
final class QuickIsFlippedTest: XCTestCase {
    
    @MainActor
    func testIsFlippedIssue() async {
        // Create STTextView
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        
        // Test 1: Check if STTextView reports isFlipped correctly
        print("STTextView isFlipped: \(textView.isFlipped)")
        XCTAssertTrue(textView.isFlipped, "STTextView MUST be flipped for correct text rendering")
        
        // Test 2: STTextView should handle flipped coordinates internally
        // NSTextView-based implementations don't expose contentView
        // Just verify the text view itself is properly flipped
        XCTAssertTrue(textView.isFlipped, "STTextView handles flipped coordinates internally")
        
        // Test 3: Enable line numbers and check gutter view
        textView.showsLineNumbers = true
        textView.layoutSubtreeIfNeeded()
        
        if let gutterView = textView.subviews.first(where: { $0 is STGutterView }) {
            print("GutterView isFlipped: \(gutterView.isFlipped)")
            XCTAssertTrue(gutterView.isFlipped, "GutterView MUST be flipped")
        } else {
            XCTFail("GutterView not found when line numbers are enabled")
        }
        
        // Test 4: Add text and check coordinate system
        textView.text = "Line 1\nLine 2\nLine 3"
        textView.layoutSubtreeIfNeeded()
        
        // Get text layout manager
        guard let layoutManager = textView.textLayoutManager else {
            XCTFail("No text layout manager available")
            return
        }
        
        var firstFragmentY: CGFloat?
        var lastFragmentY: CGFloat?
        
        layoutManager.enumerateTextLayoutFragments(from: layoutManager.documentRange.location, 
                                                   options: [.ensuresLayout]) { fragment in
            if firstFragmentY == nil {
                firstFragmentY = fragment.layoutFragmentFrame.origin.y
            }
            lastFragmentY = fragment.layoutFragmentFrame.origin.y
            return true
        }
        
        if let first = firstFragmentY, let last = lastFragmentY {
            print("First fragment Y: \(first), Last fragment Y: \(last)")
            XCTAssertLessThan(first, last, "In flipped coordinates, first line should have smaller Y than last line")
        }
    }
}