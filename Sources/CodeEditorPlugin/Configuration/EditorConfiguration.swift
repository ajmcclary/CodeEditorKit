import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Comprehensive configuration system for customizing code editor behavior and appearance.
///
/// `EditorConfiguration` provides a structured, type-safe way to configure all aspects of the code editor.
/// The configuration is organized into four main categories:
///
/// - **Layout**: Text formatting, spacing, and visual layout
/// - **Display**: Visual elements like syntax highlighting, line numbers, and annotations
/// - **Behavior**: Editing behavior, auto-completion, and text processing
/// - **Performance**: Optimization settings and resource limits
///
/// ## Basic Usage
///
/// ```swift
/// var config = EditorConfiguration()
/// config.display.fontSize = 16
/// config.display.syntaxHighlighting = true
/// config.layout.tabWidth = 4
/// config.behavior.autoIndent = true
/// 
/// // Apply to an editor
/// config.apply(to: editor)
/// ```
///
/// ## Preset Configurations
///
/// Use built-in presets for common scenarios:
///
/// ```swift
/// let readOnly = EditorConfiguration.readOnly        // For display-only
/// let minimal = EditorConfiguration.minimal          // Lightweight editing
/// let markdown = EditorConfiguration.markdown        // Markdown optimized
/// let presentation = EditorConfiguration.presentation // Presentation mode
/// ```
///
/// ## Immutable Updates
///
/// Use the `with()` methods for immutable configuration updates:
///
/// ```swift
/// let newConfig = config.with(display: modifiedDisplay)
///                      .with(layout: modifiedLayout)
/// ```
///
/// ## Builder Pattern
///
/// Use `EditorConfigurationBuilder` for fluent configuration:
///
/// ```swift
/// let config = EditorConfigurationBuilder()
///     .showLineNumbers(true)
///     .fontSize(16)
///     .tabWidth(4)
///     .wrapLines(false)
///     .build()
/// ```
///
/// ## Validation
///
/// Validate configuration before applying:
///
/// ```swift
/// let errors = config.validate()
/// if errors.isEmpty {
///     config.apply(to: editor)
/// } else {
///     // Handle configuration errors appropriately
///     logger.error("Configuration errors: \(errors)")
/// }
/// 
/// // Or throw on validation failure
/// try config.validateAndThrow()
/// ```
///
/// ## Performance Considerations
///
/// - Large `maxHighlightingLength` values may impact performance
/// - Hardware acceleration is enabled by default when available
/// - Adjust `textChangeDebounceInterval` for responsive vs. efficient highlighting
/// - Use read-only presets for display scenarios to optimize performance
public struct EditorConfiguration: Equatable, Codable, Sendable {
    // MARK: - Nested Configuration Structures
    // See separate files:
    // - EditorConfiguration+Display.swift
    // - EditorConfiguration+Layout.swift
    // - EditorConfiguration+Behavior.swift  
    // - EditorConfiguration+Performance.swift
    
    // MARK: - Configuration Properties
    
    /// Layout configuration
    public var layout = Layout()
    
    /// Display configuration
    public var display = Display()
    
    /// Behavior configuration
    public var behavior = Behavior()
    
    /// Performance configuration
    public var performance = Performance()
    
    // MARK: - Initialization
    
    public init() {}
    
    public init(layout: Layout = Layout(), display: Display = Display(), behavior: Behavior = Behavior(), performance: Performance = Performance()) {
        self.layout = layout
        self.display = display
        self.behavior = behavior
        self.performance = performance
    }
    
    // MARK: - Convenience Methods
    
    /// Create a new configuration with updated layout
    public func with(layout: Layout) -> Self {
        Self(layout: layout, display: display, behavior: behavior, performance: performance)
    }
    
    /// Create a new configuration with updated display
    public func with(display: Display) -> Self {
        Self(layout: layout, display: display, behavior: behavior, performance: performance)
    }
    
    /// Create a new configuration with updated behavior
    public func with(behavior: Behavior) -> Self {
        Self(layout: layout, display: display, behavior: behavior, performance: performance)
    }
    
    /// Create a new configuration with updated performance
    public func with(performance: Performance) -> Self {
        Self(layout: layout, display: display, behavior: behavior, performance: performance)
    }
    
    // MARK: - Validation
    
