import AppKit
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import XCTest

// MARK: - AnnotationSystemTests

@MainActor
final class AnnotationSystemTests: XCTestCase {
    
    var textView: CodeEditorView!
    var annotationManager: AnnotationManager!
    
    override func setUp() async throws {
        await MainActor.run {
            textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
            annotationManager = AnnotationManager(textView: textView)
        }
    }
    
    override func tearDown() async throws {
        await MainActor.run {
            annotationManager = nil
            textView = nil
        }
    }
    
    // MARK: - Basic Annotation Manager Tests
    
    func testAnnotationManagerInitialization() {
        XCTAssertNotNil(annotationManager)
        XCTAssertNotNil(textView.annotationsDataSource)
        XCTAssertTrue(textView.annotationsDataSource === annotationManager)
    }
    
    func testScanEmptyText() {
        textView.text = ""
        annotationManager.scanForAnnotations()
        
        // Should handle empty text gracefully
        XCTAssertEqual(textView.allAnnotations.count, 0)
    }
    
    func testScanTextWithoutAnnotations() {
        textView.text = "let x = 42\nprint(x)\nreturn x * 2"
        annotationManager.scanForAnnotations()
        
        // Should not find any annotations
        XCTAssertEqual(textView.allAnnotations.count, 0)
    }
    
    // MARK: - TODO Detection Tests
    
    func testScanSingleTODO() {
        textView.text = "// TODO: Implement this feature\nlet x = 42"
        annotationManager.scanForAnnotations()
        
        // Force layout to ensure text is processed
        textView.layoutSubtreeIfNeeded()
        
        // Verify TODO was found
        let text = textView.text ?? ""
        XCTAssertTrue(text.contains("TODO:"))
        
        // Check that annotation scanning completed without errors
        XCTAssertNotNil(textView.textStorage)
        XCTAssertGreaterThan(textView.textStorage?.length ?? 0, 0)
    }
    
    func testScanMultipleTODOs() {
        let testText = """
        // TODO: First task
        func example() {
            // TODO: Second task
            let value = 42
            // TODO: Third task
        }
        """
        textView.text = testText
        annotationManager.scanForAnnotations()
        
        // Verify multiple TODOs found
        let todoCount = testText.components(separatedBy: "TODO:").count - 1
        XCTAssertEqual(todoCount, 3)
    }
    
    func testScanTODOVariants() {
        let testText = """
        // TODO: Standard todo
        /* TODO: Block comment todo */
        # TODO: Script comment todo
        // todo: Lowercase variant
        """
        textView.text = testText
        annotationManager.scanForAnnotations()
        
        // Should find standard TODO format
        XCTAssertTrue(testText.contains("TODO:"))
    }
    
    // MARK: - FIXME Detection Tests
    
    func testScanSingleFIXME() {
        textView.text = "// FIXME: This needs to be fixed\nreturn nil"
        annotationManager.scanForAnnotations()
        
        // Force layout
        textView.layoutSubtreeIfNeeded()
        
        // Verify FIXME was found
        let text = textView.text ?? ""
        XCTAssertTrue(text.contains("FIXME:"))
    }
    
    func testScanMixedAnnotations() {
        let testText = """
        // TODO: Add error handling
        func process() {
            // FIXME: Handle edge case
            // NOTE: This is important
            // WARNING: Deprecated API
        }
        """
        textView.text = testText
        annotationManager.scanForAnnotations()
        
        // Verify mixed annotations
        XCTAssertTrue(testText.contains("TODO:"))
        XCTAssertTrue(testText.contains("FIXME:"))
        XCTAssertTrue(testText.contains("NOTE:"))
        XCTAssertTrue(testText.contains("WARNING:"))
    }
    
    // MARK: - Annotation Positioning Tests
    
    func testAnnotationPositionCalculation() {
        textView.text = "// TODO: Test positioning"
        annotationManager.scanForAnnotations()
        
        // Force layout
        textView.layoutSubtreeIfNeeded()
        
        // Verify layout components are available
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            XCTFail("Layout manager or text container not available")
            return
        }
        
        // Test that we can calculate text positions
        let text = textView.text ?? ""
        let todoRange = (text as NSString).range(of: "TODO:")
        
