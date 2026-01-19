import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Platform Configuration Provider

/// Provides platform-optimized configurations for different runtime environments
public enum PlatformConfigurations {
    // MARK: - Platform-Specific Base Configurations

    /// Base configuration for macOS platform
    public static var macOS: EditorConfiguration {
        var config = EditorConfiguration.default

        // Display optimizations for macOS
        config.display.fontSize = 14.0
        config.display.isLineNumbersEnabled = true
        config.display.highlightSelectedLine = true
        config.display.enableSyntaxHighlighting = true
        config.display.enableCodeFolding = true
        config.display.showMinimap = true

        // Layout optimizations for macOS
        config.layout.gutterWidth = 50.0
        config.layout.minimapWidth = 100.0
        config.layout.lineHeightMultiple = 1.2
        config.layout.wrapLines = false
        config.layout.insertSpacesForTabs = true

        // Behavior settings for macOS
        config.behavior.enableCodeCompletion = true
        config.behavior.autoIndent = true
        config.behavior.isContinuousSpellCheckingEnabled = false

        // Performance settings for macOS
        config.performance.useHardwareAcceleration = true
        config.performance.maxSyntaxHighlightingLength = 500_000
        config.performance.smoothScrolling = true

        return config
    }

    /// Base configuration for iOS platform
    public static var iOS: EditorConfiguration {
        var config = EditorConfiguration.default

        // Display optimizations for iOS
        config.display.fontSize = 16.0  // Larger for touch
        config.display.isLineNumbersEnabled = true
        config.display.highlightSelectedLine = true
        config.display.enableSyntaxHighlighting = true
        config.display.enableCodeFolding = false  // Less useful on touch
        config.display.showMinimap = false  // Save screen space

        // Layout optimizations for iOS
        config.layout.gutterWidth = 50.0  // Standard width for iOS
        config.layout.minimapWidth = 0.0
        config.layout.lineHeightMultiple = 1.3  // More spacing for touch
        config.layout.wrapLines = true  // Avoid horizontal scrolling
        config.layout.insertSpacesForTabs = true

        // Behavior settings for iOS
        config.behavior.enableCodeCompletion = true
        config.behavior.autoIndent = true
        config.behavior.isContinuousSpellCheckingEnabled = false

        // Performance settings for iOS
        config.performance.useHardwareAcceleration = true
        config.performance.maxSyntaxHighlightingLength = 100_000  // Lower for mobile
        config.performance.smoothScrolling = false  // Save battery

        return config
    }

    /// Base configuration for Mac Catalyst platform
    public static var catalyst: EditorConfiguration {
        var config = EditorConfiguration.default

        // Display optimizations for Catalyst (hybrid approach)
        config.display.fontSize = 14.0  // Between macOS and iOS
        config.display.isLineNumbersEnabled = true
        config.display.highlightSelectedLine = true
        config.display.enableSyntaxHighlighting = true
        config.display.enableCodeFolding = true
        config.display.showMinimap = false  // Catalyst apps often run on smaller screens
        // Note: showInvisibleCharacters not supported on Catalyst (TextKit limitation)
        // Note: showIndentGuides not yet implemented on any platform

        // Layout optimizations for Catalyst
        config.layout.gutterWidth = 45.0  // Slightly wider for potential touch
        config.layout.minimapWidth = 0.0
        config.layout.lineHeightMultiple = 1.25  // Balanced spacing
        config.layout.wrapLines = false
        config.layout.insertSpacesForTabs = true

        // Behavior settings for Catalyst
        config.behavior.enableCodeCompletion = true
        config.behavior.autoIndent = true
        config.behavior.isContinuousSpellCheckingEnabled = false

        // Performance settings for Catalyst
        config.performance.useHardwareAcceleration = true
        config.performance.maxSyntaxHighlightingLength = 250_000  // Middle ground
        config.performance.smoothScrolling = true

        return config
    }

    // MARK: - Device-Specific Configurations

    /// Configuration optimized for iPhone
    public static var iPhone: EditorConfiguration {
        var config = iOS

        // iPhone-specific adjustments
        config.display.fontSize = 16.0  // Keep iOS default
        config.display.isLineNumbersEnabled = true  // Keep iOS default
        config.layout.gutterWidth = 50.0  // Keep iOS default
        config.layout.wrapLines = true  // Essential on small screens
        config.performance.maxSyntaxHighlightingLength = 50_000

        return config
    }

    /// Configuration optimized for iPad
    public static var iPad: EditorConfiguration {
        var config = iOS

        // iPad-specific adjustments
        config.display.fontSize = 16.0
        config.display.showMinimap = true  // Enough screen space
        config.layout.gutterWidth = 45.0
        config.layout.minimapWidth = 80.0
        config.layout.wrapLines = false  // Can handle horizontal scrolling
        config.performance.maxSyntaxHighlightingLength = 200_000

        return config
    }

