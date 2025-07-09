import Foundation

extension EditorConfiguration {
    // MARK: - Preset Configurations
    
    /// Default configuration with standard settings
    public static let `default` = EditorConfiguration()
    
    /// Minimal configuration for lightweight editing
    public static let minimal: EditorConfiguration = {
        var config = EditorConfiguration()
        config.display.showLineNumbers = false
        config.display.enableSyntaxHighlighting = false
        config.display.enableAnnotations = false
        config.display.enableCodeFolding = false
        config.display.showMinimap = false
        config.behavior.enableCodeCompletion = false
        return config
    }()
    
    /// Read-only configuration for viewing code
    public static let readOnly: EditorConfiguration = {
        var config = EditorConfiguration()
        config.behavior.isEditable = false
        config.behavior.enableCodeCompletion = false
        config.behavior.autoIndent = false  // No need for auto-indent in read-only mode
        config.behavior.isAutomaticQuoteSubstitutionEnabled = false
        config.behavior.isAutomaticDashSubstitutionEnabled = false
        return config
    }()
    
    /// Configuration optimized for Markdown editing
    public static let markdown: EditorConfiguration = {
        var config = EditorConfiguration()
        config.layout.wrapLines = true
        config.behavior.isAutomaticLinkDetectionEnabled = true
        config.behavior.isAutomaticQuoteSubstitutionEnabled = true
        config.behavior.isAutomaticDashSubstitutionEnabled = true
        config.display.enableCodeFolding = false
        return config
    }()
    
    /// Configuration for presentation/demo mode
    public static let presentation: EditorConfiguration = {
        var config = EditorConfiguration()
        config.display.fontSize = 18
        config.display.showLineNumbers = false
        config.display.enableAnnotations = false
        config.display.highlightSelectedLine = false
        config.layout.wrapLines = true
        config.behavior.isEditable = false
        config.behavior.enableCodeCompletion = false
        return config
    }()
    
    // MARK: - Platform-Specific Presets
    
    /// Configuration optimized for iOS devices
    public static let iOS: EditorConfiguration = {
        var config = EditorConfiguration()
        config.display.fontSize = 16.0 // Larger for touch
        config.layout.gutterWidth = 50.0 // Wider for touch targets
        config.behavior.enableCodeCompletion = true
        config.behavior.isAutomaticTextReplacementEnabled = false // Better performance on mobile
        config.performance.maxSyntaxHighlightingLength = 100_000 // Smaller limit for mobile
        config.performance.smoothScrolling = true
        return config
    }()
    
    /// Configuration optimized for Mac Catalyst
    public static let catalyst: EditorConfiguration = {
        var config = EditorConfiguration()
        config.display.fontSize = 14.0 // Between macOS and iOS
        config.layout.gutterWidth = 45.0 // Slightly wider for potential touch
        config.behavior.enableCodeCompletion = true
        config.performance.useHardwareAcceleration = true
        config.performance.maxSyntaxHighlightingLength = 250_000
        // Catalyst-specific optimizations
        config.behavior.isAutomaticQuoteSubstitutionEnabled = false
        config.behavior.isAutomaticDashSubstitutionEnabled = false
        return config
    }()
    
    /// Configuration optimized for macOS
    public static let macOS: EditorConfiguration = {
        var config = EditorConfiguration()
        // Default configuration is already optimized for macOS
        // This preset makes it explicit and allows customization
        config.display.fontSize = 13.0
        config.layout.gutterWidth = 40.0
        config.behavior.enableCodeCompletion = true
        config.behavior.isAutomaticTextReplacementEnabled = true
        config.behavior.isAutomaticQuoteSubstitutionEnabled = true
        config.performance.useHardwareAcceleration = true
        config.performance.maxSyntaxHighlightingLength = 500_000
        return config
    }()
    
    /// Automatically selects the best configuration for the current platform
    /// 
    /// - Note: This returns a basic platform-appropriate configuration.
    /// For runtime-optimized configuration, use PlatformCapabilities.shared.recommendedConfiguration()
    /// on the main actor.
    public static var platformOptimized: EditorConfiguration {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        return iOS
        #elseif targetEnvironment(macCatalyst)
        return catalyst
        #elseif canImport(AppKit)
        return macOS
        #else
        return `default`
        #endif
    }
}
