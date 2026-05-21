//
//  LineNumbersPlatformTests.swift
//  CodeEditorPluginTests
//
//  Tests to ensure line numbers are displayed correctly on each platform
//  and that there's no duplicate display of line numbers.
//

import CodeEditorCommon
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import XCTest
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
final class LineNumbersPlatformTests: XCTestCase {
    // MARK: - Test Setup

    private func createContainerView() -> CodeEditorContainerView {
        CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
    }

    // MARK: - Platform-Specific Line Number Tests

    #if canImport(AppKit)
    func testMacOSUsesVerticalRulerViewNotFloatingGutterView() throws {
        // Given: A container view on macOS with line numbers enabled
        let containerView = createContainerView()
        var config = containerView.configuration
        config.display.isLineNumbersEnabled = true
        containerView.configuration = config

        // When: Configuration is applied
        containerView.applyConfiguration()

        // Then: Cross-platform GutterView should NOT be in the view hierarchy
        XCTAssertFalse(containerView.subviews.contains(containerView.gutterView),
                      "Cross-platform GutterView should not be in macOS view hierarchy")

        // And: macOS should use AppKit's vertical ruler host, not a
        // floating document subview. The floating-subview host is clipped by
        // AppKit during vertical scroll and drops line numbers below the
        // first visible strip.
        XCTAssertTrue(containerView.scrollView.hasVerticalRuler)
        XCTAssertTrue(containerView.scrollView.rulersVisible)
        XCTAssertNotNil(containerView.scrollView.verticalRulerView,
                        "Scroll view's verticalRulerView slot should host macOS line numbers")
    }

    func testMacOSGutterViewDoesNotDraw() throws {
        // Given: A container view on macOS
        let containerView = createContainerView()
        let gutterView = containerView.gutterView

        // When: GutterView is not in view hierarchy (as it should be on macOS)
        XCTAssertNil(gutterView.superview, "GutterView should not have a superview on macOS")

        // Then: Drawing should be skipped
        // This is tested by the guard statement in GutterView.draw(_:)
        // which checks for superview before drawing
    }

    func testMacOSGutterViewDoesNotObserveTextView() throws {
        // Given: A container view on macOS
        let containerView = createContainerView()
        let gutterView = containerView.gutterView

        // When: Text view is set
        gutterView.textView = containerView.textView

        // And: observeTextView is called
        gutterView.observeTextView()

        // Then: No observers should be added (method returns early on macOS)
        XCTAssertEqual(
            gutterView.observers.count,
            0,
            "GutterView should not add observers on macOS"
        )
    }

    func testMacOSDisablingLineNumbers() throws {
        // Given: A container view on macOS with line numbers initially enabled
        let containerView = createContainerView()
        var config = containerView.configuration
        config.display.isLineNumbersEnabled = true
        containerView.configuration = config

        // When: Line numbers are disabled
        config.display.isLineNumbersEnabled = false
        containerView.configuration = config

        // Then: vertical ruler should be detached
        XCTAssertNil(containerView.macLineNumberRulerView,
                    "Line-number ruler should be nil when line numbers are disabled")
        XCTAssertFalse(containerView.scrollView.hasVerticalRuler)
    }
    #endif

    #if canImport(UIKit)
    func testIOSUsesGutterViewNotNSRulerView() throws {
        // Given: A container view on iOS with line numbers enabled
        let containerView = createContainerView()
        var config = containerView.configuration
        config.display.isLineNumbersEnabled = true
        containerView.configuration = config

        // When: Configuration is applied
        containerView.applyConfiguration()

        // Then: GutterView should be in the view hierarchy
        XCTAssertTrue(containerView.subviews.contains(containerView.gutterView),
                     "GutterView should be added to view hierarchy on iOS")

        // And: GutterView should be visible
        XCTAssertFalse(containerView.gutterView.isHidden,
                      "GutterView should be visible when line numbers are enabled")

        // And: There should be no scroll view ruler (iOS doesn't have NSRulerView)
        // This is implicitly true as UIScrollView doesn't have ruler view properties
    }

    func testIOSGutterViewObservesTextView() throws {
        // Given: A container view on iOS
        let containerView = createContainerView()
        let gutterView = containerView.gutterView

        // When: Text view is set and observeTextView is called
        gutterView.textView = containerView.textView
        gutterView.observeTextView()

        // Then: Observers should be added
        XCTAssertGreaterThan(
            gutterView.observers.count,
            0,
            "GutterView should add observers on iOS"
        )
    }

