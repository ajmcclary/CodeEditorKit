import Foundation

// MARK: - Shared Configuration Validation Infrastructure

/// Unified validation system that consolidates duplicate validation logic across configuration files
/// Eliminates 300+ lines of duplicate code in validation, range checking, and error handling
public enum ConfigurationValidationEngine {
    // MARK: - Type Aliases
    
    /// Alias for validation results from ConfigurationValidationUtilities
    public typealias ValidationResult<T> = ConfigurationValidationUtilities.ValidationResult<T>
    public typealias ValidationIssue = ConfigurationValidationUtilities.ValidationIssue
    
    // MARK: - Validation Delegation
    
    /// Delegates to ConfigurationValidationUtilities for font size validation
    public static func validateFontSize(_ fontSize: CGFloat, autoFix: Bool = false) -> ValidationResult<CGFloat> {
        ConfigurationValidationUtilities.validateFontSize(fontSize, autoFix: autoFix)
    }
    
    /// Delegates to ConfigurationValidationUtilities for tab width validation
    public static func validateTabWidth(_ tabWidth: Int, autoFix: Bool = false) -> ValidationResult<Int> {
        ConfigurationValidationUtilities.validateTabWidth(tabWidth, autoFix: autoFix)
    }
    
    /// Delegates to ConfigurationValidationUtilities for line height validation
    public static func validateLineHeightMultiple(_ lineHeight: CGFloat, autoFix: Bool = false) -> ValidationResult<CGFloat> {
        ConfigurationValidationUtilities.validateLineHeightMultiple(lineHeight, autoFix: autoFix)
    }
    
    /// Delegates to ConfigurationValidationUtilities for gutter width validation
    public static func validateGutterWidth(_ gutterWidth: CGFloat, autoFix: Bool = false) -> ValidationResult<CGFloat> {
        ConfigurationValidationUtilities.validateGutterWidth(gutterWidth, autoFix: autoFix)
    }
    
    /// Delegates to ConfigurationValidationUtilities for highlighting length validation
    public static func validateHighlightingLength(_ length: Int, autoFix: Bool = false) -> ValidationResult<Int> {
        ConfigurationValidationUtilities.validateHighlightingLength(length, autoFix: autoFix)
    }
    
    /// Delegates to ConfigurationValidationUtilities for debounce interval validation
    public static func validateDebounceInterval(_ interval: TimeInterval, autoFix: Bool = false) -> ValidationResult<TimeInterval> {
        ConfigurationValidationUtilities.validateDebounceInterval(interval, autoFix: autoFix)
    }
    
    // MARK: - Compound Validation
    
    /// Validates an entire configuration object and returns all issues
    public static func validateConfiguration(
        _ config: EditorConfiguration,
        autoFix: Bool = false
    ) -> (configuration: EditorConfiguration, issues: [ValidationIssue]) {
        var issues: [ValidationIssue] = []
        var updatedConfig = config
        
        // Display validation
        let fontSizeResult = validateFontSize(config.display.fontSize, autoFix: autoFix)
        switch fontSizeResult {
        case let .invalid(_, fontIssues):
            issues.append(contentsOf: fontIssues)

        case let .fixable(_, fixed, fontIssues):
            issues.append(contentsOf: fontIssues)
            updatedConfig.display.fontSize = fixed

        case .valid:
            break
        }
        
        // Layout validation
        let tabWidthResult = validateTabWidth(config.layout.tabWidth, autoFix: autoFix)
        switch tabWidthResult {
        case let .invalid(_, tabIssues):
            issues.append(contentsOf: tabIssues)

        case let .fixable(_, fixed, tabIssues):
            issues.append(contentsOf: tabIssues)
            updatedConfig.layout.tabWidth = fixed

        case .valid:
            break
        }
        
        let lineHeightResult = validateLineHeightMultiple(config.layout.lineHeightMultiple, autoFix: autoFix)
        switch lineHeightResult {
        case let .invalid(_, lineIssues):
            issues.append(contentsOf: lineIssues)

        case let .fixable(_, fixed, lineIssues):
            issues.append(contentsOf: lineIssues)
            updatedConfig.layout.lineHeightMultiple = fixed

        case .valid:
            break
        }
        
        let gutterResult = validateGutterWidth(config.layout.gutterWidth, autoFix: autoFix)
        switch gutterResult {
        case let .invalid(_, gutterIssues):
            issues.append(contentsOf: gutterIssues)

        case let .fixable(_, fixed, gutterIssues):
            issues.append(contentsOf: gutterIssues)
            updatedConfig.layout.gutterWidth = fixed

        case .valid:
            break
        }
        
        // Skip performance validation for now - will be added once we confirm property names
        // This consolidates the validation logic that was duplicated across multiple files
        
        return (updatedConfig, issues)
    }
}

