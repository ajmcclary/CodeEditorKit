import Foundation

#if canImport(SwiftUI)
  import SwiftUI
#endif

// MARK: - Convenience Methods

extension EditorConfigurationBuilder {
  /// Configures the editor with a predefined theme
  ///
  /// This method sets up the editor configuration to match a SwiftUI theme style.
  /// The theme affects various visual aspects of the editor:
  ///
  /// ## Theme Behavior
  ///
  /// The `theme()` method configures:
  /// - **Syntax Highlighting**: Automatically enabled for both default and dark themes
  /// - **Line Highlighting**: Selected line highlighting is enabled
  /// - **Editor Settings**: Optimized for the theme's visual style
  ///
  /// ## Important Notes
  ///
  /// 1. **Color Application**: This method doesn't directly set colors. Actual colors
  ///    are applied through:
  ///    - The syntax highlighting system for code tokens
  ///    - Platform-specific views for background/text colors
  ///    - SwiftUI environment values for UI components
  ///
  /// 2. **Theme Types**:
  ///    - `.default`: Light theme optimized for standard displays
  ///    - `.dark`: Dark theme optimized for low-light environments
  ///    - Custom themes: Apply the same settings as default theme
  ///
  /// 3. **Integration**: Works in conjunction with:
  ///    - `CodeEditorSwiftUITheme` for SwiftUI color definitions
  ///    - Syntax highlighters for token coloring
  ///    - Platform appearance (respects system dark/light mode)
  ///
  /// ## Example Usage
  ///
  /// ```swift
  /// // Apply dark theme
  /// let config = EditorConfigurationBuilder()
  ///     .theme(.dark)
  ///     .fontSize(14)
  ///     .build()
  ///
  /// // Use with SwiftUI
  /// CodeEditor(text: $code)
  ///     .codeEditorTheme(.dark)  // SwiftUI modifier
  ///     .environment(\.codeEditorConfiguration, config)
  /// ```
  ///
  /// ## Theme Customization
  ///
  /// To create a custom theme:
  /// 1. Define a custom `CodeEditorSwiftUITheme`
  /// 2. Implement custom syntax highlighting colors
  /// 3. Apply through this method for consistent settings
  ///
  /// - Parameter theme: The theme to apply (.default, .dark, or custom)
  /// - Returns: The builder for chaining
  ///
  /// - Note: Theme colors are resolved at runtime based on the current
  ///   system appearance and syntax highlighting configuration
  ///
  /// - SeeAlso: `CodeEditorSwiftUITheme`, `Theme`, `enableSyntaxHighlighting(_:)`
  @discardableResult
  public func theme(_ theme: CodeEditorSwiftUITheme) -> Self {
    // Note: CodeEditorSwiftUITheme provides colors for SwiftUI environment
    // The actual theme colors are applied through the syntax highlighting system
    // This method configures the editor to match the theme's style

    var builder = self

    // Apply theme-specific settings
    // Both default and dark themes enable syntax highlighting and line highlighting
    // for better code readability
    if theme.name == "dark" || theme.name == "default" {
      builder = builder
        .highlightSelectedLine(true)
        .enableSyntaxHighlighting(true)
    } else {
      // Custom themes also get these enhancements by default
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
