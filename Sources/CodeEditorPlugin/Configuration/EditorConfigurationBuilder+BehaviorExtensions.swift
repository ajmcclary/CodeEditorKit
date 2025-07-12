import Foundation

// MARK: - Behavior Settings

extension EditorConfigurationBuilder {
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
}
