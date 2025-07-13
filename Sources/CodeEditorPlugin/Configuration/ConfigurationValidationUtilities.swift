import Foundation

// MARK: - Configuration Validation Utilities

/// Shared validation utilities that consolidate duplicate validation patterns
/// across configuration extensions without conflicting with existing implementations
public enum ConfigurationValidationUtilities {
    // MARK: - Validation Result Types
    
    /// Result of a validation operation
    public enum ValidationResult<T> {
        case valid(T)
        case invalid(T, issues: [ValidationIssue])
        case fixable(T, fixed: T, issues: [ValidationIssue])
    }
    
    /// Validation issue with optional auto-fix capability
    public struct ValidationIssue {
        public let property: String
        public let message: String
        public let severity: Severity
        public let suggestedFix: String?
        
        public enum Severity {
            case warning
            case error
        }
        
        public init(property: String, message: String, severity: Severity, suggestedFix: String? = nil) {
            self.property = property
            self.message = message
            self.severity = severity
            self.suggestedFix = suggestedFix
        }
    }
    
    // MARK: - Generic Range Validation
    
    /// Generic range validator that consolidates all the duplicate range checking logic
    /// Used for font size, tab width, line height, gutter width, etc.
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
    public static func validateFontSize(_ fontSize: CGFloat, autoFix: Bool = false) -> ValidationResult<CGFloat> {
        validateRange(
            value: fontSize,
            in: PlatformConstants.validFontSizeRange,
            property: "fontSize",
            autoFix: autoFix
        )
    }
    
    /// Validates tab width using platform-specific constraints  
    public static func validateTabWidth(_ tabWidth: Int, autoFix: Bool = false) -> ValidationResult<Int> {
        validateRange(
            value: tabWidth,
            in: PlatformConstants.validTabWidthRange,
            property: "tabWidth",
            autoFix: autoFix
        )
    }
    
    /// Validates line height multiplier
    public static func validateLineHeightMultiple(_ lineHeight: CGFloat, autoFix: Bool = false) -> ValidationResult<CGFloat> {
        validateRange(
            value: lineHeight,
            in: PlatformConstants.validLineHeightMultipleRange,
            property: "lineHeightMultiple",
            autoFix: autoFix
        )
    }
    
    /// Validates gutter width
    public static func validateGutterWidth(_ gutterWidth: CGFloat, autoFix: Bool = false) -> ValidationResult<CGFloat> {
        validateRange(
            value: gutterWidth,
            in: PlatformConstants.validGutterWidthRange,
            property: "gutterWidth",
            autoFix: autoFix
        )
    }
    
    /// Validates syntax highlighting max length
    public static func validateHighlightingLength(_ length: Int, autoFix: Bool = false) -> ValidationResult<Int> {
        validateRange(
            value: length,
            in: PlatformConstants.validHighlightingLengthRange,
            property: "maxHighlightingLength",
            autoFix: autoFix
        )
    }
    
    /// Validates debounce interval
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
/// Reduces duplicate decode-with-defaults patterns without conflicting with existing code
public enum ConfigurationCodableHelpers {
    /// Decodes a value with a default fallback, commonly used pattern in config files
    public static func decodeWithDefault<T, Key>(
        _ type: T.Type,
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        defaultValue: T
    ) throws -> T where T: Decodable {
        try container.decodeIfPresent(type, forKey: key) ?? defaultValue
    }
    
    /// Decodes with validation and auto-correction if needed
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
public enum ConfigurationBuilderHelpers {
    /// Creates a validated configuration update
    public static func updateWithValidation<T>(
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
    public static func createDocumentation(
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
public enum ConfigurationMigrationHelpers {
    /// Maps old validation methods to new shared utilities
    @available(*, deprecated, message: "Use ConfigurationValidationUtilities.validateFontSize instead")
    public static func legacyValidateFontSize(_ fontSize: CGFloat) -> Bool {
        switch ConfigurationValidationUtilities.validateFontSize(fontSize) {
        case .valid:
            return true

        case .invalid, .fixable:
            return false
        }
    }
    
    /// Maps old validation methods to new shared utilities
    @available(*, deprecated, message: "Use ConfigurationValidationUtilities.validateTabWidth instead")
    public static func legacyValidateTabWidth(_ tabWidth: Int) -> Bool {
        switch ConfigurationValidationUtilities.validateTabWidth(tabWidth) {
        case .valid:
            return true

        case .invalid, .fixable:
            return false
        }
    }
}
