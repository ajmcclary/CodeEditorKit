# Platform Abstraction

@Metadata {
    @PageColor(orange)
}

Learn how CodeEditorPlugin's sophisticated abstraction layer enables true cross-platform development.

## Overview

The platform abstraction system goes beyond simple conditional compilation to provide a unified API that automatically adapts to each platform while maintaining native performance and feel. Built with careful attention to Mac Catalyst compatibility, it ensures your code works seamlessly across macOS, iOS, and Mac Catalyst.

## Design Principles

### Use `#if canImport` for Platform Detection

**Always use `#if canImport(AppKit)` or `#if canImport(UIKit)` instead of `#if os()`** for better Catalyst compatibility:

```swift
// ✅ Correct - Works properly with Catalyst
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
// macOS-specific code
#elseif canImport(UIKit)
// iOS and Catalyst code
#endif

// ❌ Avoid - Can cause issues with Catalyst
#if os(macOS)
// This won't work correctly for Catalyst apps
#endif
```

### Explicit Catalyst Handling

When Catalyst needs different behavior from iOS:

```swift
#if targetEnvironment(macCatalyst)
// Catalyst-specific code
#elseif canImport(AppKit)
// macOS-specific code
#else
// iOS-specific code
#endif
```

## Unified Type System

Write your code once using platform-agnostic types:

```swift
// Platform-agnostic type aliases
let color: PlatformColor = .systemBlue
let font: PlatformFont = PlatformFonts.monospacedSystemFont(ofSize: 14)
let view: PlatformView = myCustomView

// Cross-platform font helpers
let systemFont = PlatformFonts.systemFont(ofSize: 16, weight: .medium)
let systemSize = PlatformFonts.systemFontSize
```

### Modular Font System

Fonts are now organized in a dedicated `PlatformFonts` helper for better maintainability:

```swift
// These types work identically on all platforms
let backgroundColor = PlatformColors.systemBackground
let textColor = PlatformColors.label
let codeFont = PlatformFonts.monospacedSystemFont(ofSize: 14, weight: .regular)
```

### Available Platform Types

- `PlatformColor` → NSColor/UIColor
- `PlatformFont` → NSFont/UIFont  
- `PlatformView` → NSView/UIView
- `PlatformViewController` → NSViewController/UIViewController
- `PlatformImage` → NSImage/UIImage

### Hex Color Support

Create colors from hex strings (cross-platform):

```swift
// Create colors from hex strings
let primaryColor = PlatformColor(hexString: "#FF6B6B")
let backgroundColor = PlatformColor(hexString: "#1E1E1E", alpha: 0.95)
```

## Semantic Color System

Adaptive colors that respond to dark/light mode:

```swift
// Semantic colors adapt automatically
PlatformColors.label              // Primary text
PlatformColors.secondaryLabel     // Secondary text
PlatformColors.systemBackground   // Main background
PlatformColors.secondarySystemBackground
PlatformColors.controlBackground  // Control backgrounds
```

## Core Components

### PlatformImports.swift

Provides type aliases and semantic color/font systems:

- **Type Aliases**: `PlatformColor`, `PlatformFont`, `PlatformView`, etc.
- **Semantic Colors**: `PlatformColors.label`, `.systemBackground`, etc.
- **Font Helpers**: `PlatformFonts.monospacedSystemFont()`, etc.

### PlatformCapabilities.swift

Runtime capability detection and feature availability:

```swift
let capabilities = PlatformCapabilities.shared

// Check platform
switch capabilities.currentPlatform {
case .macOS:
    print("Running on macOS")
case .iOS:
    print("Running on iOS")
case .catalyst:
    print("Running on Mac Catalyst")
}

// Check features
if capabilities.supportsTextKit2 {
    // Use TextKit2 features
}

// Get optimized configuration
let config = capabilities.recommendedConfiguration()
```

### CrossPlatformCoordinator.swift

Manages feature parity and platform-specific behaviors:

```swift
let coordinator = CrossPlatformCoordinator.shared

// Get platform-optimized values
let fontSize = coordinator.platformAdjustments.defaultFontSize
let gutterWidth = coordinator.platformAdjustments.gutterWidth

// Check feature availability
if coordinator.isFeatureAvailable(\.minimap) {
    // Enable minimap feature
}

// Configure input handling
coordinator.configureInputHandling(for: textView)
```

### TextInputFeatures.swift

Protocol-based abstraction for text input features:

