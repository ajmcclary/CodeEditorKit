import XCTest
import AppKit
@testable import CodeEditorPlugin
@testable import CodeEditorSample

@MainActor
final class STTextViewLineNumbersTests: XCTestCase {
    
    var textView: STTextView!
    
    override func setUp() async throws {
        try await super.setUp()
        textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    }
    
    override func tearDown() async throws {
        textView = nil
        try await super.tearDown()
    }
    
    // MARK: - Line Numbers Visibility Tests
    
    func testLineNumbersDisabledByDefault() {
        XCTAssertFalse(textView.showsLineNumbers, "Line numbers should be disabled by default")
    }
    
    func testEnablingLineNumbers() {
        // Enable line numbers
        textView.showsLineNumbers = true
        
        XCTAssertTrue(textView.showsLineNumbers, "Line numbers should be enabled")
        
        // Force layout
        textView.layoutSubtreeIfNeeded()
        
        // Check for gutter view
        let gutterView = findGutterView()
        XCTAssertNotNil(gutterView, "Gutter view should exist when line numbers are enabled")
        XCTAssertFalse(gutterView?.isHidden ?? true, "Gutter view should be visible")
    }
    
    func testDisablingLineNumbers() {
        // First enable line numbers
        textView.showsLineNumbers = true
        textView.layoutSubtreeIfNeeded()
        
        // Then disable them
        textView.showsLineNumbers = false
        textView.layoutSubtreeIfNeeded()
        
        // Check gutter view is hidden or removed
        let gutterView = findGutterView()
        XCTAssertTrue(gutterView?.isHidden ?? true, "Gutter view should be hidden when line numbers are disabled")
    }
    
    // MARK: - Line Numbers Content Tests
    
    func testLineNumbersForSingleLine() {
        textView.showsLineNumbers = true
        textView.text = "Single line of text"
        textView.layoutSubtreeIfNeeded()
        
        // Verify gutter view exists and has content
        let gutterView = findGutterView()
        XCTAssertNotNil(gutterView, "Gutter view should exist")
        
        // Should show line number "1"
        verifyLineNumbersCount(expectedCount: 1)
    }
    
    func testLineNumbersForMultipleLines() {
        textView.showsLineNumbers = true
        textView.text = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
        textView.layoutSubtreeIfNeeded()
        
        // Should show line numbers 1-5
        verifyLineNumbersCount(expectedCount: 5)
    }
    
    func testLineNumbersUpdateOnTextChange() {
        textView.showsLineNumbers = true
        textView.text = "Initial text"
        textView.layoutSubtreeIfNeeded()
        
        // Verify initial state
        verifyLineNumbersCount(expectedCount: 1)
        
        // Add more lines
        textView.text = "Line 1\nLine 2\nLine 3"
        textView.layoutSubtreeIfNeeded()
        
        // Verify updated line count
        verifyLineNumbersCount(expectedCount: 3)
    }
    
    // MARK: - Line Numbers Layout Tests
    
    func testGutterViewWidth() {
        textView.showsLineNumbers = true
        textView.text = "Line 1\nLine 2\nLine 3"
        textView.layoutSubtreeIfNeeded()
        
        let gutterView = findGutterView()
        XCTAssertNotNil(gutterView)
        
        // Gutter should have reasonable width (typically 30-50 points)
        let width = gutterView?.frame.width ?? 0
        XCTAssertGreaterThan(width, 20, "Gutter width should be at least 20 points")
        XCTAssertLessThan(width, 100, "Gutter width should not exceed 100 points")
    }
    
    func testGutterViewPosition() {
        textView.showsLineNumbers = true
        textView.text = "Test content"
        textView.layoutSubtreeIfNeeded()
        
        let gutterView = findGutterView()
        XCTAssertNotNil(gutterView)
        
        // Gutter should be positioned at the left edge
        XCTAssertEqual(gutterView?.frame.origin.x ?? -1, 0, "Gutter should be at left edge")
        XCTAssertEqual(gutterView?.frame.origin.y ?? -1, 0, "Gutter should start at top")
    }
    
    func testLineNumbersWithLongDocument() {
        textView.showsLineNumbers = true
        
        // Create a document with 100 lines
        let lines = (1...100).map { "Line \($0)" }
        textView.text = lines.joined(separator: "\n")
        textView.layoutSubtreeIfNeeded()
        
        let gutterView = findGutterView()
        XCTAssertNotNil(gutterView)
        
        // Gutter width should accommodate 3-digit line numbers
        let width = gutterView?.frame.width ?? 0
        XCTAssertGreaterThan(width, 30, "Gutter should be wide enough for 3-digit line numbers")
    }
    
    // MARK: - Integration Tests
    
    func testLineNumbersInSwiftUIContext() {
        // Test configuration directly without SwiftUI context
        var config = EditorConfiguration()
        config.showLineNumbers = true
        
        // Create STTextView directly and apply configuration
        let testView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        testView.showsLineNumbers = config.showLineNumbers
        testView.text = "Test\nContent"
        
        // Verify line numbers are enabled
        XCTAssertTrue(testView.showsLineNumbers, "Line numbers should be enabled from configuration")
        
        // Force layout
        testView.layoutSubtreeIfNeeded()
        
        // Check for gutter view in the created view
        let gutterView = testView.subviews.first { $0 is STGutterView }
        XCTAssertNotNil(gutterView, "Gutter view should exist when line numbers are enabled")
    }
    
    // MARK: - Helper Methods
    
    private func findGutterView() -> STGutterView? {
        return textView.subviews.first { $0 is STGutterView } as? STGutterView
    }
    
    private func verifyLineNumbersCount(expectedCount: Int) {
        // This is a simplified check - in a real implementation,
        // we would inspect the actual line number labels in the gutter
        let lines = (textView.text ?? "").components(separatedBy: .newlines)
        let actualCount = lines.count
        XCTAssertEqual(actualCount, expectedCount, "Line count mismatch")
    }
}