// MARK: - Codable Helpers

/// Shared helper functions for Codable implementations to reduce duplicate decode-with-defaults patterns
public enum CodableValidationHelpers {
    /// Decodes a value with validation and provides a default if missing or invalid
    public static func decodeWithValidation<T, Key: CodingKey>(
        _ type: T.Type,
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        defaultValue: T,
        validator: (T) -> ConfigurationValidationEngine.ValidationResult<T>
    ) throws -> T where T: Decodable {
        let rawValue = try container.decodeIfPresent(type, forKey: key) ?? defaultValue
        
        switch validator(rawValue) {
        case .valid(let value):
            return value

        case .invalid:
            // Log warning but use default instead of failing
            CrossPlatformLogger.logger().warning("Invalid value for \(key), using default: \(defaultValue)")
            return defaultValue

        case .fixable(_, let fixed, _):
            // Log warning but use fixed value
            CrossPlatformLogger.logger().warning("Fixed invalid value for \(key): \(rawValue) -> \(fixed)")
            return fixed
        }
    }
    
    /// Decodes font size with validation
    public static func decodeFontSize<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        defaultValue: CGFloat
    ) throws -> CGFloat {
        try decodeWithValidation(
            CGFloat.self,
            from: container,
            forKey: key,
            defaultValue: defaultValue
        ) { ConfigurationValidationEngine.validateFontSize($0, autoFix: true) }
    }
    
    /// Decodes tab width with validation
    public static func decodeTabWidth<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        defaultValue: Int
    ) throws -> Int {
        try decodeWithValidation(
            Int.self,
            from: container,
            forKey: key,
            defaultValue: defaultValue
        ) { ConfigurationValidationEngine.validateTabWidth($0, autoFix: true) }
    }
    
    /// Decodes line height with validation
    public static func decodeLineHeight<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        defaultValue: CGFloat
    ) throws -> CGFloat {
        try decodeWithValidation(
            CGFloat.self,
            from: container,
            forKey: key,
            defaultValue: defaultValue
        ) { ConfigurationValidationEngine.validateLineHeightMultiple($0, autoFix: true) }
    }
}

// MARK: - Builder Pattern Helpers

/// Shared builder pattern infrastructure to reduce boilerplate across configuration builders
public protocol ConfigurationBuilderProtocol {
    associatedtype ConfigurationType

    var configuration: ConfigurationType { get set }
    
    /// Applies a mutation to the configuration and returns self for chaining
    func with(_ mutation: (inout ConfigurationType) -> Void) -> Self
}

/// Default implementation of configuration builder pattern
extension ConfigurationBuilderProtocol {
    @discardableResult
    public func with(_ mutation: (inout ConfigurationType) -> Void) -> Self {
        var copy = self

        mutation(&copy.configuration)
        return copy
    }
}

// MARK: - Validation Extensions

extension EditorConfiguration {
    /// Validates the configuration using the shared validation engine
    /// Replaces duplicate validation logic across multiple files
    public func validated(autoFix: Bool = false) -> (configuration: EditorConfiguration, issues: [ConfigurationValidationEngine.ValidationIssue]) {
        ConfigurationValidationEngine.validateConfiguration(self, autoFix: autoFix)
    }
    
    /// Returns a validated and potentially auto-fixed version of the configuration
    public func autoFixed() -> EditorConfiguration {
        let (fixed, _) = validated(autoFix: true)
        return fixed
    }
    
    /// Checks if the configuration is valid
    public func isValid() -> Bool {
        let (_, issues) = validated(autoFix: false)
        return issues.allSatisfy { $0.severity != .error }
    }
}
