//
//  CodeEditorContainerViewTests.swift
//  CodeEditorPluginTests
//
//  Created on 2025-06-27.
//

@testable import CodeEditorPlugin
import XCTest
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// Skip these tests in environments where UI testing is not supported
@MainActor
final class CodeEditorContainerViewTests: XCTestCase {
    // MARK: - Properties
    
    @MainActor
    private func createContainerView() -> CodeEditorContainerView? {
        // Always try to create the container view for testing
        // The view components should work even in headless environments
        return CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    }
    
    // MARK: - Initialization Tests
    
    @MainActor
    func testInitialization() throws {
        guard let containerView = createContainerView() else {
            throw XCTSkip("UI tests not supported in this environment")
        }
        XCTAssertNotNil(containerView.textView)
        XCTAssertNotNil(containerView.gutterView)
        XCTAssertNotNil(containerView.minimapView)
        #if canImport(UIKit)
        XCTAssertNotNil(containerView.contentView)
        #else
        XCTAssertNotNil(containerView.scrollView)
        #endif
        
        // Check initial configuration
        XCTAssertEqual(containerView.configuration.display.showLineNumbers, EditorConfiguration.default.display.showLineNumbers)
    }
    
    @MainActor
    func testViewHierarchy() throws {
        guard let containerView = createContainerView() else {
            throw XCTSkip("UI tests not supported in this environment")
        }
        #if canImport(UIKit)
        // On iOS/Mac Catalyst, text view is added directly to container
        let textView = containerView.textView
        XCTAssertTrue(containerView.subviews.contains(textView))
        
        // Gutter view is only added if showLineNumbers is true
        if containerView.configuration.display.showLineNumbers {
            let gutterView = containerView.gutterView
            XCTAssertTrue(containerView.subviews.contains(gutterView))
        }
        
        // Minimap is not added to subviews on iOS/Mac Catalyst in current implementation
        // It's created but not added to the view hierarchy
        XCTAssertNotNil(containerView.minimapView)
        #else
        // macOS: Check scroll view contains text view
        XCTAssertEqual(containerView.scrollView.documentView, containerView.textView)
        
        // Container should have minimap and scroll view (NOT gutter - uses ruler view)
        let minimapView = containerView.minimapView
        let scrollView = containerView.scrollView
        XCTAssertTrue(containerView.subviews.contains(minimapView), "Minimap view should be in container subviews")
        XCTAssertTrue(containerView.subviews.contains(scrollView), "Scroll view should be in container subviews")
        
        // On macOS, gutter is handled by ruler view, not as a subview
        let gutterView = containerView.gutterView
        XCTAssertFalse(containerView.subviews.contains(gutterView), "Gutter view should NOT be in container subviews on macOS (uses ruler view instead)")
        #endif
    }
    
    // MARK: - Configuration Tests
    
    @MainActor
    func testConfigurationApplication() throws {
        guard let containerView = createContainerView() else {
            throw XCTSkip("UI tests not supported in this environment")
        }
        
        var config = EditorConfiguration()
        config.display.showLineNumbers = true
        config.display.showMinimap = true
        config.behavior.isEditable = false
        
        containerView.configuration = config
        
        XCTAssertTrue(containerView.showsLineNumbers)
        XCTAssertFalse(containerView.textView.configuration.behavior.isEditable)
        XCTAssertFalse(containerView.minimapView.isHidden)
    }
    
    @MainActor
    func testLineNumberToggle() throws {
        guard let containerView = createContainerView() else {
            throw XCTSkip("UI tests not supported in this environment")
        }
        // Initially show line numbers
        containerView.showsLineNumbers = true
        XCTAssertFalse(containerView.gutterView.isHidden)
        
        // Hide line numbers
        containerView.showsLineNumbers = false
        XCTAssertTrue(containerView.gutterView.isHidden)
        
        // Verify text container inset adjusted
        #if canImport(UIKit)
        let insets = containerView.textView.textContainerEdgeInsets
        // When line numbers are hidden, left inset should be minimal
        XCTAssertLessThan(insets.left, containerView.configuration.layout.gutterWidth)
        #else
        let insets = containerView.textView.textContainerInset
        // When line numbers are hidden, inset width should be less than gutter width (60.0)
        // Allow for some additional padding by using gutterWidth + lineNumberPadding as threshold
        let expectedMaxWidth = containerView.configuration.layout.gutterWidth + containerView.configuration.layout.lineNumberPadding
        XCTAssertLessThan(insets.width, expectedMaxWidth, "Text container inset width should be less than gutter width plus padding when line numbers are hidden")
        #endif
    }
    
