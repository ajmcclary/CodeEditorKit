import Foundation

// MARK: - Performance Settings

extension EditorConfigurationBuilder {
  /// Controls whether hardware acceleration is used
  /// - Parameter enabled: Whether to use hardware acceleration
  /// - Returns: The builder for chaining
  @discardableResult
  func useHardwareAcceleration(_ enabled: Bool) -> Self {
    with { $0.performance.useHardwareAcceleration = enabled }
  }

  /// Sets the maximum length for syntax highlighting
  /// - Parameter length: Maximum length for highlighting (0 = unlimited)
  /// - Returns: The builder for chaining
  @discardableResult
  func maxHighlightingLength(_ length: Int) -> Self {
    with { $0.performance.maxSyntaxHighlightingLength = length }
  }

  /// Sets a custom memory monitor instance
  /// - Parameter monitor: The memory monitor to use, or nil to use default
  /// - Returns: The builder for chaining
  @discardableResult
  func memoryMonitor(_ monitor: MemoryMonitor?) -> Self {
    with { $0.performance.memoryMonitor = monitor }
  }
}
