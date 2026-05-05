import Foundation

// MARK: - Configuration Validation Utilities

/// Shared validation utilities that consolidate duplicate validation patterns
/// across configuration extensions without conflicting with existing implementations
public enum ConfigurationValidationUtilities {
    // MARK: - Validation Result Types

    /// Result of a validation operation
    /// 
    /// Represents the outcome of validating a configuration value, providing different states
    /// based on whether the value is acceptable, needs fixing, or is completely invalid.
    public enum ValidationResult<T> {
        /// The value is valid and can be used as-is
        /// - Parameter value: The validated value
        case valid(T)

        /// The value is invalid and cannot be automatically fixed
        /// - Parameters:
        ///   - value: The original invalid value
        ///   - issues: Array of validation issues describing what's wrong
        case invalid(T, issues: [ValidationIssue])

        /// The value is invalid but can be automatically corrected
        /// - Parameters:
        ///   - value: The original invalid value
        ///   - fixed: The automatically corrected value
        ///   - issues: Array of validation issues describing the fixes applied
        case fixable(T, fixed: T, issues: [ValidationIssue])
    }

    /// Validation issue with optional auto-fix capability
    /// 
    /// Represents a specific problem found during configuration validation,
    /// including details about the issue and potential fixes.
    public struct ValidationIssue {
        /// The name of the property that has the validation issue
        public let property: String

        /// Human-readable description of the validation issue
        public let message: String

        /// The severity level of this validation issue
        public let severity: Severity

        /// Optional suggestion for how to fix this issue
        public let suggestedFix: String?

        /// Severity level for validation issues
        /// 
        /// Determines how critical a validation issue is and how it should be handled.
        public enum Severity {
            /// Non-critical issue that doesn't prevent usage but should be addressed
            case warning

            /// Critical issue that prevents proper functioning and must be fixed
            case error
        }

        /// Creates a new validation issue
        /// - Parameters:
        ///   - property: The name of the property with the issue
        ///   - message: Human-readable description of the problem
        ///   - severity: How critical this issue is
        ///   - suggestedFix: Optional suggestion for fixing the issue
        public init(property: String, message: String, severity: Severity, suggestedFix: String? = nil) {
            self.property = property
            self.message = message
            self.severity = severity
            self.suggestedFix = suggestedFix
        }
    }

    // MARK: - Generic Range Validation

    /// Generic range validator that consolidates all the duplicate range checking logic
    /// 
    /// Used for font size, tab width, line height, gutter width, etc. This provides a unified
    /// approach to validating that numeric configuration values fall within acceptable bounds.
    /// 
    /// - Parameters:
    ///   - value: The value to validate
    ///   - range: The acceptable range for the value
    ///   - property: The name of the property being validated (for error messages)
    ///   - autoFix: Whether to automatically fix out-of-range values by clamping to bounds
    /// - Returns: A validation result indicating success, failure, or auto-fix applied
    public static func validateRange<T: Comparable & CustomStringConvertible>(
        value: T,
        in range: ClosedRange<T>,
        property: String,
        autoFix: Bool = false
    ) -> ValidationResult<T> {
        guard range.contains(value) else {
            let message: String
            let suggestedValue: T

            if value < range.lowerBound {
                suggestedValue = range.lowerBound
                message = "\(property) value \(value) is below minimum \(range.lowerBound)"
            } else {
                suggestedValue = range.upperBound
                message = "\(property) value \(value) is above maximum \(range.upperBound)"
            }

            let issue = ValidationIssue(
                property: property,
                message: message,
                severity: .error,
                suggestedFix: "Use \(suggestedValue) instead"
            )

            if autoFix {
                return .fixable(value, fixed: suggestedValue, issues: [issue])
            } else {
                return .invalid(value, issues: [issue])
            }
        }

        return .valid(value)
    }

    // MARK: - Specific Validators

    /// Validates font size using platform-specific constraints
    /// 
    /// Ensures the font size falls within the acceptable range defined by `PlatformConstants.validFontSizeRange`.
    /// This prevents fonts that are too small to read or too large to be practical.
    /// 
    /// - Parameters:
    ///   - fontSize: The font size to validate
    ///   - autoFix: Whether to automatically clamp out-of-range values to the nearest valid value
    /// - Returns: A validation result with the original or corrected font size
    public static func validateFontSize(_ fontSize: CGFloat, autoFix: Bool = false) -> ValidationResult<CGFloat> {
        validateRange(
            value: fontSize,
            in: PlatformConstants.validFontSizeRange,
            property: "fontSize",
            autoFix: autoFix
        )
    }

    /// Validates tab width using platform-specific constraints
    /// 
    /// Ensures the tab width falls within the acceptable range defined by `PlatformConstants.validTabWidthRange`.
    /// This prevents tabs that are too narrow to be useful or too wide to be practical.
    /// 
    /// - Parameters:
    ///   - tabWidth: The tab width in spaces to validate
    ///   - autoFix: Whether to automatically clamp out-of-range values to the nearest valid value
    /// - Returns: A validation result with the original or corrected tab width
    public static func validateTabWidth(_ tabWidth: Int, autoFix: Bool = false) -> ValidationResult<Int> {
        validateRange(
            value: tabWidth,
            in: PlatformConstants.validTabWidthRange,
            property: "tabWidth",
            autoFix: autoFix
        )
    }