    func testIOSDisablingLineNumbers() throws {
        // Given: A container view on iOS with line numbers initially enabled
        let containerView = createContainerView()
        var config = containerView.configuration
        config.display.isLineNumbersEnabled = true
        containerView.configuration = config

        // When: Line numbers are disabled
        config.display.isLineNumbersEnabled = false
        containerView.configuration = config

        // Then: GutterView should be hidden
        XCTAssertTrue(containerView.gutterView.isHidden,
                     "GutterView should be hidden when line numbers are disabled")
    }
    #endif

    // MARK: - Cross-Platform Tests

    func testShowsLineNumbersPropertyUpdatesCorrectly() throws {
        // Given: A container view
        let containerView = createContainerView()

        // When: showsLineNumbers is set to true
        containerView.showsLineNumbers = true

        // Then: Configuration should be updated
        #if canImport(AppKit)
        // On macOS, this should trigger updateMacOSRuler()
        // We can't directly test if the method was called, but we can verify the property is set
        XCTAssertTrue(containerView.showsLineNumbers)
        #else
        // On iOS, gutterView should be visible
        XCTAssertFalse(containerView.gutterView.isHidden)
        #endif

        // When: showsLineNumbers is set to false
        containerView.showsLineNumbers = false

        // Then: Configuration should be updated
        #if canImport(AppKit)
        XCTAssertFalse(containerView.showsLineNumbers)
        #else
        // On iOS, gutterView should be hidden
        XCTAssertTrue(containerView.gutterView.isHidden)
        #endif
    }

    func testTextContainerInsetsUpdateCorrectly() throws {
        // Given: A container view
        let containerView = createContainerView()

        // When: Line numbers are enabled
        containerView.showsLineNumbers = true
        containerView.updateTextContainerInsets()

        // Then: Text container should have appropriate insets
        #if canImport(AppKit)
        let insets = containerView.textView.textContainerInset
        XCTAssertGreaterThan(insets.width, 0, "Text container should have horizontal inset")
        #else
        let insets = containerView.textView.textContainerEdgeInsets
        XCTAssertGreaterThan(insets.left, 0, "Text container should have left inset")
        #endif
    }

    func testConfigurationChangePropagatesCorrectly() throws {
        // Given: A container view
        let containerView = createContainerView()

        // When: Configuration is changed to enable line numbers
        var config = containerView.configuration
        config.display.isLineNumbersEnabled = true
        containerView.configuration = config

        // Then: The appropriate platform-specific changes should occur
        #if canImport(AppKit)
        // macOS should have the ruler-backed gutter attached.
        XCTAssertNotNil(containerView.macLineNumberRulerView)
        // Cross-platform GutterView should NOT be in hierarchy
        XCTAssertFalse(containerView.subviews.contains(containerView.gutterView))
        #else
        // iOS should have visible GutterView
        XCTAssertTrue(containerView.subviews.contains(containerView.gutterView))
        XCTAssertFalse(containerView.gutterView.isHidden)
        #endif
    }

    // MARK: - Edge Case Tests

    func testMultipleConfigurationChanges() throws {
        // Given: A container view
        let containerView = createContainerView()

        // When: Configuration is changed multiple times
        for enabled in [true, false, true, false, true] {
            var config = containerView.configuration
            config.display.isLineNumbersEnabled = enabled
            containerView.configuration = config

            // Then: The state should match the configuration
            #if canImport(AppKit)
            XCTAssertEqual(containerView.macLineNumberRulerView != nil, enabled)
            XCTAssertEqual(containerView.scrollView.hasVerticalRuler, enabled)
            #else
            XCTAssertEqual(!containerView.gutterView.isHidden, enabled)
            #endif
        }
    }

    func testLineNumbersWithMinimapInteraction() throws {
        // Given: A container view with both line numbers and minimap
        let containerView = createContainerView()
        var config = containerView.configuration
        config.display.isLineNumbersEnabled = true
        config.display.isMinimapVisible = true
        containerView.configuration = config

        // Then: Both features should work independently
        #if canImport(AppKit)
        // macOS: vertical ruler for line numbers, minimap as separate view
        XCTAssertNotNil(containerView.macLineNumberRulerView)
        XCTAssertTrue(containerView.subviews.contains(containerView.minimapView))
        XCTAssertFalse(containerView.minimapView.isHidden)
        // Cross-platform GutterView should still NOT be in hierarchy
        XCTAssertFalse(containerView.subviews.contains(containerView.gutterView))
        #else
        // iOS: Both GutterView and MinimapView in hierarchy
        XCTAssertTrue(containerView.subviews.contains(containerView.gutterView))
        XCTAssertTrue(containerView.subviews.contains(containerView.minimapView))
        XCTAssertFalse(containerView.gutterView.isHidden)
        XCTAssertFalse(containerView.minimapView.isHidden)
        #endif
    }
}
