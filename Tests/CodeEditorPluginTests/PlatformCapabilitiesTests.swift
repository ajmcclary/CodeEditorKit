//
//  PlatformCapabilitiesTests.swift
//  CodeEditorPluginTests
//
//  Tests for PlatformCapabilities functionality
//

@testable import CodeEditorPlugin
import XCTest

final class PlatformCapabilitiesTests: XCTestCase {
    // MARK: - Properties
    
    // We'll create a fresh instance for each test since PlatformCapabilities is MainActor-isolated
    
    // MARK: - Platform Detection Tests
    
    @MainActor
    func testPlatformDetection() {
        let capabilities = PlatformCapabilities.shared
        let platform = capabilities.currentPlatform
        
        #if targetEnvironment(macCatalyst)
        XCTAssertEqual(platform, .catalyst)
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertEqual(platform, .macOS)
        #elseif canImport(UIKit)
        XCTAssertEqual(platform, .iOS)
        #endif
    }
    
    @MainActor
    func testPlatformDisplayName() {
        let capabilities = PlatformCapabilities.shared
        let platform = capabilities.currentPlatform
        let displayName = platform.name
        
        switch platform {
        case .macOS:
            XCTAssertEqual(displayName, "macOS")

        case .iOS:
            XCTAssertEqual(displayName, "iOS")

        case .catalyst:
            XCTAssertEqual(displayName, "Mac Catalyst")
        }
    }
    
    // MARK: - Feature Availability Tests
    
    @MainActor
    func testTextKit2Support() {
        let capabilities = PlatformCapabilities.shared
        XCTAssertTrue(capabilities.supportsTextKit2)
    }
    
    @MainActor
    func testMultipleCursorsSupport() {
        let capabilities = PlatformCapabilities.shared
        let isAvailable = capabilities.isFeatureAvailable(.multipleCursors)
        let platform = capabilities.currentPlatform
        
        switch platform {
        case .macOS:
            XCTAssertTrue(isAvailable)

        case .iOS, .catalyst:
            XCTAssertFalse(isAvailable)
        }
    }
    
    @MainActor
    func testMinimapSupport() {
        let capabilities = PlatformCapabilities.shared
        let isAvailable = capabilities.isFeatureAvailable(.minimap)
        // supportsMinimap is true for iOS and Catalyst, false for macOS
        let platform = capabilities.currentPlatform
        
        switch platform {
        case .macOS:
            XCTAssertFalse(capabilities.supportsMinimap)
            XCTAssertFalse(isAvailable)

        case .iOS, .catalyst:
            XCTAssertTrue(capabilities.supportsMinimap)
            XCTAssertTrue(isAvailable)
        }
    }
    
    @MainActor
    func testCodeFoldingSupport() {
        let capabilities = PlatformCapabilities.shared
        // Code folding should be available on all platforms
        XCTAssertTrue(capabilities.isFeatureAvailable(.codeFolding))
    }
    
    @MainActor
    func testLSPSupport() {
        let capabilities = PlatformCapabilities.shared
        let isAvailable = capabilities.isFeatureAvailable(.languageServerProtocol)
        
        // LSP requires process spawning, only available on macOS
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertTrue(isAvailable)
        #else
        XCTAssertFalse(isAvailable)
        #endif
    }
    
    @MainActor
    func testHardwareAcceleration() {
        let capabilities = PlatformCapabilities.shared
        // Hardware acceleration should be available on all platforms
        XCTAssertTrue(capabilities.isFeatureAvailable(.hardwareAcceleration))
    }
    
    // MARK: - Feature Availability Level Tests
    
    @MainActor
    func testGoToDefinitionAvailability() {
        let capabilities = PlatformCapabilities.shared
        let availability = capabilities.getFeatureAvailability(.goToDefinition)
        let platform = capabilities.currentPlatform
        
        switch platform {
        case .macOS:
            XCTAssertEqual(availability, .full)

        case .catalyst:
            XCTAssertEqual(availability, .partial)

        case .iOS:
            // iOS includes both iPhone and iPad
            #if canImport(UIKit)
            if UIDevice.current.userInterfaceIdiom == .pad {
                XCTAssertEqual(availability, .partial)
            } else {
                XCTAssertEqual(availability, .unavailable)
            }
            #else
            XCTAssertEqual(availability, .unavailable)
            #endif
        }
    }
    
    @MainActor
    func testFindReplaceAvailability() {
        let capabilities = PlatformCapabilities.shared
        let availability = capabilities.getFeatureAvailability(.findReplace)
        
        // Find/Replace should be available on all platforms
        XCTAssertNotEqual(availability, .unavailable)
    }
    
