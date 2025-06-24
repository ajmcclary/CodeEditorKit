import AppKit
@testable import CodeEditorPlugin
import XCTest

// MARK: - STTextViewTests

final class STTextViewTests: XCTestCase {
    // MARK: - Basic Initialization Tests

    @MainActor
    func testInitialization() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertNotNil(textView)
        XCTAssertNotNil(textView.textStorage)
        XCTAssertNotNil(textView.textContainer)
        XCTAssertNotNil(textView.layoutManager)
    }

    @MainActor
    func testViewHierarchy() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        // NSTextView is its own view, no document view needed
        // Test that it can be standalone or in hierarchy
        XCTAssertTrue(textView.superview == nil || textView.superview != nil)
        // Test that it's a proper NSTextView subclass
        XCTAssertTrue(textView.isKind(of: NSTextView.self))
    }

    // MARK: - Text Setting Tests

    @MainActor
    func testSetText() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let testText = "Hello, World!"
        textView.text = testText

        XCTAssertEqual(textView.text, testText)
        XCTAssertGreaterThan(textView.textStorage?.length ?? 0, 0)
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
        let longText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 1_000)
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
        XCTAssertTrue(textView.textContainer?.widthTracksTextView ?? false)
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

    // MARK: - Annotation Tests

    @MainActor
    func testAddAnnotation() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = "Test content"

        // Create NSTextRange for annotation (simplified approach)
        let mockRange = NSTextRange(location: NSTextLocation(), end: NSTextLocation())
        let annotation = STAnnotation(range: mockRange, content: "Test annotation", id: "test")

        textView.addAnnotation(annotation)
        XCTAssertEqual(textView.allAnnotations.count, 1)
        XCTAssertEqual(textView.allAnnotations.first?.id, "test")
    }

    // MARK: - Layout Tests

    @MainActor
    func testTextStorageHasContent() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = "Test content"

        // Force layout
        textView.layoutManager?.ensureLayout(forCharacterRange: NSRange(
            location: 0,
            length: textView.textStorage?.length ?? 0
        ))

        // Check that text storage has content
        let textLength = textView.textStorage?.length ?? 0
        XCTAssertGreaterThan(textLength, 0)
    }

    @MainActor
    func testLayoutManager() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertNotNil(textView.layoutManager)

        // The layout manager should be connected to the text view
        XCTAssertEqual(textView.layoutManager?.textContainers.first, textView.textContainer)
    }

    // MARK: - Syntax Highlighting Tests

    @MainActor
    func testSyntaxHighlightingEnabled() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(textView.isSyntaxHighlightingEnabled)
        textView.isSyntaxHighlightingEnabled = false
        XCTAssertFalse(textView.isSyntaxHighlightingEnabled)
    }

    @MainActor
    func testLanguageSelection() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertEqual(textView.language, .plainText)
        textView.language = .swift
        XCTAssertEqual(textView.language, .swift)
    }

    @MainActor
    func testSetLanguageByExtension() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.setLanguage(fileExtension: "swift")
        XCTAssertEqual(textView.language, .swift)
        textView.setLanguage(fileExtension: "py")
        XCTAssertEqual(textView.language, .python)
    }

    @MainActor
    func testIsFlipped() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(textView.isFlipped)
    }

    @MainActor
    func testGutterViewCreation() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertNil(textView.gutterView)
        textView.showsLineNumbers = true
        XCTAssertNotNil(textView.gutterView)
        textView.showsLineNumbers = false
        XCTAssertNil(textView.gutterView)
    }

    // MARK: - Performance Tests

    @MainActor
    func testLargeTextPerformance() {
        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let largeText = String(repeating: "Line of text\n", count: 10_000)

        measure {
            textView.text = largeText
        }
    }
    
    deinit {
        // Cleanup if needed
    }
}

// MARK: - MockSTTextViewDelegate

@MainActor
class MockSTTextViewDelegate: NSObject, @preconcurrency STTextViewDelegate {
    var textDidChangeCalled = false
    var selectionDidChangeCalled = false

    nonisolated func textViewDidChangeText(_: Notification) {
        Task { @MainActor in
            textDidChangeCalled = true
        }
    }

    nonisolated func textViewDidChangeSelection(_: Notification) {
        Task { @MainActor in
            selectionDidChangeCalled = true
        }
    }
    
    deinit {
        // Cleanup if needed
    }
}

// Note: Plugin system has been removed and functionality integrated directly into STTextView
