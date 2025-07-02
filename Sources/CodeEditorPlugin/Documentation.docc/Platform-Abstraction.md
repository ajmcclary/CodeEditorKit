# Platform Abstraction

@Metadata {
    @PageColor(orange)
}

Learn how CodeEditorPlugin's sophisticated abstraction layer enables true cross-platform development.

## Overview

The platform abstraction system goes beyond simple conditional compilation to provide a unified API that automatically adapts to each platform while maintaining native performance and feel.

## Unified Type System

Write your code once using platform-agnostic types:

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

## Runtime Capability Detection

Check feature availability at runtime:

```swift
let capabilities = PlatformCapabilities.shared

if capabilities.supportsTextKit2 {
    // Use TextKit2 features
}

if capabilities.supportsHardwareAcceleration {
    // Enable GPU acceleration
}

// Get optimal configuration
let config = capabilities.recommendedPerformanceConfiguration
```

## Cross-Platform Input Handling

Handle input differences transparently:

```swift
let coordinator = CrossPlatformCoordinator()

// Configure once, works everywhere
coordinator.configureInputHandling(for: textView)

// Unified event handling
coordinator.handleTouchInput(event: touchEvent)    // iOS
coordinator.handleMouseInput(event: mouseEvent)    // macOS
coordinator.handleKeyboardShortcut(event: keyEvent) // Both
```

## Platform-Specific Features

Access platform features when needed:

```swift
#if canImport(AppKit)
// macOS-specific features
editor.enableHoverEffects()
editor.setupTouchBar()
#endif

#if canImport(UIKit)
// iOS-specific features  
editor.setupKeyboardAvoidance()
editor.enableHapticFeedback()
#endif
```

## Best Practices

1. **Always Use Abstractions**: Prefer `PlatformColor` over `NSColor`/`UIColor`
2. **Check Capabilities**: Use runtime detection for optional features
3. **Semantic Colors**: Use semantic colors for automatic dark mode support
4. **Test All Platforms**: Verify behavior on macOS, iOS, and Catalyst

## Benefits

- **50% Less Platform Code**: Write UI logic once
- **Automatic Adaptation**: Colors and fonts adapt to each platform
- **Native Performance**: No abstraction penalties
- **Future-Proof**: New platform features automatically available

## See Also

- <doc:Architecture-Overview>
- <doc:macOS-Integration>
- <doc:iOS-Integration>