import Foundation

#if canImport(SwiftUI)
  import SwiftUI
#endif

// MARK: - Convenience Methods

extension EditorConfigurationBuilder {
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
