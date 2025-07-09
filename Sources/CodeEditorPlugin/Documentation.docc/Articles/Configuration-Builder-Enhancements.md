# Configuration Builder Enhancements

Learn about the enhanced EditorConfigurationBuilder with feature-based extensions and improved validation.

## Overview

The `EditorConfigurationBuilder` has been significantly enhanced with a cleaner architecture, feature-based organization, and advanced validation capabilities. The builder now provides better type safety, clearer organization, and comprehensive validation feedback.

## Feature-Based Organization

The builder is now organized into logical feature extensions, making it easier to discover and use related configuration options:

### Display Configuration
```swift
import CodeEditorPlugin

let config = EditorConfigurationBuilder()
    // Display settings
    .fontSize(14)
    .showLineNumbers(true)
    .enableSyntaxHighlighting(true)
    .highlightSelectedLine(true)
    .selectedLineHighlightColor(.systemBlue.withAlphaComponent(0.1))
    .enableAnnotations(true)
    .showInvisibleCharacters(false)
    .showMinimap(true)
    .enableCodeFolding(true)
    .showFoldingControls(true)
    .build()
```

### Layout Configuration
```swift
let config = EditorConfigurationBuilder()
    // Layout settings
    .gutterWidth(50)
    .tabWidth(4)
    .insertSpacesForTabs(true)
    .wrapLines(false)
    .lineSpacing(1.2)
    .build()
```

### Behavior Configuration
```swift
let config = EditorConfigurationBuilder()
    // Behavior settings
    .isEditable(true)
    .autoIndent(true)
    .enableCodeCompletion(true)
    .enableSpellCheck(false)
    .build()
```

### Performance Configuration
```swift
let config = EditorConfigurationBuilder()
    // Performance settings
    .useHardwareAcceleration(true)
    .maxHighlightingLength(500_000)
    .memoryMonitor(customMonitor)
    .build()
```

## Language-Specific Configuration

Configure the editor for specific programming languages with optimized settings:

```swift
// Swift development
let swiftConfig = EditorConfigurationBuilder()
    .language(.swift)  // Sets appropriate tab width, syntax highlighting, etc.
    .fontSize(14)
    .build()

// Web development
let webConfig = EditorConfigurationBuilder()
    .language(.javascript)  // 2-space indentation, appropriate settings
    .enableCodeCompletion(true)
    .build()

// Python development
let pythonConfig = EditorConfigurationBuilder()
    .language(.python)  // 4-space indentation, no tabs
    .enableSpellCheck(false)
    .build()
```

### Language Presets

Each language automatically configures:
- Tab width and indentation style
- Syntax highlighting enablement
- Code completion settings
- Line wrapping preferences
- Spell checking defaults

Supported languages include:
- **4-space languages**: Swift, Python, Java, SQL, Ruby, PHP, Shell
- **2-space languages**: JavaScript, TypeScript, HTML, CSS, XML, JSON, YAML
- **Tab languages**: Go, Rust, C, C++
- **Document languages**: Markdown (with spell check), Plain Text

## Theme Support

Apply visual themes to match your application:

```swift
// Dark theme
let darkConfig = EditorConfigurationBuilder()
    .theme(.dark)
    .fontSize(14)
    .build()

// Custom theme
let customTheme = CodeEditorSwiftUITheme(
    name: "custom",
    backgroundColor: Color(NSColor.windowBackgroundColor),
    textColor: Color.primary,
    selectionColor: Color.accentColor.opacity(0.3),
    commentColor: Color.gray,
    keywordColor: Color.purple,
    stringColor: Color.red,
    numberColor: Color.orange,
    symbolColor: Color.blue
)

let customConfig = EditorConfigurationBuilder()
    .theme(customTheme)
    .build()
```

## Convenience Methods

### Presentation Mode
```swift
let presentationConfig = EditorConfigurationBuilder()
    .presentationMode()  // Large font, no line numbers, wrapped text
    .build()

// Equivalent to:
// .fontSize(18)
// .showLineNumbers(false)
// .enableAnnotations(false)
// .highlightSelectedLine(false)
// .wrapLines(true)
```

### Code Review Mode
```swift
let reviewConfig = EditorConfigurationBuilder()
    .codeReviewMode()  // Read-only with all visual aids
    .build()

// Equivalent to:
// .isEditable(false)
// .showLineNumbers(true)
// .enableAnnotations(true)
// .highlightSelectedLine(true)
// .enableSyntaxHighlighting(true)
```

## Advanced Validation

The builder now provides multiple validation methods:

### Build with Validation
```swift
let result = EditorConfigurationBuilder()
    .fontSize(200)  // Too large!
    .buildWithValidation()

switch result {
case .success(let config):
    // Use the configuration
    editor.apply(config)
    
case .failure(let error):
    // Handle validation error
    for issue in error.issues {
        print("Issue: \(issue.message) at \(issue.path)")
    }
}
```