```swift
// Create platform-appropriate text input features
let features = TextInputFeaturesFactory.create()

// Apply to text view
let config = EditorConfiguration()
config.applyTextInputFeatures(to: textView)
```

## Platform Differences

### macOS
- Full keyboard shortcut support
- Touch Bar support
- Multiple windows
- Context menus with submenus
- Hardware acceleration always available

### iOS
- Touch and gesture support
- Apple Pencil support (iPad)
- Limited keyboard shortcuts
- Simplified toolbar
- Larger default font sizes

### Mac Catalyst
- Hybrid of macOS and iOS features
- Multiple window support
- Keyboard shortcuts available
- No Touch Bar support
- Intermediate font sizes

## Best Practices

### Platform Detection Pattern

```swift
// Use this pattern for platform-specific code
#if targetEnvironment(macCatalyst)
    // Catalyst-specific implementation
#elseif canImport(AppKit)
    // macOS-specific implementation
#elseif canImport(UIKit)
    // iOS-specific implementation
#endif
```

### Feature Availability Checking

```swift
// Always check before using platform-specific features
let capabilities = PlatformCapabilities.shared
if capabilities.supportsFeature {
    // Use the feature
} else {
    // Provide fallback
}
```

### iOS Stubs for macOS Features

```swift
// Provide stubs for iOS when adding macOS-only features
#if canImport(AppKit)
public struct MacFeature {
    public func performAction() { /* implementation */ }
}
#else
// iOS stub
public struct MacFeature {
    public func performAction() { /* no-op or alternative */ }
}
#endif
```

### Testing All Platforms

Always test your code on:
- macOS native
- iOS (iPhone and iPad)
- Mac Catalyst

## Migration Guide

### From `#if os()` to `#if canImport()`

```swift
// Before
#if os(macOS)
let color = NSColor.labelColor
#else
let color = UIColor.label
#endif

// After
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
let color = NSColor.labelColor
#elseif canImport(UIKit)
let color = UIColor.label
#endif

// Better - Use abstraction
let color = PlatformColors.label
```

### From Direct Types to Platform Types

```swift
// Before
var font: NSFont  // or UIFont

// After
var font: PlatformFont
```

### Adding Catalyst Support

```swift
// Before (iOS and macOS only)
#if os(macOS)
    // macOS code
#else
    // iOS code
#endif

// After (with Catalyst support)
#if targetEnvironment(macCatalyst)
    // Catalyst-specific code
#elseif canImport(AppKit)
    // macOS code
#else
    // iOS code
#endif
```

## Common Issues and Solutions

### Issue: Code doesn't work on Catalyst
**Solution**: Replace `#if os()` with `#if canImport()` and add explicit Catalyst handling.

### Issue: Colors don't adapt to dark mode
**Solution**: Use semantic colors from `PlatformColors` instead of hard-coded colors.

### Issue: Feature crashes on older OS versions
**Solution**: Use `PlatformCapabilities` to check feature availability at runtime.

### Issue: UI looks wrong on different platforms
**Solution**: Use `CrossPlatformCoordinator.platformAdjustments` for platform-specific values.

## Adding New Abstractions

When adding new platform-specific features:

1. **Define the abstraction** (protocol or type alias)
2. **Implement for each platform** using `#if canImport()`
3. **Add Catalyst-specific handling** if needed
4. **Provide iOS stubs** for macOS-only features
5. **Add tests** to `PlatformAbstractionTests.swift`
6. **Document** platform differences

Example:

```swift
// 1. Define abstraction
protocol MyFeature {
    func performAction()
}

// 2. Implement for platforms
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
struct AppKitMyFeature: MyFeature {
    func performAction() { /* macOS */ }
}
#else
struct UIKitMyFeature: MyFeature {
    func performAction() { /* iOS/Catalyst */ }
}
#endif

// 3. Create factory
enum MyFeatureFactory {
    static func create() -> MyFeature {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return AppKitMyFeature()
        #else
        return UIKitMyFeature()
        #endif
    }
}
```

## Benefits

- **50% Less Platform Code**: Write UI logic once
- **Automatic Adaptation**: Colors and fonts adapt to each platform
- **Native Performance**: No abstraction penalties
- **Future-Proof**: New platform features automatically available
- **Catalyst Ready**: Full support for Mac Catalyst apps

## See Also

- <doc:Architecture-Overview>
- <doc:macOS-Integration>
- <doc:iOS-Integration>
- <doc:Catalyst-Best-Practices>