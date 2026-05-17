import CodeEditorConfiguration
import CodeEditorDiagnostics
import CodeEditorPlatform
@testable import CodeEditorPlugin
import XCTest
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class PlatformAbstractionTests: XCTestCase {
    deinit {
        // Cleanup
    }
    // MARK: - Platform Detection Tests

    func testPlatformDetection() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()

        #if canImport(AppKit)
        XCTAssertEqual(capabilities.currentPlatform, .macOS)
        #else
        XCTAssertEqual(capabilities.currentPlatform, .iOS)
        #endif
    }

    func testSystemVersionDetection() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()

        XCTAssertFalse(capabilities.systemVersion.isEmpty)

        let components = capabilities.systemVersionComponents
        XCTAssertGreaterThan(components.major, 0)
        XCTAssertGreaterThanOrEqual(components.minor, 0)
        XCTAssertGreaterThanOrEqual(components.patch, 0)
    }

    // MARK: - Type Alias Tests

    func testPlatformTypeAliases() {
        #if canImport(AppKit)
        XCTAssertTrue(PlatformColor.self == NSColor.self)
        XCTAssertTrue(PlatformFont.self == NSFont.self)
        XCTAssertTrue(PlatformView.self == NSView.self)
        #elseif canImport(UIKit)
        XCTAssertTrue(PlatformColor.self == UIColor.self)
        XCTAssertTrue(PlatformFont.self == UIFont.self)
        XCTAssertTrue(PlatformView.self == UIView.self)
        #endif
    }

    // MARK: - Color System Tests

    func testSemanticColors() {
        // Test that all semantic colors are non-nil
        XCTAssertNotNil(PlatformColors.label)
        XCTAssertNotNil(PlatformColors.secondaryLabel)
        XCTAssertNotNil(PlatformColors.tertiaryLabel)
        XCTAssertNotNil(PlatformColors.systemBackground)
        XCTAssertNotNil(PlatformColors.secondarySystemBackground)
        XCTAssertNotNil(PlatformColors.controlBackground)
        XCTAssertNotNil(PlatformColors.separator)
        XCTAssertNotNil(PlatformColors.disabledControlText)
        XCTAssertNotNil(PlatformColors.black)
        XCTAssertNotNil(PlatformColors.clear)
        XCTAssertNotNil(PlatformColors.controlAccentColor)
        XCTAssertNotNil(PlatformColors.textBackgroundColor)
    }

    func testHexColorInitialization() {
        // Test 3-digit hex
        let color3 = PlatformColor(hexString: "#F00")
        XCTAssertNotNil(color3)

        // Test 4-digit hex
        let color4 = PlatformColor(hexString: "#F00F")
        XCTAssertNotNil(color4)

        // Test 6-digit hex
        let color6 = PlatformColor(hexString: "#FF0000")
        XCTAssertNotNil(color6)

        // Test 8-digit hex
        let color8 = PlatformColor(hexString: "#FF0000FF")
        XCTAssertNotNil(color8)

        // Test without hash
        let colorNoHash = PlatformColor(hexString: "FF0000")
        XCTAssertNotNil(colorNoHash)

        // Test invalid hex
        let colorInvalid = PlatformColor(hexString: "GGGGGG")
        XCTAssertNil(colorInvalid)
    }

    // MARK: - Font System Tests

    func testFontCreation() {
        let monoFont = PlatformFonts.monospacedSystemFont(ofSize: 14.0)
        XCTAssertNotNil(monoFont)

        let systemFont = PlatformFonts.systemFont(ofSize: 16.0)
        XCTAssertNotNil(systemFont)

        let fontSize = PlatformFonts.systemFontSize
        XCTAssertGreaterThan(fontSize, 0)
    }

    // MARK: - Capability Detection Tests

    func testTextKitCapabilities() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()

        #if canImport(AppKit)
        // macOS 13+ should support TextKit2
        if capabilities.systemVersionComponents.major >= 13 {
            XCTAssertTrue(capabilities.supportsRequiredTextKit2Surface)
        }
        #elseif canImport(UIKit)
        // iOS 16+ should support TextKit2
        if capabilities.systemVersionComponents.major >= 16 {
            XCTAssertTrue(capabilities.supportsRequiredTextKit2Surface)
        }
        #endif

        XCTAssertTrue(capabilities.supportsRequiredTextKit2Surface)
    }

    func testPlatformSpecificCapabilities() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()

        switch capabilities.currentPlatform {
        case .macOS:
            XCTAssertTrue(capabilities.supportsTouchBar)
            XCTAssertTrue(capabilities.supportsKeyboardShortcuts)
            XCTAssertFalse(capabilities.supportsPencilInput)

        case .iOS:
            XCTAssertFalse(capabilities.supportsTouchBar)
            XCTAssertTrue(capabilities.supportsGestureRecognizers)
            #if canImport(UIKit) && !targetEnvironment(simulator)
            // Only test on real devices
            if UIDevice.current.userInterfaceIdiom == .pad {
                XCTAssertTrue(capabilities.supportsPencilInput)
            }
            #endif
        }
    }

    // MARK: - Configuration Tests

    func testRecommendedConfiguration() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        let config = capabilities.recommendedConfiguration()

        XCTAssertNotNil(config)

        switch capabilities.currentPlatform {
        case .iOS:
            // iOS config varies by device
            #if canImport(UIKit)
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad-specific config
                XCTAssertEqual(config.display.fontSize, 16.0)
                XCTAssertEqual(config.layout.gutterWidth, 45.0)
            } else {
                // iPhone config
                XCTAssertEqual(config.display.fontSize, 16.0)
                XCTAssertEqual(config.layout.gutterWidth, 50.0)
            }
            #else
            XCTAssertEqual(config.display.fontSize, 16.0)
            XCTAssertEqual(config.layout.gutterWidth, 50.0)
            #endif

        case .macOS:
            // Default config should be unchanged
            XCTAssertEqual(config.display.fontSize, EditorConfiguration.default.display.fontSize)
        }
    }

    // MARK: - Cross-Platform Coordinator Tests

    func testCrossPlatformCoordinator() {
        let coordinator = CrossPlatformCoordinator()

        XCTAssertNotNil(coordinator.platformAdjustments)

        // Test feature availability using the new API
        XCTAssertTrue(coordinator.isFeatureAvailable(.syntaxHighlighting))
        XCTAssertTrue(coordinator.isFeatureAvailable(.codeCompletion))

        // Test platform adjustments
        #if canImport(AppKit)
        XCTAssertEqual(coordinator.platformAdjustments.defaultFontSize, 12.0)
        #else
        XCTAssertEqual(coordinator.platformAdjustments.defaultFontSize, 14.0)
        #endif
    }

    func testToolbarItemCreation() {
        let coordinator = CrossPlatformCoordinator()
        let toolbarItems = coordinator.createToolbarItems()

        XCTAssertFalse(toolbarItems.isEmpty)

        #if canImport(AppKit)
        // macOS should have more toolbar items
        XCTAssertGreaterThanOrEqual(toolbarItems.count, 4)
        #elseif canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad has more toolbar items
            XCTAssertGreaterThanOrEqual(toolbarItems.count, 4)
        } else {
            // iPhone should have fewer toolbar items
            XCTAssertLessThanOrEqual(toolbarItems.count, 2)
        }
        #endif
    }

    // MARK: - Text Input Features Tests

    func testTextInputFeatures() {
        let features = TextInputFeaturesFactory.create()

        XCTAssertNotNil(features)
        XCTAssertTrue(features.supportsSpellChecking)

        #if canImport(AppKit)
        XCTAssertTrue(features.supportsGrammarChecking)
        XCTAssertTrue(features.supportsAutomaticTextCompletion)
        #else
        // iOS and iOS don't support these features
        XCTAssertFalse(features.supportsGrammarChecking)
        XCTAssertFalse(features.supportsAutomaticTextCompletion)
        #endif
    }

    // MARK: - MacOS Version Detection Tests

    func testMacOSVersionDetection() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        let version = capabilities.systemVersionComponents
        XCTAssertGreaterThan(version.major, 0)

        // Test platform detection
        #if canImport(AppKit)
        XCTAssertEqual(capabilities.currentPlatform, .macOS)
        // Test version-based capabilities
        XCTAssertEqual(capabilities.systemVersionComponents.major >= 14, version.major >= 14)
        XCTAssertEqual(capabilities.systemVersionComponents.major >= 13, version.major >= 13)
        XCTAssertEqual(capabilities.systemVersionComponents.major >= 12, version.major >= 12)
        #else
        XCTAssertEqual(capabilities.currentPlatform, .iOS)
        #endif
    }

    // MARK: - Memory and Performance Tests

    func testPerformanceRecommendations() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()

        XCTAssertGreaterThan(capabilities.recommendedCacheSize, 0)
        XCTAssertGreaterThan(capabilities.maxRecommendedFileSize, 0)

        // Cache size should be less than max file size
        XCTAssertLessThan(capabilities.recommendedCacheSize, capabilities.maxRecommendedFileSize * 10)
    }

    // MARK: - Feature Status Tests

    func testFeatureStatusLogic() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()

        // Test full feature availability
        let syntaxHighlighting = capabilities.getFeatureAvailability(.syntaxHighlighting)
        XCTAssertTrue(syntaxHighlighting.isAvailable)
        XCTAssertTrue(syntaxHighlighting.isFullyAvailable)

        // Test platform-specific features
        #if canImport(UIKit)
        let touchSupport = capabilities.getFeatureAvailability(.touchSupport)
        XCTAssertTrue(touchSupport.isAvailable)

        let floatingPanels = capabilities.getFeatureAvailability(.floatingPanels)
        XCTAssertFalse(floatingPanels.isAvailable)
        #else
        let minimap = capabilities.getFeatureAvailability(.minimap)
        // minimap is only available on iOS now
        XCTAssertFalse(minimap.isAvailable)
        #endif
    }
}

// MARK: - Performance Tests

extension PlatformAbstractionTests {
    func testCapabilityDetectionPerformance() {
        measure(options: Self.standardMeasureOptions) {
            let capabilities = CodeEditorDependencies.makePlatformCapabilities()
            _ = capabilities.currentPlatform
            _ = capabilities.supportsRequiredTextKit2Surface
            _ = capabilities.supportsHardwareAcceleration
            _ = capabilities.recommendedCacheSize
        }
    }

    func testConfigurationCreationPerformance() {
        measure(options: Self.standardMeasureOptions) {
            let capabilities = CodeEditorDependencies.makePlatformCapabilities()
            _ = capabilities.recommendedConfiguration()
        }
    }
}
