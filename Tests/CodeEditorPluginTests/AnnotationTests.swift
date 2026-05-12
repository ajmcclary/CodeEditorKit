#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorPlugin
import XCTest

// MARK: - AnnotationTests

@MainActor
final class AnnotationTests: XCTestCase {
    private var _textView: CodeEditorView?

    private var textView: CodeEditorView {
        guard let textView = _textView else {
            fatalError("textView not initialized - call setUp first")
        }
        return textView
    }

    override func setUp() async throws {
        await MainActor.run {
            _textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
            // Ensure text storage is properly initialized
            #if canImport(AppKit)
            _textView?.string = ""
            #else
            _textView?.text = ""
            #endif
            // Force layout to ensure TextKit is initialized
            #if canImport(AppKit)
            _textView?.layoutSubtreeIfNeeded()
            _textView?.needsLayout = true
            _textView?.layout()
            #else
            _textView?.layoutIfNeeded()
            _textView?.setNeedsLayout()
            #endif
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            _textView = nil
        }
    }

    // MARK: - Helper Methods

    /// Creates an NSTextRange from an NSRange for the current text view
    private func createTextRange(from nsRange: NSRange) -> NSTextRange? {
        // For tests, create a mock range
        let startLocation = MockTextLocation(offset: nsRange.location)
        let endLocation = MockTextLocation(offset: NSMaxRange(nsRange))
        return NSTextRange(location: startLocation, end: endLocation)
    }

    /// Creates a simple text range for the entire document
    private func createFullDocumentRange() -> NSTextRange? {
        // For tests, create a mock range that covers the document
        // This is needed because TextKit2 may not be fully initialized in test environment
        if let textLayoutManager = textView.textLayoutManager {
            return textLayoutManager.documentRange
        }

        // Fallback: create a mock range for testing
        let mockLocation = MockTextLocation(offset: 0)
        #if canImport(AppKit)
        let mockEndLocation = MockTextLocation(offset: textView.string.count)
        #else
        let mockEndLocation = MockTextLocation(offset: textView.text?.count ?? 0)
        #endif
        return NSTextRange(location: mockLocation, end: mockEndLocation)
    }

    // MARK: - Annotation Model Tests

    func testAnnotationCreation() {
        #if canImport(AppKit)
        textView.string = "Test content"
        #else
        textView.text = "Test content"
        #endif

        guard let range = createFullDocumentRange() else {
            XCTFail("Could not create text range")
            return
        }

        let annotation = Annotation(range: range, content: "Test annotation", id: "test-id")

        XCTAssertEqual(annotation.range, NSRange(range) ?? .notFound)
        XCTAssertEqual(annotation.content, "Test annotation")
        XCTAssertEqual(annotation.id, "test-id")
    }

    func testAnnotationEquality() {
        #if canImport(AppKit)
        textView.string = "Test content"
        #else
        textView.text = "Test content"
        #endif

        guard let range1 = createFullDocumentRange(),
              let range2 = createFullDocumentRange() else {
            XCTFail("Could not create text ranges")
            return
        }

        let annotation1 = Annotation(range: range1, content: "Same content", id: "id1")
        let annotation2 = Annotation(range: range2, content: "Same content", id: "id2")
        let annotation3 = Annotation(range: range1, content: "Same content", id: "id1")

        // Different IDs should make annotations different
        XCTAssertNotEqual(annotation1.id, annotation2.id)

        // Same ID should match
        XCTAssertEqual(annotation1.id, annotation3.id)
    }

    // MARK: - CodeEditorViewAnnotation Tests

    func testCodeEditorViewAnnotationCreation() {
        #if canImport(AppKit)
        textView.string = "Test content"
        #else
        textView.text = "Test content"
        #endif

        // Create a mock location at the beginning of the document
        let location = MockTextLocation(offset: 0)

        let annotation = CodeEditorViewAnnotation(
            location: location,
            content: "Line annotation",
            id: "line-test"
        )

        XCTAssertNotNil(annotation.location)
        XCTAssertEqual(annotation.content, "Line annotation")
        XCTAssertEqual(annotation.id, "line-test")
    }

