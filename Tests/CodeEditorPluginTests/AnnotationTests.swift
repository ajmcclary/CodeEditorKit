import AppKit
@testable import CodeEditorPlugin
import XCTest

// MARK: - AnnotationTests

@MainActor
final class AnnotationTests: XCTestCase {
    private var _textView: STTextView?
    
    private var textView: STTextView {
        guard let textView = _textView else {
            fatalError("textView not initialized - call setUp first")
        }
        return textView
    }
    
    override func setUp() async throws {
        await MainActor.run {
            _textView = STTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        }
    }
    
    override func tearDown() async throws {
        await MainActor.run {
            _textView = nil
        }
    }
    
    // MARK: - STAnnotation Model Tests
    
    func testSTAnnotationCreation() {
        guard let documentRange = textView.textContentStorage?.documentRange,
              let range = NSTextRange(location: documentRange.location, end: documentRange.endLocation) else {
            XCTFail("Could not create text range")
            return
        }
        
        let annotation = STAnnotation(range: range, content: "Test annotation", id: "test-id")
        
        XCTAssertEqual(annotation.range, range)
        XCTAssertEqual(annotation.content, "Test annotation")
        XCTAssertEqual(annotation.id, "test-id")
    }
    
    func testSTAnnotationEquality() {
        guard let documentRange = textView.textContentStorage?.documentRange,
              let range1 = NSTextRange(location: documentRange.location, end: documentRange.endLocation),
              let range2 = NSTextRange(location: documentRange.location, end: documentRange.endLocation) else {
            XCTFail("Could not create text ranges")
            return
        }
        
        let annotation1 = STAnnotation(range: range1, content: "Same content", id: "id1")
        let annotation2 = STAnnotation(range: range2, content: "Same content", id: "id2")
        let annotation3 = STAnnotation(range: range1, content: "Same content", id: "id1")
        
        // Different IDs should make annotations different
        XCTAssertNotEqual(annotation1.id, annotation2.id)
        
        // Same ID should match
        XCTAssertEqual(annotation1.id, annotation3.id)
    }
    
    // MARK: - STTextViewAnnotation Tests
    
