# Deprecation Timeline

@Metadata {
    @PageKind(article)
    @PageImage(purpose: card, source: "advanced-features-hero")
}

Track deprecated APIs and their removal timeline to ensure smooth migrations.

## Overview

This document provides a comprehensive timeline for deprecated APIs in CodeEditorPlugin. Each deprecated API includes:
- The version when it was deprecated
- The recommended replacement
- The planned removal version
- Migration guidance

## Deprecation Policy

CodeEditorPlugin follows semantic versioning (SemVer) and maintains deprecated APIs for:
- **Minor versions**: Deprecated APIs remain functional with warnings
- **Major versions**: Deprecated APIs may be removed
- **Minimum support**: At least 2 minor versions or 6 months, whichever is longer

## Current Deprecations

### Version 1.0.0 Deprecations

These APIs were deprecated in version 1.0.0 and will be removed in version 2.0.0.

#### Singleton Patterns

##### MemoryMonitor.shared
- **Deprecated**: v1.0.0
- **Removal**: v2.0.0 (Q2 2025)
- **Replacement**: Use dependency injection
- **Migration**:
```swift
// Old (deprecated)
let monitor = MemoryMonitor.shared

// New (recommended)
let monitor = MemoryMonitor()
var config = EditorConfiguration()
config.performance.memoryMonitor = monitor
```

##### UnifiedEventSystem.shared
- **Deprecated**: v1.0.0
- **Removal**: v2.0.0 (Q2 2025)
- **Replacement**: Use dependency injection
- **Migration**:
```swift
// Old (deprecated)
UnifiedEventSystem.shared.publish(event)

// New (recommended)
let eventSystem = UnifiedEventSystem()
var config = EditorConfiguration()
config.eventSystem = eventSystem
eventSystem.publish(event)
```

##### ContextMenuCoordinator.shared
- **Deprecated**: v1.0.0
- **Removal**: v2.0.0 (Q2 2025)
- **Replacement**: Use dependency injection
- **Migration**: Pass coordinator instances to components that need them

##### ToolbarCoordinator.shared
- **Deprecated**: v1.0.0
- **Removal**: v2.0.0 (Q2 2025)
- **Replacement**: Use dependency injection
- **Migration**: Pass coordinator instances to components that need them

##### InputCoordinator.shared
- **Deprecated**: v1.0.0
- **Removal**: v2.0.0 (Q2 2025)
- **Replacement**: Use dependency injection
- **Migration**: Pass coordinator instances to components that need them

#### API Naming Consistency

##### Boolean Property Names
The following properties were renamed for consistency with Swift naming conventions:

###### CodeEditorView Properties
- **showInvisibleCharacters** → **isInvisibleCharactersEnabled**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  
- **showLineNumbers** → **isLineNumbersEnabled**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  
- **syntaxHighlightingEnabled** → **isSyntaxHighlightingEnabled**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  
- **selectedLineHighlightingEnabled** → **isSelectedLineHighlightEnabled**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  
- **codeFoldingEnabled** → **isCodeFoldingEnabled**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  
- **showFoldingControls** → **isFoldingControlsEnabled**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  
- **enableCodeCompletion** → **isCodeCompletionEnabled**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)

###### EditorConfiguration Properties
- **showLineNumbers** → **isLineNumbersEnabled**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  - **Location**: EditorConfiguration.Display
  
- **syntaxHighlighting** → **enableSyntaxHighlighting**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  - **Location**: EditorConfiguration.Display
  
- **showAnnotations** → **enableAnnotations**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  - **Location**: EditorConfiguration.Display
  
- **showCodeFolding** → **enableCodeFolding**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  - **Location**: EditorConfiguration.Display
  
- **enableAutoCompletion** → **enableCodeCompletion**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  - **Location**: EditorConfiguration.Behavior
  
- **smartQuotes** → **isAutomaticQuoteSubstitutionEnabled**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  - **Location**: EditorConfiguration.Behavior

#### Property Renames