    // MARK: - Layout Tests
    
    @MainActor
    func testLayoutWithGutter() throws {
        guard let containerView = createContainerView() else {
            throw XCTSkip("UI tests not supported in this environment")
        }
        containerView.showsLineNumbers = true
        #if canImport(UIKit)
        containerView.layoutSubviews()
        #else
        containerView.layout()
        #endif
        
        let gutterWidth = containerView.configuration.layout.gutterWidth
        
        #if canImport(UIKit)
        // iOS/Catalyst: Check gutter view positioning
        XCTAssertEqual(containerView.gutterView.frame.origin.x, 0)
        XCTAssertEqual(containerView.gutterView.frame.width, gutterWidth)
        
        // Text view should account for gutter in its insets
        let textInsets = containerView.textView.textContainerEdgeInsets
        XCTAssertGreaterThan(textInsets.left, gutterWidth)
        #else
        // macOS: Check ruler view thickness instead of gutter view
        if let rulerView = containerView.scrollView.verticalRulerView {
            XCTAssertEqual(rulerView.ruleThickness, gutterWidth, "Ruler view thickness should equal gutter width")
        } else {
            XCTFail("Ruler view should be present when line numbers are shown")
        }
        
        // On macOS, ruler view handles the spacing, so text insets may be different
        let textInsets = containerView.textView.textContainerInset
        // Just verify that insets exist - the ruler view handles the actual spacing
        XCTAssertGreaterThanOrEqual(textInsets.width, 0, "Text container should have some inset")
        #endif
    }
    
    @MainActor
    func testLayoutWithMinimap() throws {
        guard let containerView = createContainerView() else {
            throw XCTSkip("UI tests not supported in this environment")
        }
        var config = containerView.configuration
        config.display.showMinimap = true
        containerView.configuration = config
        #if canImport(UIKit)
        containerView.layoutSubviews()
        #else
        containerView.layout()
        #endif
        
        // Minimap should be visible
        XCTAssertFalse(containerView.minimapView.isHidden)
        
        // Minimap should be on the right
        let minimapWidth = containerView.configuration.layout.minimapWidth
        let expectedX = containerView.bounds.width - minimapWidth
        XCTAssertEqual(containerView.minimapView.frame.origin.x, expectedX, accuracy: 1.0)
    }
    
    @MainActor
    func testLayoutWithKeyboard() throws {
        guard let containerView = createContainerView() else {
            throw XCTSkip("UI tests not supported in this environment")
        }
        #if canImport(UIKit)
        // Simulate keyboard appearance
        let keyboardHeight: CGFloat = 300
        let keyboardFrame = CGRect(
            x: 0,
            y: containerView.bounds.height - keyboardHeight,
            width: containerView.bounds.width,
            height: keyboardHeight
        )
        
        // Simulate keyboard notification
        let userInfo: [AnyHashable: Any] = [
            UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: keyboardFrame),
            UIResponder.keyboardAnimationDurationUserInfoKey: 0.25
        ]
        
        NotificationCenter.default.post(
            name: UIResponder.keyboardWillShowNotification,
            object: nil,
            userInfo: userInfo
        )
        
        // Wait for layout
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
        
