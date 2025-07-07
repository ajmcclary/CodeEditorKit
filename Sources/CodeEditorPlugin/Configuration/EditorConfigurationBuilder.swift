import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - EditorConfigurationBuilder

/// A fluent builder for creating EditorConfiguration instances with a simplified API
/// 
/// This builder provides a more approachable way to configure the code editor
/// without needing to understand the full nested structure of EditorConfiguration.
///
/// ## Example Usage
///
/// ```swift
/// let config = EditorConfigurationBuilder()
///     .fontSize(16)
///     .showLineNumbers(true)
///     .tabWidth(4)
///     .theme(.dark)
///     .language(.swift)
///     .enableSyntaxHighlighting(true)
///     .build()
/// 
/// editor.configuration = config
/// ```
public struct EditorConfigurationBuilder {
    // MARK: - Properties
    
    private var configuration = EditorConfiguration()
    
    // MARK: - Generic Setters
    
    /// Generic method to set display configuration values
    private func withDisplay<T>(_ keyPath: WritableKeyPath<EditorConfiguration.Display, T>, value: T) -> Self {
        var display = configuration.display
        display[keyPath: keyPath] = value
        var newConfig = configuration
        newConfig = newConfig.with(display: display)
        var newBuilder = self
        newBuilder.configuration = newConfig
        return newBuilder
    }
    
    /// Generic method to set layout configuration values
    private func withLayout<T>(_ keyPath: WritableKeyPath<EditorConfiguration.Layout, T>, value: T) -> Self {
        var layout = configuration.layout
        layout[keyPath: keyPath] = value
        var newConfig = configuration
        newConfig = newConfig.with(layout: layout)
        var newBuilder = self
        newBuilder.configuration = newConfig
        return newBuilder
    }
    
    /// Generic method to set behavior configuration values
    private func withBehavior<T>(_ keyPath: WritableKeyPath<EditorConfiguration.Behavior, T>, value: T) -> Self {
        var behavior = configuration.behavior
        behavior[keyPath: keyPath] = value
        var newConfig = configuration
        newConfig = newConfig.with(behavior: behavior)
        var newBuilder = self
        newBuilder.configuration = newConfig
        return newBuilder
    }
    
    /// Generic method to set performance configuration values
    private func withPerformance<T>(_ keyPath: WritableKeyPath<EditorConfiguration.Performance, T>, value: T) -> Self {
        var performance = configuration.performance
        performance[keyPath: keyPath] = value
        var newConfig = configuration
        newConfig = newConfig.with(performance: performance)
        var newBuilder = self
        newBuilder.configuration = newConfig
        return newBuilder
    }
    
    // MARK: - Initialization
    
    /// Creates a new configuration builder with default settings.
    ///
    /// The builder starts with `EditorConfiguration.default` settings which can
    /// be customized using the fluent API methods.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = EditorConfigurationBuilder()
    ///     .fontSize(14)
    ///     .showLineNumbers(true)
    ///     .build()
    /// ```
    public init() {}
    
    /// Creates a configuration builder starting from an existing configuration.
    ///
    /// Use this initializer to create variations of existing configurations or
    /// to modify preset configurations.
    ///
    /// - Parameter base: The base configuration to start with
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Start with a preset and customize
    /// let config = EditorConfigurationBuilder(base: .minimal)
    ///     .fontSize(16)
    ///     .enableSyntaxHighlighting(true)
    ///     .build()
    /// 
    /// // Create a variation of existing config
    /// let darkModeConfig = EditorConfigurationBuilder(base: currentConfig)
    ///     .theme(.dark)
    ///     .build()
    /// ```
    public init(base: EditorConfiguration) {
        self.configuration = base
    }
    
    // MARK: - Display Settings
    
