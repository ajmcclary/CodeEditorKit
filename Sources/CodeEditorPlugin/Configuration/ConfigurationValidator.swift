import Foundation
import os.log

/// Validator for editor configuration with migration support
public struct ConfigurationValidator {
    private let logger = Logger(subsystem: "CodeEditorPlugin", category: "ConfigurationValidator")
    
    // MARK: - Validation
    
    /// Validate a configuration and return any issues found
    public func validate(_ configuration: EditorConfiguration) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Display validation
        issues.append(contentsOf: validateDisplay(configuration.display))
        
        // Layout validation
        issues.append(contentsOf: validateLayout(configuration.layout))
        
        // Behavior validation
        issues.append(contentsOf: validateBehavior(configuration.behavior))
        
        // Performance validation
        issues.append(contentsOf: validatePerformance(configuration.performance))
        
        // Cross-configuration validation
        issues.append(contentsOf: validateCrossConfiguration(configuration))
        
        return issues
    }
    
    /// Fix common validation issues automatically
    public func autoFix(_ configuration: inout EditorConfiguration) -> [ValidationFix] {
        var fixes: [ValidationFix] = []
        let issues = validate(configuration)
        
        for issue in issues where issue.isAutoFixable {
            if let fix = applyAutoFix(for: issue, to: &configuration) {
                fixes.append(fix)
            }
        }
        
        return fixes
    }
    
    // MARK: - Display Validation
    
    private func validateDisplay(_ display: EditorConfiguration.Display) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Font size validation - more permissive range
        if display.fontSize < 6.0 || display.fontSize > 120.0 {
            issues.append(ValidationIssue(
                severity: .warning,
                path: "display.fontSize",
                message: "Font size \(display.fontSize) is outside recommended range (6-120)",
                suggestedValue: max(6.0, min(120.0, display.fontSize))
            ))
        }
        
        return issues
    }
    
    // MARK: - Layout Validation
    
    private func validateLayout(_ layout: EditorConfiguration.Layout) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Tab width validation - more permissive range
        if layout.tabWidth < 1 || layout.tabWidth > 32 {
            issues.append(ValidationIssue(
                severity: .warning,
                path: "layout.tabWidth",
                message: "Tab width \(layout.tabWidth) is outside recommended range (1-32)",
                suggestedValue: max(1, min(32, layout.tabWidth))
            ))
        }
        
        // Gutter width validation (showGutter is controlled by display.showLineNumbers)
        if layout.gutterWidth < 20.0 {
            issues.append(ValidationIssue(
                severity: .warning,
                path: "layout.gutterWidth",
                message: "Gutter width \(layout.gutterWidth) may be too narrow for line numbers",
                suggestedValue: max(40.0, layout.gutterWidth)
            ))
        }
        
        // Line spacing validation
        if layout.lineHeightMultiple < 0 {
            issues.append(ValidationIssue(
                severity: .error,
                path: "layout.lineSpacing",
                message: "Line spacing cannot be negative",
                suggestedValue: max(0, layout.lineHeightMultiple)
            ))
        }
        
        // Text container width fraction validation
        if layout.textContainerWidthFraction < 0 || layout.textContainerWidthFraction > 1 {
            issues.append(ValidationIssue(
                severity: .warning,
                path: "layout.textContainerWidthFraction",
                message: "Text container width fraction \(layout.textContainerWidthFraction) is outside valid range (0...1)",
                suggestedValue: max(0, min(1, layout.textContainerWidthFraction))
            ))
        }
        
        return issues
    }
    
    // MARK: - Behavior Validation
    
    private func validateBehavior(_: EditorConfiguration.Behavior) -> [ValidationIssue] {
        // Currently no behavior-specific validation rules
        // Future validation rules can be added here
        []
    }
    
    // MARK: - Performance Validation
    
    private func validatePerformance(_ performance: EditorConfiguration.Performance) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Syntax highlighting length validation
        if performance.maxSyntaxHighlightingLength < 1_000 {
            issues.append(ValidationIssue(
                severity: .warning,
                path: "performance.maxSyntaxHighlightingLength",
                message: "Max syntax highlighting length is very low, may impact user experience",
                suggestedValue: max(10_000, performance.maxSyntaxHighlightingLength)
            ))
        }
        
        return issues
    }
    
    // MARK: - Cross-Configuration Validation
    
    private func validateCrossConfiguration(_ configuration: EditorConfiguration) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Read-only mode conflicts
        if !configuration.behavior.isEditable {
            if configuration.behavior.autoIndent {
                issues.append(ValidationIssue(
                    severity: .warning,
                    path: "behavior.autoIndent",
                    message: "Auto-indent is enabled in read-only mode",
                    suggestedValue: false
                ))
            }
            
            if configuration.behavior.enableCodeCompletion {
                issues.append(ValidationIssue(
                    severity: .warning,
                    path: "behavior.enableCodeCompletion",
                    message: "Code completion is enabled in read-only mode",
                    suggestedValue: false
                ))
            }
        }
        
        // Performance mode conflicts
        if !configuration.performance.useHardwareAcceleration &&
           configuration.performance.smoothScrolling {
            issues.append(ValidationIssue(
                severity: .info,
                path: "performance.smoothScrolling",
                message: "Smooth scrolling may not work well without hardware acceleration",
                suggestedValue: false
            ))
        }
        
        return issues
    }
    
    // MARK: - Auto-Fix
    
    private func applyAutoFix(for issue: ValidationIssue, to configuration: inout EditorConfiguration) -> ValidationFix? {
        guard let suggestedValue = issue.suggestedValue else { return nil }
        
        let keyPath = issue.path.split(separator: ".").map(String.init)
        guard keyPath.count == 2 else { return nil }
        
        let oldValue: Any?
        
        switch (keyPath[0], keyPath[1]) {
        case ("display", "fontSize"):
            oldValue = configuration.display.fontSize
            if let newValue = suggestedValue as? CGFloat {
                configuration.display.fontSize = newValue
            }
            
        case ("layout", "tabWidth"):
            oldValue = configuration.layout.tabWidth
            if let newValue = suggestedValue as? Int {
                configuration.layout.tabWidth = newValue
            }
            
        case ("layout", "gutterWidth"):
            oldValue = configuration.layout.gutterWidth
            if let newValue = suggestedValue as? CGFloat {
                configuration.layout.gutterWidth = newValue
            }
            
        case ("layout", "lineSpacing"):
            oldValue = configuration.layout.lineHeightMultiple
            if let newValue = suggestedValue as? CGFloat {
                configuration.layout.lineHeightMultiple = newValue
            }
            
        case ("behavior", "autoIndent"):
            oldValue = configuration.behavior.autoIndent
            if let newValue = suggestedValue as? Bool {
                configuration.behavior.autoIndent = newValue
            }
            
        case ("behavior", "enableCodeCompletion"):
            oldValue = configuration.behavior.enableCodeCompletion
            if let newValue = suggestedValue as? Bool {
                configuration.behavior.enableCodeCompletion = newValue
            }
            
        case ("performance", "maxSyntaxHighlightingLength"):
            oldValue = configuration.performance.maxSyntaxHighlightingLength
            if let newValue = suggestedValue as? Int {
                configuration.performance.maxSyntaxHighlightingLength = newValue
            }
            
        case ("performance", "smoothScrolling"):
            oldValue = configuration.performance.smoothScrolling
            if let newValue = suggestedValue as? Bool {
                configuration.performance.smoothScrolling = newValue
            }
            
        default:
            return nil
        }
        
        return ValidationFix(
            issue: issue,
            oldValue: ValidationValue(from: oldValue),
            newValue: ValidationValue(from: suggestedValue),
            applied: Date()
        )
    }
}

