import Foundation

/// Validator for editor configuration with migration support
public struct ConfigurationValidator {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "ConfigurationValidator")
    
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
    
    // MARK: - Cross-Configuration Validation
    
    private func validateCrossConfiguration(_ configuration: EditorConfiguration) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Validate syntax highlighting settings
        if configuration.display.enableSyntaxHighlighting && configuration.performance.maxSyntaxHighlightingLength <= 0 {
            issues.append(ValidationIssue(
                severity: .error,
                path: "performance.maxSyntaxHighlightingLength",
                message: "Max syntax highlighting length must be positive when syntax highlighting is enabled",
                suggestedValue: 500_000
            ))
        }
        
        // Validate minimap settings
        if configuration.display.showMinimap && configuration.layout.minimapWidth <= 0 {
            issues.append(ValidationIssue(
                severity: .error,
                path: "layout.minimapWidth",
                message: "Minimap width must be positive when minimap is enabled",
                suggestedValue: 100.0
            ))
        }
        
        // Add other cross-configuration validations as needed
        
        return issues
    }
    
    // MARK: - Auto-Fix
    
    private func applyAutoFix(
        for issue: ValidationIssue,
        to configuration: inout EditorConfiguration
    ) -> ValidationFix? {
        guard let suggestedValue = issue.suggestedValue else {
            return nil
        }
        
        let oldValue: Any?
        let keyPath = issue.path
        
        // Extract old value and apply fix based on path
        switch keyPath {
        case "display.fontSize":
            oldValue = configuration.display.fontSize
            if let newValue = suggestedValue as? CGFloat {
                configuration.display.fontSize = newValue
            }
            
        case "layout.tabWidth":
            oldValue = configuration.layout.tabWidth
            if let newValue = suggestedValue as? Int {
                configuration.layout.tabWidth = newValue
            }
            
        case "layout.gutterWidth":
            oldValue = configuration.layout.gutterWidth
            if let newValue = suggestedValue as? CGFloat {
                configuration.layout.gutterWidth = newValue
            }
            
        case "layout.lineSpacing":
            oldValue = configuration.layout.lineHeightMultiple
            if let newValue = suggestedValue as? CGFloat {
                configuration.layout.lineHeightMultiple = newValue
            }
            
        case "layout.textContainerWidthFraction":
            oldValue = configuration.layout.textContainerWidthFraction
            if let newValue = suggestedValue as? CGFloat {
                configuration.layout.textContainerWidthFraction = newValue
            }
            
        // Add performance cases as needed
            
        case "performance.maxSyntaxHighlightingLength":
            oldValue = configuration.performance.maxSyntaxHighlightingLength
            if let newValue = suggestedValue as? Int {
                configuration.performance.maxSyntaxHighlightingLength = newValue
            }
            
        case "layout.minimapWidth":
            oldValue = configuration.layout.minimapWidth
            if let newValue = suggestedValue as? CGFloat {
                configuration.layout.minimapWidth = newValue
            }
            
        // Add other auto-fix cases as needed
            
        default:
            logger.warning("Unknown configuration path for auto-fix: \(keyPath)")
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
