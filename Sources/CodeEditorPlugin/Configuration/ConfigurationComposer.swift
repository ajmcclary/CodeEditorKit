import Foundation

/// A composable configuration builder that reduces duplication in preset definitions
/// by providing base configurations and functional composition methods.
public enum ConfigurationComposer {
    // MARK: - Base Configuration Builders

    /// Creates a base configuration with common settings
    /// - Parameters:
    ///   - fontSize: The font size for the editor (default: 13.0)
    ///   - lineNumbers: Whether to show line numbers (default: true)
    ///   - syntaxHighlighting: Whether to enable syntax highlighting (default: true)
    ///   - editable: Whether the editor is editable (default: true)
    ///   - tabWidth: The tab width in spaces (default: 4)
    /// - Returns: A base EditorConfiguration with the specified settings
    public static func baseConfiguration(
        fontSize: CGFloat = 13.0,
        lineNumbers: Bool = true,
        syntaxHighlighting: Bool = true,
        editable: Bool = true,
        tabWidth: Int = 4
    ) -> EditorConfiguration {
        var config = EditorConfiguration()

        // Display settings
        config.display.fontSize = fontSize
        config.display.isLineNumbersEnabled = lineNumbers
        config.display.enableSyntaxHighlighting = syntaxHighlighting

        // Behavior settings
        config.behavior.isEditable = editable

        // Layout settings
        config.layout.tabWidth = tabWidth

        return config
    }

    /// Creates a base configuration optimized for mobile platforms
    /// - Parameters:
    ///   - fontSize: The font size (default: 16.0 for better touch readability)
    ///   - gutterWidth: The gutter width (default: 50.0 for touch targets)
    /// - Returns: A mobile-optimized base configuration
    public static func mobileBaseConfiguration(
        fontSize: CGFloat = 16.0,
        gutterWidth: CGFloat = 50.0
    ) -> EditorConfiguration {
        var config = baseConfiguration(fontSize: fontSize)
        config.layout.gutterWidth = gutterWidth
        config.behavior.isAutomaticTextReplacementEnabled = false // Better performance
        config.performance.smoothScrolling = true
        return config
    }

    /// Creates a base configuration optimized for read-only viewing
    /// - Parameter fontSize: The font size for the viewer
    /// - Returns: A read-only optimized configuration
    public static func readOnlyBaseConfiguration(
        fontSize: CGFloat = 13.0
    ) -> EditorConfiguration {
        var config = baseConfiguration(fontSize: fontSize, editable: false)
        config.behavior.enableCodeCompletion = false
        config.behavior.autoIndent = false
        config.behavior.isAutomaticQuoteSubstitutionEnabled = false
        config.behavior.isAutomaticDashSubstitutionEnabled = false
        config.behavior.isAutomaticTextReplacementEnabled = false
        config.behavior.isAutomaticTextCompletionEnabled = false
        return config
    }

    // MARK: - Composition Methods

    /// Applies minimal UI settings to a configuration
    /// - Parameter config: The configuration to modify
    /// - Returns: The modified configuration
    public static func applyMinimalUI(to config: EditorConfiguration) -> EditorConfiguration {
        var modified = config
        modified.display.isLineNumbersEnabled = false
        modified.display.enableAnnotations = false
        modified.display.enableCodeFolding = false
        modified.display.showMinimap = false
        modified.display.showFoldingControls = false
        return modified
    }

    /// Applies performance optimizations for large files
    /// - Parameters:
    ///   - config: The configuration to modify
    ///   - maxHighlightingLength: Maximum file size for syntax highlighting
    /// - Returns: The modified configuration
    public static func applyLargeFileOptimizations(
        to config: EditorConfiguration,
        maxHighlightingLength: Int = 100_000
    ) -> EditorConfiguration {
        var modified = config
        modified.performance.maxSyntaxHighlightingLength = maxHighlightingLength
        modified.performance.useHardwareAcceleration = true
        return modified
    }

