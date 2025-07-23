import Foundation

// MARK: - Layout Validation

extension ConfigurationValidator {
    func validateLayout(_ layout: EditorConfiguration.Layout) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Tab width validation - more permissive range
        if !PlatformConstants.validTabWidthRange.contains(layout.tabWidth) {
            issues.append(ValidationIssue(
                severity: .warning,
                path: "layout.tabWidth",
                message: "Tab width \(layout.tabWidth) is outside recommended range (\(PlatformConstants.validTabWidthRange.lowerBound)-\(PlatformConstants.validTabWidthRange.upperBound))",
                suggestedValue: max(PlatformConstants.validTabWidthRange.lowerBound, min(PlatformConstants.validTabWidthRange.upperBound, layout.tabWidth))
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
                severity: .error,
                path: "layout.textContainerWidthFraction",
                message: "Text container width fraction must be between 0 and 1",
                suggestedValue: max(0, min(1, layout.textContainerWidthFraction))
            ))
        }

        return issues
    }
}
