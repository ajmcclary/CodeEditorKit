import CodeEditorPlugin
import Foundation

// MARK: - EditorConfiguration Extensions

// Use the plugin's EditorConfiguration as the main type
// EditorConfiguration is directly available from the CodeEditorPlugin module

// MARK: - ConfigurationPreset

/// Predefined editor configuration presets for common use cases.
///
/// `ConfigurationPreset` provides ready-to-use editor configurations optimized
/// for different scenarios, from full-featured development to minimal reading
/// experiences. Each preset combines multiple configuration settings to create
/// cohesive, purpose-built editor experiences.
///
/// ## Available Presets
///
/// - `fullFeatured`: Complete development environment with all features
/// - `minimal`: Streamlined interface for basic text editing
/// - `readOnly`: Optimized for code viewing and reading
/// - `markdown`: Tailored for Markdown document editing
/// - `presentation`: Large fonts and high contrast for demonstrations
///
/// ## Usage
///
/// ```swift
/// // Apply a preset to the editor
/// appState.applyPreset(.minimal)
///
/// // Get the configuration for a preset
/// let config = ConfigurationPreset.markdown.configuration
/// ```
///
/// ## Customization
///
/// Presets serve as starting points that can be further customized:
/// ```swift
/// var config = ConfigurationPreset.readOnly.configuration
/// config.display.fontSize = 16.0
/// config.layout.lineSpacing = 1.5
/// ```
///
/// ## Design Philosophy
///
/// Each preset is designed around a specific use case:
/// - **Full Featured**: Maximum functionality for active development
/// - **Minimal**: Distraction-free writing and editing
/// - **Read Only**: Optimal readability for code review
/// - **Markdown**: Document-focused with appropriate spacing
/// - **Presentation**: Visibility for audiences and screenshots
///
/// - SeeAlso: `configuration` for detailed configuration options
/// - SeeAlso: `configuration` for custom configurations
/// - SeeAlso: `ConfigurationCoordinator` for applying presets
enum ConfigurationPreset: String, CaseIterable {
    /// Complete development environment with all features enabled.
    case fullFeatured = "full"
    
    /// Streamlined interface for basic text editing.
    case minimal
    
    /// Optimized for code viewing and reading.
    case readOnly = "readonly"
    
    /// Tailored for Markdown document editing.
    case markdown
    
    /// Large fonts and high contrast for demonstrations.
    case presentation

    /// Human-readable display name for the preset.
    ///
    /// - Returns: A localized display name suitable for UI presentation.
    var displayName: String {
        switch self {
        case .fullFeatured: "Full Featured"
        case .minimal: "Minimal"
        case .readOnly: "Read Only"
        case .markdown: "Markdown"
        case .presentation: "Presentation"
        }
    }

    /// Detailed description of the preset's purpose and characteristics.
    ///
    /// - Returns: A description explaining when and why to use this preset.
    var description: String {
        switch self {
        case .fullFeatured: "All features enabled for code editing"
        case .minimal: "Basic text editing with minimal UI"
        case .readOnly: "Syntax highlighted code viewer"
        case .markdown: "Optimized for Markdown editing"
        case .presentation: "Large font, high contrast for demos"
        }
    }

    /// The complete editor configuration for this preset.
    ///
    /// Generates a fully configured `EditorConfiguration` instance with
    /// all settings optimized for the preset's intended use case.
    ///
    /// ## Implementation Details
    ///
    /// Each preset uses `EditorConfigurationBuilder` to construct its
    /// configuration, starting from appropriate base configurations
    /// and applying specific customizations.
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // Get configuration for development
    /// let devConfig = ConfigurationPreset.fullFeatured.configuration
    ///
    /// // Get configuration for presentations
    /// let presentConfig = ConfigurationPreset.presentation.configuration
    /// ```
    ///
    /// - Returns: A complete `EditorConfiguration` instance.
    ///
    /// - SeeAlso: `EditorConfigurationBuilder` for configuration construction
    var configuration: EditorConfiguration {
        switch self {
        case .fullFeatured:
            return EditorConfigurationBuilder()
                .showLineNumbers(true)
                .showInvisibleCharacters(false)
                .highlightSelectedLine(true)
                .wrapLines(false)
                .isEditable(true)
                .autoIndent(true)
                .tabWidth(4)
                .insertSpacesForTabs(true)
                .fontSize(14)
                .lineSpacing(1.2)
                .enableAnnotations(true)
                .useHardwareAcceleration(true)
                .enableCodeCompletion(true)
                .enableSyntaxHighlighting(true)
                .build()

        case .minimal:
            return EditorConfigurationBuilder(base: .minimal)
                .fontSize(14)
                .lineSpacing(1.5)
                .wrapLines(true)
                .build()

        case .readOnly:
            return EditorConfigurationBuilder(base: .readOnly)
                .showLineNumbers(true)
                .fontSize(13)
                .lineSpacing(1.2)
                .enableAnnotations(true)
                .build()

        case .markdown:
            return EditorConfigurationBuilder(base: .markdown)
                .fontSize(16)
                .lineSpacing(1.6)
                .tabWidth(2)
                .build()

        case .presentation:
            return EditorConfigurationBuilder(base: .presentation)
                .fontSize(20)
                .lineSpacing(1.4)
                .build()
        }
    }
}