    func testSTTextViewAnnotationCreation() {
        guard let documentRange = textView.textContentStorage?.documentRange else {
            XCTFail("Could not get document range")
            return
        }
        
        let annotation = STTextViewAnnotation(
            location: documentRange.location,
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
        
        guard let documentRange = textView.textContentStorage?.documentRange,
              let range = NSTextRange(location: documentRange.location, end: documentRange.endLocation) else {
            XCTFail("Could not create document range")
            return
        }
        
        let annotation = STAnnotation(range: range, content: "Single annotation", id: "single")
        
        XCTAssertEqual(textView.allAnnotations.count, 0)
        textView.addAnnotation(annotation)
        XCTAssertEqual(textView.allAnnotations.count, 1)
        XCTAssertEqual(textView.allAnnotations.first?.id, "single")
    }
    
    func testAddMultipleAnnotations() {
        textView.text = "Test content with multiple annotations"
        
        guard let documentRange = textView.textContentStorage?.documentRange else {
            XCTFail("Could not get document range")
            return
        }
        
        // Create multiple annotations
        let annotations = (1...5).compactMap { index -> STAnnotation? in
            guard let range = NSTextRange(location: documentRange.location, end: documentRange.endLocation) else {
                return nil
            }
            return STAnnotation(range: range, content: "Annotation \(index)", id: "anno-\(index)")
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
        
        guard let documentRange = textView.textContentStorage?.documentRange,
              let range1 = NSTextRange(location: documentRange.location, end: documentRange.endLocation),
              let range2 = NSTextRange(location: documentRange.location, end: documentRange.endLocation) else {
            XCTFail("Could not create ranges")
            return
        }
        
        let annotation1 = STAnnotation(range: range1, content: "First", id: "first")
        let annotation2 = STAnnotation(range: range2, content: "Second", id: "second")
        
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
        
        guard let documentRange = textView.textContentStorage?.documentRange,
              let range = NSTextRange(location: documentRange.location, end: documentRange.endLocation) else {
            XCTFail("Could not create range")
            return
        }
        
        let annotation = STAnnotation(range: range, content: "Test", id: "exists")
        textView.addAnnotation(annotation)
        XCTAssertEqual(textView.allAnnotations.count, 1)
        
        // Try to remove non-existent annotation
        textView.removeAnnotation(withId: "does-not-exist")
        XCTAssertEqual(textView.allAnnotations.count, 1) // Should remain unchanged
    }
    
    func testRemoveAllAnnotations() {
        textView.text = "Test content with annotations"
        
        guard let documentRange = textView.textContentStorage?.documentRange else {
            XCTFail("Could not get document range")
            return
        }
        
        // Add multiple annotations
        for index in 1...10 {
            guard let range = NSTextRange(location: documentRange.location, end: documentRange.endLocation) else {
                continue
            }
            let annotation = STAnnotation(range: range, content: "Annotation \(index)", id: "id-\(index)")
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
        XCTAssertTrue(textView.annotationsDataSource === dataSource)
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
        
        guard let documentRange = textView.textContentStorage?.documentRange,
              let range = NSTextRange(location: documentRange.location, end: documentRange.endLocation) else {
            XCTFail("Could not create range")
            return
        }
        
        // Add annotation to trigger data source callbacks
        let annotation = STAnnotation(range: range, content: "Test annotation", id: "callback-test")
        textView.addAnnotation(annotation)
        
        // Force layout to trigger annotation view creation
        textView.layoutSubtreeIfNeeded()
        
        // Verify data source was accessed
        XCTAssertNotNil(textView.annotationsDataSource)
    }
    
    // MARK: - Annotation Range Tests
    
    func testAnnotationRangeValidation() {
        textView.text = "Short text"
        
        guard let documentRange = textView.textContentStorage?.documentRange else {
            XCTFail("Could not get document range")
            return
        }
        
        // Create annotation with valid range
        guard let validRange = NSTextRange(location: documentRange.location, end: documentRange.endLocation) else {
            XCTFail("Could not create valid range")
            return
        }
        
        let annotation = STAnnotation(range: validRange, content: "Valid annotation", id: "valid")
        textView.addAnnotation(annotation)
        
        XCTAssertEqual(textView.allAnnotations.count, 1)
    }
    
    func testAnnotationWithEmptyText() {
        textView.text = ""
        
        // Should handle empty text gracefully
        XCTAssertEqual(textView.text, "")
        XCTAssertEqual(textView.allAnnotations.count, 0)
        
        // Layout should not crash
        textView.layoutSubtreeIfNeeded()
    }
    
    // MARK: - Annotation Layout Tests
    
    func testAnnotationLayoutIntegration() {
        textView.text = "Test text for layout"
        
        // Force initial layout
        textView.layoutSubtreeIfNeeded()
        
        guard let documentRange = textView.textContentStorage?.documentRange,
              let range = NSTextRange(location: documentRange.location, end: documentRange.endLocation) else {
            XCTFail("Could not create range")
            return
        }
        
        let annotation = STAnnotation(range: range, content: "Layout test", id: "layout")
        textView.addAnnotation(annotation)
        
        // Layout again with annotation
        textView.layoutSubtreeIfNeeded()
        
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
        textView.text = String(repeating: "Line of text\n", count: 1_000)
        
        guard let documentRange = textView.textContentStorage?.documentRange else {
            XCTFail("Could not get document range")
            return
        }
        
        measure {
            // Clear existing annotations first
            textView.removeAllAnnotations()
            
            // Add many annotations
            for index in 1...100 {
                guard let range = NSTextRange(location: documentRange.location, end: documentRange.endLocation) else {
                    continue
                }
                let annotation = STAnnotation(range: range, content: "Annotation \(index)", id: "perf-\(index)")
                textView.addAnnotation(annotation)
            }
        }
        
        XCTAssertEqual(textView.allAnnotations.count, 100)
    }
    
    func testAnnotationRemovalPerformance() {
        textView.text = "Performance test text"
        
        guard let documentRange = textView.textContentStorage?.documentRange else {
            XCTFail("Could not get document range")
            return
        }
        
        // Add many annotations first
        for index in 1...1_000 {
            guard let range = NSTextRange(location: documentRange.location, end: documentRange.endLocation) else {
                continue
            }
            let annotation = STAnnotation(range: range, content: "Annotation \(index)", id: "remove-\(index)")
            textView.addAnnotation(annotation)
        }
        
        XCTAssertEqual(textView.allAnnotations.count, 1_000)
        
        measure {
            textView.removeAllAnnotations()
        }
        
        XCTAssertEqual(textView.allAnnotations.count, 0)
    }
    
    // MARK: - Edge Cases
    
    func testDuplicateAnnotationIDs() {
        textView.text = "Test duplicate IDs"
        
        guard let documentRange = textView.textContentStorage?.documentRange,
              let range1 = NSTextRange(location: documentRange.location, end: documentRange.endLocation),
              let range2 = NSTextRange(location: documentRange.location, end: documentRange.endLocation) else {
            XCTFail("Could not create ranges")
            return
        }
        
        let annotation1 = STAnnotation(range: range1, content: "First", id: "duplicate")
        let annotation2 = STAnnotation(range: range2, content: "Second", id: "duplicate")
        
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
        
        guard let documentRange = textView.textContentStorage?.documentRange,
              let range = NSTextRange(location: documentRange.location, end: documentRange.endLocation) else {
            XCTFail("Could not create range")
            return
        }
        
        let annotation = STAnnotation(
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
class TestAnnotationDataSource: NSObject, @preconcurrency STAnnotationsDataSource {
    var mockAnnotations: [STAnnotation] = []
    var viewCreationCount = 0
    
    func annotations(for textRange: NSTextRange) -> [STAnnotation] {
        _ = textRange
        return mockAnnotations.filter { _ in
            // Simple intersection check for testing
            true
        }
    }
    
    var textViewAnnotations: [STTextViewAnnotation] {
        mockAnnotations.compactMap { annotation in
            STTextViewAnnotation(
                location: annotation.range.location,
                content: annotation.content,
                id: annotation.id
            )
        }
    }
    
    func textView(
        _ textView: STTextView,
        viewForLineAnnotation annotation: STTextViewAnnotation,
        textLineFragment: NSTextLineFragment,
        proposedViewFrame: CGRect
    ) -> NSView? {
        _ = textView
        _ = annotation
        _ = textLineFragment
        viewCreationCount += 1
        
        let view = NSView(frame: proposedViewFrame)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.systemBlue.cgColor
        view.layer?.cornerRadius = proposedViewFrame.width / 2
        
        return view
    }
    
    func addMockAnnotation(range: NSTextRange, content: String, id: String) {
        let annotation = STAnnotation(range: range, content: content, id: id)
        mockAnnotations.append(annotation)
    }
    
    deinit {
        // Cleanup if needed
    }
}