    /// Validates line height multiplier
    /// 
    /// Ensures the line height multiplier falls within the acceptable range defined by 
    /// `PlatformConstants.validLineHeightMultipleRange`. This prevents line spacing that is
    /// too tight to read or too loose to be practical.
    /// 
    /// - Parameters:
    ///   - lineHeight: The line height multiplier to validate (1.0 = normal spacing)
    ///   - autoFix: Whether to automatically clamp out-of-range values to the nearest valid value
    /// - Returns: A validation result with the original or corrected line height multiplier
    public static func validateLineHeightMultiple(_ lineHeight: CGFloat, autoFix: Bool = false) -> ValidationResult<CGFloat> {
        validateRange(
            value: lineHeight,
            in: PlatformConstants.validLineHeightMultipleRange,
            property: "lineHeightMultiple",
            autoFix: autoFix
        )
    }

    /// Validates gutter width
    /// 
    /// Ensures the gutter width falls within the acceptable range defined by 
    /// `PlatformConstants.validGutterWidthRange`. This prevents gutters that are too narrow
    /// to display line numbers or too wide to be practical.
    /// 
    /// - Parameters:
    ///   - gutterWidth: The gutter width in points to validate
    ///   - autoFix: Whether to automatically clamp out-of-range values to the nearest valid value
    /// - Returns: A validation result with the original or corrected gutter width
    public static func validateGutterWidth(_ gutterWidth: CGFloat, autoFix: Bool = false) -> ValidationResult<CGFloat> {
        validateRange(
            value: gutterWidth,
            in: PlatformConstants.validGutterWidthRange,
            property: "gutterWidth",
            autoFix: autoFix
        )
    }

    /// Validates syntax highlighting maximum length
    /// 
    /// Ensures the maximum highlighting length falls within the acceptable range defined by 
    /// `PlatformConstants.validHighlightingLengthRange`. This prevents syntax highlighting
    /// from being applied to excessively long documents which could impact performance.
    /// 
    /// - Parameters:
    ///   - length: The maximum document length for syntax highlighting to validate
    ///   - autoFix: Whether to automatically clamp out-of-range values to the nearest valid value
    /// - Returns: A validation result with the original or corrected highlighting length limit
    public static func validateHighlightingLength(_ length: Int, autoFix: Bool = false) -> ValidationResult<Int> {
        validateRange(
            value: length,
            in: PlatformConstants.validHighlightingLengthRange,
            property: "maxHighlightingLength",
            autoFix: autoFix
        )
    }

    /// Validates debounce interval for text change events
    /// 
    /// Ensures the debounce interval falls within the acceptable range defined by 
    /// `PlatformConstants.validDebounceIntervalRange`. This prevents intervals that are too
    /// short (causing performance issues) or too long (making the editor feel unresponsive).
    /// 
    /// - Parameters:
    ///   - interval: The debounce interval in seconds to validate
    ///   - autoFix: Whether to automatically clamp out-of-range values to the nearest valid value
    /// - Returns: A validation result with the original or corrected debounce interval
    public static func validateDebounceInterval(_ interval: TimeInterval, autoFix: Bool = false) -> ValidationResult<TimeInterval> {
        validateRange(
            value: interval,
            in: PlatformConstants.validDebounceIntervalRange,
            property: "textChangeDebounceInterval",
            autoFix: autoFix
        )
    }

    // MARK: - Error Generation Helpers

    /// Creates a standard configuration error message
    /// 
    /// Generates a consistent error message format for configuration validation failures.
    /// This helps maintain uniform error reporting across the entire configuration system.
    /// 
    /// - Parameters:
    ///   - property: The name of the configuration property that failed validation
    ///   - value: The invalid value that was provided
    ///   - expectedRange: Human-readable description of the expected value range
    ///   - suggestedValue: Optional suggested replacement value
    /// - Returns: A formatted error message string
    public static func createValidationError(
        for property: String,
        value: Any,
        expectedRange: String,
        suggestedValue: Any? = nil
    ) -> String {
        var message = "Invalid \(property): \(value). Expected range: \(expectedRange)."
        if let suggested = suggestedValue {
            message += " Suggested value: \(suggested)."
        }
        return message
    }

    /// Creates a configuration warning message
    /// 
    /// Generates a consistent warning message format for configuration validation issues
    /// that don't prevent operation but should be addressed.
    /// 
    /// - Parameters:
    ///   - property: The name of the configuration property that has the warning
    ///   - value: The problematic value
    ///   - reason: Explanation of why this is problematic
    /// - Returns: A formatted warning message string
    public static func createValidationWarning(
        for property: String,
        value: Any,
        reason: String
    ) -> String {
        "Warning for \(property): \(value). \(reason)"
    }
}