// MARK: - Configuration Migration

/// Migrator for updating configurations between versions
public struct ConfigurationMigrator {
    private let logger = Logger(subsystem: "CodeEditorPlugin", category: "ConfigurationMigrator")
    
    /// Current configuration version
    public static let currentVersion = "2.0"
    
    /// Migrate a configuration from an older version
    public func migrate(
        from configuration: [String: Any],
        version: String
    ) -> Result<EditorConfiguration, MigrationError> {
        logger.info("Migrating configuration from version \(version) to \(Self.currentVersion)")
        
        var migrated = configuration
        
        // Apply migrations in sequence
        if version < "1.1" {
            migrated = migrateFrom1_0To1_1(migrated)
        }
        
        if version < "1.2" {
            migrated = migrateFrom1_1To1_2(migrated)
        }
        
        if version < "2.0" {
            migrated = migrateFrom1_2To2_0(migrated)
        }
        
        // Decode the migrated configuration
        do {
            let data = try JSONSerialization.data(withJSONObject: migrated)
            let decoder = JSONDecoder()
            let config = try decoder.decode(EditorConfiguration.self, from: data)
            
            // Validate the migrated configuration
            let validator = ConfigurationValidator()
            let issues = validator.validate(config)
            
            if issues.contains(where: { $0.severity == .error }) {
                throw MigrationError.validationFailed(issues)
            }
            
            return .success(config)
        } catch {
            return .failure(.decodingFailed(error))
        }
    }
    