    /// Applies markdown-specific settings
    /// - Parameter config: The configuration to modify
    /// - Returns: The modified configuration
    public static func applyMarkdownSettings(to config: EditorConfiguration) -> EditorConfiguration {
        var modified = config
        modified.layout.wrapLines = true
        modified.behavior.isAutomaticLinkDetectionEnabled = true
        modified.behavior.isAutomaticQuoteSubstitutionEnabled = true
        modified.behavior.isAutomaticDashSubstitutionEnabled = true
        modified.display.enableCodeFolding = false
        return modified
    }

    /// Applies presentation mode settings
    /// - Parameters:
    ///   - config: The configuration to modify
    ///   - fontSize: The presentation font size (default: 18.0)
    /// - Returns: The modified configuration
    public static func applyPresentationSettings(
        to config: EditorConfiguration,
        fontSize: CGFloat = 18.0
    ) -> EditorConfiguration {
        var modified = config
        modified.display.fontSize = fontSize
        modified.display.isLineNumbersEnabled = false
        modified.display.enableAnnotations = false
        modified.display.highlightSelectedLine = false
        modified.layout.wrapLines = true
        modified.behavior.isEditable = false
        modified.behavior.enableCodeCompletion = false
        return modified
    }

    // MARK: - Platform-Specific Compositions

    /// Creates a configuration by composing platform-specific optimizations
    /// - Parameters:
    ///   - base: The base configuration to start from
    ///   - platform: The target platform
    /// - Returns: A platform-optimized configuration
    public static func platformOptimized(
        from _: EditorConfiguration,
        for platform: Platform
    ) -> EditorConfiguration {
        switch platform {
        case .iOS:
            return applyLargeFileOptimizations(
                to: mobileBaseConfiguration(),
                maxHighlightingLength: 100_000
            )

        case .catalyst:
            var config = baseConfiguration(fontSize: 14.0)
            config.layout.gutterWidth = 45.0
            config.behavior.isAutomaticQuoteSubstitutionEnabled = false
            config.behavior.isAutomaticDashSubstitutionEnabled = false
            return applyLargeFileOptimizations(
                to: config,
                maxHighlightingLength: 250_000
            )

        case .macOS:
            var config = baseConfiguration()
            config.layout.gutterWidth = 40.0  // Standard macOS gutter width
            config.behavior.isAutomaticTextReplacementEnabled = true
            config.behavior.isAutomaticQuoteSubstitutionEnabled = true
            return applyLargeFileOptimizations(
                to: config,
                maxHighlightingLength: 500_000
            )
        }
    }

    /// Platform enumeration for configuration targeting
    public enum Platform {
        /// iOS platform configuration
        case iOS
        /// macOS platform configuration
        case macOS
        /// Mac Catalyst platform configuration
        case catalyst
    }
}

// MARK: - Functional Composition Extension

extension EditorConfiguration {
    /// Applies a transformation to the configuration
    /// - Parameter transform: The transformation to apply
    /// - Returns: The transformed configuration
    public func applying(_ transform: (inout EditorConfiguration) -> Void) -> EditorConfiguration {
        var copy = self
        transform(&copy)
        return copy
    }

    /// Composes multiple transformations
    /// - Parameter transforms: The transformations to apply in order
    /// - Returns: The transformed configuration
    public func applying(_ transforms: ((inout EditorConfiguration) -> Void)...) -> EditorConfiguration {
        var copy = self
        for transform in transforms {
            transform(&copy)
        }
        return copy
    }
}

// MARK: - Preset Builders Using Composition

extension ConfigurationComposer {
    /// Creates the minimal preset using composition
    public static func createMinimalPreset() -> EditorConfiguration {
        baseConfiguration(syntaxHighlighting: false)
            .applying { config in
                config = applyMinimalUI(to: config)
                config.behavior.enableCodeCompletion = false
            }
    }

    /// Creates the read-only preset using composition
    public static func createReadOnlyPreset() -> EditorConfiguration {
        readOnlyBaseConfiguration()
    }

    /// Creates the markdown preset using composition
    public static func createMarkdownPreset() -> EditorConfiguration {
        baseConfiguration()
            .applying { config in
                config = applyMarkdownSettings(to: config)
            }
    }

    /// Creates the presentation preset using composition
    public static func createPresentationPreset() -> EditorConfiguration {
        readOnlyBaseConfiguration()
            .applying { config in
                config = applyPresentationSettings(to: config)
            }
    }
}