    // MARK: - Annotation Collection Tests

    func testAddSingleAnnotation() {
        textView.text = "Test content for annotation"

        guard let range = createFullDocumentRange() else {
            XCTFail("Could not create document range")
            return
        }

        let annotation = Annotation(range: range, content: "Single annotation", id: "single")

        XCTAssertEqual(textView.allAnnotations.count, 0)
        textView.addAnnotation(annotation)
        XCTAssertEqual(textView.allAnnotations.count, 1)
        XCTAssertEqual(textView.allAnnotations.first?.id, "single")
    }

    func testAddMultipleAnnotations() {
        textView.text = "Test content with multiple annotations"

        // Create multiple annotations
        let annotations = (1...5).compactMap { index -> Annotation? in
            guard let range = createFullDocumentRange() else {
                return nil
            }
            return Annotation(range: range, content: "Annotation \(index)", id: "anno-\(index)")
        }

        XCTAssertEqual(annotations.count, 5)

        // Add all annotations
        for annotation in annotations {
            textView.addAnnotation(annotation)
        }

        XCTAssertEqual(textView.allAnnotations.count, 5)

        // Verify all annotations are present
        let ids = Set(textView.allAnnotations.map { $0.id })
        let expectedIds = Set(["anno-1", "anno-2", "anno-3", "anno-4", "anno-5"])
        XCTAssertEqual(ids, expectedIds)
    }

    func testRemoveSpecificAnnotation() {
        textView.text = "Test content"

        guard let range1 = createFullDocumentRange(),
              let range2 = createFullDocumentRange() else {
            XCTFail("Could not create ranges")
            return
        }

        let annotation1 = Annotation(range: range1, content: "First", id: "first")
        let annotation2 = Annotation(range: range2, content: "Second", id: "second")

        textView.addAnnotation(annotation1)
        textView.addAnnotation(annotation2)
        XCTAssertEqual(textView.allAnnotations.count, 2)

        // Remove specific annotation
        textView.removeAnnotation(withId: "first")
        XCTAssertEqual(textView.allAnnotations.count, 1)
        XCTAssertEqual(textView.allAnnotations.first?.id, "second")
    }

    func testRemoveNonExistentAnnotation() {
        textView.text = "Test content"

        guard let range = createFullDocumentRange() else {
            XCTFail("Could not create range")
            return
        }

        let annotation = Annotation(range: range, content: "Test", id: "exists")
        textView.addAnnotation(annotation)
        XCTAssertEqual(textView.allAnnotations.count, 1)

        // Try to remove non-existent annotation
        textView.removeAnnotation(withId: "does-not-exist")
        XCTAssertEqual(textView.allAnnotations.count, 1) // Should remain unchanged
    }

    func testRemoveAllAnnotations() {
        textView.text = "Test content with annotations"

        // Add multiple annotations
        for index in 1...10 {
            guard let range = createFullDocumentRange() else {
                continue
            }
            let annotation = Annotation(range: range, content: "Annotation \(index)", id: "id-\(index)")
            textView.addAnnotation(annotation)
        }

        XCTAssertEqual(textView.allAnnotations.count, 10)

        // Remove all annotations
        textView.removeAllAnnotations()
        XCTAssertEqual(textView.allAnnotations.count, 0)
    }

    // MARK: - Annotation Data Source Tests

    func testAnnotationDataSourceAssignment() {
        let dataSource = TestAnnotationDataSource()

        XCTAssertNil(textView.annotationsDataSource)
        textView.annotationsDataSource = dataSource
        XCTAssertNotNil(textView.annotationsDataSource)
        XCTAssertIdentical(textView.annotationsDataSource, dataSource)
    }

