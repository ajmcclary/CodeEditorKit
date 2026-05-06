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
///     .isLineNumbersEnabled(true)
///     .tabWidth(4)
///     .theme(.dark)
///     .language(.swift)
///     .enableSyntaxHighlighting(true)
///     .build()
///
/// editor.configuration = config
/// ```
struct EditorConfigurationBuilder: Sendable {
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
  ///     .isLineNumbersEnabled(true)
  ///     .build()
  /// ```
  init() {
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
  init(base: EditorConfiguration) {
    self.configuration = base
  }

  /// Creates a configuration builder starting from a preset configuration.
  ///
  /// This is a convenience initializer that uses shared base configurations
  /// to reduce duplication and ensure consistency.
  ///
  /// - Parameter preset: The preset configuration to start with
  ///
  /// ## Example
  ///
  /// ```swift
  /// let config = EditorConfigurationBuilder(preset: .minimal)
  ///     .fontSize(16)
  ///     .enableSyntaxHighlighting(true)
  ///     .build()
  /// ```
  init(preset: PresetConfiguration) {
    switch preset {
    case .default:
      self.configuration = .default

    case .minimal:
      self.configuration = .minimal

    case .readOnly:
      self.configuration = .readOnly

    case .markdown:
      self.configuration = .markdown

    case .presentation:
      self.configuration = .presentation

    case .iOS:
      self.configuration = .iOS

    case .catalyst:
      self.configuration = .catalyst

    case .macOS:
      self.configuration = .macOS

    case .platformOptimized:
      self.configuration = .platformOptimized
    }
  }

  // MARK: - Internal Helper

  /// Creates a new builder with the modified configuration
  internal func with(_ modifier: (inout EditorConfiguration) -> Void) -> Self {
    var copy = self
    modifier(&copy.configuration)
    return copy
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
  ///     .isLineNumbersEnabled(true)
  ///     .tabWidth(4)
  ///     .theme(.dark)
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
  @discardableResult
  func build() -> EditorConfiguration {
    // Validate and auto-fix any issues
    var finalConfig = configuration
    let validator = ConfigurationValidator()
    _ = validator.autoFix(&finalConfig)

    return finalConfig
  }

  /// Build the configuration with validation feedback.
  /// 
  /// This method returns a Result type containing either the validated configuration
  /// or validation issues that were found. Unlike `build()`, this method does not
  /// automatically fix issues - it returns them for the caller to handle.
  ///
  /// - Returns: A Result containing either the configuration or validation error
  func buildWithValidation() -> Result<EditorConfiguration, ConfigurationValidationError> {
    let validator = ConfigurationValidator()
    let issues = validator.validate(configuration)

    if issues.isEmpty {
      return .success(configuration)
    } else {
      // Return only non-auto-fixable issues if there are any
      let criticalIssues = issues.filter { !$0.isAutoFixable }
      if !criticalIssues.isEmpty {
        return .failure(ConfigurationValidationError(issues: criticalIssues))
      } else {
        // All issues are auto-fixable, return success with the original config
        // The caller can choose to apply fixes if desired
        return .success(configuration)
      }
    }
  }

  /// Build the configuration with detailed validation report.
  /// 
  /// This method returns both the configuration and a validation report containing
  /// all issues found and any fixes that were applied.
  ///
  /// - Returns: A tuple containing the configuration and validation report
  func buildWithReport() -> (configuration: EditorConfiguration, report: ValidationReport) {
    let validator = ConfigurationValidator()
    var finalConfig = configuration

    // Get initial issues
    let issues = validator.validate(configuration)

    // Apply auto-fixes
    let fixes = validator.autoFix(&finalConfig)

    // Create report
    let report = ValidationReport(
      originalIssues: issues,
      appliedFixes: fixes,
      finalConfiguration: finalConfig
    )

    return (finalConfig, report)
  }

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
  func buildWithFeedback() -> (configuration: EditorConfiguration, fixes: [ValidationFix]) {
    // Validate and auto-fix any issues
    var finalConfig = configuration
    let validator = ConfigurationValidator()
    let fixes = validator.autoFix(&finalConfig)

    return (finalConfig, fixes)
  }
}
