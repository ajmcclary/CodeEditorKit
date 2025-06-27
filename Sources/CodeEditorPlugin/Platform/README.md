# Platform Abstraction Layer

This directory contains the platform abstraction layer for CodeEditorPlugin, providing seamless cross-platform support for macOS, iOS, and Mac Catalyst.

## Design Principles

### 1. Use `#if canImport` for Platform Detection

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

### 2. Explicit Catalyst Handling

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

### 3. Use Platform Type Aliases

Always use the platform-agnostic type aliases defined in `PlatformImports.swift`:

```swift
// ✅ Correct
let color: PlatformColor = PlatformColors.label
let font: PlatformFont = PlatformFonts.monospacedSystemFont(ofSize: 14)

// ❌ Avoid
let color = NSColor.labelColor  // or UIColor.label
```

## Core Components

### PlatformImports.swift

Provides type aliases and semantic color/font systems:

- **Type Aliases**: `PlatformColor`, `PlatformFont`, `PlatformView`, etc.
- **Semantic Colors**: `PlatformColors.label`, `.systemBackground`, etc.
- **Font Helpers**: `PlatformFonts.monospacedSystemFont()`, etc.

### PlatformCapabilities.swift

Runtime capability detection and feature availability:

- **Platform Detection**: `.macOS`, `.iOS`, `.catalyst`
- **Feature Detection**: TextKit2, hardware acceleration, etc.
- **Recommended Configurations**: Platform-optimized settings
- **Catalyst-Specific Adjustments**: Font sizes, spacing, and behavior

### CrossPlatformCoordinator.swift

Manages feature parity and platform-specific behaviors:

- **Feature Availability Matrix**: Track feature support across platforms
- **Platform Adjustments**: Font sizes, spacing, touch targets
- **Input Handling**: Keyboard, mouse, touch, and pencil input
- **Context Menus**: Platform-appropriate menu creation

### TextInputFeatures.swift

Protocol-based abstraction for text input features:

- **Platform-Specific Implementations**: `AppKitTextInputFeatures`, `UIKitTextInputFeatures`
- **Feature Detection**: Spell checking, grammar checking, smart quotes
- **Configuration Application**: Apply settings to text views

### MacOSVersionDetection.swift

Simplified version detection for macOS features:

- **Version Checking**: Uses actual macOS version numbers (12, 13, 14)
- **Feature Detection**: TextKit2 stability, CADisplayLink support
- **iOS Stubs**: Provides stubs for iOS builds

## Usage Examples

### Basic Platform Types

```swift
import CodeEditorPlugin

// Use platform-agnostic types
var backgroundColor: PlatformColor = PlatformColors.systemBackground
var textFont: PlatformFont = PlatformFonts.monospacedSystemFont(ofSize: 14)

// Cross-platform view creation
let containerView: PlatformView = createEditorContainer()
```

### Runtime Capability Detection

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

### Platform-Specific Adjustments

```swift
let coordinator = CrossPlatformCoordinator.shared

// Get platform-optimized values
let fontSize = coordinator.platformAdjustments.defaultFontSize
let gutterWidth = coordinator.platformAdjustments.gutterWidth

// Check feature availability
if coordinator.isFeatureAvailable(\.minimap) {
    // Enable minimap feature
}
```

### Text Input Features

```swift
// Create platform-appropriate text input features
let features = TextInputFeaturesFactory.create()

// Apply to text view
let config = EditorConfiguration()
config.applyTextInputFeatures(to: textView)
```

### Hex Color Support

```swift
// Create colors from hex strings (cross-platform)
let primaryColor = PlatformColor(hexString: "#FF6B6B")
let backgroundColor = PlatformColor(hexString: "#1E1E1E", alpha: 0.95)
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

### 1. Platform Detection Pattern

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

### 2. Feature Availability Checking

```swift
// Always check before using platform-specific features
let capabilities = PlatformCapabilities.shared
if capabilities.supportsFeature {
    // Use the feature
} else {
    // Provide fallback
}
```

### 3. iOS Stubs for macOS Features

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

### 4. Testing All Platforms

Always test your code on:
- macOS native
- iOS (iPhone and iPad)
- Mac Catalyst

Use `PlatformAbstractionTests.swift` as a reference for comprehensive testing.

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