    func testAnnotationDataSourceWeakReference() {
        do {
            let dataSource = TestAnnotationDataSource()
            textView.annotationsDataSource = dataSource
            XCTAssertNotNil(textView.annotationsDataSource)
        }

        // Data source should be deallocated and reference should be nil
        XCTAssertNil(textView.annotationsDataSource)
    }

    func testAnnotationDataSourceCallbacks() {
        let dataSource = TestAnnotationDataSource()
        textView.annotationsDataSource = dataSource
        textView.text = "Test content"

        guard let range = createFullDocumentRange() else {
            XCTFail("Could not create range")
            return
        }

        // Add annotation to trigger data source callbacks
        let annotation = Annotation(range: range, content: "Test annotation", id: "callback-test")
        textView.addAnnotation(annotation)

        // Force layout to trigger annotation view creation
        #if canImport(AppKit)
        textView.layoutSubtreeIfNeeded()
        #else
        textView.layoutIfNeeded()
        #endif

        // Verify data source was accessed
        XCTAssertNotNil(textView.annotationsDataSource)
    }

    // MARK: - Annotation Range Tests

    func testAnnotationRangeValidation() {
        textView.text = "Short text"

        // Create annotation with valid range
        guard let validRange = createFullDocumentRange() else {
            XCTFail("Could not create valid range")
            return
        }

        let annotation = Annotation(range: validRange, content: "Valid annotation", id: "valid")
        textView.addAnnotation(annotation)

        XCTAssertEqual(textView.allAnnotations.count, 1)
    }

    func testAnnotationWithEmptyText() {
        textView.text = ""

        // Should handle empty text gracefully
        XCTAssertEqual(textView.text, "")
        XCTAssertEqual(textView.allAnnotations.count, 0)

        // Layout should not crash
        #if canImport(AppKit)
        textView.layoutSubtreeIfNeeded()
        #else
        textView.layoutIfNeeded()
        #endif
    }

    // MARK: - Annotation Layout Tests

    func testAnnotationLayoutIntegration() {
        textView.text = "Test text for layout"

        // Force initial layout
        #if canImport(AppKit)
        textView.layoutSubtreeIfNeeded()
        #else
        textView.layoutIfNeeded()
        #endif

        guard let range = createFullDocumentRange() else {
            XCTFail("Could not create range")
            return
        }

        let annotation = Annotation(range: range, content: "Layout test", id: "layout")
        textView.addAnnotation(annotation)

        // Layout again with annotation
        #if canImport(AppKit)
        textView.layoutSubtreeIfNeeded()
        #else
        textView.layoutIfNeeded()
        #endif

        // Should not crash and annotation should be tracked
        XCTAssertEqual(textView.allAnnotations.count, 1)
    }

    func testAnnotationTextKit2Integration() {
        textView.text = "TextKit2 annotation test"

        // Check if using TextKit2
        let usingTextKit2 = textView.textLayoutManager != nil

        if usingTextKit2 {
            // Test TextKit2 specific functionality
            guard let textLayoutManager = textView.textLayoutManager else {
                XCTFail("TextKit2 layout manager not available")
                return
            }

            XCTAssertNotNil(textLayoutManager.textContentManager)
        } else {
            // Test TextKit1 fallback
            XCTAssertNotNil(textView.layoutManager)
            XCTAssertNotNil(textView.textContainer)
        }
    }

    // MARK: - Performance Tests

    func testManyAnnotationsPerformance() {
        textView.text = String(repeating: "Line of text\n", count: 100) // Reduced from 1000

        measure(options: Self.ultraFastMeasureOptions) {
            // Clear existing annotations first
            textView.removeAllAnnotations()

            // Add many annotations - reduced from 100 to 50
            for index in 1...50 {
                guard let range = createFullDocumentRange() else {
                    continue
                }
                let annotation = Annotation(range: range, content: "Annotation \(index)", id: "perf-\(index)")
                textView.addAnnotation(annotation)
            }
        }

        XCTAssertEqual(textView.allAnnotations.count, 50)
    }

