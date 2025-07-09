import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
  import AppKit
#elseif canImport(UIKit)
  import UIKit
#endif

// MARK: - Display Settings

extension EditorConfigurationBuilder {
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
}
