import Foundation

extension EditorConfiguration {
    // MARK: - Preset Configurations
    
    /// Default configuration with standard settings
    public static let `default` = EditorConfiguration()
    
    /// Minimal configuration for lightweight editing
    public static let minimal = ConfigurationComposer.createMinimalPreset()
    
    /// Read-only configuration for viewing code
    public static let readOnly = ConfigurationComposer.createReadOnlyPreset()
    
    /// Configuration optimized for Markdown editing
    public static let markdown = ConfigurationComposer.createMarkdownPreset()
    
    /// Configuration for presentation/demo mode
    public static let presentation = ConfigurationComposer.createPresentationPreset()
    
    // MARK: - Platform-Specific Presets
    
    /// Configuration optimized for iOS devices
    public static let iOS = ConfigurationComposer.platformOptimized(
        from: .default,
        for: .iOS
    )
    
    /// Configuration optimized for Mac Catalyst
    public static let catalyst = ConfigurationComposer.platformOptimized(
        from: .default,
        for: .catalyst
    )
    
    /// Configuration optimized for macOS
    public static let macOS = ConfigurationComposer.platformOptimized(
        from: .default,
        for: .macOS
    )
    
    /// Automatically selects the best configuration for the current platform
    /// 
    /// This is a compile-time preset that returns a platform-specific configuration
    /// based on the build target. It does not adapt to device capabilities at runtime.
    /// 
    /// ## Platform Selection
    /// - iOS builds: Returns `.iOS` preset
    /// - Mac Catalyst builds: Returns `.catalyst` preset  
    /// - macOS builds: Returns `.macOS` preset
    /// - Other platforms: Returns `.default`
    /// 
    /// ## Runtime Optimization
    /// 
    /// For a configuration that adapts to actual device capabilities at runtime,
    /// use `PlatformCapabilities.shared.recommendedConfiguration()` instead:
    /// 
    /// ```swift
    /// // Compile-time preset
    /// let preset = EditorConfiguration.platformOptimized
    /// 
    /// // Runtime-optimized
    /// let optimized = await MainActor.run {
    ///     PlatformCapabilities.shared.recommendedConfiguration()
    /// }
    /// ```
    /// 
    /// - SeeAlso: `PlatformCapabilities.recommendedConfiguration()`
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
