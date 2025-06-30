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
public final class EditorConfigurationBuilder {
    // MARK: - Properties
    
    private var configuration = EditorConfiguration()
    
    // MARK: - Deinitialization
    
    deinit {
        // Clean up any resources if needed
    }
    
    // MARK: - Initialization
    
    /// Creates a new configuration builder with default settings
    public init() {}
    
    /// Creates a configuration builder starting from an existing configuration
    /// - Parameter base: The base configuration to start with
    public init(base: EditorConfiguration) {
        self.configuration = base
    }
    
    // MARK: - Display Settings
    
    /// Sets the font size for the editor
    /// - Parameter size: The font size in points (typically 10-24)
    /// - Returns: The builder for chaining
    @discardableResult
    public func fontSize(_ size: CGFloat) -> Self {
        var display = configuration.display
        display.fontSize = size
        configuration = configuration.with(display: display)
        return self
    }
    
    /// Controls whether line numbers are shown
    /// - Parameter show: Whether to show line numbers
    /// - Returns: The builder for chaining
    @discardableResult
    public func showLineNumbers(_ show: Bool) -> Self {
        var display = configuration.display
        display.showLineNumbers = show
        configuration = configuration.with(display: display)
        return self
    }
    
    /// Controls whether syntax highlighting is enabled
    /// - Parameter enabled: Whether to enable syntax highlighting
    /// - Returns: The builder for chaining
    @discardableResult
    public func enableSyntaxHighlighting(_ enabled: Bool) -> Self {
        var display = configuration.display
        display.enableSyntaxHighlighting = enabled
        configuration = configuration.with(display: display)
        return self
    }
    
    /// Controls whether the current line is highlighted
    /// - Parameter highlight: Whether to highlight the selected line
    /// - Returns: The builder for chaining
    @discardableResult
    public func highlightSelectedLine(_ highlight: Bool) -> Self {
        var display = configuration.display
        display.highlightSelectedLine = highlight
        configuration = configuration.with(display: display)
        return self
    }
    
    /// Controls whether annotations (TODO, FIXME, etc.) are shown
    /// - Parameter enabled: Whether to enable annotations
    /// - Returns: The builder for chaining
    @discardableResult
    public func enableAnnotations(_ enabled: Bool) -> Self {
        var display = configuration.display
        display.enableAnnotations = enabled
        configuration = configuration.with(display: display)
        return self
    }
    
    /// Controls whether invisible characters are shown
    /// - Parameter show: Whether to show invisible characters
    /// - Returns: The builder for chaining
    @discardableResult
    public func showInvisibleCharacters(_ show: Bool) -> Self {
        var display = configuration.display
        display.showInvisibleCharacters = show
        configuration = configuration.with(display: display)
        return self
    }
    
    // MARK: - Layout Settings
    
    /// Sets the tab width in spaces
    /// - Parameter width: The tab width (typically 2, 4, or 8)
    /// - Returns: The builder for chaining
    @discardableResult
    public func tabWidth(_ width: Int) -> Self {
        var layout = configuration.layout
        layout.tabWidth = width
        configuration = configuration.with(layout: layout)
        return self
    }
    
    /// Controls whether to insert spaces instead of tabs
    /// - Parameter insertSpaces: Whether to insert spaces for tabs
    /// - Returns: The builder for chaining
    @discardableResult
    public func insertSpacesForTabs(_ insertSpaces: Bool) -> Self {
        var layout = configuration.layout
        layout.insertSpacesForTabs = insertSpaces
        configuration = configuration.with(layout: layout)
        return self
    }
    
    /// Controls whether long lines are wrapped
    /// - Parameter wrap: Whether to wrap long lines
    /// - Returns: The builder for chaining
    @discardableResult
    public func wrapLines(_ wrap: Bool) -> Self {
        var layout = configuration.layout
        layout.wrapLines = wrap
        configuration = configuration.with(layout: layout)
        return self
    }
    
    /// Sets the line spacing multiplier
    /// - Parameter spacing: The line spacing multiplier (typically 1.0-1.5)
    /// - Returns: The builder for chaining
    @discardableResult
    public func lineSpacing(_ spacing: CGFloat) -> Self {
        var layout = configuration.layout
        layout.lineSpacing = spacing
        configuration = configuration.with(layout: layout)
        return self
    }
    
    // MARK: - Behavior Settings
    