    /// Sets the font size for the editor.
    ///
    /// The font size affects all text in the editor including line numbers.
    /// The editor uses the system's monospaced font at the specified size.
    ///
    /// - Parameter size: The font size in points (recommended: 10-24)
    /// - Returns: The builder instance for method chaining
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = EditorConfigurationBuilder()
    ///     .fontSize(16)     // Comfortable reading size
    ///     .fontSize(12)     // Compact view
    ///     .fontSize(20)     // Presentation mode
    ///     .build()
    /// ```
    ///
    /// - Note: Font sizes outside 8-72 range will trigger validation warnings
    @discardableResult
    public func fontSize(_ size: CGFloat) -> Self {
        withDisplay(\.fontSize, value: size)
    }
    
    /// Controls whether line numbers are shown in the gutter.
    ///
    /// Line numbers help with navigation, debugging, and code discussion.
    /// They appear in a separate gutter area that doesn't scroll horizontally.
    ///
    /// - Parameter show: `true` to show line numbers, `false` to hide them
    /// - Returns: The builder instance for method chaining
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = EditorConfigurationBuilder()
    ///     .showLineNumbers(true)   // Default for most code editing
    ///     .showLineNumbers(false)  // Clean view for markdown or notes
    ///     .build()
    /// ```
    ///
    /// - SeeAlso: `gutterWidth(_:)` for customizing gutter size
    @discardableResult
    public func showLineNumbers(_ show: Bool) -> Self {
        withDisplay(\.showLineNumbers, value: show)
    }
    
    /// Controls whether syntax highlighting is enabled
    /// - Parameter enabled: Whether to enable syntax highlighting
    /// - Returns: The builder for chaining
    @discardableResult
    public func enableSyntaxHighlighting(_ enabled: Bool) -> Self {
        withDisplay(\.enableSyntaxHighlighting, value: enabled)
    }
    
    /// Controls whether the current line is highlighted
    /// - Parameter highlight: Whether to highlight the selected line
    /// - Returns: The builder for chaining
    @discardableResult
    public func highlightSelectedLine(_ highlight: Bool) -> Self {
        withDisplay(\.highlightSelectedLine, value: highlight)
    }
    
    /// Sets the color used to highlight the selected line
    /// - Parameter color: The color to use for highlighting the selected line
    /// - Returns: The builder for chaining
    @discardableResult
    public func selectedLineHighlightColor(_ color: PlatformColor) -> Self {
        withDisplay(\.selectedLineHighlightColor, value: color)
    }
    
    /// Controls whether annotations (TODO, FIXME, etc.) are shown
    /// - Parameter enabled: Whether to enable annotations
    /// - Returns: The builder for chaining
    @discardableResult
    public func enableAnnotations(_ enabled: Bool) -> Self {
        withDisplay(\.enableAnnotations, value: enabled)
    }
    
    /// Controls whether invisible characters are shown
    /// - Parameter show: Whether to show invisible characters
    /// - Returns: The builder for chaining
    @discardableResult
    public func showInvisibleCharacters(_ show: Bool) -> Self {
        withDisplay(\.showInvisibleCharacters, value: show)
    }
    
    // MARK: - Layout Settings
    
    /// Sets the tab width in spaces
    /// - Parameter width: The tab width (typically 2, 4, or 8)
    /// - Returns: The builder for chaining
    @discardableResult
    public func tabWidth(_ width: Int) -> Self {
        withLayout(\.tabWidth, value: width)
    }
    
    /// Controls whether to insert spaces instead of tabs
    /// - Parameter insertSpaces: Whether to insert spaces for tabs
    /// - Returns: The builder for chaining
    @discardableResult
    public func insertSpacesForTabs(_ insertSpaces: Bool) -> Self {
        withLayout(\.insertSpacesForTabs, value: insertSpaces)
    }
    
    /// Controls whether long lines are wrapped
    /// - Parameter wrap: Whether to wrap long lines
    /// - Returns: The builder for chaining
    @discardableResult
    public func wrapLines(_ wrap: Bool) -> Self {
        withLayout(\.wrapLines, value: wrap)
    }
    
    /// Sets the line spacing multiplier
    /// - Parameter spacing: The line spacing multiplier (typically 1.0-1.5)
    /// - Returns: The builder for chaining
    @discardableResult
    public func lineSpacing(_ spacing: CGFloat) -> Self {
        withLayout(\.lineSpacing, value: spacing)
    }
    
