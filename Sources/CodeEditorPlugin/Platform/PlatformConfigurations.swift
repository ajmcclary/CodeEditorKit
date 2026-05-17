import CodeEditorCommon
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
        config.display.isSelectedLineHighlighted = true
        config.display.isSyntaxHighlightingEnabled = true
        config.display.isCodeFoldingEnabled = true
        config.display.isMinimapVisible = true

        // Layout optimizations for macOS
        config.layout.gutterWidth = 50.0
        config.layout.minimapWidth = 100.0
        config.layout.lineHeightMultiple = 1.2
        config.layout.wrapLines = false
        config.layout.insertSpacesForTabs = true

        // Behavior settings for macOS
        config.behavior.isCodeCompletionEnabled = true
        config.behavior.isAutoIndentEnabled = true
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
        config.display.isSelectedLineHighlighted = true
        config.display.isSyntaxHighlightingEnabled = true
        config.display.isCodeFoldingEnabled = false  // Less useful on touch
        config.display.isMinimapVisible = false  // Save screen space

        // Layout optimizations for iOS
        config.layout.gutterWidth = 50.0  // Standard width for iOS
        config.layout.minimapWidth = 0.0
        config.layout.lineHeightMultiple = 1.3  // More spacing for touch
        config.layout.wrapLines = true  // Avoid horizontal scrolling
        config.layout.insertSpacesForTabs = true

        // Behavior settings for iOS
        config.behavior.isCodeCompletionEnabled = true
        config.behavior.isAutoIndentEnabled = true
        config.behavior.isContinuousSpellCheckingEnabled = false

        // Performance settings for iOS
        config.performance.useHardwareAcceleration = true
        config.performance.maxSyntaxHighlightingLength = 100_000  // Lower for mobile
        config.performance.smoothScrolling = false  // Save battery

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
        config.display.isMinimapVisible = true  // Enough screen space
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
        config.display.isCodeFoldingEnabled = true
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
        config.display.isSyntaxHighlightingEnabled = false
        config.display.isMinimapVisible = false
        config.display.isCodeFoldingEnabled = false
        config.performance.maxSyntaxHighlightingLength = 10_000
        config.performance.useHardwareAcceleration = false
        config.performance.smoothScrolling = false

        return config
    }

    /// Configuration for high-performance devices
    public static var highPerformance: EditorConfiguration {
        var config = EditorConfiguration.default

        // Enable all features
        config.display.isSyntaxHighlightingEnabled = true
        config.display.isMinimapVisible = true
        config.display.isCodeFoldingEnabled = true
        config.display.areInvisibleCharactersVisible = true
        config.performance.maxSyntaxHighlightingLength = 1_000_000
        config.performance.useHardwareAcceleration = true
        config.performance.smoothScrolling = true

        return config
    }

    // MARK: - Configuration Selection

    /// Get the recommended configuration for the current platform
    /// - Parameter capabilities: Platform capabilities (defaults to dependency factory)
    @MainActor
    public static func recommended(capabilities: PlatformCapabilities? = nil) -> EditorConfiguration {
        let capabilities = capabilities ?? CodeEditorDependencies.makePlatformCapabilities()

        // Start with platform base
        var config: EditorConfiguration
        switch capabilities.currentPlatform {
        case .macOS:
            config = macOS

        case .iOS:
            config = iOS
        }

        // Apply device-specific adjustments
        let deviceType = capabilities.deviceType

        // Apply device-specific adjustments for iOS / iPadOS
        if capabilities.currentPlatform == .iOS {
            switch deviceType {
            case .iPhone:
                config = iPhone

            case .iPad:
                config = iPad

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
            config.display.isMinimapVisible = false
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
        #if canImport(UIKit)
        // Enable smooth scrolling for ProMotion displays
        if UIKitScreenMetrics.maximumFramesPerSecond > 60 {
            config.performance.smoothScrolling = true
        }
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
