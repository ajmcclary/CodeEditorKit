import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
  import AppKit
#elseif canImport(UIKit)
  import UIKit
#endif

#if canImport(SwiftUI)
  import SwiftUI
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

  private var configuration: EditorConfiguration

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
  public init() {
    self.configuration = EditorConfiguration()
  }

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

  // MARK: - Private Helper

  /// Creates a new builder with the modified configuration
  private func with(_ modifier: (inout EditorConfiguration) -> Void) -> Self {
    var copy = self
    modifier(&copy.configuration)
    return copy
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
    with { $0.display.fontSize = size }
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
    with { $0.display.showLineNumbers = show }
  }

  /// Controls whether syntax highlighting is enabled
  /// - Parameter enabled: Whether to enable syntax highlighting
  /// - Returns: The builder for chaining
  @discardableResult
  public func enableSyntaxHighlighting(_ enabled: Bool) -> Self {
    with { $0.display.enableSyntaxHighlighting = enabled }
  }

  /// Controls whether the current line is highlighted
  /// - Parameter highlight: Whether to highlight the selected line
  /// - Returns: The builder for chaining
  @discardableResult
  public func highlightSelectedLine(_ highlight: Bool) -> Self {
    with { $0.display.highlightSelectedLine = highlight }
  }

  /// Sets the color used to highlight the selected line
  /// - Parameter color: The color to use for highlighting the selected line
  /// - Returns: The builder for chaining
  @discardableResult
  public func selectedLineHighlightColor(_ color: PlatformColor) -> Self {
    with { $0.display.selectedLineHighlightColor = color }
  }

  /// Controls whether annotations (TODO, FIXME, etc.) are shown
  /// - Parameter enabled: Whether to enable annotations
  /// - Returns: The builder for chaining
  @discardableResult
  public func enableAnnotations(_ enabled: Bool) -> Self {
    with { $0.display.enableAnnotations = enabled }
  }

  /// Controls whether invisible characters are shown
  /// - Parameter show: Whether to show invisible characters
  /// - Returns: The builder for chaining
  @discardableResult
  public func showInvisibleCharacters(_ show: Bool) -> Self {
    with { $0.display.showInvisibleCharacters = show }
  }

  /// Controls whether to show the minimap
  /// - Parameter show: Whether to show the minimap
  /// - Returns: The builder for chaining
  @discardableResult
  public func showMinimap(_ show: Bool) -> Self {
    with { $0.display.showMinimap = show }
  }

  /// Controls whether code folding is enabled
  /// - Parameter enable: Whether to enable code folding
  /// - Returns: The builder for chaining
  @discardableResult
  public func enableCodeFolding(_ enable: Bool) -> Self {
    with { $0.display.enableCodeFolding = enable }
  }

  /// Controls whether folding controls are shown in the gutter
  /// - Parameter show: Whether to show folding controls
  /// - Returns: The builder for chaining
  @discardableResult
  public func showFoldingControls(_ show: Bool) -> Self {
    with { $0.display.showFoldingControls = show }
  }

  // MARK: - Layout Settings

  /// Sets the tab width in spaces
  /// - Parameter width: The tab width (typically 2, 4, or 8)
  /// - Returns: The builder for chaining
  @discardableResult
  public func tabWidth(_ width: Int) -> Self {
    with { $0.layout.tabWidth = width }
  }

  /// Controls whether to insert spaces instead of tabs
  /// - Parameter insertSpaces: Whether to insert spaces for tabs
  /// - Returns: The builder for chaining
  @discardableResult
  public func insertSpacesForTabs(_ insertSpaces: Bool) -> Self {
    with { $0.layout.insertSpacesForTabs = insertSpaces }
  }

  /// Controls whether long lines are wrapped
  /// - Parameter wrap: Whether to wrap long lines
  /// - Returns: The builder for chaining
  @discardableResult
  public func wrapLines(_ wrap: Bool) -> Self {
    with { $0.layout.wrapLines = wrap }
  }

  /// Sets the line spacing multiplier
  /// - Parameter spacing: The line spacing multiplier (typically 1.0-1.5)
  /// - Returns: The builder for chaining
  @discardableResult
  public func lineSpacing(_ spacing: CGFloat) -> Self {
    with { $0.layout.lineHeightMultiple = spacing }
  }

  // MARK: - Behavior Settings

  /// Controls whether the editor is editable
  /// - Parameter editable: Whether the editor is editable
  /// - Returns: The builder for chaining
  @discardableResult
  public func isEditable(_ editable: Bool) -> Self {
    with { $0.behavior.isEditable = editable }
  }

  /// Controls whether auto-indentation is enabled
  /// - Parameter enabled: Whether to enable auto-indentation
  /// - Returns: The builder for chaining
  @discardableResult
  public func autoIndent(_ enabled: Bool) -> Self {
    with { $0.behavior.autoIndent = enabled }
  }

  /// Controls whether code completion is enabled
  /// - Parameter enabled: Whether to enable code completion
  /// - Returns: The builder for chaining
  @discardableResult
  public func enableCodeCompletion(_ enabled: Bool) -> Self {
    with { $0.behavior.enableCodeCompletion = enabled }
  }

  /// Controls whether spell checking is enabled
  /// - Parameter enabled: Whether to enable spell checking
  /// - Returns: The builder for chaining
  @discardableResult
  public func enableSpellCheck(_ enabled: Bool) -> Self {
    with { $0.behavior.isContinuousSpellCheckingEnabled = enabled }
  }

  // MARK: - Performance Settings

  /// Controls whether hardware acceleration is used
  /// - Parameter enabled: Whether to use hardware acceleration
  /// - Returns: The builder for chaining
  @discardableResult
  public func useHardwareAcceleration(_ enabled: Bool) -> Self {
    with { $0.performance.useHardwareAcceleration = enabled }
  }

  /// Sets the maximum length for syntax highlighting
  /// - Parameter length: Maximum length for highlighting (0 = unlimited)
  /// - Returns: The builder for chaining
  @discardableResult
  public func maxHighlightingLength(_ length: Int) -> Self {
    with { $0.performance.maxSyntaxHighlightingLength = length }
  }

  // MARK: - Language Configuration

  /// Language-specific configuration settings
  private struct LanguageSettings {
    let syntaxHighlighting: Bool
    let codeCompletion: Bool
    let autoIndent: Bool
    let tabWidth: Int
    let insertSpacesForTabs: Bool
    let wrapLines: Bool
    let enableSpellCheck: Bool
  }

  /// Base language settings for code languages
  private static let baseCodeSettings = LanguageSettings(
    syntaxHighlighting: true,
    codeCompletion: true,
    autoIndent: true,
    tabWidth: 4,
    insertSpacesForTabs: true,
    wrapLines: false,
    enableSpellCheck: false
  )
  
  /// Base language settings for document languages
  private static let baseDocumentSettings = LanguageSettings(
    syntaxHighlighting: true,
    codeCompletion: false,
    autoIndent: false,
    tabWidth: 4,
    insertSpacesForTabs: true,
    wrapLines: true,
    enableSpellCheck: true
  )
  
  /// Helper to create language settings with custom overrides
  private static func createSettings(
    base: LanguageSettings,
    tabWidth: Int? = nil,
    insertSpacesForTabs: Bool? = nil, // swiftlint:disable:this discouraged_optional_boolean
    syntaxHighlighting: Bool? = nil // swiftlint:disable:this discouraged_optional_boolean
  ) -> LanguageSettings {
    LanguageSettings(
      syntaxHighlighting: syntaxHighlighting ?? base.syntaxHighlighting,
      codeCompletion: base.codeCompletion,
      autoIndent: base.autoIndent,
      tabWidth: tabWidth ?? base.tabWidth,
      insertSpacesForTabs: insertSpacesForTabs ?? base.insertSpacesForTabs,
      wrapLines: base.wrapLines,
      enableSpellCheck: base.enableSpellCheck
    )
  }
  
  /// Default language configurations
  private static let languageSettings: [Language: LanguageSettings] = {
    var settings: [Language: LanguageSettings] = [:]
    
    // Standard 4-space languages with spaces
    let fourSpaceLanguages: [Language] = [.swift, .python, .java, .sql, .ruby, .php, .shell]
    for language in fourSpaceLanguages {
      settings[language] = baseCodeSettings
    }
    
    // 2-space languages
    let twoSpaceLanguages: [Language] = [.javascript, .typescript, .html, .css, .xml, .json, .yaml]
    for language in twoSpaceLanguages {
      settings[language] = createSettings(base: baseCodeSettings, tabWidth: 2)
    }
    
    // Tab languages
    let tabLanguages: [Language] = [.go, .rust, .c, .cpp]
    for language in tabLanguages {
      settings[language] = createSettings(base: baseCodeSettings, insertSpacesForTabs: false)
    }
    
    // Document languages
    settings[.markdown] = baseDocumentSettings
    settings[.plainText] = createSettings(base: baseDocumentSettings, syntaxHighlighting: false)
    
    return settings
  }()

  // MARK: - Convenience Methods

  /// Configures the editor for a specific language
  /// - Parameter language: The language to optimize for
  /// - Returns: The builder for chaining
  @discardableResult
  public func language(_ language: Language) -> Self {
    guard let settings = Self.languageSettings[language] else {
      // Default settings for unknown languages
      return enableSyntaxHighlighting(true)
        .enableCodeCompletion(true)
        .autoIndent(true)
        .tabWidth(4)
        .insertSpacesForTabs(true)
    }

    var builder = self
    builder = builder.enableSyntaxHighlighting(settings.syntaxHighlighting)
    builder = builder.enableCodeCompletion(settings.codeCompletion)
    builder = builder.autoIndent(settings.autoIndent)
    builder = builder.tabWidth(settings.tabWidth)
    builder = builder.insertSpacesForTabs(settings.insertSpacesForTabs)

    if settings.wrapLines {
      builder = builder.wrapLines(settings.wrapLines)
    }

    if settings.enableSpellCheck {
      builder = builder.enableSpellCheck(settings.enableSpellCheck)
    }

    return builder
  }

  /// Configures the editor with a predefined theme
  /// - Parameter theme: The theme to apply (.default, .dark, or custom)
  /// - Returns: The builder for chaining
  @discardableResult
  public func theme(_ theme: CodeEditorSwiftUITheme) -> Self {
    // Note: CodeEditorSwiftUITheme provides colors for SwiftUI environment
    // The actual theme colors are applied through the syntax highlighting system
    // This method configures the editor to match the theme's style

    var builder = self

    // Apply dark theme specific settings
    if theme.name == "dark" {
      builder = builder
        .highlightSelectedLine(true)
        .enableSyntaxHighlighting(true)
    } else if theme.name == "default" {
      builder = builder
        .highlightSelectedLine(true)
        .enableSyntaxHighlighting(true)
    }

    // Note: Background and text colors are handled by the platform-specific
    // views based on the system appearance and the syntax highlighting theme

    return builder
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
    // Validate and auto-fix any issues
    var finalConfig = configuration
    let validator = ConfigurationValidator()
    _ = validator.autoFix(&finalConfig)
    
    return finalConfig
  }
  
  /// Build the configuration with validation feedback.
  ///
  /// This method returns both the final configuration and any validation fixes that were applied.
  /// Use this when you need to know if any configuration values were adjusted during validation.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let (config, fixes) = EditorConfigurationBuilder()
  ///     .fontSize(200) // Too large
  ///     .buildWithFeedback()
  ///
  /// if !fixes.isEmpty {
  ///     for fix in fixes {
  ///         logger.debug("Fixed \(fix.issue.path): \(fix.oldValue ?? "nil") -> \(fix.newValue)")
  ///     }
  /// }
  /// ```
  ///
  /// - Returns: A tuple containing the final configuration and any validation fixes applied
  public func buildWithFeedback() -> (configuration: EditorConfiguration, fixes: [ValidationFix]) {
    // Validate and auto-fix any issues
    var finalConfig = configuration
    let validator = ConfigurationValidator()
    let fixes = validator.autoFix(&finalConfig)
    
    return (finalConfig, fixes)
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