    // MARK: - Behavior Settings
    
    /// Controls whether the editor is editable
    /// - Parameter editable: Whether the editor is editable
    /// - Returns: The builder for chaining
    @discardableResult
    public func isEditable(_ editable: Bool) -> Self {
        withBehavior(\.isEditable, value: editable)
    }
    
    /// Controls whether auto-indentation is enabled
    /// - Parameter enabled: Whether to enable auto-indentation
    /// - Returns: The builder for chaining
    @discardableResult
    public func autoIndent(_ enabled: Bool) -> Self {
        withBehavior(\.autoIndent, value: enabled)
    }
    
    /// Controls whether code completion is enabled
    /// - Parameter enabled: Whether to enable code completion
    /// - Returns: The builder for chaining
    @discardableResult
    public func enableCodeCompletion(_ enabled: Bool) -> Self {
        withBehavior(\.enableCodeCompletion, value: enabled)
    }
    
    /// Controls whether spell checking is enabled
    /// - Parameter enabled: Whether to enable spell checking
    /// - Returns: The builder for chaining
    @discardableResult
    public func enableSpellCheck(_ enabled: Bool) -> Self {
        withBehavior(\.isContinuousSpellCheckingEnabled, value: enabled)
    }
    
    // MARK: - Performance Settings
    
    /// Controls whether hardware acceleration is used
    /// - Parameter enabled: Whether to use hardware acceleration
    /// - Returns: The builder for chaining
    @discardableResult
    public func useHardwareAcceleration(_ enabled: Bool) -> Self {
        withPerformance(\.useHardwareAcceleration, value: enabled)
    }
    
    /// Sets the maximum length for syntax highlighting
    /// - Parameter length: Maximum length for highlighting (0 = unlimited)
    /// - Returns: The builder for chaining
    @discardableResult
    public func maxHighlightingLength(_ length: Int) -> Self {
        withPerformance(\.maxSyntaxHighlightingLength, value: length)
    }
    
    // MARK: - Convenience Methods
    
    /// Configures the editor for a specific language
    /// - Parameter language: The language to optimize for
    /// - Returns: The builder for chaining
    @discardableResult
    public func language(_ language: Language) -> Self {
        switch language {
        case .swift:
            return enableSyntaxHighlighting(true)
                .enableCodeCompletion(true)
                .autoIndent(true)
                .tabWidth(4)
                .insertSpacesForTabs(true)

        case .python:
            return enableSyntaxHighlighting(true)
                .enableCodeCompletion(true)
                .autoIndent(true)
                .tabWidth(4)
                .insertSpacesForTabs(true)

        case .javascript, .typescript:
            return enableSyntaxHighlighting(true)
                .enableCodeCompletion(true)
                .autoIndent(true)
                .tabWidth(2)
                .insertSpacesForTabs(true)

        case .markdown:
            return enableSyntaxHighlighting(true)
                .enableCodeCompletion(false)
                .autoIndent(false)
                .wrapLines(true)
                .enableSpellCheck(true)

        case .plainText:
            return enableSyntaxHighlighting(false)
                .enableCodeCompletion(false)
                .autoIndent(false)
                .wrapLines(true)
                .enableSpellCheck(true)
                
        case .go, .rust, .c, .cpp:
            return enableSyntaxHighlighting(true)
                .enableCodeCompletion(true)
                .autoIndent(true)
                .tabWidth(4)
                .insertSpacesForTabs(false)
                
        case .java:
            return enableSyntaxHighlighting(true)
                .enableCodeCompletion(true)
                .autoIndent(true)
                .tabWidth(4)
                .insertSpacesForTabs(true)
                
        case .html, .css, .xml:
            return enableSyntaxHighlighting(true)
                .enableCodeCompletion(true)
                .autoIndent(true)
                .tabWidth(2)
                .insertSpacesForTabs(true)
                
        case .json, .yaml:
            return enableSyntaxHighlighting(true)
                .enableCodeCompletion(true)
                .autoIndent(true)
                .tabWidth(2)
                .insertSpacesForTabs(true)
                
        case .sql, .ruby, .php, .shell:
            return enableSyntaxHighlighting(true)
                .enableCodeCompletion(true)
                .autoIndent(true)
                .tabWidth(4)
                .insertSpacesForTabs(true)
        }
    }
    
