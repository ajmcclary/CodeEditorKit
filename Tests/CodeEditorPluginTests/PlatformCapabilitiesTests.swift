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
        let platform = capabilities.currentPlatform
        
        switch platform {
        case .macOS:
            XCTAssertTrue(isAvailable)
        case .iOS, .catalyst:
            XCTAssertFalse(isAvailable)
        }
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
            XCTAssertEqual(availability, .full)
        case .iOS:
            // Both iPhone and iPad get full symbol navigation
            XCTAssertEqual(availability, .full)
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
        XCTAssertTrue(config.display.showLineNumbers)
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
            for _ in 0..<1000 {
                _ = capabilities.currentPlatform
            }
        }
    }
    
    @MainActor
    func testFeatureAvailabilityPerformance() {
        let capabilities = PlatformCapabilities.shared
        measure {
            for _ in 0..<1000 {
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
}