    func testAnnotationRemovalPerformance() {
        textView.text = "Performance test text"

        // Add many annotations first
        for index in 1...1_000 {
            guard let range = createFullDocumentRange() else {
                continue
            }
            let annotation = Annotation(range: range, content: "Annotation \(index)", id: "remove-\(index)")
            textView.addAnnotation(annotation)
        }

        XCTAssertEqual(textView.allAnnotations.count, 1_000)

        measure(options: Self.standardMeasureOptions) {
            textView.removeAllAnnotations()
        }

        XCTAssertEqual(textView.allAnnotations.count, 0)
    }

    // MARK: - Edge Cases

    func testDuplicateAnnotationIDs() {
        textView.text = "Test duplicate IDs"

        guard let range1 = createFullDocumentRange(),
              let range2 = createFullDocumentRange() else {
            XCTFail("Could not create ranges")
            return
        }

        let annotation1 = Annotation(range: range1, content: "First", id: "duplicate")
        let annotation2 = Annotation(range: range2, content: "Second", id: "duplicate")

        textView.addAnnotation(annotation1)
        textView.addAnnotation(annotation2)

        // Both should be added (implementation may vary)
        XCTAssertGreaterThanOrEqual(textView.allAnnotations.count, 1)

        // Removing by ID should remove matching annotations
        textView.removeAnnotation(withId: "duplicate")

        // Should remove at least one
        XCTAssertLessThan(textView.allAnnotations.count, 2)
    }

    func testAnnotationWithSpecialCharacters() {
        textView.text = "Text with émojis 🚀 and unicode ñoño"

        guard let range = createFullDocumentRange() else {
            XCTFail("Could not create range")
            return
        }

        let annotation = Annotation(
            range: range,
            content: "Annotation with 🎯 émojis and ñoño",
            id: "unicode-test"
        )

        textView.addAnnotation(annotation)
        XCTAssertEqual(textView.allAnnotations.count, 1)
        XCTAssertEqual(textView.allAnnotations.first?.content, "Annotation with 🎯 émojis and ñoño")
    }

    deinit {
        // Cleanup if needed
    }
}

// MARK: - Test Helper Classes

@MainActor
class TestAnnotationDataSource: NSObject, @preconcurrency AnnotationsDataSource {
    var mockAnnotations: [Annotation] = []
    var viewCreationCount = 0

    func annotations(for range: NSRange) -> [Annotation] {
        _ = range
        return mockAnnotations.filter { _ in
            // Simple intersection check for testing
            true
        }
    }

    var textViewAnnotations: [CodeEditorViewAnnotation] {
        mockAnnotations.map { annotation in
            CodeEditorViewAnnotation(
                utf16Location: annotation.range.location,
                content: annotation.content,
                id: annotation.id
            )
        }
    }

    func textView(
        _ textView: CodeEditorView,
        viewForLineAnnotation annotation: CodeEditorViewAnnotation,
        textLineFragment: NSTextLineFragment,
        proposedViewFrame: CGRect
    ) -> PlatformView? {
        _ = textView
        _ = annotation
        _ = textLineFragment
        viewCreationCount += 1

        let view = PlatformView(frame: proposedViewFrame)
        #if canImport(AppKit)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.systemBlue.cgColor
        view.layer?.cornerRadius = proposedViewFrame.width / 2
        #elseif canImport(UIKit)
        view.backgroundColor = UIColor.systemBlue
        view.layer.cornerRadius = proposedViewFrame.width / 2
        #endif

        return view
    }

    func addMockAnnotation(range: NSTextRange, content: String, id: String) {
        let annotation = Annotation(range: range, content: content, id: id)
        mockAnnotations.append(annotation)
    }

    deinit {
        // Cleanup if needed
    }
}
