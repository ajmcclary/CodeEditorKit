//
//  LineNumbersPlatformTests.swift
//  CodeEditorPluginTests
//
//  Tests to ensure line numbers are displayed correctly on each platform
//  and that there's no duplicate display of line numbers.
//

@testable import CodeEditorPlugin
import XCTest
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
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

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    func testMacOSUsesNSRulerViewNotGutterView() throws {
        // Given: A container view on macOS with line numbers enabled
        let containerView = createContainerView()
        var config = containerView.configuration
        config.display.isLineNumbersEnabled = true
        containerView.configuration = config

        // When: Configuration is applied
        containerView.applyConfiguration()

        // Then: GutterView should NOT be in the view hierarchy
        XCTAssertFalse(containerView.subviews.contains(containerView.gutterView),
                      "GutterView should not be added to view hierarchy on macOS")

        // And: NSRulerView should be configured on the scroll view
        XCTAssertNotNil(containerView.scrollView.verticalRulerView,
                       "Scroll view should have a vertical ruler view")
        XCTAssertTrue(containerView.scrollView.hasVerticalRuler,
                     "Scroll view should have vertical ruler enabled")
        XCTAssertTrue(containerView.scrollView.rulersVisible,
                     "Scroll view rulers should be visible")

        // And: The ruler view should be the correct type
        XCTAssertTrue(containerView.scrollView.verticalRulerView is LineNumberRulerView,
                     "Vertical ruler should be LineNumberRulerView")
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

        // Then: NSRulerView should be hidden
        XCTAssertFalse(containerView.scrollView.hasVerticalRuler,
                      "Scroll view should not have vertical ruler when line numbers are disabled")
        XCTAssertFalse(containerView.scrollView.rulersVisible,
                      "Scroll view rulers should not be visible when line numbers are disabled")
        XCTAssertNil(containerView.scrollView.verticalRulerView,
                    "Vertical ruler view should be nil when line numbers are disabled")
    }
    #endif

    #if canImport(UIKit)
    func testIOSUsesGutterViewNotNSRulerView() throws {
        // Given: A container view on iOS/Catalyst with line numbers enabled
        let containerView = createContainerView()
        var config = containerView.configuration
        config.display.isLineNumbersEnabled = true
        containerView.configuration = config

        // When: Configuration is applied
        containerView.applyConfiguration()

        // Then: GutterView should be in the view hierarchy
        XCTAssertTrue(containerView.subviews.contains(containerView.gutterView),
                     "GutterView should be added to view hierarchy on iOS/Catalyst")

        // And: GutterView should be visible
        XCTAssertFalse(containerView.gutterView.isHidden,
                      "GutterView should be visible when line numbers are enabled")

        // And: There should be no scroll view ruler (iOS doesn't have NSRulerView)
        // This is implicitly true as UIScrollView doesn't have ruler view properties
    }

    func testIOSGutterViewObservesTextView() throws {
        // Given: A container view on iOS/Catalyst
        let containerView = createContainerView()
        let gutterView = containerView.gutterView

        // When: Text view is set and observeTextView is called
        gutterView.textView = containerView.textView
        gutterView.observeTextView()

        // Then: Observers should be added
        XCTAssertGreaterThan(
            gutterView.observers.count,
            0,
            "GutterView should add observers on iOS/Catalyst"
        )
    }

    func testIOSDisablingLineNumbers() throws {
        // Given: A container view on iOS/Catalyst with line numbers initially enabled
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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // On macOS, this should trigger updateMacOSRuler()
        // We can't directly test if the method was called, but we can verify the property is set
        XCTAssertTrue(containerView.showsLineNumbers)
        #else
        // On iOS/Catalyst, gutterView should be visible
        XCTAssertFalse(containerView.gutterView.isHidden)
        #endif

        // When: showsLineNumbers is set to false
        containerView.showsLineNumbers = false

        // Then: Configuration should be updated
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertFalse(containerView.showsLineNumbers)
        #else
        // On iOS/Catalyst, gutterView should be hidden
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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS should have ruler view
        XCTAssertTrue(containerView.scrollView.hasVerticalRuler)
        XCTAssertTrue(containerView.scrollView.rulersVisible)
        // GutterView should NOT be in hierarchy
        XCTAssertFalse(containerView.subviews.contains(containerView.gutterView))
        #else
        // iOS/Catalyst should have visible GutterView
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
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            XCTAssertEqual(containerView.scrollView.hasVerticalRuler, enabled)
            XCTAssertEqual(containerView.scrollView.rulersVisible, enabled)
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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS: Ruler view for line numbers, minimap as separate view
        XCTAssertTrue(containerView.scrollView.hasVerticalRuler)
        XCTAssertTrue(containerView.subviews.contains(containerView.minimapView))
        XCTAssertFalse(containerView.minimapView.isHidden)
        // GutterView should still NOT be in hierarchy
        XCTAssertFalse(containerView.subviews.contains(containerView.gutterView))
        #else
        // iOS/Catalyst: Both GutterView and MinimapView in hierarchy
        XCTAssertTrue(containerView.subviews.contains(containerView.gutterView))
        XCTAssertTrue(containerView.subviews.contains(containerView.minimapView))
        XCTAssertFalse(containerView.gutterView.isHidden)
        XCTAssertFalse(containerView.minimapView.isHidden)
        #endif
    }
}
