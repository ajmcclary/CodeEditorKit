import Foundation

// MARK: - Error-based Validation

extension EditorConfiguration {
    /// Validates the configuration and throws domain-specific errors if invalid
    /// - Throws: `DomainError.configuration` with detailed error information
    public func validateWithDomainError() throws {
        let errors = validate()

        if !errors.isEmpty {
            let errorDescriptions = errors.map { error in
                "\(error.field): \(error.constraint)"
            }
            throw DomainError.configuration(
                .validationFailed(errors: errorDescriptions)
            )
        }
    }

    /// Validates a specific property and throws if invalid
    /// - Parameters:
    ///   - keyPath: The key path to the property to validate
    ///   - value: The value to validate
    /// - Throws: `ConfigurationDomainError` with specific error details
    public func validateProperty<T>(_ keyPath: KeyPath<EditorConfiguration, T>, value: T) throws {
        switch keyPath {
        case \EditorConfiguration.display.fontSize:
            guard let fontSize = value as? CGFloat,
                  PlatformConstants.validFontSizeRange.contains(fontSize) else {
                throw ConfigurationDomainError.invalidValue(
                    property: "display.fontSize",
                    value: String(describing: value),
                    reason: "Must be between \(PlatformConstants.validFontSizeRange.lowerBound) and \(PlatformConstants.validFontSizeRange.upperBound)"
                )
            }

        case \EditorConfiguration.layout.tabWidth:
            guard let tabWidth = value as? Int,
                  PlatformConstants.validTabWidthRange.contains(tabWidth) else {
                throw ConfigurationDomainError.invalidValue(
                    property: "layout.tabWidth",
                    value: String(describing: value),
                    reason: "Must be between \(PlatformConstants.validTabWidthRange.lowerBound) and \(PlatformConstants.validTabWidthRange.upperBound)"
                )
            }

        case \EditorConfiguration.layout.lineHeightMultiple:
            guard let lineHeight = value as? CGFloat,
                  PlatformConstants.validLineHeightMultipleRange.contains(lineHeight) else {
                throw ConfigurationDomainError.invalidValue(
                    property: "layout.lineHeightMultiple",
                    value: String(describing: value),
                    reason: "Must be between \(PlatformConstants.validLineHeightMultipleRange.lowerBound) and \(PlatformConstants.validLineHeightMultipleRange.upperBound)"
                )
            }

        case \EditorConfiguration.layout.gutterWidth:
            guard let gutterWidth = value as? CGFloat,
                  PlatformConstants.validGutterWidthRange.contains(gutterWidth) else {
                throw ConfigurationDomainError.invalidValue(
                    property: "layout.gutterWidth",
                    value: String(describing: value),
                    reason: "Must be at least \(PlatformConstants.validGutterWidthRange.lowerBound)"
                )
            }

        case \EditorConfiguration.performance.maxSyntaxHighlightingLength:
            guard let maxLength = value as? Int,
                  PlatformConstants.validHighlightingLengthRange.contains(maxLength) else {
                throw ConfigurationDomainError.invalidValue(
                    property: "performance.maxSyntaxHighlightingLength",
                    value: String(describing: value),
                    reason: "Must be at least \(PlatformConstants.validHighlightingLengthRange.lowerBound)"
                )
            }

        default:
            // For unvalidated properties, no error is thrown
            break
        }
    }

    /// Checks for incompatible settings and throws if found
    /// - Throws: `ConfigurationDomainError.incompatibleSettings` if incompatible settings are detected
    public func checkCompatibility() throws {
        // Check for incompatible settings
        if behavior.isEditable == false && behavior.enableCodeCompletion == true {
            throw ConfigurationDomainError.incompatibleSettings(
                setting1: "behavior.isEditable=false",
                setting2: "behavior.enableCodeCompletion=true"
            )
        }

        // Note: wrapLinesIndented was removed from Display configuration

        if performance.maxSyntaxHighlightingLength == 0 && display.enableSyntaxHighlighting == true {
            throw ConfigurationDomainError.incompatibleSettings(
                setting1: "performance.maxSyntaxHighlightingLength=0",
                setting2: "display.enableSyntaxHighlighting=true"
            )
        }
    }
}

// MARK: - Error Recovery

extension EditorConfiguration {
    /// Attempts to fix validation errors automatically
    /// - Returns: A new configuration with fixes applied
    /// - Throws: `ConfigurationDomainError` if fixes cannot be applied
    public func withAutoFixes() throws -> EditorConfiguration {
        var fixed = self

        // Fix font size
        if !PlatformConstants.validFontSizeRange.contains(display.fontSize) {
            fixed.display.fontSize = display.fontSize < PlatformConstants.validFontSizeRange.lowerBound
                ? PlatformConstants.validFontSizeRange.lowerBound
                : PlatformConstants.validFontSizeRange.upperBound
        }

        // Fix tab width
        if !PlatformConstants.validTabWidthRange.contains(layout.tabWidth) {
            fixed.layout.tabWidth = layout.tabWidth < PlatformConstants.validTabWidthRange.lowerBound
                ? PlatformConstants.validTabWidthRange.lowerBound
                : PlatformConstants.validTabWidthRange.upperBound
        }

        // Fix line height
        if !PlatformConstants.validLineHeightMultipleRange.contains(layout.lineHeightMultiple) {
            fixed.layout.lineHeightMultiple = layout.lineHeightMultiple < PlatformConstants.validLineHeightMultipleRange.lowerBound
                ? PlatformConstants.validLineHeightMultipleRange.lowerBound
                : PlatformConstants.validLineHeightMultipleRange.upperBound
        }

        // Fix gutter width
        if !PlatformConstants.validGutterWidthRange.contains(layout.gutterWidth) {
            fixed.layout.gutterWidth = max(layout.gutterWidth, PlatformConstants.validGutterWidthRange.lowerBound)
        }

        // Fix max highlighting length
        if !PlatformConstants.validHighlightingLengthRange.contains(performance.maxSyntaxHighlightingLength) {
            fixed.performance.maxSyntaxHighlightingLength = max(
                performance.maxSyntaxHighlightingLength,
                PlatformConstants.validHighlightingLengthRange.lowerBound
            )
        }

        // Fix incompatible settings
        if !fixed.behavior.isEditable && fixed.behavior.enableCodeCompletion {
            fixed.behavior.enableCodeCompletion = false
        }

        // Note: wrapLinesIndented was removed from Display configuration

        // Validate the fixed configuration
        try fixed.validateWithDomainError()

        return fixed
    }
}
