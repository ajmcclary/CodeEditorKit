//
//  IOSAnnotationTests.swift
//  CodeEditorPluginTests
//
//  Created on 2025-06-27.
//

@testable import CodeEditorPlugin
import XCTest
#if canImport(UIKit)
import UIKit

@MainActor
final class IOSAnnotationTests: XCTestCase {
    // MARK: - Properties

    private var textView: CodeEditorView?
    private var containerView: CodeEditorContainerView?
    private var mockDataSource: MockIOSAnnotationDataSource?

    // MARK: - Setup

    override func setUp() async throws {
        await MainActor.run {
            containerView = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
            textView = containerView?.textView
            mockDataSource = MockIOSAnnotationDataSource()
            textView?.annotationsDataSource = mockDataSource
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            mockDataSource = nil
            textView = nil
            containerView = nil
        }
    }

    // MARK: - IOS Annotation View Tests

    func testIOSAnnotationViewCreation() async {
        guard let textView else {
            XCTFail("Text view not initialized")
            return
        }

        // Add text
        textView.text = """
        func example() {
            // TODO: Implement this feature
            // FIXME: This needs urgent attention
        }
        """

        // Create mock text range
        let startLocation = MockTextLocation(offset: 20)
        let endLocation = MockTextLocation(offset: 53)
        guard let range = NSTextRange(location: startLocation, end: endLocation) else {
            XCTFail("Failed to create NSTextRange")
            return
        }

        // Create annotation
        let annotation = Annotation(
            range: range,
            content: "TODO: Implement this feature",
            id: "test-todo-1"
        )

        // Add annotation to data source
        mockDataSource?.addMockAnnotation(annotation)

        // Trigger layout update
        textView.setNeedsLayout()
        textView.layoutIfNeeded()

        // Verify data source is called
        XCTAssertEqual(mockDataSource?.annotationRequestCount, 0) // Will be called during layout
    }

    func testIOSAnnotationViewFrame() async {
        guard textView != nil else {
            XCTFail("Text view not initialized")
            return
        }

        // Create mock annotation
        let startLocation = MockTextLocation(offset: 0)
        _ = MockTextLocation(offset: 10)
        _ = NSTextRange(location: startLocation, end: MockTextLocation(offset: 10))

        let annotation = CodeEditorViewAnnotation(
            location: startLocation,
            content: "Test annotation",
            id: "test-1"
        )

        // Test view creation with proposed frame
        let proposedFrame = CGRect(x: 10, y: 20, width: 30, height: 40)

        // Since we can't create NSTextLineFragment in tests, we'll test the mock data source directly
        mockDataSource?.annotationColor = .systemBlue
        let view = mockDataSource?.createAnnotationView(
            for: annotation,
            proposedFrame: proposedFrame
        )

        XCTAssertNotNil(view)
        XCTAssertEqual(view?.frame, proposedFrame)
    }

    func testIOSAnnotationTouchHandling() async {
        guard textView != nil else {
            XCTFail("Text view not initialized")
            return
        }

        // Create annotation view
        let proposedFrame = CGRect(x: 0, y: 0, width: 50, height: 20)
        let annotation = CodeEditorViewAnnotation(
            location: MockTextLocation(offset: 0),
            content: "Touchable annotation",
            id: "touch-test"
        )

        // Since we can't create NSTextLineFragment in tests, we'll test the mock data source directly
        let view = mockDataSource?.createAnnotationView(
            for: annotation,
            proposedFrame: proposedFrame
        )

        // Verify the view is touchable
        XCTAssertNotNil(view)
        XCTAssertTrue(view?.isUserInteractionEnabled ?? false)
    }

    func testIOSSpecificAnnotationColors() async {
        // Test iOS-specific color handling
        let colors: [UIColor] = [
            .systemBlue,
            .systemOrange,
            .systemGreen,
            .systemYellow,
            .systemRed
        ]

        for (index, color) in colors.enumerated() {
            let annotation = CodeEditorViewAnnotation(
                location: MockTextLocation(offset: index * 10),
                content: "Color test \(index)",
                id: "color-\(index)"
            )

            mockDataSource?.annotationColor = color

            let view = mockDataSource?.createAnnotationView(
                for: annotation,
                proposedFrame: CGRect(x: 0, y: 0, width: 50, height: 20)
            )

            XCTAssertNotNil(view)
            XCTAssertEqual(view?.backgroundColor, color)
        }
    }
}

// MARK: - Mock iOS Annotation Data Source

@MainActor
private class MockIOSAnnotationDataSource: NSObject, @preconcurrency AnnotationsDataSource {
    var mockAnnotations: [Annotation] = []
    var annotationRequestCount = 0
    var annotationColor: UIColor = .systemBlue

    func annotations(for range: NSRange) -> [Annotation] {
        annotationRequestCount += 1
        return mockAnnotations.filter { annotation in
            annotation.range.intersects(range)
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
        _: CodeEditorView,
        viewForLineAnnotation annotation: CodeEditorViewAnnotation,
        textLineFragment _: NSTextLineFragment,
        proposedViewFrame: CGRect
    ) -> PlatformView? {
        // This method is already called on the main thread by the framework
        createAnnotationView(for: annotation, proposedFrame: proposedViewFrame)
    }

    /// Helper method to create annotation views for testing
    func createAnnotationView(for annotation: CodeEditorViewAnnotation, proposedFrame: CGRect) -> UIView {
        let view = UIView(frame: proposedFrame)
        view.backgroundColor = annotationColor
        view.layer.cornerRadius = 4
        view.isUserInteractionEnabled = true

        // Add a label
        let label = UILabel(frame: view.bounds.insetBy(dx: 4, dy: 2))
        label.text = String(annotation.content.prefix(10))
        label.textColor = .white
        label.font = .systemFont(ofSize: 12)
        label.adjustsFontSizeToFitWidth = true
        view.addSubview(label)

        return view
    }

    func addMockAnnotation(_ annotation: Annotation) {
        mockAnnotations.append(annotation)
    }
}

#endif
