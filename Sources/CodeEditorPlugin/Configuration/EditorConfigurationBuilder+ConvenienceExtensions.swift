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
  ///    - `Theme` for SwiftUI color definitions
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
  /// 1. Define a custom `Theme`
  /// 2. Implement custom syntax highlighting colors
  /// 3. Apply through this method for consistent settings
  ///
  /// - Parameter theme: The theme to apply (.default, .dark, or custom)
  /// - Returns: The builder for chaining
  ///
  /// - Note: Theme colors are resolved at runtime based on the current
  ///   system appearance and syntax highlighting configuration
  ///
  /// - SeeAlso: `Theme`, `Theme`, `enableSyntaxHighlighting(_:)`
  @discardableResult
  func theme(_ theme: Theme) -> Self {
    // Note: Theme provides colors for SwiftUI environment
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
  /// 
  /// Derives from the default preset and applies:
  /// - Larger font size (18pt) for visibility
  /// - No line numbers for cleaner appearance
  /// - No annotations to reduce distractions
  /// - No line highlighting for simplicity
  /// - Line wrapping enabled for better readability
  /// 
  /// - Returns: The builder for chaining
  /// - Note: This builder starts from the default preset configuration
  @discardableResult
  func presentationMode() -> Self {
    fontSize(18)
      .isLineNumbersEnabled(false)
      .enableAnnotations(false)
      .highlightSelectedLine(false)
      .wrapLines(true)
  }

  /// Configures the editor for code review
  /// 
  /// Derives from the default preset and applies:
  /// - Read-only mode (not editable)
  /// - Line numbers visible for easy reference
  /// - Annotations enabled for review comments
  /// - Line highlighting for navigation
  /// - Syntax highlighting for code clarity
  /// 
  /// - Returns: The builder for chaining
  /// - Note: This builder starts from the default preset configuration
  @discardableResult
  func codeReviewMode() -> Self {
    isEditable(false)
      .isLineNumbersEnabled(true)
      .enableAnnotations(true)
      .highlightSelectedLine(true)
      .enableSyntaxHighlighting(true)
  }
}

// MARK: - Quick Configuration Methods

extension EditorConfigurationBuilder {
  /// Quick configuration for Swift development
  /// 
  /// Creates a new configuration based on the default preset with:
  /// - Language set to Swift
  /// - Font size 14pt
  /// - All other settings from default preset
  /// 
  /// - Returns: A configuration optimized for Swift development
  /// - Note: Internally calls `build()` which returns a complete configuration
  static func swift() -> EditorConfiguration {
    EditorConfigurationBuilder()
      .language(.swift)
      .fontSize(14)
      .build()
  }

  /// Quick configuration for web development
  /// 
  /// Creates a new configuration based on the default preset with:
  /// - Language set to JavaScript
  /// - Font size 14pt
  /// - Tab width 2 (common for web development)
  /// - All other settings from default preset
  /// 
  /// - Returns: A configuration optimized for web development
  /// - Note: Internally calls `build()` which returns a complete configuration
  static func web() -> EditorConfiguration {
    EditorConfigurationBuilder()
      .language(.javascript)
      .fontSize(14)
      .tabWidth(2)
      .build()
  }

  /// Quick configuration for Python development
  /// 
  /// Creates a new configuration based on the default preset with:
  /// - Language set to Python
  /// - Font size 14pt
  /// - All other settings from default preset
  /// 
  /// - Returns: A configuration optimized for Python development
  /// - Note: Internally calls `build()` which returns a complete configuration
  static func python() -> EditorConfiguration {
    EditorConfigurationBuilder()
      .language(.python)
      .fontSize(14)
      .build()
  }

  /// Quick configuration for documentation editing
  /// - Returns: A configuration optimized for documentation
  static func documentation() -> EditorConfiguration {
    EditorConfigurationBuilder()
      .language(.markdown)
      .fontSize(16)
      .wrapLines(true)
      .enableSpellCheck(true)
      .build()
  }

  /// Quick configuration for read-only viewing
  /// - Returns: A configuration optimized for viewing code
  static func readOnly() -> EditorConfiguration {
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
  static func builder() -> EditorConfigurationBuilder {
    EditorConfigurationBuilder()
  }

  /// Creates a configuration builder starting from this configuration
  /// - Returns: A new EditorConfigurationBuilder with this configuration as base
  func builder() -> EditorConfigurationBuilder {
    EditorConfigurationBuilder(base: self)
  }
}