    @MainActor
    func testCodeCompletionAvailability() {
        let capabilities = PlatformCapabilities.shared
        let availability = capabilities.getFeatureAvailability(.codeCompletion)
        
        // Code completion should be at least partially available on all platforms
        XCTAssertNotEqual(availability, .unavailable)
    }
    
    @MainActor
    func testSymbolNavigationAvailability() {
        let capabilities = PlatformCapabilities.shared
        let availability = capabilities.getFeatureAvailability(.symbolNavigation)
        let platform = capabilities.currentPlatform
        
        switch platform {
        case .macOS:
            XCTAssertEqual(availability, .full)

        case .catalyst:
            // Mac Catalyst gets partial symbol navigation
            XCTAssertEqual(availability, .partial)

        case .iOS:
            // iOS also gets partial symbol navigation
            XCTAssertEqual(availability, .partial)
        }
    }
    
    // MARK: - Recommended Configuration Tests
    
    @MainActor
    func testRecommendedConfiguration() {
        let capabilities = PlatformCapabilities.shared
        let config = capabilities.recommendedConfiguration()
        let platform = capabilities.currentPlatform
        
        // Common expectations
        XCTAssertNotNil(config)
        XCTAssertTrue(config.display.isLineNumbersEnabled)
        XCTAssertTrue(config.display.highlightSelectedLine)
        
        // Platform-specific expectations
        switch platform {
        case .macOS:
            // macOS uses default config values
            break

        case .iOS:
            XCTAssertEqual(config.display.fontSize, 16.0)
            XCTAssertEqual(config.layout.gutterWidth, 50.0)

        case .catalyst:
            XCTAssertEqual(config.display.fontSize, 14.0)
            XCTAssertEqual(config.layout.gutterWidth, 45.0)
        }
    }
    
    @MainActor
    func testRecommendedPerformanceConfiguration() {
        let capabilities = PlatformCapabilities.shared
        let config = capabilities.recommendedConfiguration()
        
        // Performance configuration should always be optimized
        XCTAssertTrue(config.performance.useHardwareAcceleration)
        XCTAssertTrue(config.performance.smoothScrolling)
        XCTAssertGreaterThan(config.performance.maxSyntaxHighlightingLength, 0)
    }
    
    // MARK: - Feature Detection Tests
    
