# Platform Abstraction

Learn how CodeEditorPlugin's abstraction layer enables true cross-platform development across macOS and iOS.

## Overview

The platform abstraction system goes beyond simple conditional compilation to provide a unified API that automatically adapts to each platform while maintaining native performance and feel. As of 0.2.0, the framework targets **macOS and iOS / iPadOS only** — Mac Catalyst was retired (see [CHANGELOG](../../CHANGELOG.md) for the rationale). The abstractions described here are correspondingly simpler: every cross-platform branch is a clean two-way split between AppKit and UIKit.

## Design Principles

### Use `#if canImport` for Platform Detection

**Always use `#if canImport(AppKit)` or `#if canImport(UIKit)` instead of `#if os()`** — it keeps shared code from accidentally importing platform-only APIs in the wrong build, and stays robust if Apple ever ships another platform that shares one of those frameworks:

```swift
// ✅ Correct — works on macOS and iOS
#if canImport(AppKit)
// macOS-specific code (NSColor, NSFont, NSView)
#elseif canImport(UIKit)
// iOS / iPadOS code (UIColor, UIFont, UIView)
#endif

// ❌ Avoid — `os()` masks framework-availability and complicates future ports
#if os(macOS)
// ...
#endif
```

The codebase enforces this convention across hundreds of files; new code that uses `#if os()` will fail review.

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

Fonts are organized in a dedicated `PlatformFonts` helper for better maintainability:

```swift
// These types work identically on macOS and iOS
let backgroundColor = PlatformColors.systemBackground
let textColor = PlatformColors.label
let codeFont = PlatformFonts.monospacedSystemFont(ofSize: 14, weight: .regular)
```

### Available Platform Types

- `PlatformColor` → `NSColor` / `UIColor`
- `PlatformFont` → `NSFont` / `UIFont`
- `PlatformView` → `NSView` / `UIView`
- `PlatformViewController` → `NSViewController` / `UIViewController`
- `PlatformImage` → `NSImage` / `UIImage`

### Hex Color Support

Create colors from hex strings (cross-platform):

```swift
let primaryColor = PlatformColor(hexString: "#FF6B6B")
let backgroundColor = PlatformColor(hexString: "#1E1E1E", alpha: 0.95)
```

## Semantic Color System

Adaptive colors that respond to dark / light mode:

```swift
PlatformColors.label              // Primary text
PlatformColors.secondaryLabel     // Secondary text
PlatformColors.systemBackground   // Main background
PlatformColors.secondarySystemBackground
PlatformColors.controlBackground  // Control backgrounds
```

## Core Components

### `PlatformImports.swift`

Provides type aliases and semantic color / font systems:

- **Type aliases**: `PlatformColor`, `PlatformFont`, `PlatformView`, etc.
- **Semantic colors**: `PlatformColors.label`, `.systemBackground`, etc.
- **Font helpers**: `PlatformFonts.monospacedSystemFont()`, etc.

### `PlatformCapabilities.swift`

Runtime capability detection and feature availability:

```swift
let capabilities = PlatformCapabilities()

// Check platform — exhaustive, two-way switch
switch capabilities.currentPlatform {
case .macOS:
    CrossPlatformLogger.logger().info("Running on macOS")
case .iOS:
    CrossPlatformLogger.logger().info("Running on iOS / iPadOS")
}

// Check features
if capabilities.supportsRequiredTextKit2Surface {
    // TextKit2 is the only supported layout system as of 0.2.0
}

// Get optimized configuration
let config = capabilities.recommendedConfiguration()
```

### `CrossPlatformCoordinator.swift`

Manages feature parity and platform-specific behaviors:

```swift
let coordinator = CrossPlatformCoordinator.shared

let fontSize = coordinator.platformAdjustments.defaultFontSize
let gutterWidth = coordinator.platformAdjustments.gutterWidth

if coordinator.isFeatureAvailable(.minimap) {
    // Enable minimap feature
}

coordinator.configureInputHandling(for: textView)
```

### `TextInputFeatures.swift`

Protocol-based abstraction for text input features:

```swift
let features = TextInputFeaturesFactory.create()

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

### iOS / iPadOS

- Touch and gesture support
- Apple Pencil support (iPad)
- Hardware-keyboard shortcuts via `UIKeyCommand`
- Simplified toolbar
- Larger default font sizes
- iPad supports `NavigationSplitView`-based sidebars; iPhone uses stacked navigation

## Best Practices

### Platform Detection Pattern

```swift
#if canImport(AppKit)
    // macOS-specific implementation
#elseif canImport(UIKit)
    // iOS / iPadOS implementation
#endif
```

### Feature Availability Checking

```swift
let capabilities = PlatformCapabilities()
if capabilities.isFeatureAvailable(.minimap) {
    // Use the feature
} else {
    // Provide fallback
}
```

### iOS Stubs for macOS Features

```swift
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

### Testing Both Platforms

Run the test suite on:

- macOS native (`swift test --parallel`)
- iOS Simulator (`xcodebuild -scheme CodeEditorPlugin -destination "generic/platform=iOS Simulator"`)

The CI matrix exercises both. See [`docs/FeatureMatrix.md`](../FeatureMatrix.md) for what works where.

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
#if canImport(AppKit)
let color = NSColor.labelColor
#elseif canImport(UIKit)
let color = UIColor.label
#endif

// Better — use the abstraction
let color = PlatformColors.label
```

### From Direct Types to Platform Types

```swift
// Before
var font: NSFont  // or UIFont

// After
var font: PlatformFont
```

### Migrating From a 0.1.x Catalyst Build

If you previously consumed the framework on Mac Catalyst:

- Replace `EditorConfiguration.catalyst` with `.macOS` (for Mac targets) or `.iOS` (for iPad targets).
- Drop any switches over `PlatformCapabilities.Platform.catalyst` — the case is gone.
- Remove `targetEnvironment(macCatalyst)` from your build configurations; the framework no longer evaluates that flag.
- Apple Silicon Macs can run the iOS build directly via "Designed for iPad" if you need an iPad-shaped app on Mac.

## Common Issues and Solutions

### Issue: Colors don't adapt to dark mode

**Solution:** use semantic colors from `PlatformColors` instead of hard-coded colors.

### Issue: Feature crashes on older OS versions

**Solution:** use `PlatformCapabilities` to check feature availability at runtime, plus `@available` for compile-time gating.

### Issue: UI looks wrong on different platforms

**Solution:** use `CrossPlatformCoordinator.platformAdjustments` for platform-specific values.

## Adding New Abstractions

When adding new platform-specific features:

1. **Define the abstraction** (protocol or type alias).
2. **Implement for each platform** using `#if canImport()`.
3. **Provide iOS stubs** for macOS-only features.
4. **Add tests** to `PlatformAbstractionTests.swift`.
5. **Document** platform differences here and in [`docs/FeatureMatrix.md`](../FeatureMatrix.md).

Example:

```swift
// 1. Define abstraction
protocol MyFeature {
    func performAction()
}

// 2. Implement for platforms
#if canImport(AppKit)
struct AppKitMyFeature: MyFeature {
    func performAction() { /* macOS */ }
}
#else
struct UIKitMyFeature: MyFeature {
    func performAction() { /* iOS */ }
}
#endif

// 3. Create factory
enum MyFeatureFactory {
    static func create() -> MyFeature {
        #if canImport(AppKit)
        return AppKitMyFeature()
        #else
        return UIKitMyFeature()
        #endif
    }
}
```

## Benefits

- **Less platform-conditional code:** write UI logic once.
- **Automatic adaptation:** colors and fonts adapt to each platform's appearance system.
- **Native performance:** no abstraction penalties — the type aliases compile to the underlying AppKit / UIKit types.
- **Two-platform clarity:** since Catalyst was retired, every conditional is a clean two-way split.

## See Also

- [Architecture-Overview](../Internals/architecture-overview.md)
- [macOS-Integration](macos.md)
- [iOS-Integration](ios.md)
- [UIKit-AppKit-Integration](uikit-appkit.md)
- [Feature Matrix](../FeatureMatrix.md)
