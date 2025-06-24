import XCTest
@testable import CodeEditorPlugin
import AppKit

final class STTextViewTests: XCTestCase {
    
    // MARK: - Basic Initialization Tests
    
    @MainActor
    func testInitialization() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertNotNil(textView)
        XCTAssertNotNil(textView.textLayoutManager)
        XCTAssertNotNil(textView.textContentManager)
        XCTAssertNotNil(textView.textContainer)
        XCTAssertNotNil(textView.textContentView)
    }
    
    @MainActor
    func testViewHierarchy() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        // Check that textContentView is in the view hierarchy
        XCTAssertNotNil(textView.documentView)
        XCTAssertTrue(textView.documentView is STContentView)
        XCTAssertEqual(textView.documentView, textView.textContentView)
    }
    
    // MARK: - Text Setting Tests
    
    @MainActor
    func testSetText() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let testText = "Hello, World!"
        textView.text = testText
        
        XCTAssertEqual(textView.text, testText)
        XCTAssertFalse(textView.textLayoutManager.documentRange.isEmpty)
    }
    
    @MainActor
    func testSetEmptyText() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = ""
        XCTAssertEqual(textView.text, "")
    }
    
    @MainActor
    func testSetNilText() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = "Some text"
        textView.text = nil
        XCTAssertEqual(textView.text, "")
    }
    
    @MainActor
    func testSetLongText() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let longText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 1000)
        textView.text = longText
        XCTAssertEqual(textView.text, longText)
    }
    
    // MARK: - Configuration Tests
    
    @MainActor
    func testLineNumbers() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertFalse(textView.showsLineNumbers)
        textView.showsLineNumbers = true
        XCTAssertTrue(textView.showsLineNumbers)
    }
    
    @MainActor
    func testFont() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let customFont = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        textView.font = customFont
        XCTAssertEqual(textView.font, customFont)
    }
    
    @MainActor
    func testTextColor() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let customColor = NSColor.blue
        textView.textColor = customColor
        XCTAssertEqual(textView.textColor, customColor)
    }
    
    @MainActor
    func testBackgroundColor() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let customBgColor = NSColor.darkGray
        textView.backgroundColor = customBgColor
        XCTAssertEqual(textView.backgroundColor, customBgColor)
    }
    
    @MainActor
    func testEditability() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(textView.isEditable)
        textView.isEditable = false
        XCTAssertFalse(textView.isEditable)
    }
    
    @MainActor
    func testSelectability() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(textView.isSelectable)
        textView.isSelectable = false
        XCTAssertFalse(textView.isSelectable)
    }
    
    // MARK: - Line Highlighting Tests
    
    @MainActor
    func testLineHighlighting() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertFalse(textView.highlightSelectedLine)
        textView.highlightSelectedLine = true
        XCTAssertTrue(textView.highlightSelectedLine)
    }
    
    @MainActor
    func testLineHighlightColor() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let highlightColor = NSColor.yellow.withAlphaComponent(0.3)
        textView.selectedLineHighlightColor = highlightColor
        XCTAssertEqual(textView.selectedLineHighlightColor, highlightColor)
    }
    
    // MARK: - Text Container Tests
    
    @MainActor
    func testWidthTracking() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertFalse(textView.widthTracksTextView)
        textView.widthTracksTextView = true
        XCTAssertTrue(textView.widthTracksTextView)
        XCTAssertTrue(textView.textContainer.widthTracksTextView)
    }
    
    @MainActor
    func testHorizontalResizability() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(textView.isHorizontallyResizable)
        textView.isHorizontallyResizable = false
        XCTAssertFalse(textView.isHorizontallyResizable)
    }
    
    @MainActor
    func testVerticalResizability() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(textView.isVerticallyResizable)
        textView.isVerticallyResizable = false
        XCTAssertFalse(textView.isVerticallyResizable)
    }
    
    // MARK: - Delegate Tests
    
    @MainActor
    func testDelegateAssignment() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let delegate = MockSTTextViewDelegate()
        textView.textDelegate = delegate
        XCTAssertNotNil(textView.textDelegate)
    }
    
    // MARK: - Plugin Tests
    
    @MainActor
    func testAddPlugin() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let plugin = MockSTPlugin()
        textView.addPlugin(plugin)
        
        // Verify plugin was added (we'd need to expose plugins array for testing)
        XCTAssertTrue(plugin.setUpCalled)
    }
    
    // MARK: - Layout Tests
    
    @MainActor
    func testTextLayoutManagerHasContent() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = "Test content"
        
        // Force layout
        textView.textLayoutManager.ensureLayout(for: textView.textLayoutManager.documentRange)
        
        // Check that layout was performed
        let layoutRange = textView.textLayoutManager.documentRange
        XCTAssertFalse(layoutRange.isEmpty)
    }
    
    @MainActor
    func testViewportController() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let viewportController = textView.textLayoutManager.textViewportLayoutController
        XCTAssertNotNil(viewportController.delegate)
        
        // The delegate should be the text view itself
        XCTAssertTrue(viewportController.delegate is STTextView)
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testLargeTextPerformance() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let largeText = String(repeating: "Line of text\n", count: 10000)
        
        measure {
            textView.text = largeText
        }
    }
}

// MARK: - Mock Classes

@MainActor
class MockSTTextViewDelegate: NSObject, @preconcurrency STTextViewDelegate {
    var textDidChangeCalled = false
    var selectionDidChangeCalled = false
    
    nonisolated func textViewDidChangeText(_ notification: Notification) {
        Task { @MainActor in
            textDidChangeCalled = true
        }
    }
    
    nonisolated func textViewDidChangeSelection(_ notification: Notification) {
        Task { @MainActor in
            selectionDidChangeCalled = true
        }
    }
}

@MainActor
class MockSTPlugin: STPlugin {
    typealias Coordinator = Void
    
    var setUpCalled = false
    var tearDownCalled = false
    
    func setUp(context: any PluginContext<MockSTPlugin>) {
        setUpCalled = true
    }
    
    func tearDown() {
        tearDownCalled = true
    }
}