### Build with Automatic Fixes
```swift
let (config, fixes) = EditorConfigurationBuilder()
    .fontSize(200)      // Will be clamped to 72
    .tabWidth(-1)       // Will be set to 4
    .gutterWidth(1000)  // Will be clamped to 200
    .buildWithFeedback()

// Log what was fixed
for fix in fixes {
    print("Fixed \(fix.issue.path): \(fix.oldValue ?? "nil") -> \(fix.newValue)")
}
// Output:
// Fixed display.fontSize: 200.0 -> 72.0
// Fixed layout.tabWidth: -1 -> 4
// Fixed layout.gutterWidth: 1000.0 -> 200.0
```

### Build with Detailed Report
```swift
let (config, report) = EditorConfigurationBuilder()
    .fontSize(200)
    .buildWithReport()

print("Original issues: \(report.originalIssues.count)")
print("Applied fixes: \(report.appliedFixes.count)")
print("Validation passed: \(report.isValid)")

// Access detailed information
for issue in report.originalIssues {
    print("\(issue.severity): \(issue.message)")
    if issue.suggestedFix != nil {
        print("  Suggested: \(issue.suggestedFix!)")
    }
}
```

## Validation Rules

The builder validates:

1. **Font Size**: Must be between 8 and 72 points
2. **Tab Width**: Must be between 1 and 8 spaces
3. **Gutter Width**: Must be between 20 and 200 points
4. **Line Spacing**: Must be between 0.5 and 3.0
5. **Performance Limits**: Max highlighting length must be positive

## Quick Configuration Methods

Create common configurations with static methods:

```swift
// Language-specific configurations
let swiftEditor = EditorConfigurationBuilder.swift()
let webEditor = EditorConfigurationBuilder.web()
let pythonEditor = EditorConfigurationBuilder.python()
let docsEditor = EditorConfigurationBuilder.documentation()
let viewer = EditorConfigurationBuilder.readOnly()
```

## Method Chaining

All builder methods support fluent chaining:

```swift
let config = EditorConfigurationBuilder()
    // Display
    .fontSize(14)
    .showLineNumbers(true)
    .enableSyntaxHighlighting(true)
    // Layout
    .tabWidth(4)
    .insertSpacesForTabs(true)
    // Behavior
    .isEditable(true)
    .autoIndent(true)
    // Performance
    .useHardwareAcceleration(true)
    // Language & Theme
    .language(.swift)
    .theme(.dark)
    // Build
    .build()
```

## Starting from Existing Configuration

Modify existing configurations:

```swift
// Start from a preset
let config = EditorConfigurationBuilder(base: .minimal)
    .fontSize(16)
    .enableSyntaxHighlighting(true)
    .build()

// Create variations
let darkConfig = EditorConfigurationBuilder(base: currentConfig)
    .theme(.dark)
    .build()

// Use instance method
let modified = existingConfig.builder()
    .showLineNumbers(false)
    .build()
```

## Type Safety Improvements

The builder now uses an enum instead of optional booleans internally:

```swift
// Internal implementation prevents ambiguity
private enum BooleanOverride {
    case inherit      // Use base configuration value
    case enable       // Force to true
    case disable      // Force to false
}

// This provides clearer intent than Bool?
// where nil vs false was ambiguous
```

## Integration Examples

### SwiftUI
```swift
struct ContentView: View {
    @State private var code = ""
    
    var body: some View {
        CodeEditor(text: $code)
            .environment(\.codeEditorConfiguration,
                EditorConfigurationBuilder()
                    .language(.swift)
                    .fontSize(14)
                    .theme(.dark)
                    .enableCodeFolding(true)
                    .build()
            )
    }
}
```

### UIKit/AppKit
```swift
let textView = CodeEditorView()

let config = EditorConfigurationBuilder()
    .language(.python)
    .fontSize(13)
    .showLineNumbers(true)
    .tabWidth(4)
    .insertSpacesForTabs(true)
    .enableCodeCompletion(true)
    .build()

config.apply(to: textView)
```

## Performance Considerations

The builder performs validation only when building:

```swift
// Efficient - validation happens once
let builder = EditorConfigurationBuilder()
for option in userOptions {
    builder.applyOption(option)
}
let config = builder.build()  // Single validation pass

// Inefficient - multiple validations
var config = EditorConfiguration()
for option in userOptions {
    config = applyOption(config, option)
    config.validate()  // Validates each time
}
```

## Custom Extensions

Extend the builder for your specific needs:

```swift
extension EditorConfigurationBuilder {
    /// Configure for company coding standards
    func companyStandards() -> Self {
        fontSize(13)
            .tabWidth(2)
            .insertSpacesForTabs(true)
            .showLineNumbers(true)
            .enableSyntaxHighlighting(true)
            .maxHighlightingLength(100_000)
    }
    
    /// Configure for accessibility
    func accessibleMode() -> Self {
        fontSize(18)
            .lineSpacing(1.5)
            .highlightSelectedLine(true)
            .selectedLineHighlightColor(.systemYellow.withAlphaComponent(0.3))
    }
}

// Usage
let config = EditorConfigurationBuilder()
    .companyStandards()
    .language(.typescript)
    .build()
```

## See Also

- <doc:Configuration-System>
- <doc:Configuration-Presets>
- ``EditorConfigurationBuilder``
- ``EditorConfiguration``
- ``ConfigurationValidator``