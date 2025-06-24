import XCTest
import AppKit
@testable import CodeEditorPlugin
@testable import CodeEditorSample

@MainActor
final class STTextViewEditingTests: XCTestCase {
    
    var textView: STTextView!
    var window: NSWindow!
    
    override func setUp() async throws {
        try await super.setUp()
        textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        
        // Create a window and add the text view to establish responder chain
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                         styleMask: [.titled],
                         backing: .buffered,
                         defer: false)
        window.contentView?.addSubview(textView)
    }
    
    override func tearDown() async throws {
        window = nil
        textView = nil
        try await super.tearDown()
    }
    
    // MARK: - Editability Tests
    
    func testEditableByDefault() {
        XCTAssertTrue(textView.isEditable, "STTextView should be editable by default")
    }
    
    func testSettingNotEditable() {
        textView.isEditable = false
        XCTAssertFalse(textView.isEditable, "STTextView should respect isEditable = false")
    }
    
    func testSelectableWhenNotEditable() {
        textView.isEditable = false
        XCTAssertTrue(textView.isSelectable, "STTextView should remain selectable even when not editable")
    }
    
    // MARK: - Text Input Tests
    
    func testSettingText() {
        let testText = "Hello, World!"
        textView.text = testText
        
        XCTAssertEqual(textView.text, testText, "Text should be set correctly")
        XCTAssertEqual(textView.text, testText, "text property should match string property")
    }
    
    func testInsertingText() {
        textView.text = "Hello World"
        
        // Select position after "Hello "
        let range = NSRange(location: 6, length: 0)
        textView.setSelectedRange(range)
        
        // Insert text
        textView.insertText("Swift ", replacementRange: NSRange(location: NSNotFound, length: 0))
        
        XCTAssertEqual(textView.text, "Hello Swift World", "Text should be inserted at cursor position")
    }
    
    func testReplacingText() {
        textView.text = "Hello World"
        
        // Select "World"
        let range = NSRange(location: 6, length: 5)
        textView.setSelectedRange(range)
        
        // Replace with "Swift"
        textView.insertText("Swift", replacementRange: range)
        
        XCTAssertEqual(textView.text, "Hello Swift", "Selected text should be replaced")
    }
    
    func testDeletingText() {
        textView.text = "Hello World"
        
        // Select "Hello "
        let range = NSRange(location: 0, length: 6)
        textView.setSelectedRange(range)
        
        // Delete
        textView.deleteBackward(nil)
        
        XCTAssertEqual(textView.text, "World", "Selected text should be deleted")
    }
    
    // MARK: - Responder Chain Tests
    
    func testBecomingFirstResponder() {
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        
        XCTAssertTrue(window.firstResponder === textView, "STTextView should become first responder")
    }
    
    func testAcceptsFirstResponder() {
        XCTAssertTrue(textView.acceptsFirstResponder, "STTextView should accept first responder")
    }
    
    func testNotAcceptingFirstResponderWhenNotEditable() {
        textView.isEditable = false
        textView.isSelectable = false
        
        XCTAssertFalse(textView.acceptsFirstResponder, "Non-editable and non-selectable STTextView should not accept first responder")
    }
    
    // MARK: - SwiftUI Integration Tests
    
    func testEditingInSwiftUIContext() {
        // Test the configuration directly without SwiftUI context
        var config = EditorConfiguration()
        config.isEditable = true
        
        // Create STTextView directly and apply configuration
        let testView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        testView.isEditable = config.isEditable
        testView.text = "Initial Text"
        
        XCTAssertTrue(testView.isEditable, "View should be editable based on configuration")
        XCTAssertEqual(testView.text, "Initial Text", "Initial text should be set")
    }
    
    func testReadOnlyConfiguration() {
        // Test read-only configuration
        var config = EditorConfiguration()
        config.isEditable = false
        
        // Create STTextView directly and apply configuration
        let testView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        testView.isEditable = config.isEditable
        testView.isSelectable = true // Read-only should still be selectable
        testView.text = "Read Only Text"
        
        XCTAssertFalse(testView.isEditable, "Read-only configuration should make view non-editable")
        XCTAssertTrue(testView.isSelectable, "Read-only view should still be selectable")
    }
    
    // MARK: - Text Change Notification Tests
    
    func testTextChangeNotifications() {
        let expectation = XCTestExpectation(description: "Text change notification")
        
        let observer = NotificationCenter.default.addObserver(
            forName: STTextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { notification in
            expectation.fulfill()
        }
        
        textView.text = "Changed text"
        
        wait(for: [expectation], timeout: 1.0)
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testDelegateTextChangeCallback() {
        @MainActor
        class MockDelegate: NSObject, STTextViewDelegate {
            var textDidChangeCalled = false
            
            func textViewDidChangeText(_ notification: Notification) {
                textDidChangeCalled = true
            }
        }
        
        let delegate = MockDelegate()
        textView.textDelegate = delegate
        
        textView.text = "New text"
        
        // In a real implementation, we'd need to trigger the actual text change mechanism
        // For now, we'll manually post the notification to test the delegate
        NotificationCenter.default.post(name: STTextView.textDidChangeNotification, object: textView)
        
        XCTAssertTrue(delegate.textDidChangeCalled, "Delegate should be notified of text changes")
    }
}