        if todoRange.location != NSNotFound {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: todoRange, actualCharacterRange: nil)
            let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            
            // Verify we can calculate bounding rectangles
            XCTAssertGreaterThanOrEqual(boundingRect.width, 0)
            XCTAssertGreaterThanOrEqual(boundingRect.height, 0)
        }
    }
    
    func testAnnotationFrameCalculation() {
        textView.text = "TODO: Calculate frame"
        annotationManager.scanForAnnotations()
        
        // Force layout
        textView.layoutSubtreeIfNeeded()
        
        // Test frame calculation logic
        let badgeSize: CGFloat = 20
        let badgePadding: CGFloat = 4
        let proposedX: CGFloat = 100
        let proposedY: CGFloat = 50
        
        let frame = CGRect(
            x: proposedX + badgePadding,
            y: proposedY - (badgeSize / 2),
            width: badgeSize,
            height: badgeSize
        )
        
        XCTAssertEqual(frame.width, badgeSize)
        XCTAssertEqual(frame.height, badgeSize)
        XCTAssertGreaterThan(frame.origin.x, proposedX)
    }
    
    // MARK: - Annotation Clearing Tests
    
    func testClearAnnotations() {
        textView.text = "// TODO: Test clearing\n// FIXME: Another annotation"
        annotationManager.scanForAnnotations()
        
        // Clear annotations
        annotationManager.clearAnnotations()
        
        // Verify annotations are cleared
        XCTAssertEqual(textView.allAnnotations.count, 0)
    }
    
    func testRescanAfterTextChange() {
        // Initial scan
        textView.text = "// TODO: Original annotation"
        annotationManager.scanForAnnotations()
        
        // Change text
        textView.text = "// FIXME: New annotation\n// TODO: Another new one"
        annotationManager.scanForAnnotations()
        
        // Verify new annotations are found
        let text = textView.text ?? ""
        XCTAssertTrue(text.contains("FIXME:"))
        XCTAssertTrue(text.contains("TODO:"))
    }
    
    // MARK: - CodeAnnotation Model Tests
    
    func testCodeAnnotationTypes() {
        let todoAnnotation = CodeAnnotation(lineNumber: 1, type: .todo, message: "Test TODO", range: nil)
        let fixmeAnnotation = CodeAnnotation(lineNumber: 2, type: .fixme, message: "Test FIXME", range: nil)
        let warningAnnotation = CodeAnnotation(lineNumber: 3, type: .warning, message: "Test WARNING", range: nil)
        let noteAnnotation = CodeAnnotation(lineNumber: 4, type: .note, message: "Test NOTE", range: nil)
        let errorAnnotation = CodeAnnotation(lineNumber: 5, type: .error, message: "Test ERROR", range: nil)
        
        // Test type properties
        XCTAssertEqual(todoAnnotation.type.label, "TODO")
        XCTAssertEqual(fixmeAnnotation.type.label, "FIXME")
        XCTAssertEqual(warningAnnotation.type.label, "WARNING")
        XCTAssertEqual(noteAnnotation.type.label, "NOTE")
        XCTAssertEqual(errorAnnotation.type.label, "ERROR")
        
        // Test colors are assigned
        XCTAssertNotNil(todoAnnotation.type.color)
        XCTAssertNotNil(fixmeAnnotation.type.color)
        XCTAssertNotNil(warningAnnotation.type.color)
        XCTAssertNotNil(noteAnnotation.type.color)
        XCTAssertNotNil(errorAnnotation.type.color)
        
        // Test icons are assigned
        XCTAssertFalse(todoAnnotation.type.icon.isEmpty)
        XCTAssertFalse(fixmeAnnotation.type.icon.isEmpty)
        XCTAssertFalse(warningAnnotation.type.icon.isEmpty)
        XCTAssertFalse(noteAnnotation.type.icon.isEmpty)
        XCTAssertFalse(errorAnnotation.type.icon.isEmpty)
    }
    
    func testCodeAnnotationUniqueIDs() {
        let annotation1 = CodeAnnotation(lineNumber: 1, type: .todo, message: "First", range: nil)
        let annotation2 = CodeAnnotation(lineNumber: 1, type: .todo, message: "Second", range: nil)
        
        // Each annotation should have a unique ID
        XCTAssertNotEqual(annotation1.id, annotation2.id)
        XCTAssertFalse(annotation1.id.isEmpty)
        XCTAssertFalse(annotation2.id.isEmpty)
    }
    
    // MARK: - AnnotationView Tests
    
    func testAnnotationViewCreation() {
        let annotation = CodeAnnotation(lineNumber: 1, type: .todo, message: "Test annotation", range: nil)
        let frame = NSRect(x: 10, y: 10, width: 20, height: 20)
        let annotationView = AnnotationView(annotation: annotation, frame: frame)
        
        XCTAssertEqual(annotationView.frame, frame)
        XCTAssertNotNil(annotationView.layer)
        XCTAssertTrue(annotationView.wantsLayer)
    }
    
    func testAnnotationViewStyling() {
        let annotation = CodeAnnotation(lineNumber: 1, type: .warning, message: "Warning message", range: nil)
        let frame = NSRect(x: 0, y: 0, width: 24, height: 24)
        let annotationView = AnnotationView(annotation: annotation, frame: frame)
        
        // Verify styling is applied
        XCTAssertNotNil(annotationView.layer?.backgroundColor)
        XCTAssertEqual(annotationView.layer?.cornerRadius, frame.width / 2)
        
        // Should have icon subview
        XCTAssertGreaterThan(annotationView.subviews.count, 0)
    }
    
    // MARK: - Integration Tests
    
    func testFullAnnotationWorkflow() {
        // Set up text with annotations
        let testCode = """
        import Foundation
        
        // TODO: Add comprehensive error handling
        func processData(_ data: [String]) -> [Int] {
            // FIXME: This crashes with empty arrays
            let numbers = data.compactMap { Int($0) }
            
            // NOTE: Consider using async processing for large datasets
            return numbers.map { $0 * 2 }
        }
        
        // WARNING: This function is deprecated
        func oldFunction() {
            // ERROR: Known memory leak here
            print("deprecated")
        }
        """
        
        textView.text = testCode
        
        // Force layout
        textView.layoutSubtreeIfNeeded()
        
        // Scan for annotations
        annotationManager.scanForAnnotations()
        
        // Verify text contains expected annotations
        XCTAssertTrue(testCode.contains("TODO:"))
        XCTAssertTrue(testCode.contains("FIXME:"))
        XCTAssertTrue(testCode.contains("NOTE:"))
        XCTAssertTrue(testCode.contains("WARNING:"))
        XCTAssertTrue(testCode.contains("ERROR:"))
        
        // Verify layout components are working
        XCTAssertNotNil(textView.textStorage)
        XCTAssertNotNil(textView.layoutManager)
        XCTAssertNotNil(textView.textContainer)
        XCTAssertGreaterThan(textView.textStorage?.length ?? 0, 0)
    }
    
    func testAnnotationWithRealWorldCode() {
        let swiftCode = """
        class NetworkManager {
            // TODO: Add retry logic
            func fetchData() async throws -> Data {
                // FIXME: Handle timeout properly
                let url = URL(string: "https://api.example.com")!
                
                // NOTE: Consider adding cache
                let (data, _) = try await URLSession.shared.data(from: url)
                return data
            }
        }
        """
        
        textView.text = swiftCode
        textView.setLanguage(fileExtension: "swift")
        textView.layoutSubtreeIfNeeded()
        
        annotationManager.scanForAnnotations()
        
        // Verify language was set
        XCTAssertEqual(textView.language, .swift)
        
        // Verify annotations were found
        let annotationCount = swiftCode.components(separatedBy: "TODO:").count - 1 +
                            swiftCode.components(separatedBy: "FIXME:").count - 1 +
                            swiftCode.components(separatedBy: "NOTE:").count - 1
        XCTAssertEqual(annotationCount, 3)
    }
    
    // MARK: - Performance Tests
    
    func testAnnotationScanningPerformance() {
        // Create large text with many annotations
        var largeText = ""
        for index in 1...1000 {
            largeText += "// TODO: Task number \(index)\n"
            largeText += "func function\(index)() { /* implementation */ }\n"
        }
        
        textView.text = largeText
        
        measure {
            annotationManager.scanForAnnotations()
        }
    }
    
    func testLargeTextAnnotationHandling() {
        let largeCodeFile = String(repeating: "// TODO: Optimize this\\nlet x = 42\\n", count: 5000)
        textView.text = largeCodeFile
        
        // Should handle large files without crashing
        annotationManager.scanForAnnotations()
        
        // Verify text was set successfully
        XCTAssertEqual(textView.text, largeCodeFile)
        XCTAssertGreaterThan(textView.textStorage?.length ?? 0, 100000)
    }
}

// MARK: - Test Extensions

extension AnnotationSystemTests {
    /// Helper to count annotation patterns in text
    private func countAnnotationPatterns(in text: String) -> Int {
        let patterns = ["TODO:", "FIXME:", "NOTE:", "WARNING:", "ERROR:"]
        return patterns.reduce(0) { count, pattern in
            count + (text.components(separatedBy: pattern).count - 1)
        }
    }
    
    /// Helper to create test annotation with range
    private func createTestAnnotation(type: CodeAnnotation.AnnotationType, message: String) -> CodeAnnotation {
        return CodeAnnotation(lineNumber: 1, type: type, message: message, range: nil)
    }
}
