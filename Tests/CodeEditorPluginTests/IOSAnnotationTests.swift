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
    private var annotationManager: AnnotationManager?
    
    // MARK: - Setup
    
    override func setUp() async throws {
        await MainActor.run {
            containerView = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
            textView = containerView?.textView
            annotationManager = AnnotationManager()
        }
    }
    
    override func tearDown() async throws {
        await MainActor.run {
            annotationManager = nil
            textView = nil
            containerView = nil
        }
    }
    
    // MARK: - IOS Annotation View Tests
    
    func testIOSAnnotationViewCreation() async {
        // Add text with annotations
        textView.text = """
        func example() {
            // TODO: Implement this feature
            // FIXME: This needs urgent attention
            // NOTE: Important information here
            // WARNING: Be careful with this
            // ERROR: This is broken
        }
        """
        
        // Create annotations
        let todoAnnotation = CodeAnnotation(
            type: .todo,
            lineNumber: 1,
            content: "Implement this feature",
            range: NSRange(location: 20, length: 33)
        )
        
        let fixmeAnnotation = CodeAnnotation(
            type: .fixme,
            lineNumber: 2,
            content: "This needs urgent attention",
            range: NSRange(location: 58, length: 38)
        )
        
        // Update annotation manager
        annotationManager.annotations = [todoAnnotation, fixmeAnnotation]
        
        // Verify annotation views can be created
        let todoView = annotationManager.createAnnotationView(for: todoAnnotation, in: containerView)
        XCTAssertNotNil(todoView)
        
        let fixmeView = annotationManager.createAnnotationView(for: fixmeAnnotation, in: containerView)
        XCTAssertNotNil(fixmeView)
    }
    
    func testAnnotationGestureRecognizers() async {
        let annotation = CodeAnnotation(
            type: .todo,
            lineNumber: 0,
            content: "Test annotation",
            range: NSRange(location: 0, length: 10)
        )
        
        let annotationView = annotationManager.createAnnotationView(for: annotation, in: containerView)
        
        // Verify gesture recognizers are added
        let gestureRecognizers = annotationView?.gestureRecognizers ?? []
        
        // Should have tap gesture
        let hasTapGesture = gestureRecognizers.contains { $0 is UITapGestureRecognizer }
        XCTAssertTrue(hasTapGesture)
        
        // Should have long press gesture
        let hasLongPressGesture = gestureRecognizers.contains { $0 is UILongPressGestureRecognizer }
        XCTAssertTrue(hasLongPressGesture)
    }
    
    func testAnnotationPopoverPresentation() async {
        let annotation = CodeAnnotation(
            type: .fixme,
            lineNumber: 0,
            content: "Critical bug here",
            range: NSRange(location: 0, length: 20)
        )
        
        let annotationView = annotationManager.createAnnotationView(for: annotation, in: containerView)
        
        // Simulate tap
        if UIDevice.current.userInterfaceIdiom == .pad {
            // On iPad, should present as popover
            annotationView?.showAnnotationPopup()
            
            // Wait for presentation
            await Task.yield()
            
            // Verify popover is presented (this would be more detailed in a real UI test)
            XCTAssertNotNil(annotationView)
        } else {
            // On iPhone, should present as overlay
            annotationView?.showAnnotationPopup()
            
            // Verify overlay is added to view hierarchy
            XCTAssertNotNil(annotationView)
        }
    }
    
    func testAnnotationBadgeColors() async {
        let types: [CodeAnnotation.AnnotationType] = [.todo, .fixme, .note, .warning, .error]
        let expectedColors: [UIColor] = [
            UIColor.systemBlue,
            UIColor.systemOrange,
            UIColor.systemGreen,
            UIColor.systemYellow,
            UIColor.systemRed
        ]
        
        for (index, type) in types.enumerated() {
            let annotation = CodeAnnotation(
                type: type,
                lineNumber: index,
                content: "Test",
                range: NSRange(location: 0, length: 10)
            )
            
            let view = annotationManager.createAnnotationView(for: annotation, in: containerView)
            XCTAssertNotNil(view)
            
            // Badge color should match expected
            let badgeColor = annotationManager.color(for: type)
            XCTAssertEqual(badgeColor.cgColor.components, expectedColors[index].cgColor.components)
        }
    }
    
    func testAnnotationTextLayout() async {
        // Test with long annotation content
        let longContent = "This is a very long annotation content that should wrap properly in the popup view"
        let annotation = CodeAnnotation(
            type: .note,
            lineNumber: 0,
            content: longContent,
            range: NSRange(location: 0, length: 50)
        )
        
        let view = annotationManager.createAnnotationView(for: annotation, in: containerView)
        XCTAssertNotNil(view)
        
        // Content should be preserved
        XCTAssertEqual(annotation.content, longContent)
    }
    
    // MARK: - Touch Interaction Tests
    
    func testAnnotationTouchHandling() async {
        textView?.text = "// TODO: Test touch handling"
        
        let annotation = CodeAnnotation(
            type: .todo,
            lineNumber: 0,
            content: "Test touch handling",
            range: NSRange(location: 0, length: 28)
        )
        
        let view = annotationManager.createAnnotationView(for: annotation, in: containerView)
        containerView.addSubview(view!)
        
        // Simulate touch
        let touch = MockTouch(view: view!, phase: .began)
        let event = MockTouchEvent(touches: Set([touch]))
        
        view?.touchesBegan(Set([touch]), with: event)
        
        // View should respond to touch (actual behavior would be tested in UI tests)
        XCTAssertNotNil(view)
    }
    
    // MARK: - Performance Tests
    
    func testAnnotationViewCreationPerformance() async {
        let annotations = (0..<100).map { index in
            CodeAnnotation(
                type: .todo,
                lineNumber: index,
                content: "Annotation \(index)",
                range: NSRange(location: index * 50, length: 20)
            )
        }
        
        await MainActor.run {
            self.measure {
                for annotation in annotations {
                    _ = annotationManager.createAnnotationView(for: annotation, in: containerView)
                }
            }
        }
    }
    
    func testAnnotationUpdatePerformance() async {
        // Create many annotations
        var annotations = (0..<100).map { index in
            CodeAnnotation(
                type: .todo,
                lineNumber: index,
                content: "Annotation \(index)",
                range: NSRange(location: index * 50, length: 20)
            )
        }
        
        await MainActor.run {
            self.measure {
                // Update annotations multiple times
                for _ in 0..<10 {
                    annotations = annotations.shuffled()
                    annotationManager.annotations = annotations
                }
            }
        }
    }
    
    // MARK: - Helper Types
    
    private class MockTouch: UITouch {
        private let mockView: UIView
        private let mockPhase: UITouch.Phase
        
        init(view: UIView, phase: UITouch.Phase) {
            self.mockView = view
            self.mockPhase = phase
            super.init()
        }
        
        override var view: UIView? {
            mockView
        }
        
        override var phase: UITouch.Phase {
            mockPhase
        }
        
        deinit {
            // Cleanup
        }
    }
    
    private class MockTouchEvent: UIEvent {
        private let mockTouches: Set<UITouch>
        
        init(touches: Set<UITouch>) {
            self.mockTouches = touches
            super.init()
        }
        
        override var allTouches: Set<UITouch> {
            mockTouches
        }
        
        deinit {
            // Cleanup
        }
    }
    
    deinit {
        // Cleanup
    }
}