// MARK: - Codable Helpers

/// Shared utilities for configuration Codable implementations
/// 
/// Reduces duplicate decode-with-defaults patterns without conflicting with existing code.
/// These utilities provide common patterns for safely decoding configuration values
/// with validation and fallback handling.
public enum ConfigurationCodableHelpers {
    /// Decodes a value with a default fallback, commonly used pattern in config files
    /// 
    /// This is a common pattern in configuration decoding where we want to provide
    /// sensible defaults for missing or invalid configuration values.
    /// 
    /// - Parameters:
    ///   - type: The type to decode
    ///   - container: The keyed decoding container
    ///   - key: The key to decode from
    ///   - defaultValue: The value to use if decoding fails or key is missing
    /// - Returns: The decoded value or the default value
    /// - Throws: Decoding errors only for structural issues, not missing keys
    public static func decodeWithDefault<T, Key>(
        _ type: T.Type,
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        defaultValue: T
    ) throws -> T where T: Decodable {
        try container.decodeIfPresent(type, forKey: key) ?? defaultValue
    }

    /// Decodes with validation and auto-correction if needed
    /// 
    /// Combines decoding with validation, automatically handling invalid values by either
    /// fixing them or falling back to defaults. This prevents configuration corruption
    /// from propagating through the system.
    /// 
    /// - Parameters:
    ///   - type: The type to decode
    ///   - container: The keyed decoding container
    ///   - key: The key to decode from
    ///   - defaultValue: The value to use if decoding fails or validation fails
    ///   - validator: Function that validates the decoded value
    /// - Returns: A valid configuration value (decoded, fixed, or default)
    /// - Throws: Decoding errors only for structural issues
    public static func decodeWithValidation<T, Key>(
        _ type: T.Type,
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        defaultValue: T,
        validator: (T) -> ConfigurationValidationUtilities.ValidationResult<T>
    ) throws -> T where T: Decodable {
        let rawValue = try decodeWithDefault(type, from: container, forKey: key, defaultValue: defaultValue)

        switch validator(rawValue) {
        case .valid(let value):
            return value

        case .invalid:
            // Log warning but use default instead of failing
            CrossPlatformLogger.logger().warning("Invalid value for \(key), using default: \(defaultValue)")
            return defaultValue

        case .fixable(_, let fixed, _):
            // Log auto-fix and use fixed value
            CrossPlatformLogger.logger().info("Auto-fixed value for \(key): \(rawValue) -> \(fixed)")
            return fixed
        }
    }
}

// MARK: - Builder Helpers

/// Shared builder utilities that reduce boilerplate without conflicting with existing methods
/// 
/// Provides common patterns for configuration builder implementations, including validation
/// and consistent documentation generation.
enum ConfigurationBuilderHelpers {
    /// Creates a validated configuration update
    /// 
    /// Safely updates a configuration value by validating the new value and handling
    /// validation failures gracefully. Invalid values are rejected and the current
    /// value is preserved, while fixable values are automatically corrected.
    /// 
    /// - Parameters:
    ///   - currentValue: The existing configuration value
    ///   - newValue: The proposed new value
    ///   - validator: Function that validates the new value
    /// - Returns: The validated new value, auto-fixed value, or original value on failure
    static func updateWithValidation<T>(
        _ currentValue: T,
        newValue: T,
        validator: (T) -> ConfigurationValidationUtilities.ValidationResult<T>
    ) -> T {
        switch validator(newValue) {
        case .valid(let validValue):
            return validValue

        case let .invalid(_, issues):
            // Log issues but return original value
            for issue in issues {
                CrossPlatformLogger.logger().warning("Validation failed: \(issue.message)")
            }
            return currentValue

        case let .fixable(_, fixed, issues):
            // Log auto-fix and return fixed value
            for issue in issues {
                CrossPlatformLogger.logger().info("Auto-fixed: \(issue.message)")
            }
            return fixed
        }
    }

    /// Standard documentation template for builder methods
    /// 
    /// Generates consistent DocC-compatible documentation for configuration builder methods.
    /// This ensures all builder methods have uniform documentation style and include
    /// necessary information about valid ranges and return values.
    /// 
    /// - Parameters:
    ///   - property: The name of the property being set
    ///   - description: Description of what this property controls
    ///   - validRange: Optional description of valid value ranges
    /// - Returns: A formatted documentation comment string
    static func createDocumentation(
        for property: String,
        description: String,
        validRange: String? = nil
    ) -> String {
        var docs = "/// Sets the \(property). \(description)"
        if let range = validRange {
            docs += " Valid range: \(range)."
        }
        docs += "\n/// - Returns: The builder instance for method chaining"
        return docs
    }
}

// MARK: - Migration Helpers

/// Utilities to help migrate from the old scattered validation approach
/// 
/// Provides compatibility wrappers for legacy validation methods while encouraging
/// migration to the new unified validation system. These methods are deprecated
/// and will be removed in a future version.
public enum ConfigurationMigrationHelpers {
}
