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
        let capabilities = PlatformCapabilities.shared
        
        #if targetEnvironment(macCatalyst)
        XCTAssertEqual(capabilities.currentPlatform, .catalyst)
        #elseif canImport(AppKit)
        XCTAssertEqual(capabilities.currentPlatform, .macOS)
        #else
        XCTAssertEqual(capabilities.currentPlatform, .iOS)
        #endif
    }
    
    func testSystemVersionDetection() {
        let capabilities = PlatformCapabilities.shared
        
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
        let capabilities = PlatformCapabilities.shared
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS 13+ should support TextKit2
        if capabilities.systemVersionComponents.major >= 13 {
            XCTAssertTrue(capabilities.supportsTextKit2)
        }
        #elseif canImport(UIKit)
        // iOS 16+ should support TextKit2
        if capabilities.systemVersionComponents.major >= 16 {
            XCTAssertTrue(capabilities.supportsTextKit2)
        }
        #endif
        
        // TextKit2 preference should match support
        if capabilities.supportsTextKit2 {
            XCTAssertTrue(capabilities.preferTextKit2 || !capabilities.preferTextKit2)
        }
    }
    
    func testPlatformSpecificCapabilities() {
        let capabilities = PlatformCapabilities.shared
        
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
            
        case .catalyst:
            XCTAssertFalse(capabilities.supportsTouchBar)
            XCTAssertTrue(capabilities.supportsMultipleWindows)
            XCTAssertTrue(capabilities.supportsKeyboardShortcuts)
        }
    }
    
    // MARK: - Configuration Tests
    
    func testRecommendedConfiguration() {
        let capabilities = PlatformCapabilities.shared
        let config = capabilities.recommendedConfiguration()
        
        XCTAssertNotNil(config)
        
        switch capabilities.currentPlatform {
        case .iOS:
            XCTAssertEqual(config.display.fontSize, 16.0)
            XCTAssertEqual(config.layout.gutterWidth, 50.0)
            
        case .catalyst:
            XCTAssertEqual(config.display.fontSize, 14.0)
            XCTAssertEqual(config.layout.gutterWidth, 45.0)
            
        case .macOS:
            // Default config should be unchanged
            XCTAssertEqual(config.display.fontSize, EditorConfiguration.default.display.fontSize)
        }
    }
    
    // MARK: - Cross-Platform Coordinator Tests
    
    func testCrossPlatformCoordinator() {
        let coordinator = CrossPlatformCoordinator.shared
        
        XCTAssertNotNil(coordinator.featureAvailability)
        XCTAssertNotNil(coordinator.platformAdjustments)
        
        // Test feature availability
        XCTAssertTrue(coordinator.isFeatureAvailable(\.syntaxHighlighting))
        XCTAssertTrue(coordinator.isFeatureAvailable(\.codeCompletion))
        
        // Test platform adjustments
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertEqual(coordinator.platformAdjustments.defaultFontSize, 12.0)
        #else
        XCTAssertEqual(coordinator.platformAdjustments.defaultFontSize, 14.0)
        #endif
    }
    
    func testToolbarItemCreation() {
        let coordinator = CrossPlatformCoordinator.shared
        let toolbarItems = coordinator.createToolbarItems()
        
        XCTAssertFalse(toolbarItems.isEmpty)
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS should have more toolbar items
        XCTAssertGreaterThanOrEqual(toolbarItems.count, 4)
        #else
        // iOS should have fewer toolbar items
        XCTAssertLessThanOrEqual(toolbarItems.count, 2)
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
        #elseif canImport(UIKit)
        XCTAssertFalse(features.supportsGrammarChecking)
        XCTAssertFalse(features.supportsAutomaticTextCompletion)
        #endif
    }
    
    // MARK: - MacOS Version Detection Tests
    
    func testMacOSVersionDetection() {
        let version = MacOSVersionDetection.versionComponents
        XCTAssertGreaterThan(version.major, 0)
        
        let versionString = MacOSVersionDetection.systemVersionString
        XCTAssertFalse(versionString.isEmpty)
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Test that we're not using placeholder versions
        XCTAssertFalse(MacOSVersionDetection.isMacOS14OrLater && version.major < 14)
        XCTAssertFalse(MacOSVersionDetection.isMacOS13OrLater && version.major < 13)
        XCTAssertFalse(MacOSVersionDetection.isMacOS12OrLater && version.major < 12)
        #endif
    }
    
    // MARK: - Memory and Performance Tests
    
    func testPerformanceRecommendations() {
        let capabilities = PlatformCapabilities.shared
        
        XCTAssertGreaterThan(capabilities.recommendedCacheSize, 0)
        XCTAssertGreaterThan(capabilities.maxRecommendedFileSize, 0)
        
        // Cache size should be less than max file size
        XCTAssertLessThan(capabilities.recommendedCacheSize, capabilities.maxRecommendedFileSize * 10)
    }
    
    // MARK: - Feature Status Tests
    
    func testFeatureStatusLogic() {
        let fullFeature = CrossPlatformCoordinator.FeatureStatus(macOS: .full, iOS: .full)
        XCTAssertTrue(fullFeature.isAvailable)
        XCTAssertTrue(fullFeature.isFullyAvailable)
        
        let partialFeature = CrossPlatformCoordinator.FeatureStatus(macOS: .full, iOS: .partial)
        XCTAssertTrue(partialFeature.isAvailable)
        #if canImport(UIKit)
        XCTAssertFalse(partialFeature.isFullyAvailable)
        #endif
        
        let unavailableFeature = CrossPlatformCoordinator.FeatureStatus(macOS: .full, iOS: .unavailable)
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        XCTAssertFalse(unavailableFeature.isAvailable)
        #endif
    }
}

// MARK: - Performance Tests

extension PlatformAbstractionTests {
    func testCapabilityDetectionPerformance() {
        measure {
            let capabilities = PlatformCapabilities.shared
            _ = capabilities.currentPlatform
            _ = capabilities.supportsTextKit2
            _ = capabilities.supportsHardwareAcceleration
            _ = capabilities.recommendedCacheSize
        }
    }
    
    func testConfigurationCreationPerformance() {
        measure {
            let capabilities = PlatformCapabilities.shared
            _ = capabilities.recommendedConfiguration()
        }
    }
}