##### EditorConfiguration.Layout
- **lineSpacing** → **lineHeightMultiple**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  - **Reason**: Aligns with platform text system terminology

##### EditorConfiguration.Performance
- **maxHighlightingLength** → **maxSyntaxHighlightingLength**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  - **Reason**: More descriptive name

##### String+Extensions
- **cursorTextProvider** → **predicateTextProvider**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  - **Reason**: Better describes the functionality

#### SwiftUI Modifiers

##### CodeEditorTheme
- **shouldBecomeFirstResponder(_:)** → **becomeFirstResponder(_:)**
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  - **Reason**: Simpler, more direct naming

#### Platform Capabilities

##### PlatformCapabilities
- **isPhone** property → **deviceType** enum
  - **Deprecated**: v1.0.0
  - **Removal**: v2.0.0 (Q2 2025)
  - **Migration**:
```swift
// Old (deprecated)
if PlatformCapabilities.shared.isPhone {
    // Phone-specific code
}

// New (recommended)
switch PlatformCapabilities.shared.deviceType {
case .phone:
    // Phone-specific code
case .pad:
    // iPad-specific code
case .mac:
    // Mac-specific code
case .tv:
    // Apple TV-specific code
case .watch:
    // Apple Watch-specific code
case .vision:
    // Apple Vision Pro-specific code
case .unknown:
    // Fallback code
}
```

## Migration Guide

### Step 1: Update Dependencies
Ensure you're using the latest version of CodeEditorPlugin before migrating:
```swift
.package(url: "https://github.com/yourusername/CodeEditorPlugin.git", from: "1.0.0")
```

### Step 2: Enable Deprecation Warnings
In your build settings, ensure deprecation warnings are enabled:
- Xcode: Build Settings → "Treat Warnings as Errors" → No (to see warnings)
- SwiftPM: Add `-Xswiftc -warn-deprecated-uses` to build flags

### Step 3: Address Warnings Systematically
1. **Singletons**: Replace all singleton usage with dependency injection
2. **Property Names**: Update to new boolean property names
3. **Configuration**: Use the new property names in EditorConfiguration
4. **Platform Detection**: Switch to deviceType enum

### Step 4: Test Thoroughly
After migration:
1. Run your full test suite
2. Test on all supported platforms
3. Verify performance hasn't degraded
4. Check memory usage patterns

## Future Deprecations

### Version 1.1.0 Changes

#### MemoryMonitor Auto-Start Removal
- **Changed**: v1.1.0
- **Description**: MemoryMonitor no longer starts monitoring automatically in the initializer
- **Migration**:
```swift
// v1.0.0 (automatic start)
let monitor = MemoryMonitor()
// Monitoring started automatically

// v1.1.0+ (explicit start required)
let monitor = MemoryMonitor()
monitor.startMonitoring() // Must call explicitly
```
- **Reason**: Provides better control over when resource-intensive monitoring begins
- **Note**: This is a behavioral change, not an API removal

### Under Consideration
- **Legacy theme format**: Migration to new theme system
- **Synchronous highlighting APIs**: Move to async-only
- **File-based configuration**: Move to code-based only

## Best Practices

### For Library Users
1. **Stay Updated**: Follow release notes for deprecation announcements
2. **Migrate Early**: Don't wait until the last minute
3. **Test Incrementally**: Migrate one API at a time
4. **Use Compiler Warnings**: Let the compiler guide your migration

### For Contributors
1. **Document Deprecations**: Always include migration guidance
2. **Provide Alternatives**: Never deprecate without a replacement
3. **Use Semantic Versioning**: Follow the deprecation policy
4. **Add to This Document**: Keep the timeline updated

## Version History

- **v1.0.0** (December 2024): Initial deprecations for API consistency
- **v1.1.0** (Planned Q1 2025): Memory monitoring improvements
- **v2.0.0** (Planned Q2 2025): Major version with deprecated API removal

## See Also

- <doc:Migration-Guide>
- <doc:API-Stability>
- <doc:Versioning-Policy>
- <doc:Release-Notes>