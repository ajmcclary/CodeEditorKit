//
//  CodeEditorContainerViewTests.swift
//  CodeEditorPluginTests
//
//  Created on 2025-06-27.
//

@testable import CodeEditorPlugin
import XCTest
#if canImport(UIKit)
import UIKit

@MainActor
final class CodeEditorContainerViewTests: XCTestCase {
    // MARK: - Properties
    
    private var containerView: CodeEditorContainerView?
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        containerView = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    }
    
    override func tearDown() {
        containerView = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(containerView.textView)
        XCTAssertNotNil(containerView.gutterView)
        XCTAssertNotNil(containerView.minimapView)
        XCTAssertNotNil(containerView.contentView)
        
        // Check initial configuration
        XCTAssertEqual(containerView.configuration.display.showLineNumbers, EditorConfiguration.default.display.showLineNumbers)
    }
    
    func testViewHierarchy() {
        // Content view should contain text view
        XCTAssertTrue(containerView.contentView.subviews.contains(containerView.textView))
        
        // Container should have gutter and minimap
        XCTAssertTrue(containerView.subviews.contains(containerView.gutterView))
        XCTAssertTrue(containerView.subviews.contains(containerView.minimapView))
        XCTAssertTrue(containerView.subviews.contains(containerView.contentView))
    }
    
    // MARK: - Configuration Tests
    
    func testConfigurationApplication() {
        var config = EditorConfiguration()
        config.display.showLineNumbers = true
        config.display.showMinimap = true
        config.behavior.isEditable = false
        
        containerView.configuration = config
        
        XCTAssertTrue(containerView.textView.configuration.display.showLineNumbers)
        XCTAssertFalse(containerView.textView.configuration.behavior.isEditable)
        XCTAssertFalse(containerView.minimapView.isHidden)
    }
    
    func testLineNumberToggle() {
        // Initially show line numbers
        containerView.showsLineNumbers = true
        XCTAssertFalse(containerView.gutterView.isHidden)
        
        // Hide line numbers
        containerView.showsLineNumbers = false
        XCTAssertTrue(containerView.gutterView.isHidden)
        
        // Verify text container inset adjusted
        let insets = containerView.textView.textContainerEdgeInsets
        XCTAssertLessThan(insets.left, 50) // Should be less than gutter width
    }
    
    // MARK: - Layout Tests
    
    func testLayoutWithGutter() {
        containerView.showsLineNumbers = true
        containerView.layoutSubviews()
        
        let gutterWidth = containerView.configuration.layout.gutterWidth
        
        // Gutter should be positioned on the left
        XCTAssertEqual(containerView.gutterView.frame.origin.x, 0)
        XCTAssertEqual(containerView.gutterView.frame.width, gutterWidth)
        
        // Text view should account for gutter in its insets
        let textInsets = containerView.textView.textContainerInset
        XCTAssertGreaterThan(textInsets.left, gutterWidth)
    }
    
    func testLayoutWithMinimap() {
        var config = containerView.configuration
        config.display.showMinimap = true
        containerView.configuration = config
        containerView.layoutSubviews()
        
        // Minimap should be visible
        XCTAssertFalse(containerView.minimapView.isHidden)
        
        // Minimap should be on the right
        let expectedX = containerView.bounds.width - 120 // Minimap width
        XCTAssertEqual(containerView.minimapView.frame.origin.x, expectedX, accuracy: 1.0)
    }
    
    func testLayoutWithKeyboard() {
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
    }
    
    // MARK: - ContentView Tests
    
    func testContentViewGestureRecognizers() {
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
    }
    
    func testContentViewInputAccessory() {
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
    }
    
    // MARK: - Minimap Tests
    
    func testMinimapNavigation() {
        var config = containerView.configuration
        config.display.showMinimap = true
        containerView.configuration = config
        
        // Add some text
        containerView.textView.text = Array(repeating: "Line\n", count: 100).joined()
        containerView.layoutSubviews()
        
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
    
    func testLayoutPerformance() {
        // Add substantial content
        containerView.textView.text = Array(repeating: "This is a test line\n", count: 1_000).joined()
        
        measure {
            for _ in 0..<100 {
                containerView.setNeedsLayout()
                containerView.layoutIfNeeded()
            }
        }
    }
    
    func testConfigurationChangePerformance() {
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
    
    func testSmallFrameLayout() {
        containerView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        containerView.layoutSubviews()
        
        // Ensure no negative dimensions
        XCTAssertGreaterThan(containerView.textView.frame.width, 0)
        XCTAssertGreaterThan(containerView.textView.frame.height, 0)
    }
    
    func testLargeContentScroll() {
        // Add very large content
        let largeText = Array(repeating: "Line\n", count: 10_000).joined()
        containerView.textView.text = largeText
        
        // Ensure scrolling is enabled
        XCTAssertTrue(containerView.textView.isScrollEnabled)
        XCTAssertTrue(containerView.textView.alwaysBounceVertical)
        
        // Content size should be larger than frame
        XCTAssertGreaterThan(containerView.textView.contentSize.height, containerView.textView.frame.height)
    }
    
    deinit {
        // Cleanup
    }
}
#endif