    /// Configuration optimized for iPad Pro
    public static var iPadPro: EditorConfiguration {
        var config = iPad

        // iPad Pro-specific adjustments
        config.display.enableCodeFolding = true
        config.layout.minimapWidth = 100.0
        config.performance.maxSyntaxHighlightingLength = 300_000
        config.performance.smoothScrolling = true  // ProMotion display

        return config
    }

    // MARK: - Performance-Based Configurations

    /// Configuration for low-memory devices
    public static var lowMemory: EditorConfiguration {
        var config = EditorConfiguration.minimal

        // Aggressive memory optimizations
        config.display.enableSyntaxHighlighting = false
        config.display.showMinimap = false
        config.display.enableCodeFolding = false
        config.performance.maxSyntaxHighlightingLength = 10_000
        config.performance.useHardwareAcceleration = false
        config.performance.smoothScrolling = false

        return config
    }

    /// Configuration for high-performance devices
    public static var highPerformance: EditorConfiguration {
        var config = EditorConfiguration.default

        // Enable all features
        config.display.enableSyntaxHighlighting = true
        config.display.showMinimap = true
        config.display.enableCodeFolding = true
        config.display.showInvisibleCharacters = true
        config.performance.maxSyntaxHighlightingLength = 1_000_000
        config.performance.useHardwareAcceleration = true
        config.performance.smoothScrolling = true

        return config
    }

    // MARK: - Configuration Selection

    /// Get the recommended configuration for the current platform
    /// - Parameter capabilities: Platform capabilities (defaults to shared instance)
    @MainActor
    public static func recommended(capabilities: PlatformCapabilities = .shared) -> EditorConfiguration {
        let capabilities = capabilities

        // Start with platform base
        var config: EditorConfiguration
        switch capabilities.currentPlatform {
        case .macOS:
            config = macOS

        case .iOS:
            config = iOS

        case .catalyst:
            config = catalyst
        }

        // Apply device-specific adjustments
        let deviceType = capabilities.deviceType

        // Apply device-specific adjustments for iOS and Catalyst
        if capabilities.currentPlatform == .iOS || capabilities.currentPlatform == .catalyst {
            switch deviceType {
            case .iPhone:
                config = iPhone

            case .iPad:
                // For Catalyst on iPad, use iPad config but keep Catalyst-specific overrides
                if capabilities.currentPlatform == .catalyst {
                    config = iPad
                    // Keep some Catalyst-specific settings
                    config.layout.gutterWidth = 45.0  // Catalyst prefers this
                    config.display.fontSize = 15.0     // Use iPad font size
                    config.display.showMinimap = false // Don't show minimap on Catalyst
                } else {
                    config = iPad
                }

            case .appleTV, .appleWatch, .visionPro, .carPlay:
                // Use minimal config for unsupported devices
                config = EditorConfiguration.minimal

                default:
                // Keep platform default
                let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.platform", category: "PlatformConfigurations")
                logger.warning("Unknown device type '\(String(describing: deviceType))' detected, using platform default configuration")
            }
        }

        // Apply performance adjustments
        let memoryInGB = ProcessInfo.processInfo.physicalMemory / (1_024 * 1_024 * 1_024)
        if memoryInGB < 4 {
            // Low memory adjustments
            config.performance.maxSyntaxHighlightingLength = min(config.performance.maxSyntaxHighlightingLength, 50_000)
            config.display.showMinimap = false
        } else if memoryInGB >= 16 {
            // High memory adjustments
            config.performance.maxSyntaxHighlightingLength = max(config.performance.maxSyntaxHighlightingLength, 500_000)
        }

        // Apply architecture adjustments
        #if arch(arm64)
        // Apple Silicon optimizations
        config.performance.useHardwareAcceleration = true
        #endif

        // Apply display-specific adjustments
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        // Enable smooth scrolling for ProMotion displays
        if UIScreen.main.maximumFramesPerSecond > 60 {
            config.performance.smoothScrolling = true
        }
        #elseif targetEnvironment(macCatalyst)
        // Catalyst always supports smooth scrolling
        config.performance.smoothScrolling = true
        #endif

        return config
    }

    /// Get configuration for a specific device type
    public static func configuration(for deviceType: DeviceType) -> EditorConfiguration {
        switch deviceType {
        case .mac:
            return macOS

        case .iPhone:
            return iPhone

        case .iPad:
            return iPad

        case .appleTV, .appleWatch, .visionPro, .carPlay:
            return EditorConfiguration.minimal

        case .unspecified, .unknown:
            let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.platform", category: "PlatformConfigurations")
            logger.warning("Device type '\(deviceType)' is unspecified or unknown, returning default configuration")
            return EditorConfiguration.default
        }
    }
}

// MARK: - EditorConfiguration Extension

extension EditorConfiguration {
    // Note: platformOptimized is already defined in EditorConfiguration+Presets.swift
}