    /// Validate the configuration and return any validation errors
    public func validate() -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Validate display settings
        if display.fontSize <= 0 {
            errors.append(ValidationError(field: "display.fontSize", value: display.fontSize, constraint: "must be greater than 0"))
        }
        if display.fontSize > 100 {
            errors.append(ValidationError(field: "display.fontSize", value: display.fontSize, constraint: "must be 100 or less"))
        }
        
        // Validate layout settings
        if layout.tabWidth <= 0 {
            errors.append(ValidationError(field: "layout.tabWidth", value: layout.tabWidth, constraint: "must be greater than 0"))
        }
        if layout.tabWidth > 32 {
            errors.append(ValidationError(field: "layout.tabWidth", value: layout.tabWidth, constraint: "must be 32 or less"))
        }
        
        if layout.lineHeightMultiple < 0 {
            errors.append(ValidationError(field: "layout.lineSpacing", value: layout.lineHeightMultiple, constraint: "must be 0 or greater"))
        }
        if layout.lineHeightMultiple > 50 {
            errors.append(ValidationError(field: "layout.lineSpacing", value: layout.lineHeightMultiple, constraint: "must be 50 or less"))
        }
        
        if layout.gutterWidth < 0 {
            errors.append(ValidationError(field: "layout.gutterWidth", value: layout.gutterWidth, constraint: "must be 0 or greater"))
        }
        
        // Validate performance settings
        if performance.maxSyntaxHighlightingLength < 0 {
            errors.append(ValidationError(field: "performance.maxSyntaxHighlightingLength", value: performance.maxSyntaxHighlightingLength, constraint: "must be 0 or greater"))
        }
        
        if performance.textChangeDebounceInterval < Duration.zero {
            errors.append(ValidationError(field: "performance.textChangeDebounceInterval", value: performance.textChangeDebounceInterval.timeInterval, constraint: "must be 0 or greater"))
        }
        if performance.textChangeDebounceInterval > Duration.seconds(5) {
            errors.append(ValidationError(field: "performance.textChangeDebounceInterval", value: performance.textChangeDebounceInterval.timeInterval, constraint: "must be 5 seconds or less"))
        }
        
        return errors
    }
    
    /// Validate the configuration and throw an error if invalid
    public func validateAndThrow() throws {
        let errors = validate()
        if !errors.isEmpty {
            throw CodeEditorError.configurationValidationFailed(errors)
        }
    }
    
    // MARK: - Configuration Application
    
    /// Apply configuration to a CodeEditorView.
    ///
    /// Updates the editor view with all settings from this configuration.
    /// This method handles platform-specific differences and ensures all
    /// configuration options are properly applied.
    ///
    /// ## What Gets Applied
    ///
    /// - Display settings (font size, line numbers, syntax highlighting)
    /// - Layout settings (tab width, line spacing, gutter width)
    /// - Behavior settings (editability, auto-indent, completion)
    /// - Performance settings (hardware acceleration, debouncing)
    /// - Platform-specific text input features
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = EditorConfiguration.minimal
    /// config.apply(to: editorView)
    /// 
    /// // Or apply directly via the property
    /// editorView.configuration = config
    /// ```
    ///
    /// - Parameter view: The CodeEditorView to configure
    ///
    /// - Note: Setting the view's `configuration` property directly also
    ///         triggers this method internally.
    ///
    /// - SeeAlso: ``CodeEditorView/configuration``
    @MainActor public func apply(to view: CodeEditorView) {
        // Set the view's configuration property which will trigger applyConfiguration()
        // This will apply all the settings internally
        view.configuration = self
        
        // Apply cross-platform text input features that aren't handled by applyConfiguration
        applyTextInputFeatures(to: view)
    }
    
    /// Create a CodeFoldingConfiguration from this EditorConfiguration.
    ///
    /// Maps the code folding settings from this EditorConfiguration to a
    /// CodeFoldingConfiguration that can be used by the CodeFoldingEngine.
    ///
    /// - Returns: A configured CodeFoldingConfiguration instance
    internal func createCodeFoldingConfiguration() -> CodeFoldingConfiguration {
        var config = CodeFoldingConfiguration()
        config.enabled = display.enableCodeFolding
        config.showGutterControls = display.showFoldingControls
        config.minimumLineCount = display.minimumFoldableLines
        config.animatesFolding = performance.animateCodeFolding
        return config
    }
}