    /// Configures the editor for presentation mode
    /// - Returns: The builder for chaining
    @discardableResult
    public func presentationMode() -> Self {
        fontSize(18)
            .showLineNumbers(false)
            .enableAnnotations(false)
            .highlightSelectedLine(false)
            .wrapLines(true)
    }
    
    /// Configures the editor for code review
    /// - Returns: The builder for chaining
    @discardableResult
    public func codeReviewMode() -> Self {
        isEditable(false)
            .showLineNumbers(true)
            .enableAnnotations(true)
            .highlightSelectedLine(true)
            .enableSyntaxHighlighting(true)
    }
    
    // MARK: - Build
    
    /// Builds the final EditorConfiguration
    /// - Returns: The configured EditorConfiguration instance
    /// Builds and returns the final EditorConfiguration.
    ///
    /// Call this method after chaining all desired configuration methods to get
    /// the final configuration object that can be applied to a CodeEditorView.
    ///
    /// - Returns: The configured EditorConfiguration instance
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = EditorConfigurationBuilder()
    ///     .fontSize(14)
    ///     .showLineNumbers(true)
    ///     .tabWidth(4)
    ///     .theme(.monokai)
    ///     .language(.python)
    ///     .build()  // Returns the final configuration
    /// 
    /// // Apply to editor
    /// editor.configuration = config
    /// 
    /// // Or apply directly
    /// config.apply(to: editor)
    /// ```
    ///
    /// - Note: The configuration is automatically validated when applied to an editor
    ///
    /// - SeeAlso: `EditorConfiguration.validate()`, `EditorConfiguration.apply(to:)`
    public func build() -> EditorConfiguration {
        configuration
    }
}

// MARK: - Convenience Extensions

extension EditorConfiguration {
    /// Creates a new configuration builder
    /// - Returns: A new EditorConfigurationBuilder
    public static func builder() -> EditorConfigurationBuilder {
        EditorConfigurationBuilder()
    }
    
    /// Creates a configuration builder starting from this configuration
    /// - Returns: A new EditorConfigurationBuilder with this configuration as base
    public func builder() -> EditorConfigurationBuilder {
        EditorConfigurationBuilder(base: self)
    }
}

// MARK: - Quick Configuration Methods

extension EditorConfigurationBuilder {
    /// Quick configuration for Swift development
    /// - Returns: A configuration optimized for Swift development
    public static func swift() -> EditorConfiguration {
        EditorConfigurationBuilder()
            .language(.swift)
            .fontSize(14)
            .build()
    }
    
    /// Quick configuration for web development
    /// - Returns: A configuration optimized for web development
    public static func web() -> EditorConfiguration {
        EditorConfigurationBuilder()
            .language(.javascript)
            .fontSize(14)
            .tabWidth(2)
            .build()
    }
    
    /// Quick configuration for Python development
    /// - Returns: A configuration optimized for Python development
    public static func python() -> EditorConfiguration {
        EditorConfigurationBuilder()
            .language(.python)
            .fontSize(14)
            .build()
    }
    
    /// Quick configuration for documentation editing
    /// - Returns: A configuration optimized for documentation
    public static func documentation() -> EditorConfiguration {
        EditorConfigurationBuilder()
            .language(.markdown)
            .fontSize(16)
            .wrapLines(true)
            .enableSpellCheck(true)
            .build()
    }
    
    /// Quick configuration for read-only viewing
    /// - Returns: A configuration optimized for viewing code
    public static func readOnly() -> EditorConfiguration {
        EditorConfigurationBuilder()
            .codeReviewMode()
            .fontSize(14)
            .build()
    }
}
