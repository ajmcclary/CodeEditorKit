# EditorConfigurationBuilder Auto-Fix Behavior

Learn how the EditorConfigurationBuilder automatically validates and corrects configuration issues.

## Overview

The `EditorConfigurationBuilder` includes an automatic validation and fix system that ensures your configuration values are within safe and performant ranges. When you call `build()`, the builder automatically applies fixes for common configuration issues.

## Auto-Fix Behavior

### What Gets Auto-Fixed

The builder automatically corrects the following issues:

#### Display Settings
- **Font Size**: Clamps values to the range 6.0-120.0
  - Values below 6.0 are set to 6.0
  - Values above 120.0 are set to 120.0

#### Layout Settings
- **Tab Width**: Clamps values to the range 1-32
  - Values below 1 are set to 1
  - Values above 32 are set to 32
- **Gutter Width**: Ensures minimum width of 40.0 for line number visibility
  - Values below 20.0 are set to 40.0
- **Line Spacing**: Prevents negative values
  - Negative values are set to 0
- **Text Container Width Fraction**: Clamps to valid percentage range 0.0-1.0

#### Behavior Settings
- **Auto-Indent**: Disabled in read-only mode
- **Code Completion**: Disabled in read-only mode

#### Performance Settings
- **Max Syntax Highlighting Length**: Ensures reasonable limits
  - Negative values are set to 0
  - Values above 1,000,000 are clamped to 1,000,000
- **Smooth Scrolling**: Disabled when hardware acceleration is off

### Build Methods

The builder provides several methods with different auto-fix behaviors:

```swift
// Standard build - applies all auto-fixes silently
let config = builder.build()

// Build with validation - returns errors without auto-fixing
let result = builder.buildWithValidation()
switch result {
case .success(let config):
    // Use valid configuration
case .failure(let error):
    // Handle validation errors
}

// Build with feedback - applies fixes and returns what was changed
let (config, fixes) = builder.buildWithFeedback()
for fix in fixes {
    print("Fixed \(fix.issue.path): \(fix.oldValue) -> \(fix.newValue)")
}

// Build with detailed report - comprehensive validation information
let (config, report) = builder.buildWithReport()
print("Found \(report.originalIssues.count) issues")
print("Applied \(report.appliedFixes.count) fixes")
```

## Examples

### Example 1: Font Size Auto-Fix

```swift
let config = EditorConfigurationBuilder()
    .fontSize(200) // Too large!
    .build()

// config.display.fontSize is now 120.0 (maximum allowed)
```

### Example 2: Read-Only Mode Auto-Fix

```swift
let config = EditorConfigurationBuilder()
    .isEditable(false)
    .enableCodeCompletion(true) // Incompatible!
    .build()

// config.behavior.enableCodeCompletion is now false
```

### Example 3: Performance Auto-Fix

```swift
let config = EditorConfigurationBuilder()
    .useHardwareAcceleration(false)
    .smoothScrolling(true) // Requires hardware acceleration!
    .build()

// config.performance.smoothScrolling is now false
```

### Example 4: Getting Fix Feedback

```swift
let (config, fixes) = EditorConfigurationBuilder()
    .fontSize(3)      // Too small
    .tabWidth(100)    // Too large
    .buildWithFeedback()

// fixes contains:
// - fontSize: 3.0 -> 6.0
// - tabWidth: 100 -> 32
```

## Validation Severity Levels

The validator categorizes issues by severity:

- **Error**: Critical issues that prevent proper operation (always auto-fixed)
- **Warning**: Issues that may cause unexpected behavior (auto-fixed by default)
- **Info**: Suggestions for better performance or user experience (auto-fixed by default)

## Disabling Auto-Fix

If you need to validate without auto-fixing, use `buildWithValidation()`:

```swift
let result = EditorConfigurationBuilder()
    .fontSize(200)
    .buildWithValidation()

switch result {
case .success(let config):
    // Configuration is valid (or only has auto-fixable issues)
    print("Config is valid")
case .failure(let error):
    // Configuration has critical issues
    for issue in error.issues {
        print("\(issue.severity): \(issue.message)")
    }
}
```

## Best Practices

1. **Use Standard Build for Production**: The `build()` method ensures safe configurations
2. **Use Feedback Methods for Debugging**: When troubleshooting, use `buildWithFeedback()` or `buildWithReport()`
3. **Validate User Input**: When accepting user-provided values, use `buildWithValidation()` to provide feedback
4. **Log Auto-Fixes**: In development, log auto-fixes to catch configuration mistakes early

## Related Documentation

- ``EditorConfigurationBuilder``
- ``ConfigurationValidator``
- ``ValidationIssue``
- ``ValidationFix``
- ``ValidationReport``