    /// Controls whether the editor is editable
    /// - Parameter editable: Whether the editor is editable
    /// - Returns: The builder for chaining
    @discardableResult
    public func isEditable(_ editable: Bool) -> Self {
        var behavior = configuration.behavior
        behavior.isEditable = editable
        configuration = configuration.with(behavior: behavior)
        return self
    }
    
    /// Controls whether auto-indentation is enabled
    /// - Parameter enabled: Whether to enable auto-indentation
    /// - Returns: The builder for chaining
    @discardableResult
    public func autoIndent(_ enabled: Bool) -> Self {
        var behavior = configuration.behavior
        behavior.autoIndent = enabled
        configuration = configuration.with(behavior: behavior)
        return self
    }
    
    /// Controls whether code completion is enabled
    /// - Parameter enabled: Whether to enable code completion
    /// - Returns: The builder for chaining
    @discardableResult
    public func enableCodeCompletion(_ enabled: Bool) -> Self {
        var behavior = configuration.behavior
        behavior.enableCodeCompletion = enabled
        configuration = configuration.with(behavior: behavior)
        return self
    }
    
    /// Controls whether spell checking is enabled
    /// - Parameter enabled: Whether to enable spell checking
    /// - Returns: The builder for chaining
    @discardableResult
    public func enableSpellCheck(_ enabled: Bool) -> Self {
        var behavior = configuration.behavior
        behavior.isContinuousSpellCheckingEnabled = enabled
        configuration = configuration.with(behavior: behavior)
        return self
    }
    
    // MARK: - Performance Settings
    
    /// Controls whether hardware acceleration is used
    /// - Parameter enabled: Whether to use hardware acceleration
    /// - Returns: The builder for chaining
    @discardableResult
    public func useHardwareAcceleration(_ enabled: Bool) -> Self {
        var performance = configuration.performance
        performance.useHardwareAcceleration = enabled
        configuration = configuration.with(performance: performance)
        return self
    }
    
    /// Sets the maximum length for syntax highlighting
    /// - Parameter length: Maximum length for highlighting (0 = unlimited)
    /// - Returns: The builder for chaining
    @discardableResult
    public func maxHighlightingLength(_ length: Int) -> Self {
        var performance = configuration.performance
        performance.maxSyntaxHighlightingLength = length
        configuration = configuration.with(performance: performance)
        return self
    }
    
    // MARK: - Convenience Methods
    
    /// Applies a predefined theme
    /// - Parameter theme: The theme to apply
    /// - Returns: The builder for chaining
    @discardableResult
    public func theme(_ theme: EditorTheme) -> Self {
        switch theme {
        case .light:
            return enableSyntaxHighlighting(true)
                .highlightSelectedLine(true)
                .showLineNumbers(true)

        case .dark:
            return enableSyntaxHighlighting(true)
                .highlightSelectedLine(true)
                .showLineNumbers(true)

        case .minimal:
            return enableSyntaxHighlighting(false)
                .highlightSelectedLine(false)
                .showLineNumbers(false)
                .enableAnnotations(false)
        }
    }
    
    /// Configures the editor for a specific language
    /// - Parameter language: The language to optimize for
    /// - Returns: The builder for chaining
    @discardableResult
    public func language(_ language: LanguageType) -> Self {
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

        case .javascript:
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
    public func build() -> EditorConfiguration {
        configuration
    }
}

// MARK: - Supporting Types

/// Predefined editor themes
public enum EditorTheme {
    case light
    case dark
    case minimal
}

/// Simplified language types for configuration
public enum LanguageType {
    case swift
    case python
    case javascript
    case markdown
    case plainText
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
            .theme(.dark)
            .fontSize(14)
            .build()
    }
    
    /// Quick configuration for web development
    /// - Returns: A configuration optimized for web development
    public static func web() -> EditorConfiguration {
        EditorConfigurationBuilder()
            .language(.javascript)
            .theme(.dark)
            .fontSize(14)
            .tabWidth(2)
            .build()
    }
    
    /// Quick configuration for Python development
    /// - Returns: A configuration optimized for Python development
    public static func python() -> EditorConfiguration {
        EditorConfigurationBuilder()
            .language(.python)
            .theme(.dark)
            .fontSize(14)
            .build()
    }
    
    /// Quick configuration for documentation editing
    /// - Returns: A configuration optimized for documentation
    public static func documentation() -> EditorConfiguration {
        EditorConfigurationBuilder()
            .language(.markdown)
            .theme(.light)
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