    @MainActor
    func testIsFeatureAvailable() {
        let capabilities = PlatformCapabilities.shared
        // Test a feature that should be available on all platforms
        XCTAssertTrue(capabilities.isFeatureAvailable(.syntaxHighlighting))
        XCTAssertTrue(capabilities.isFeatureAvailable(.lineNumbers))
        
        // Test platform-specific features
        let platform = capabilities.currentPlatform
        
        switch platform {
        case .macOS:
            XCTAssertTrue(capabilities.isFeatureAvailable(.multipleCursors))
            XCTAssertFalse(capabilities.isFeatureAvailable(.minimap))

        case .iOS, .catalyst:
            XCTAssertFalse(capabilities.isFeatureAvailable(.multipleCursors))
            XCTAssertTrue(capabilities.isFeatureAvailable(.minimap))
        }
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testPlatformDetectionPerformance() {
        let capabilities = PlatformCapabilities.shared
        measure {
            for _ in 0..<1_000 {
                _ = capabilities.currentPlatform
            }
        }
    }
    
    @MainActor
    func testFeatureAvailabilityPerformance() {
        let capabilities = PlatformCapabilities.shared
        measure {
            for _ in 0..<1_000 {
                _ = capabilities.isFeatureAvailable(.syntaxHighlighting)
                _ = capabilities.getFeatureAvailability(.goToDefinition)
            }
        }
    }
    
    @MainActor
    func testRecommendedConfigurationPerformance() {
        let capabilities = PlatformCapabilities.shared
        measure {
            for _ in 0..<100 {
                _ = capabilities.recommendedConfiguration()
            }
        }
    }
    
    // MARK: - Additional Tests for Review Feedback
    
    @MainActor
    func testRecommendedConfigurationMemoryAdjustments() {
        let capabilities = PlatformCapabilities.shared
        let config = capabilities.recommendedConfiguration()
        
        // Check that memory-based adjustments are applied
        let memoryInGB = ProcessInfo.processInfo.physicalMemory / (1_024 * 1_024 * 1_024)
        
        if memoryInGB < 4 {
            // Low memory devices should have reduced syntax highlighting length
            XCTAssertLessThanOrEqual(
                config.performance.maxSyntaxHighlightingLength,
                100_000,
                "Low memory devices should have reduced syntax highlighting limit"
            )
        } else if memoryInGB >= 16 {
            // High memory devices can handle larger files
            XCTAssertGreaterThanOrEqual(
                config.performance.maxSyntaxHighlightingLength,
                500_000,
                "High memory devices should support larger files"
            )
        }
    }
    
    @MainActor
    func testRecommendedConfigurationDeviceSpecific() {
        let capabilities = PlatformCapabilities.shared
        let config = capabilities.recommendedConfiguration()
        let deviceType = capabilities.deviceType
        
        // Verify device-specific settings are applied
        switch deviceType {
        case .mac:
            // On Mac (including Catalyst), check platform-specific adjustments
            if capabilities.currentPlatform == .catalyst {
                XCTAssertEqual(config.display.fontSize, 14.0, "Catalyst should use 14pt font")
                XCTAssertEqual(config.layout.gutterWidth, 45.0, "Catalyst should use 45pt gutter")
            } else {
                XCTAssertEqual(config.display.fontSize, 14.0, "Mac should use 14pt font")
                XCTAssertEqual(config.layout.gutterWidth, 50.0, "Mac should use 50pt gutter")
            }
            
        case .iPhone:
            XCTAssertEqual(config.display.fontSize, 16.0, "iPhone should use 16pt font")
            XCTAssertEqual(config.layout.gutterWidth, 50.0, "iPhone should use 50pt gutter")
            XCTAssertFalse(config.display.showMinimap, "iPhone should not show minimap")
            
        case .iPad:
            XCTAssertEqual(config.display.fontSize, 15.0, "iPad should use 15pt font")
            XCTAssertEqual(config.layout.gutterWidth, 45.0, "iPad should use 45pt gutter")
            // Note: iPad's recommendedConfiguration() sets showMinimap to false
            XCTAssertFalse(config.display.showMinimap, "iPad should not show minimap")
            
        default:
            // Other device types use their default configurations
            break
        }
    }
    
    @MainActor
    func testRecommendedConfigurationPerformanceCapabilities() {
        let capabilities = PlatformCapabilities.shared
        let config = capabilities.recommendedConfiguration()
        let perfCaps = capabilities.performanceCapabilities
        
        // Verify performance capabilities are respected
        if !perfCaps.supportsHardwareAcceleration {
            XCTAssertFalse(config.performance.useHardwareAcceleration,
                         "Hardware acceleration should be disabled when not supported")
        }
        
        // Performance config should always exist
        XCTAssertNotNil(config.performance, "Performance config should exist")
        XCTAssertGreaterThan(
            config.performance.maxSyntaxHighlightingLength,
            0,
            "Max syntax highlighting length should be positive"
        )
    }
    
    @MainActor
    func testAllFeaturesHaveAvailabilityLevel() {
        let capabilities = PlatformCapabilities.shared
        
        // Test all known features
        let features: [PlatformCapabilities.EditorFeature] = [
            .syntaxHighlighting, .lineNumbers, .codeFolding, .minimap,
            .multipleCursors, .languageServerProtocol, .goToDefinition,
            .findReplace, .codeCompletion, .symbolNavigation,
            .hardwareAcceleration, .autoIndent
        ]
        
        for feature in features {
            let availability = capabilities.getFeatureAvailability(feature)
            // Every feature should have a defined availability level
            XCTAssertTrue([.full, .partial, .unavailable].contains(availability),
                        "Feature \(feature) should have valid availability level")
        }
    }
    
    @MainActor
    func testInputCapabilities() {
        let capabilities = PlatformCapabilities.shared
        let inputCaps = capabilities.inputCapabilities
        
        // Basic validation of input capabilities based on platform
        #if targetEnvironment(macCatalyst)
        // Catalyst supports keyboard, mouse, and touch
        XCTAssertTrue(inputCaps.preferredInputMethods.contains(.keyboard), "Catalyst should support keyboard")
        XCTAssertTrue(inputCaps.preferredInputMethods.contains(.mouse), "Catalyst should support mouse")
        XCTAssertTrue(inputCaps.preferredInputMethods.contains(.touch), "Catalyst should support touch")
        XCTAssertTrue(inputCaps.supportsKeyboardShortcuts, "Catalyst should support keyboard shortcuts")
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS supports keyboard, mouse, and trackpad
        XCTAssertTrue(inputCaps.preferredInputMethods.contains(.keyboard), "macOS should support keyboard")
        XCTAssertTrue(inputCaps.preferredInputMethods.contains(.mouse), "macOS should support mouse")
        XCTAssertTrue(inputCaps.preferredInputMethods.contains(.trackpad), "macOS should support trackpad")
        XCTAssertFalse(inputCaps.preferredInputMethods.contains(.touch), "macOS should not support touch")
        XCTAssertTrue(inputCaps.supportsKeyboardShortcuts, "macOS should support keyboard shortcuts")
        #else
        // iOS supports touch
        XCTAssertTrue(inputCaps.preferredInputMethods.contains(.touch), "iOS should support touch")
        XCTAssertFalse(inputCaps.preferredInputMethods.contains(.keyboard), "iOS should not prefer keyboard")
        #endif
    }
}