    // MARK: - Version Migrations
    
    private func migrateFrom1_0To1_1(_ config: [String: Any]) -> [String: Any] {
        var migrated = config
        
        // Migrate flat structure to nested structure
        if let fontSize = config["fontSize"] as? Double {
            migrated.removeValue(forKey: "fontSize")
            var display = migrated["display"] as? [String: Any] ?? [:]
            display["fontSize"] = fontSize
            migrated["display"] = display
        }
        
        if let showLineNumbers = config["showLineNumbers"] as? Bool {
            migrated.removeValue(forKey: "showLineNumbers")
            var display = migrated["display"] as? [String: Any] ?? [:]
            display["showLineNumbers"] = showLineNumbers
            migrated["display"] = display
        }
        
        return migrated
    }
    
    private func migrateFrom1_1To1_2(_ config: [String: Any]) -> [String: Any] {
        var migrated = config
        
        // Add performance section if missing
        if migrated["performance"] == nil {
            migrated["performance"] = [
                "useHardwareAcceleration": true,
                "maxSyntaxHighlightingLength": 500_000,
                "largeFileThreshold": 1_000_000
            ]
        }
        
        return migrated
    }
    
    private func migrateFrom1_2To2_0(_ config: [String: Any]) -> [String: Any] {
        var migrated = config
        
        // Rename deprecated keys
        if var behavior = migrated["behavior"] as? [String: Any] {
            if let autoComplete = behavior["autoComplete"] as? Bool {
                behavior.removeValue(forKey: "autoComplete")
                behavior["enableCodeCompletion"] = autoComplete
                migrated["behavior"] = behavior
            }
        }
        
        // Add new display options
        if var display = migrated["display"] as? [String: Any] {
            if display["enableAnnotations"] == nil {
                display["enableAnnotations"] = true
            }
            migrated["display"] = display
        }
        
        return migrated
    }
}

// MARK: - Supporting Types

/// Validation issue found in configuration
public struct ValidationIssue: Sendable {
    public let severity: Severity
    public let path: String
    public let message: String
    public let suggestedValue: (any Sendable)?
    
    public var isAutoFixable: Bool {
        suggestedValue != nil
    }
    
    public enum Severity: Comparable, Sendable {
        case info
        case warning
        case error
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.info, .warning), (.info, .error), (.warning, .error):
                return true

            default:
                return false
            }
        }
    }
}

/// Wrapper for values in validation fixes
public enum ValidationValue: Sendable {
    case int(Int)
    case double(Double)
    case float(CGFloat)
    case bool(Bool)
    case string(String)
    case null
    
    init(from value: Any?) {
        guard let value else {
            self = .null
            return
        }
        
        switch value {
        case let intValue as Int:
            self = .int(intValue)
            
        case let doubleValue as Double:
            self = .double(doubleValue)
            
        case let floatValue as CGFloat:
            self = .float(floatValue)
            
        case let boolValue as Bool:
            self = .bool(boolValue)
            
        case let stringValue as String:
            self = .string(stringValue)
            
        default:
            self = .string("\(value)")
        }
    }
    
    public var description: String {
        switch self {
        case .int(let value): return "\(value)"
        case .double(let value): return "\(value)"
        case .float(let value): return "\(value)"
        case .bool(let value): return "\(value)"
        case .string(let value): return value
        case .null: return "nil"
        }
    }
}

/// Fix applied to resolve a validation issue
public struct ValidationFix: Sendable {
    public let issue: ValidationIssue
    public let oldValue: ValidationValue
    public let newValue: ValidationValue
    public let applied: Date
}

