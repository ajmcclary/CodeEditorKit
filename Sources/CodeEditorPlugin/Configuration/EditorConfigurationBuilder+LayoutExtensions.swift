import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
  import AppKit
#elseif canImport(UIKit)
  import UIKit
#endif

// MARK: - Layout Settings

extension EditorConfigurationBuilder {
  /// Sets the width of the gutter area.
  ///
  /// The gutter contains line numbers and other editor annotations.
  /// Adjust this to accommodate different line number lengths or touch targets.
  ///
  /// - Parameter width: The gutter width in points (recommended: 30-60)
  /// - Returns: The builder instance for method chaining
  ///
  /// ## Example
  ///
  /// ```swift
  /// let config = EditorConfigurationBuilder()
  ///     .gutterWidth(40)   // Default width
  ///     .gutterWidth(50)   // Wider for touch targets on iOS
  ///     .gutterWidth(30)   // Compact for small screens
  ///     .build()
  /// ```
  @discardableResult
  public func gutterWidth(_ width: CGFloat) -> Self {
    with { $0.layout.gutterWidth = width }
  }

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
}