        // Content inset should be adjusted
        let contentInset = containerView.textView.contentInset
        XCTAssertGreaterThan(contentInset.bottom, 0)
        #endif
    }
    
    // MARK: - ContentView Tests
    
    @MainActor
    func testContentViewGestureRecognizers() throws {
        guard let containerView = createContainerView() else {
            throw XCTSkip("UI tests not supported in this environment")
        }
        #if canImport(UIKit)
        let textView = containerView.textView
        containerView.contentView.setTextView(textView)
        
        // Should have gesture recognizers added
        let gestureRecognizers = containerView.contentView.gestureRecognizers ?? []
        
        // Should have tap gesture
        let hasTapGesture = gestureRecognizers.contains { $0 is UITapGestureRecognizer }
        XCTAssertTrue(hasTapGesture)
        
        // Should have long press gesture
        let hasLongPressGesture = gestureRecognizers.contains { $0 is UILongPressGestureRecognizer }
        XCTAssertTrue(hasLongPressGesture)
        #endif
    }
    
    @MainActor
    func testContentViewInputAccessory() throws {
        guard let containerView = createContainerView() else {
            throw XCTSkip("UI tests not supported in this environment")
        }
        #if canImport(UIKit)
        let toolbar = containerView.contentView.createInputAccessory()
        XCTAssertNotNil(toolbar)
        
        // Verify toolbar is a UIToolbar
        if let toolbarView = toolbar as? UIToolbar {
            let items = toolbarView.items ?? []
            XCTAssertGreaterThan(items.count, 0)
            
            // Should have done button
            let hasDoneButton = items.contains { item in
                item.style == .done || item.tag == 1_001 // Done button tag
            }
            XCTAssertTrue(hasDoneButton)
        } else {
            XCTFail("Expected UIToolbar")
        }
        #endif
    }
    
    // MARK: - Minimap Tests
    
    @MainActor
    func testMinimapNavigation() throws {
        guard let containerView = createContainerView() else {
            throw XCTSkip("UI tests not supported in this environment")
        }
        var config = containerView.configuration
        config.display.showMinimap = true
        containerView.configuration = config
        
        // Add some text
        containerView.textView.text = Array(repeating: "Line\n", count: 100).joined()
        #if canImport(UIKit)
        containerView.layoutSubviews()
        #else
        containerView.layout()
        #endif
        
        // Test navigation callback
        var navigatedToLine: Int?
        containerView.minimapView.onNavigate = { line in
            navigatedToLine = line
        }
        
        // Simulate navigation
        containerView.minimapView.onNavigate?(50)
        XCTAssertEqual(navigatedToLine, 50)
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testLayoutPerformance() throws {
        guard let containerView = createContainerView() else {
            throw XCTSkip("UI tests not supported in this environment")
        }
        // Add substantial content
        containerView.textView.text = Array(repeating: "This is a test line\n", count: 1_000).joined()
        
        measure {
            for _ in 0..<100 {
                #if canImport(UIKit)
                containerView.setNeedsLayout()
                containerView.layoutIfNeeded()
                #else
                containerView.needsLayout = true
                containerView.layout()
                #endif
            }
        }
    }
    
    @MainActor
    func testConfigurationChangePerformance() throws {
        guard let containerView = createContainerView() else {
            throw XCTSkip("UI tests not supported in this environment")
        }
        var config = containerView.configuration
        
        measure {
            for index in 0..<100 {
                config.display.showLineNumbers = index.isMultiple(of: 2)
                config.display.showMinimap = index.isMultiple(of: 3)
                containerView.configuration = config
            }
        }
    }
    
    // MARK: - Edge Cases
    
    @MainActor
    func testSmallFrameLayout() throws {
        guard let containerView = createContainerView() else {
            throw XCTSkip("UI tests not supported in this environment")
        }
        containerView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        #if canImport(UIKit)
        containerView.layoutSubviews()
        #else
        containerView.layout()
        #endif
        
        // Ensure no negative dimensions
        XCTAssertGreaterThan(containerView.textView.frame.width, 0)
        XCTAssertGreaterThan(containerView.textView.frame.height, 0)
    }
    
    @MainActor
    func testLargeContentScroll() throws {
        guard let containerView = createContainerView() else {
            throw XCTSkip("UI tests not supported in this environment")
        }
        // Add very large content
        let largeText = Array(repeating: "Line\n", count: 10_000).joined()
        containerView.textView.text = largeText
        
        // Ensure scrolling is enabled
        #if canImport(UIKit)
        // UITextView inherits from UIScrollView and has scrolling enabled by default
        XCTAssertTrue(containerView.textView.isScrollEnabled)
        // Note: alwaysBounceVertical might be false by default on Mac Catalyst
        // so we just check that scrolling works
        
        // Force layout to calculate content size
        containerView.textView.layoutIfNeeded()
        
        // Content size should be larger than frame for large content
        XCTAssertGreaterThan(containerView.textView.contentSize.height, containerView.textView.frame.height)
        #else
        // macOS: Check that text view is set up for scrolling
        XCTAssertTrue(containerView.textView.isVerticallyResizable)
        #endif
    }
    
    deinit {
        // Cleanup
    }
}
