//
//  CrossPlatformCoordinatorTests.swift
//  CodeEditorPluginTests
//
//  Tests for CrossPlatformCoordinator functionality
//

@testable import CodeEditorPlugin
import XCTest
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class CrossPlatformCoordinatorTests: XCTestCase {
    // MARK: - Properties

    // Tests create their own coordinator instances as needed

    // MARK: - Initialization Tests

    @MainActor
    func testDefaultInitialization() {
        // Test default initialization creates proper instances
        let coordinator = CrossPlatformCoordinator()

        // Verify all components are initialized
        XCTAssertNotNil(coordinator.capabilities)
        XCTAssertNotNil(coordinator.inputCoordinator)
        XCTAssertNotNil(coordinator.toolbarCoordinator)
        XCTAssertNotNil(coordinator.contextMenuCoordinator)

        // Verify coordinator works correctly
        XCTAssertNotNil(coordinator.platformAdjustments)
        XCTAssertTrue(coordinator.isFeatureAvailable(.syntaxHighlighting))
    }

    @MainActor
    func testDependencyInjection() {
        // Create custom dependencies
        let customCapabilities = CodeEditorDependencies.makePlatformCapabilities()
        let customInputCoordinator = InputCoordinator(capabilities: customCapabilities)
        let customToolbarCoordinator = ToolbarCoordinator(capabilities: customCapabilities)
        let customContextMenuCoordinator = ContextMenuCoordinator(capabilities: customCapabilities)

        // Create coordinator with dependency injection
        let coordinator = CrossPlatformCoordinator(
            capabilities: customCapabilities,
            inputCoordinator: customInputCoordinator,
            toolbarCoordinator: customToolbarCoordinator,
            contextMenuCoordinator: customContextMenuCoordinator
        )

        // Verify dependencies are used
        XCTAssertIdentical(coordinator.inputCoordinator, customInputCoordinator)
        XCTAssertIdentical(coordinator.toolbarCoordinator, customToolbarCoordinator)
        XCTAssertIdentical(coordinator.contextMenuCoordinator, customContextMenuCoordinator)

        // Verify coordinator works correctly
        XCTAssertNotNil(coordinator.platformAdjustments)
        XCTAssertTrue(coordinator.isFeatureAvailable(.syntaxHighlighting))
    }

    @MainActor
    func testPlatformAdjustments() {
        let coordinator = CrossPlatformCoordinator()
        let adjustments = coordinator.platformAdjustments

        #if canImport(AppKit)
        XCTAssertEqual(adjustments.defaultFontSize, 12.0)
        XCTAssertEqual(adjustments.lineSpacing, 1.2)
        XCTAssertEqual(adjustments.gutterWidth, 40.0)
        XCTAssertEqual(adjustments.minimumTouchTargetSize, 24.0)
        XCTAssertEqual(adjustments.maxFileSize, 10_000_000)
        XCTAssertEqual(adjustments.maxSyntaxHighlightingLength, 1_000_000)
        XCTAssertTrue(adjustments.isMinimapVisible)
        XCTAssertTrue(adjustments.enableMultiCursor)
        #else
        // iOS - values may be adjusted for iPad
        #if canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad gets optimized adjustments
            XCTAssertEqual(adjustments.defaultFontSize, 14.0)
            XCTAssertEqual(adjustments.lineSpacing, 1.4)
            XCTAssertEqual(adjustments.gutterWidth, 50.0)
            XCTAssertEqual(adjustments.minimumTouchTargetSize, 44.0)
            XCTAssertEqual(adjustments.maxFileSize, 8_000_000) // iPad: 8MB
            XCTAssertEqual(adjustments.maxSyntaxHighlightingLength, 750_000) // iPad: 750K
            // Minimap depends on screen width
            if UIScreen.main.bounds.width > 1_000 {
                XCTAssertTrue(adjustments.isMinimapVisible)
            } else {
                XCTAssertFalse(adjustments.isMinimapVisible)
            }
            XCTAssertFalse(adjustments.enableMultiCursor)
        } else {
            // iPhone or default iOS
            XCTAssertEqual(adjustments.defaultFontSize, 14.0)
            XCTAssertEqual(adjustments.lineSpacing, 1.4)
            XCTAssertEqual(adjustments.gutterWidth, 50.0)
            XCTAssertEqual(adjustments.minimumTouchTargetSize, 44.0)
            XCTAssertEqual(adjustments.maxFileSize, 5_000_000)
            XCTAssertEqual(adjustments.maxSyntaxHighlightingLength, 500_000)
            XCTAssertFalse(adjustments.isMinimapVisible)
            XCTAssertFalse(adjustments.enableMultiCursor)
        }
        #else
        // iOS uses default iOS values
        XCTAssertEqual(adjustments.defaultFontSize, 14.0)
        XCTAssertEqual(adjustments.lineSpacing, 1.4)
        XCTAssertEqual(adjustments.gutterWidth, 50.0)
        XCTAssertEqual(adjustments.minimumTouchTargetSize, 44.0)
        XCTAssertEqual(adjustments.maxFileSize, 5_000_000)
        XCTAssertEqual(adjustments.maxSyntaxHighlightingLength, 500_000)
        XCTAssertFalse(adjustments.isMinimapVisible)
        XCTAssertFalse(adjustments.enableMultiCursor)
        #endif
        #endif
    }

    // MARK: - Feature Availability Tests

    @MainActor
    func testFeatureAvailability() {
        // Use instance property instead of deprecated singleton
        let coordinator = CrossPlatformCoordinator()

        // Test common features
        XCTAssertTrue(coordinator.isFeatureAvailable(.syntaxHighlighting))
        XCTAssertTrue(coordinator.isFeatureAvailable(.lineNumbers))

        // Test platform-specific features
        #if canImport(AppKit)
        XCTAssertTrue(coordinator.isFeatureAvailable(.multipleCursors))
        XCTAssertFalse(coordinator.isFeatureAvailable(.minimap))
        #else
        XCTAssertFalse(coordinator.isFeatureAvailable(.multipleCursors))
        XCTAssertTrue(coordinator.isFeatureAvailable(.minimap))
        #endif
    }

    @MainActor
    func testFeatureAvailabilityLevel() {
        // Use instance property instead of deprecated singleton
        let coordinator = CrossPlatformCoordinator()
        let goToDefAvailability = coordinator.getFeatureAvailability(.goToDefinition)
        let symbolNavAvailability = coordinator.getFeatureAvailability(.symbolNavigation)

        #if canImport(AppKit)
        XCTAssertEqual(goToDefAvailability, .full)
        XCTAssertEqual(symbolNavAvailability, .full)
        #elseif canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertEqual(goToDefAvailability, .partial)
            XCTAssertEqual(symbolNavAvailability, .partial)
        } else {
            XCTAssertEqual(goToDefAvailability, .unavailable)
            XCTAssertEqual(symbolNavAvailability, .partial)
        }
        #endif
    }

    // MARK: - Configuration Tests

    @MainActor
    func testRecommendedConfiguration() {
        // Use instance property instead of deprecated singleton
        let coordinator = CrossPlatformCoordinator()
        let config = coordinator.recommendedConfiguration()

        XCTAssertNotNil(config)
        XCTAssertTrue(config.display.isLineNumbersEnabled)
        XCTAssertTrue(config.performance.useHardwareAcceleration)

        #if canImport(AppKit)
        // Platform-specific values are set by PlatformCapabilities
        #else
        // Platform-specific values are set by PlatformCapabilities
        #endif
    }

    // MARK: - Toolbar Items Tests

    @MainActor
    func testCreateToolbarItems() {
        // Use instance property instead of deprecated singleton
        let coordinator = CrossPlatformCoordinator()
        let items = coordinator.createToolbarItems()

        XCTAssertFalse(items.isEmpty)

        // All platforms should have find
        XCTAssertTrue(items.contains { $0.id == "find" })

        #if canImport(AppKit)
        // macOS should have full toolbar
        XCTAssertTrue(items.contains { $0.id == "replace" })
        XCTAssertTrue(items.contains { $0.id == "symbol" })
        XCTAssertTrue(items.contains { $0.id == "format" })
        #elseif canImport(UIKit)
        // iOS should have limited toolbar
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertTrue(items.contains { $0.id == "symbol" })
            // iPad also gets format option
            XCTAssertTrue(items.contains { $0.id == "format" })
        } else {
            // iPhone doesn't get format
            XCTAssertFalse(items.contains { $0.id == "format" })
        }
        #endif
    }

    // MARK: - Text View Optimization Tests

    @MainActor
    func testOptimizeTextView() {
        // Use instance property instead of deprecated singleton
        let coordinator = CrossPlatformCoordinator()
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        coordinator.optimizeTextView(textView)

        #if canImport(UIKit)
        XCTAssertTrue(textView.isSelectable)
        XCTAssertTrue(textView.isEditable)
        XCTAssertEqual(textView.autocorrectionType, .no)
        XCTAssertEqual(textView.autocapitalizationType, .none)
        XCTAssertEqual(textView.smartDashesType, .no)
        XCTAssertEqual(textView.smartQuotesType, .no)
        #endif
    }

    // MARK: - Platform Input Tests

    @MainActor
    func testHandleKeyInput() {
        // Use instance property instead of deprecated singleton
        let coordinator = CrossPlatformCoordinator()
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        let handled = coordinator.handlePlatformInput(
            .keyDown(key: "d", modifiers: .command),
            in: textView
        )

        #if canImport(AppKit)
        XCTAssertTrue(handled)
        #else
        // iOS only handles keyboard input with external keyboard
        XCTAssertEqual(handled, coordinator.isExternalKeyboardConnected())
        #endif
    }

    @MainActor
    func testHandleMouseInput() {
        // Use instance property instead of deprecated singleton
        let coordinator = CrossPlatformCoordinator()
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        let handled = coordinator.handlePlatformInput(
            .mouse(location: CGPoint(x: 100, y: 100), type: .rightClick),
            in: textView
        )

        #if canImport(AppKit)
        XCTAssertTrue(handled)
        #else
        // iOS handles mouse input differently for right click
        // InputCoordinator may still return false for right click on iOS
        // even if a pointing device is connected (it only handles down and hover)
        XCTAssertFalse(handled) // Right click not handled on iOS
        #endif
    }

    // MARK: - Context Menu Tests

    @MainActor
    func testCreateContextMenu() {
        // Use instance property instead of deprecated singleton
        let coordinator = CrossPlatformCoordinator()
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        // Add some text content so selection actions are available
        textView.text = "Hello, World! This is a test."

        // Set a valid selection range within the text
        let range = NSRange(location: 0, length: 5) // Select "Hello"
        textView.selectedRange = range

        let menu = coordinator.createContextMenu(for: range, in: textView)

        XCTAssertNotNil(menu)

        // All platforms should have basic editing actions
        #if canImport(AppKit)
        // macOS returns NSMenu
        let nsMenu = menu
        XCTAssertGreaterThan(nsMenu.items.count, 3)
        #else
        // iOS returns UIMenu (PlatformContextMenu is typealias for UIMenu)
        // iOS should have at least: Cut, Copy, (separator), Select All = 4 items
        // But separators might not count as children in UIMenu
        XCTAssertGreaterThanOrEqual(menu.children.count, 3)
        #endif
    }

    // MARK: - Performance Tests

    @MainActor
    func testFeatureCheckPerformance() {
        // Use instance property instead of deprecated singleton
        let coordinator = CrossPlatformCoordinator()

        measure(options: Self.standardMeasureOptions) {
            for _ in 0..<1_000 {
                _ = coordinator.isFeatureAvailable(.syntaxHighlighting)
            }
        }
    }

    @MainActor
    func testToolbarCreationPerformance() {
        // Use instance property instead of deprecated singleton
        let coordinator = CrossPlatformCoordinator()

        measure(options: Self.standardMeasureOptions) {
            for _ in 0..<100 {
                _ = coordinator.createToolbarItems()
            }
        }
    }
}
