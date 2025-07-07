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
    // MARK: - Initialization Tests
    
    @MainActor
    func testSingletonInstance() {
        let instance1 = CrossPlatformCoordinator.shared
        let instance2 = CrossPlatformCoordinator.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    @MainActor
    func testDependencyInjection() {
        // Create custom dependencies
        let customCapabilities = PlatformCapabilities.shared
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
        XCTAssertTrue(coordinator.inputCoordinator === customInputCoordinator)
        XCTAssertTrue(coordinator.toolbarCoordinator === customToolbarCoordinator)
        XCTAssertTrue(coordinator.contextMenuCoordinator === customContextMenuCoordinator)
        
        // Verify coordinator works correctly
        XCTAssertNotNil(coordinator.platformAdjustments)
        XCTAssertTrue(coordinator.isFeatureAvailable(.syntaxHighlighting))
    }
    
    @MainActor
    func testPlatformAdjustments() {
        let coordinator = CrossPlatformCoordinator.shared
        let adjustments = coordinator.platformAdjustments
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertEqual(adjustments.defaultFontSize, 12.0)
        XCTAssertEqual(adjustments.lineSpacing, 1.2)
        XCTAssertEqual(adjustments.gutterWidth, 40.0)
        XCTAssertEqual(adjustments.minimumTouchTargetSize, 24.0)
        XCTAssertEqual(adjustments.maxFileSize, 10_000_000)
        XCTAssertEqual(adjustments.maxHighlightingLength, 1_000_000)
        XCTAssertTrue(adjustments.showMinimap)
        XCTAssertTrue(adjustments.enableMultiCursor)
        #else
        XCTAssertEqual(adjustments.defaultFontSize, 14.0)
        XCTAssertEqual(adjustments.lineSpacing, 1.4)
        XCTAssertEqual(adjustments.gutterWidth, 50.0)
        XCTAssertEqual(adjustments.minimumTouchTargetSize, 44.0)
        XCTAssertEqual(adjustments.maxFileSize, 5_000_000)
        XCTAssertEqual(adjustments.maxHighlightingLength, 500_000)
        XCTAssertFalse(adjustments.showMinimap)
        XCTAssertFalse(adjustments.enableMultiCursor)
        #endif
    }
    
    // MARK: - Feature Availability Tests
    
    @MainActor
    func testFeatureAvailability() {
        let coordinator = CrossPlatformCoordinator.shared
        
        // Test common features
        XCTAssertTrue(coordinator.isFeatureAvailable(.syntaxHighlighting))
        XCTAssertTrue(coordinator.isFeatureAvailable(.lineNumbers))
        
        // Test platform-specific features
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertTrue(coordinator.isFeatureAvailable(.multipleCursors))
        XCTAssertFalse(coordinator.isFeatureAvailable(.minimap))
        #else
        XCTAssertFalse(coordinator.isFeatureAvailable(.multipleCursors))
        XCTAssertTrue(coordinator.isFeatureAvailable(.minimap))
        #endif
    }
    
    @MainActor
    func testFeatureAvailabilityLevel() {
        let coordinator = CrossPlatformCoordinator.shared
        let goToDefAvailability = coordinator.getFeatureAvailability(.goToDefinition)
        let symbolNavAvailability = coordinator.getFeatureAvailability(.symbolNavigation)
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertEqual(goToDefAvailability, .full)
        XCTAssertEqual(symbolNavAvailability, .full)
        #elseif targetEnvironment(macCatalyst)
        XCTAssertEqual(goToDefAvailability, .partial)
        XCTAssertEqual(symbolNavAvailability, .partial)
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
        let coordinator = CrossPlatformCoordinator.shared
        let config = coordinator.recommendedConfiguration()
        
        XCTAssertNotNil(config)
        XCTAssertTrue(config.display.showLineNumbers)
        XCTAssertTrue(config.performance.useHardwareAcceleration)
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Platform-specific values are set by PlatformCapabilities
        #else
        // Platform-specific values are set by PlatformCapabilities
        #endif
    }
    
    // MARK: - Toolbar Items Tests
    
    @MainActor
    func testCreateToolbarItems() {
        let coordinator = CrossPlatformCoordinator.shared
        let items = coordinator.createToolbarItems()
        
        XCTAssertFalse(items.isEmpty)
        
        // All platforms should have find
        XCTAssertTrue(items.contains { $0.id == "find" })
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
        let coordinator = CrossPlatformCoordinator.shared
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
        let coordinator = CrossPlatformCoordinator.shared
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        
        let handled = coordinator.handlePlatformInput(
            .keyDown(key: "d", modifiers: .command),
            in: textView
        )
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertTrue(handled)
        #elseif targetEnvironment(macCatalyst)
        // Mac Catalyst always handles keyboard input
        XCTAssertTrue(handled)
        #else
        // iOS only handles keyboard input with external keyboard
        XCTAssertEqual(handled, coordinator.isExternalKeyboardConnected())
        #endif
    }
    
    @MainActor
    func testHandleMouseInput() {
        let coordinator = CrossPlatformCoordinator.shared
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        
        let handled = coordinator.handlePlatformInput(
            .mouse(location: CGPoint(x: 100, y: 100), type: .rightClick),
            in: textView
        )
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertTrue(handled)
        #elseif targetEnvironment(macCatalyst)
        // Mac Catalyst always handles mouse input
        XCTAssertTrue(handled)
        #else
        // iOS only handles mouse with pointing device
        XCTAssertEqual(handled, coordinator.isPointingDeviceConnected())
        #endif
    }
    
    // MARK: - Context Menu Tests
    
    @MainActor
    func testCreateContextMenu() {
        let coordinator = CrossPlatformCoordinator.shared
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let range = NSRange(location: 0, length: 10)
        let menu = coordinator.createContextMenu(for: range, in: textView)
        
        XCTAssertNotNil(menu)
        
        // All platforms should have basic editing actions
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS returns NSMenu
        let nsMenu = menu
        XCTAssertGreaterThan(nsMenu.items.count, 3)
        #else
        // iOS returns UIMenu (PlatformContextMenu is typealias for UIMenu)
        XCTAssertGreaterThanOrEqual(menu.children.count, 3)
        #endif
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testFeatureCheckPerformance() {
        let coordinator = CrossPlatformCoordinator.shared
        
        measure {
            for _ in 0..<1_000 {
                _ = coordinator.isFeatureAvailable(.syntaxHighlighting)
            }
        }
    }
    
    @MainActor
    func testToolbarCreationPerformance() {
        let coordinator = CrossPlatformCoordinator.shared
        
        measure {
            for _ in 0..<100 {
                _ = coordinator.createToolbarItems()
            }
        }
    }
}
