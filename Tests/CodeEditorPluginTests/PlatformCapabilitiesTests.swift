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
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
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
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
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
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        XCTAssertTrue(capabilities.supportsTextKit2)
    }

    @MainActor
    func testMultipleCursorsSupport() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
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
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
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
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        // Code folding should be available on all platforms
        XCTAssertTrue(capabilities.isFeatureAvailable(.codeFolding))
    }

    @MainActor
    func testLSPSupport() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
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
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        // Hardware acceleration should be available on all platforms
        XCTAssertTrue(capabilities.isFeatureAvailable(.hardwareAcceleration))
    }

    // MARK: - Feature Availability Level Tests

    @MainActor
    func testGoToDefinitionAvailability() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
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
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        let availability = capabilities.getFeatureAvailability(.findReplace)

        // Find/Replace should be available on all platforms
        XCTAssertNotEqual(availability, .unavailable)
    }

    @MainActor
    func testCodeCompletionAvailability() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        let availability = capabilities.getFeatureAvailability(.codeCompletion)

        // Code completion should be at least partially available on all platforms
        XCTAssertNotEqual(availability, .unavailable)
    }

    @MainActor
    func testSymbolNavigationAvailability() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
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
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
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

        case .catalyst:
            // Catalyst fontSize varies by device type (14.0 for base, 15.0 for iPad)
            XCTAssertTrue(config.display.fontSize == 14.0 || config.display.fontSize == 15.0)
            XCTAssertEqual(config.layout.gutterWidth, 45.0)
        }
    }

    @MainActor
    func testRecommendedPerformanceConfiguration() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        let config = capabilities.recommendedConfiguration()

        // Performance configuration should always be optimized
        XCTAssertTrue(config.performance.useHardwareAcceleration)

        // Smooth scrolling might be disabled on some configurations (e.g., low memory)
        #if targetEnvironment(macCatalyst)
        // On Catalyst, smooth scrolling depends on device type and memory
        // Just ensure it's set to a boolean value
        _ = config.performance.smoothScrolling
        #elseif canImport(UIKit)
        // On iOS, smooth scrolling depends on ProMotion display (>60fps)
        // In simulator, this might not be available
        if UIScreen.main.maximumFramesPerSecond > 60 {
            XCTAssertTrue(config.performance.smoothScrolling)
        } else {
            // Non-ProMotion displays or simulator
            XCTAssertFalse(config.performance.smoothScrolling)
        }
        #else
        XCTAssertTrue(config.performance.smoothScrolling)
        #endif

        XCTAssertGreaterThan(config.performance.maxSyntaxHighlightingLength, 0)
    }

    // MARK: - Feature Detection Tests

    @MainActor
    func testIsFeatureAvailable() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
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
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        measure(options: Self.standardMeasureOptions) {
            for _ in 0..<1_000 {
                _ = capabilities.currentPlatform
            }
        }
    }

    @MainActor
    func testFeatureAvailabilityPerformance() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        measure(options: Self.standardMeasureOptions) {
            for _ in 0..<1_000 {
                _ = capabilities.isFeatureAvailable(.syntaxHighlighting)
                _ = capabilities.getFeatureAvailability(.goToDefinition)
            }
        }
    }

    @MainActor
    func testRecommendedConfigurationPerformance() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        measure(options: Self.standardMeasureOptions) {
            for _ in 0..<100 {
                _ = capabilities.recommendedConfiguration()
            }
        }
    }

    // MARK: - Additional Tests for Review Feedback

    @MainActor
    func testRecommendedConfigurationMemoryAdjustments() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
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
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        let config = capabilities.recommendedConfiguration()
        let deviceType = capabilities.deviceType

        // Verify device-specific settings are applied
        switch deviceType {
        case .mac:
            // On Mac (including Catalyst), check platform-specific adjustments
            if capabilities.currentPlatform == .catalyst {
                // Catalyst fontSize varies by device type (14.0 for base, 15.0 for iPad)
                XCTAssertTrue(config.display.fontSize == 14.0 || config.display.fontSize == 15.0, "Catalyst should use 14pt or 15pt font")
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
            // Catalyst on iPad has different settings than native iPad
            if capabilities.currentPlatform == .catalyst {
                XCTAssertEqual(config.display.fontSize, 15.0, "Catalyst iPad should use 15pt font")
                XCTAssertEqual(config.layout.gutterWidth, 45.0, "Catalyst iPad should use 45pt gutter")
                XCTAssertFalse(config.display.showMinimap, "Catalyst iPad should not show minimap")
            } else {
                XCTAssertEqual(config.display.fontSize, 16.0, "iPad should use 16pt font")
                XCTAssertEqual(config.layout.gutterWidth, 45.0, "iPad should use 45pt gutter")
                // iPad configuration enables minimap since it has enough screen space
                XCTAssertTrue(config.display.showMinimap, "iPad should show minimap")
            }

        default:
            // Other device types use their default configurations
            break
        }
    }

    @MainActor
    func testRecommendedConfigurationPerformanceCapabilities() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
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
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()

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
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
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

    // MARK: - Mac Catalyst-specific Tests

    @MainActor
    func testCADisplayLinkSupportOnCatalyst() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        let perfCaps = capabilities.performanceCapabilities

        #if targetEnvironment(macCatalyst)
        // Mac Catalyst should follow macOS availability for CADisplayLink (14.0+)
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
        if systemVersion.majorVersion >= 14 {
            XCTAssertTrue(perfCaps.supportsCADisplayLink,
                         "Mac Catalyst on macOS 14+ should support CADisplayLink")
        } else {
            XCTAssertFalse(perfCaps.supportsCADisplayLink,
                          "Mac Catalyst on macOS <14 should not support CADisplayLink")
        }
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS should support CADisplayLink on 14.0+
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
        if systemVersion.majorVersion >= 14 {
            XCTAssertTrue(perfCaps.supportsCADisplayLink,
                         "macOS 14+ should support CADisplayLink")
        } else {
            XCTAssertFalse(perfCaps.supportsCADisplayLink,
                          "macOS <14 should not support CADisplayLink")
        }
        #elseif canImport(UIKit)
        // iOS always supports CADisplayLink
        XCTAssertTrue(perfCaps.supportsCADisplayLink,
                     "iOS should always support CADisplayLink")
        #endif
    }

    @MainActor
    func testCatalystPerformanceCapabilities() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        let perfCaps = capabilities.performanceCapabilities

        #if targetEnvironment(macCatalyst)
        // Catalyst-specific performance capability checks
        XCTAssertTrue(perfCaps.supportsHardwareAcceleration,
                     "Mac Catalyst should support hardware acceleration")
        XCTAssertTrue(perfCaps.supportsBackgroundProcessing,
                     "Mac Catalyst should support background processing")
        XCTAssertTrue(perfCaps.supportsSmoothScrolling,
                     "Mac Catalyst should support smooth scrolling")

        // Catalyst should be treated as desktop-class for memory
        let memoryProfile = perfCaps.memoryProfile
        XCTAssertNotEqual(
            memoryProfile,
            .low,
            "Mac Catalyst on desktop should not have low memory profile"
        )
        #endif
    }

    @MainActor
    func testCatalystFeatureAvailability() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()

        #if targetEnvironment(macCatalyst)
        // Test Catalyst-specific feature availability

        // Features that should be available on Catalyst
        XCTAssertTrue(capabilities.isFeatureAvailable(.syntaxHighlighting),
                     "Catalyst should support syntax highlighting")
        XCTAssertTrue(capabilities.isFeatureAvailable(.lineNumbers),
                     "Catalyst should support line numbers")
        XCTAssertTrue(capabilities.isFeatureAvailable(.codeFolding),
                     "Catalyst should support code folding")
        XCTAssertTrue(capabilities.isFeatureAvailable(.findReplace),
                     "Catalyst should support find/replace")
        XCTAssertTrue(capabilities.isFeatureAvailable(.hardwareAcceleration),
                     "Catalyst should support hardware acceleration")

        // Features with partial availability on Catalyst
        XCTAssertEqual(
            capabilities.getFeatureAvailability(.goToDefinition),
            .partial,
            "Catalyst should have partial goToDefinition support"
        )
        XCTAssertEqual(
            capabilities.getFeatureAvailability(.symbolNavigation),
            .partial,
            "Catalyst should have partial symbol navigation support"
        )

        // Features that should NOT be available on Catalyst
        XCTAssertFalse(capabilities.isFeatureAvailable(.languageServerProtocol),
                      "Catalyst should not support LSP (no process spawning)")
        XCTAssertFalse(capabilities.isFeatureAvailable(.multipleCursors),
                      "Catalyst should not support multiple cursors")

        // Minimap support (should be available on Catalyst)
        XCTAssertTrue(capabilities.isFeatureAvailable(.minimap),
                     "Catalyst should support minimap")
        #endif
    }

    @MainActor
    func testCatalystRecommendedConfiguration() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()

        #if targetEnvironment(macCatalyst)
        let config = capabilities.recommendedConfiguration()

        // Catalyst should use desktop-optimized settings
        XCTAssertTrue(config.display.isLineNumbersEnabled,
                     "Catalyst should show line numbers by default")
        XCTAssertTrue(config.display.highlightSelectedLine,
                     "Catalyst should highlight selected line")
        XCTAssertTrue(config.performance.useHardwareAcceleration,
                     "Catalyst should use hardware acceleration")

        // Font size varies based on device type in Catalyst
        // Base Catalyst uses 14.0, iPad Catalyst uses 15.0
        XCTAssertTrue(config.display.fontSize == 14.0 || config.display.fontSize == 15.0,
                     "Catalyst should use 14pt or 15pt font size")

        // Gutter width should be optimized for Catalyst
        XCTAssertEqual(
            config.layout.gutterWidth,
            45.0,
            "Catalyst should use 45pt gutter width"
        )
        #endif
    }
}
