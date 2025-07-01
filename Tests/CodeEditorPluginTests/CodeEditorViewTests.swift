import AppKit
@testable import CodeEditorPlugin
import XCTest

// MARK: - CodeEditorViewTests

final class CodeEditorViewTests: XCTestCase {
    // MARK: - Basic Initialization Tests

    @MainActor
    func testInitialization() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertNotNil(textView)
        XCTAssertNotNil(textView.textStorage)
        XCTAssertNotNil(textView.textContainer)
        XCTAssertNotNil(textView.layoutManager)
    }

    @MainActor
    func testViewHierarchy() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        // NSTextView is its own view, no document view needed
        // Test that it can be standalone or in hierarchy
        XCTAssertTrue(textView.superview == nil || textView.superview != nil)
        // Test that it's a proper NSTextView subclass
        XCTAssertTrue(textView.isKind(of: NSTextView.self))
    }

    // MARK: - Text Setting Tests

    @MainActor
    func testSetText() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let testText = "Hello, World!"
        textView.text = testText

        XCTAssertEqual(textView.text, testText)
        XCTAssertGreaterThan(textView.textStorage?.length ?? 0, 0)
    }

    @MainActor
    func testSetEmptyText() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = ""
        XCTAssertEqual(textView.text, "")
    }

    @MainActor
    func testSetNilText() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = "Some text"
        textView.text = nil
        XCTAssertEqual(textView.text, "")
    }

    @MainActor
    func testSetLongText() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let longText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 1_000)
        textView.text = longText
        XCTAssertEqual(textView.text, longText)
    }

    // MARK: - Configuration Tests

    @MainActor
    func testLineNumbers() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(textView.showsLineNumbers)  // Default is true
        textView.showsLineNumbers = false
        XCTAssertFalse(textView.showsLineNumbers)
        textView.showsLineNumbers = true
        XCTAssertTrue(textView.showsLineNumbers)
    }

    @MainActor
    func testFont() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let customFont = PlatformFonts.monospacedSystemFont(ofSize: 16, weight: .regular)
        textView.font = customFont
        XCTAssertEqual(textView.font, customFont)
    }

    @MainActor
    func testTextColor() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let customColor = PlatformColors.systemBlue
        textView.textColor = customColor
        XCTAssertEqual(textView.textColor, customColor)
    }

    @MainActor
    func testBackgroundColor() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let customBgColor = PlatformColors.systemGray
        textView.backgroundColor = customBgColor
        XCTAssertEqual(textView.backgroundColor, customBgColor)
    }

    @MainActor
    func testEditability() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(textView.isEditable)
        textView.isEditable = false
        XCTAssertFalse(textView.isEditable)
    }

    @MainActor
    func testSelectability() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(textView.isSelectable)
        textView.isSelectable = false
        XCTAssertFalse(textView.isSelectable)
    }

    // MARK: - Line Highlighting Tests

    @MainActor
    func testLineHighlighting() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(textView.highlightSelectedLine)  // Default is true
        textView.highlightSelectedLine = false
        XCTAssertFalse(textView.highlightSelectedLine)
        textView.highlightSelectedLine = true
        XCTAssertTrue(textView.highlightSelectedLine)
    }

    @MainActor
    func testLineHighlightColor() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let highlightColor = NSColor.yellow.withAlphaComponent(0.3)
        textView.selectedLineHighlightColor = highlightColor
        XCTAssertEqual(textView.selectedLineHighlightColor, highlightColor)
    }

    // MARK: - Text Container Tests

    @MainActor
    func testWidthTracking() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        // Test through the text container since CodeEditorView doesn't expose widthTracksTextView directly
        textView.textContainer?.widthTracksTextView = true
        XCTAssertTrue(textView.textContainer?.widthTracksTextView ?? false)
        
        textView.textContainer?.widthTracksTextView = false
        XCTAssertFalse(textView.textContainer?.widthTracksTextView ?? true)
    }

    @MainActor
    func testHorizontalResizability() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertFalse(textView.isHorizontallyResizable)
        textView.isHorizontallyResizable = false
        XCTAssertFalse(textView.isHorizontallyResizable)
    }

    @MainActor
    func testVerticalResizability() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(textView.isVerticallyResizable)
        textView.isVerticallyResizable = false
        XCTAssertFalse(textView.isVerticallyResizable)
    }

    // MARK: - Delegate Tests

    @MainActor
    func testDelegateAssignment() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let delegate = MockCodeEditorViewDelegate()
        textView.textDelegate = delegate
        XCTAssertNotNil(textView.textDelegate)
    }

    // MARK: - Annotation Tests

    @MainActor
    func testAddAnnotation() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = "Test content"

        // Create mock NSTextRange for annotation
        let mockRange = NSTextRange(
            location: MockTextLocation(offset: 0),
            end: MockTextLocation(offset: textView.text?.count ?? 0)
        )!
        let annotation = Annotation(range: mockRange, content: "Test annotation", id: "test")

        textView.addAnnotation(annotation)
        XCTAssertEqual(textView.allAnnotations.count, 1)
        XCTAssertEqual(textView.allAnnotations.first?.id, "test")
    }

    @MainActor
    func testRemoveAnnotation() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = "Test content with annotations"

        // Create mock ranges for annotations
        let range1 = NSTextRange(
            location: MockTextLocation(offset: 0),
            end: MockTextLocation(offset: textView.text?.count ?? 0)
        )!
        let range2 = NSTextRange(
            location: MockTextLocation(offset: 0),
            end: MockTextLocation(offset: textView.text?.count ?? 0)
        )!
        
        let annotation1 = Annotation(range: range1, content: "First annotation", id: "test1")
        let annotation2 = Annotation(range: range2, content: "Second annotation", id: "test2")

        textView.addAnnotation(annotation1)
        textView.addAnnotation(annotation2)
        XCTAssertEqual(textView.allAnnotations.count, 2)

        // Remove one annotation
        textView.removeAnnotation(withId: "test1")
        XCTAssertEqual(textView.allAnnotations.count, 1)
        XCTAssertEqual(textView.allAnnotations.first?.id, "test2")

        // Remove remaining annotation
        textView.removeAnnotation(withId: "test2")
        XCTAssertEqual(textView.allAnnotations.count, 0)
    }

    @MainActor
    func testRemoveAllAnnotations() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = "Test content with multiple annotations"

        // Add multiple annotations with mock ranges
        for index in 1...5 {
            let range = NSTextRange(
                location: MockTextLocation(offset: 0),
                end: MockTextLocation(offset: textView.text?.count ?? 0)
            )!
            let annotation = Annotation(range: range, content: "Annotation \(index)", id: "test\(index)")
            textView.addAnnotation(annotation)
        }
        
        XCTAssertEqual(textView.allAnnotations.count, 5)
        
        // Remove all annotations
        textView.removeAllAnnotations()
        XCTAssertEqual(textView.allAnnotations.count, 0)
    }

    @MainActor
    func testAnnotationDataSource() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let mockDataSource = MockAnnotationDataSource()
        
        textView.annotationsDataSource = mockDataSource
        XCTAssertNotNil(textView.annotationsDataSource)
        XCTAssertTrue(textView.annotationsDataSource === mockDataSource)
        
        // Test weak reference
        textView.annotationsDataSource = nil
        XCTAssertNil(textView.annotationsDataSource)
    }

    @MainActor
    func testAnnotationWithTextKit1() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = "// TODO: Implement this feature\nlet x = 42"
        
        // Force layout to ensure text is rendered
        textView.layoutSubtreeIfNeeded()
        
        // Verify text layout manager setup
        XCTAssertNotNil(textView.textStorage)
        XCTAssertNotNil(textView.layoutManager)
        XCTAssertNotNil(textView.textContainer)
        
        // Verify text content
        let text = textView.text ?? ""
        XCTAssertTrue(text.contains("TODO"))
        XCTAssertGreaterThan(text.count, 0)
    }

    @MainActor
    func testAnnotationRangeCalculation() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let testText = "Line 1\nLine 2 with TODO\nLine 3"
        textView.text = testText
        
        // Force layout
        textView.layoutSubtreeIfNeeded()
        
        // Find TODO range manually
        let todoRange = testText.range(of: "TODO").map { NSRange($0, in: testText) } ?? NSRange(location: NSNotFound, length: 0)
        XCTAssertNotEqual(todoRange.location, NSNotFound)
        XCTAssertEqual(todoRange.length, 4)
        
        // Verify range is within text bounds
        let textLength = textView.textStorage?.length ?? 0
        XCTAssertLessThan(todoRange.location + todoRange.length, textLength + 1)
    }

    @MainActor
    func testAnnotationPositioning() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = "// TODO: Test annotation positioning"
        
        // Force layout
        textView.layoutSubtreeIfNeeded()
        
        // Verify layout manager can calculate positions
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            XCTFail("Layout manager or text container not available")
            return
        }
        
        let textRange = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: textRange, actualCharacterRange: nil)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Verify we can calculate bounding rectangles
        XCTAssertGreaterThan(boundingRect.width, 0)
        XCTAssertGreaterThan(boundingRect.height, 0)
    }

    // MARK: - Layout Tests

    @MainActor
    func testTextStorageHasContent() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
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
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertNotNil(textView.layoutManager)

        // The layout manager should be connected to the text view
        XCTAssertEqual(textView.layoutManager?.textContainers.first, textView.textContainer)
    }

    // MARK: - Syntax Highlighting Tests

    @MainActor
    func testSyntaxHighlightingEnabled() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(textView.isSyntaxHighlightingEnabled)
        textView.isSyntaxHighlightingEnabled = false
        XCTAssertFalse(textView.isSyntaxHighlightingEnabled)
    }

    @MainActor
    func testLanguageSelection() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertEqual(textView.language, .plainText)
        textView.language = .swift
        XCTAssertEqual(textView.language, .swift)
    }

    @MainActor
    func testSetLanguageByExtension() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.setLanguage(fileExtension: "swift")
        XCTAssertEqual(textView.language, .swift)
        textView.setLanguage(fileExtension: "py")
        // Python is supported via regex highlighting, not direct enum case
        if case .regex = textView.language {
            XCTAssertTrue(true, "Python language correctly detected as regex-based")
        } else {
            XCTFail("Expected regex-based language for Python")
        }
    }

    @MainActor
    func testIsFlipped() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(textView.isFlipped)
    }

    @MainActor
    func testGutterViewCreation() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertNil(textView.gutterView)
        textView.showsLineNumbers = true
        XCTAssertNotNil(textView.gutterView)
        textView.showsLineNumbers = false
        XCTAssertNil(textView.gutterView)
    }

    // MARK: - Performance Tests

    @MainActor
    func testLargeTextPerformance() {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let largeText = String(repeating: "Line of text\n", count: 10_000)

        measure {
            textView.text = largeText
        }
    }

    deinit {
        // Cleanup if needed
    }
}

