import Foundation

// MARK: - Display Validation

extension ConfigurationValidator {
    func validateDisplay(_ display: EditorConfiguration.Display) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Font size validation - more permissive range
        if !PlatformConstants.validFontSizeRange.contains(display.fontSize) {
            issues.append(ValidationIssue(
                severity: .warning,
                path: "display.fontSize",
                message: "Font size \(display.fontSize) is outside recommended range (\(PlatformConstants.validFontSizeRange.lowerBound)-\(PlatformConstants.validFontSizeRange.upperBound))",
                suggestedValue: max(PlatformConstants.validFontSizeRange.lowerBound, min(PlatformConstants.validFontSizeRange.upperBound, display.fontSize))
            ))
        }
        
        return issues
    }
}