/// Validation report containing issues and fixes
public struct ValidationReport: Sendable {
    public let originalIssues: [ValidationIssue]
    public let appliedFixes: [ValidationFix]
    public let finalConfiguration: EditorConfiguration
    
    public var hasIssues: Bool {
        !originalIssues.isEmpty
    }
    
    public var hasCriticalIssues: Bool {
        originalIssues.contains { $0.severity == .error }
    }
    
    public var summary: String {
        var parts: [String] = []
        
        if originalIssues.isEmpty {
            parts.append("✅ Configuration is valid")
        } else {
            let errors = originalIssues.filter { $0.severity == .error }.count
            let warnings = originalIssues.filter { $0.severity == .warning }.count
            let infos = originalIssues.filter { $0.severity == .info }.count
            
            if errors > 0 {
                parts.append("❌ \(errors) error\(errors == 1 ? "" : "s")")
            }
            if warnings > 0 {
                parts.append("⚠️ \(warnings) warning\(warnings == 1 ? "" : "s")")
            }
            if infos > 0 {
                parts.append("ℹ️ \(infos) info\(infos == 1 ? "" : "s")")
            }
        }
        
        if !appliedFixes.isEmpty {
            parts.append("🔧 \(appliedFixes.count) fix\(appliedFixes.count == 1 ? "" : "es") applied")
        }
        
        return parts.joined(separator: ", ")
    }
}

/// Configuration validation error containing issues found during validation
public struct ConfigurationValidationError: Error, Sendable {
    public let issues: [ValidationIssue]
    
    public init(issues: [ValidationIssue]) {
        self.issues = issues
    }
    
    public var localizedDescription: String {
        let errorCount = issues.filter { $0.severity == .error }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        
        var parts: [String] = []
        if errorCount > 0 {
            parts.append("\(errorCount) error\(errorCount == 1 ? "" : "s")")
        }
        if warningCount > 0 {
            parts.append("\(warningCount) warning\(warningCount == 1 ? "" : "s")")
        }
        
        return "Configuration validation failed with \(parts.joined(separator: " and "))"
    }
}

/// Migration error types
public enum MigrationError: Error {
    case unsupportedVersion(String)
    case decodingFailed(Error)
    case validationFailed([ValidationIssue])
    case migrationFailed(String)
}

// MARK: - Configuration Diff

/// Utility to compare configurations
public enum ConfigurationDiff {
    /// Compare two configurations and return differences
    public static func diff(
        _ config1: EditorConfiguration,
        _ config2: EditorConfiguration
    ) -> [ConfigurationChange] {
        var changes: [ConfigurationChange] = []
        
        // Compare display settings
        if config1.display.fontSize != config2.display.fontSize {
            changes.append(ConfigurationChange(
                path: "display.fontSize",
                oldValue: config1.display.fontSize,
                newValue: config2.display.fontSize
            ))
        }
        
        if config1.display.showLineNumbers != config2.display.showLineNumbers {
            changes.append(ConfigurationChange(
                path: "display.showLineNumbers",
                oldValue: config1.display.showLineNumbers,
                newValue: config2.display.showLineNumbers
            ))
        }
        
        // Compare layout settings
        if config1.layout.tabWidth != config2.layout.tabWidth {
            changes.append(ConfigurationChange(
                path: "layout.tabWidth",
                oldValue: config1.layout.tabWidth,
                newValue: config2.layout.tabWidth
            ))
        }
        
        // Compare behavior settings
        if config1.behavior.isEditable != config2.behavior.isEditable {
            changes.append(ConfigurationChange(
                path: "behavior.isEditable",
                oldValue: config1.behavior.isEditable,
                newValue: config2.behavior.isEditable
            ))
        }
        
        // Compare performance settings
        if config1.performance.useHardwareAcceleration != config2.performance.useHardwareAcceleration {
            changes.append(ConfigurationChange(
                path: "performance.useHardwareAcceleration",
                oldValue: config1.performance.useHardwareAcceleration,
                newValue: config2.performance.useHardwareAcceleration
            ))
        }
        
        // Add more comparisons as needed...
        
        return changes
    }
}

/// Represents a change between configurations
public struct ConfigurationChange {
    public let path: String
    public let oldValue: Any
    public let newValue: Any
    
    public var description: String {
        "\(path): \(oldValue) → \(newValue)"
    }
}