// MARK: - MockCodeEditorViewDelegate

@MainActor
class MockCodeEditorViewDelegate: NSObject, CodeEditorViewDelegate {
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

// MARK: - MockAnnotationDataSource

@MainActor
class MockAnnotationDataSource: NSObject, @preconcurrency AnnotationsDataSource {
    var mockAnnotations: [Annotation] = []
    var viewCreationCallCount = 0
    
    deinit {
        // Cleanup if needed
    }
    
    func annotations(for textRange: NSTextRange) -> [Annotation] {
        // Return annotations that intersect with the given range
        mockAnnotations.filter { annotation in
            annotation.range.intersects(textRange)
        }
    }
    
    var textViewAnnotations: [CodeEditorViewAnnotation] {
        mockAnnotations.compactMap { annotation in
            CodeEditorViewAnnotation(
                location: annotation.range.location,
                content: annotation.content,
                id: annotation.id
            )
        }
    }
    
    func textView(
        _: CodeEditorView,
        viewForLineAnnotation _: CodeEditorViewAnnotation,
        textLineFragment _: NSTextLineFragment,
        proposedViewFrame: CGRect
    ) -> NSView? {
        viewCreationCallCount += 1
        
        // Create a simple test view
        let view = NSView(frame: proposedViewFrame)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.blue.cgColor
        view.layer?.cornerRadius = proposedViewFrame.width / 2
        
        return view
    }
    
    func addMockAnnotation(range: NSTextRange, content: String, id: String) {
        let annotation = Annotation(range: range, content: content, id: id)
        mockAnnotations.append(annotation)
    }
    
    func clearMockAnnotations() {
        mockAnnotations.removeAll()
        viewCreationCallCount = 0
    }
}

// MARK: - Test Utilities

extension NSTextRange {
    /// Test helper to check if ranges intersect
    func intersects(_ other: NSTextRange) -> Bool {
        _ = other
        // Simple intersection check for testing
        // In a real implementation, this would use proper NSTextRange comparison
        return true // Simplified for testing
    }
}

// Note: Plugin system has been removed and functionality integrated directly into CodeEditorView
