import CoreGraphics
import Foundation

extension EditorConfiguration {
    // MARK: - Preset Configurations

    /// Default configuration with standard settings
    public static let `default` = EditorConfiguration()

    /// Minimal configuration for lightweight editing
    public static let minimal: EditorConfiguration = {
        var config = EditorConfiguration()
        config.display.isSyntaxHighlightingEnabled = false
        config.display.isLineNumbersEnabled = false
        config.display.areAnnotationsEnabled = false
        config.display.isCodeFoldingEnabled = false
        config.display.isMinimapVisible = false
        config.display.areFoldingControlsVisible = false
        config.behavior.isCodeCompletionEnabled = false
        return config
    }()

    /// Read-only configuration for viewing code
    public static let readOnly: EditorConfiguration = {
        var config = EditorConfiguration()
        config.behavior.isEditable = false
        config.behavior.isCodeCompletionEnabled = false
        config.behavior.isAutoIndentEnabled = false
        config.behavior.isAutomaticQuoteSubstitutionEnabled = false
        config.behavior.isAutomaticDashSubstitutionEnabled = false
        config.behavior.isAutomaticTextReplacementEnabled = false
        config.behavior.isAutomaticTextCompletionEnabled = false
        return config
    }()

    /// Configuration optimized for Markdown editing
    public static let markdown: EditorConfiguration = {
        var config = EditorConfiguration()
        config.layout.wrapLines = true
        config.behavior.isAutomaticLinkDetectionEnabled = true
        config.behavior.isAutomaticQuoteSubstitutionEnabled = true
        config.behavior.isAutomaticDashSubstitutionEnabled = true
        config.display.isCodeFoldingEnabled = false
        return config
    }()

    /// Configuration for presentation/demo mode
    public static let presentation: EditorConfiguration = {
        var config = readOnly
        config.display.fontSize = 18.0
        config.display.isLineNumbersEnabled = false
        config.display.areAnnotationsEnabled = false
        config.display.isSelectedLineHighlighted = false
        config.layout.wrapLines = true
        return config
    }()

    // MARK: - Platform-Specific Presets

    /// Configuration optimized for iOS devices
    public static let iOS: EditorConfiguration = {
        var config = EditorConfiguration()
        config.display.fontSize = 16.0
        config.layout.gutterWidth = 50.0
        config.behavior.isAutomaticTextReplacementEnabled = false
        config.performance.smoothScrolling = true
        config.performance.maxSyntaxHighlightingLength = 100_000
        config.performance.useHardwareAcceleration = true
        return config
    }()

    /// Configuration optimized for macOS
    public static let macOS: EditorConfiguration = {
        var config = EditorConfiguration()
        config.layout.gutterWidth = 40.0
        config.behavior.isAutomaticTextReplacementEnabled = true
        config.behavior.isAutomaticQuoteSubstitutionEnabled = true
        config.performance.maxSyntaxHighlightingLength = 500_000
        config.performance.useHardwareAcceleration = true
        return config
    }()

    /// Automatically selects the best configuration for the current platform.
    ///
    /// Compile-time preset based on the build target. For runtime device-aware
    /// selection use `PlatformCapabilities().recommendedConfiguration()` instead.
    public static var platformOptimized: EditorConfiguration {
        #if canImport(UIKit)
        return iOS
        #elseif canImport(AppKit)
        return macOS
        #else
        return `default`
        #endif
    }
}
