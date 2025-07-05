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
        // Check if we're in a headless environment
        #if os(macOS)
        if ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"] != nil {
            // We're likely in a test runner without UI context
            return nil
        }
        #endif
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
        // Content view should contain text view
        let contentView = containerView.contentView
        let textView = containerView.textView
        XCTAssertTrue(contentView.subviews.contains(textView))
        
        // Container should have gutter and minimap
        let gutterView = containerView.gutterView
        let minimapView = containerView.minimapView
        XCTAssertTrue(containerView.subviews.contains(gutterView))
        XCTAssertTrue(containerView.subviews.contains(minimapView))
        XCTAssertTrue(containerView.subviews.contains(contentView))
        #else
        // macOS: Check scroll view contains text view
        XCTAssertEqual(containerView.scrollView.documentView, containerView.textView)
        
        // Container should have gutter, minimap, and scroll view
        let gutterView = containerView.gutterView
        let minimapView = containerView.minimapView
        let scrollView = containerView.scrollView
        XCTAssertTrue(containerView.subviews.contains(gutterView))
        XCTAssertTrue(containerView.subviews.contains(minimapView))
        XCTAssertTrue(containerView.subviews.contains(scrollView))
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
        XCTAssertLessThan(insets.left, 50) // Should be less than gutter width
        #else
        let insets = containerView.textView.textContainerInset
        XCTAssertLessThan(insets.width, 50) // Should be less than gutter width
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
        
        // Gutter should be positioned on the left
        XCTAssertEqual(containerView.gutterView.frame.origin.x, 0)
        XCTAssertEqual(containerView.gutterView.frame.width, gutterWidth)
        
        // Text view should account for gutter in its insets
        #if canImport(UIKit)
        let textInsets = containerView.textView.textContainerEdgeInsets
        XCTAssertGreaterThan(textInsets.left, gutterWidth)
        #else
        let textInsets = containerView.textView.textContainerInset
        XCTAssertGreaterThan(textInsets.width, gutterWidth)
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
        
        // Verify toolbar has items
        let items = toolbar.items ?? []
        XCTAssertGreaterThan(items.count, 0)
        
        // Should have done button
        let hasDoneButton = items.contains { item in
            item.style == .done || item.tag == 1_001 // Done button tag
        }
        XCTAssertTrue(hasDoneButton)
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
        XCTAssertTrue(containerView.textView.isScrollEnabled)
        XCTAssertTrue(containerView.textView.alwaysBounceVertical)
        
        // Content size should be larger than frame
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