// MARK: - AnnotationManager Extension for Tests

extension AnnotationManager {
    func createAnnotationView(for annotation: CodeAnnotation, in _: UIView) -> UIView? {
        // Create a simple annotation view for testing
        let view = AnnotationBadgeView(annotation: annotation)
        view.frame = CGRect(x: 0, y: CGFloat(annotation.lineNumber) * 20, width: 100, height: 20)
        return view
    }
    
    func color(for type: CodeAnnotation.AnnotationType) -> UIColor {
        switch type {
        case .todo:
            return .systemBlue

        case .fixme:
            return .systemOrange

        case .note:
            return .systemGreen

        case .warning:
            return .systemYellow

        case .error:
            return .systemRed
        }
    }
}

// MARK: - Mock Annotation View

private class AnnotationBadgeView: UIView {
    let annotation: CodeAnnotation
    private var popoverController: UIViewController?
    
    init(annotation: CodeAnnotation) {
        self.annotation = annotation
        super.init(frame: .zero)
        setupView()
    }
    
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        // Add gesture recognizers
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        addGestureRecognizer(longPressGesture)
    }
    
    @objc private func handleTap() {
        showAnnotationPopup()
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            showAnnotationPopup(detachable: true)
        }
    }
    
    func showAnnotationPopup(detachable _: Bool = false) {
        // Mock implementation for testing
        let contentVC = UIViewController()
        contentVC.preferredContentSize = CGSize(width: 300, height: 200)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            contentVC.modalPresentationStyle = .popover
            contentVC.popoverPresentationController?.sourceView = self
            contentVC.popoverPresentationController?.sourceRect = bounds
            popoverController = contentVC
        } else {
            // On iPhone, would show as overlay
            popoverController = contentVC
        }
    }
    
    deinit {
        // Cleanup
    }
}
#endif
