# CodeEditorPlugin Platform Abstraction System

## Overview

The CodeEditorPlugin provides a comprehensive cross-platform abstraction system that enables seamless development across macOS and iOS platforms. This system goes beyond simple type aliases to provide runtime capability detection, performance optimization, and platform-appropriate UI patterns.

## Architecture Components

### 1. PlatformImports.swift - Type Aliases & Color System

```swift
// Basic type aliases for cross-platform compatibility
public typealias PlatformColor = NSColor  // macOS
public typealias PlatformColor = UIColor  // iOS

// Semantic color system
PlatformColors.label                    // Adaptive label color
PlatformColors.systemBackground         // Adaptive background color
PlatformColors.controlBackground        // Adaptive control background
```

### 2. PlatformCapabilities.swift - Runtime Feature Detection

```swift
let capabilities = PlatformCapabilities.shared

// Feature availability checking
if capabilities.supportsTextKit2 {
    // Use TextKit2 features
}

if capabilities.supportsHardwareAcceleration {
    // Enable GPU-accelerated rendering
}

// Memory-aware configuration
let config = capabilities.recommendedPerformanceConfiguration
```

### 3. CrossPlatformCoordinator.swift - UI Pattern Abstraction

```swift
let coordinator = CrossPlatformCoordinator()

// Platform-appropriate input handling
coordinator.configureInputHandling(for: textView)

// Context menu creation
let contextMenu = coordinator.createContextMenu(for: selectedText)
```

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

### Color System

```swift
// Semantic colors that adapt to light/dark mode
label: PlatformColors.label                     // Primary text
secondaryLabel: PlatformColors.secondaryLabel   // Secondary text
systemBackground: PlatformColors.systemBackground  // Main background
controlBackground: PlatformColors.controlBackground // Control backgrounds
separator: PlatformColors.separator             // Divider lines
```

### Font System

```swift
// Cross-platform font creation
let codeFont = PlatformFonts.monospacedSystemFont(ofSize: 14, weight: .regular)
let uiFont = PlatformFonts.systemFont(ofSize: 16, weight: .medium)

// System font size
let defaultSize = PlatformFonts.systemFontSize
```

### Runtime Capabilities

```swift
let capabilities = PlatformCapabilities.shared

// Check platform features
print("TextKit2 Support: \(capabilities.supportsTextKit2)")
print("Hardware Acceleration: \(capabilities.supportsHardwareAcceleration)")
print("Smooth Scrolling: \(capabilities.supportsSmoothScrolling)")

// Get optimal configuration
let config = capabilities.recommendedPerformanceConfiguration
textView.configure(with: config)
```

### Feature Availability Matrix

```swift
let coordinator = CrossPlatformCoordinator()

// Check specific feature availability
let availability = coordinator.featureAvailability

if availability[.syntaxHighlighting] == .fullSupport {
    // Enable full syntax highlighting
} else if availability[.syntaxHighlighting] == .partialSupport {
    // Enable basic syntax highlighting
}
```

### Input Handling Abstraction

```swift
let coordinator = CrossPlatformCoordinator()

// Configure platform-appropriate input handling
coordinator.configureInputHandling(for: textView)

// Handle different input types
coordinator.handleKeyboardInput(event: keyEvent)    // Keyboard
coordinator.handleMouseInput(event: mouseEvent)     // Mouse (macOS)
coordinator.handleTouchInput(event: touchEvent)     // Touch (iOS)
coordinator.handlePencilInput(event: pencilEvent)   // Apple Pencil (iPad)
```

## Platform-Specific Features

### macOS-Specific Features

```swift
#if canImport(AppKit)
// macOS-only features
- Touch Bar support
- Services menu integration
- AppleScript support
- Full keyboard shortcut support
- Mouse and trackpad gestures
#endif
```

### iOS-Specific Features

```swift
#if canImport(UIKit)
// iOS-only features
- Touch gestures and multi-touch
- Apple Pencil support
- Keyboard toolbar
- Share sheet integration
- Drag and drop
#endif
```

## Performance Optimization

### Memory-Aware Configuration

```swift
let capabilities = PlatformCapabilities.shared

// Get device-specific recommendations
let memoryConfig = capabilities.recommendedMemoryConfiguration
let cacheSize = capabilities.optimalCacheSize

// Apply optimizations
textView.configure(cacheSize: cacheSize)
textView.setMemoryPressureHandling(enabled: memoryConfig.enablePressureHandling)
```

### Hardware Acceleration

```swift
if capabilities.supportsHardwareAcceleration {
    // Enable Metal rendering
    textView.enableHardwareAcceleration()
    
    // Use GPU-accelerated syntax highlighting
    highlighter.useGPUAcceleration = true
}
```

## Best Practices

### 1. Always Use Platform Abstractions

```swift
// ✅ Good: Use platform abstractions
let color: PlatformColor = PlatformColors.label
let font: PlatformFont = PlatformFonts.systemFont(ofSize: 16)

// ❌ Bad: Direct platform types
#if canImport(AppKit)
let color = NSColor.labelColor
#else
let color = UIColor.label
#endif
```

### 2. Check Capabilities Before Using Features

```swift
// ✅ Good: Check capabilities first
if PlatformCapabilities.shared.supportsTextKit2 {
    enableTextKit2Features()
}

// ❌ Bad: Assume feature availability
enableTextKit2Features() // May crash on older systems
```

### 3. Use Semantic Colors

```swift
// ✅ Good: Semantic color names
backgroundColor = PlatformColors.systemBackground
textColor = PlatformColors.label

// ❌ Bad: Hard-coded colors
backgroundColor = PlatformColor.white  // Doesn't adapt to dark mode
```

### 4. Leverage Cross-Platform Coordinator

```swift
// ✅ Good: Use coordinator for complex platform differences
let coordinator = CrossPlatformCoordinator()
coordinator.configureInputHandling(for: textView)

// ❌ Bad: Manual platform-specific code scattered throughout
#if canImport(AppKit)
// Handle mouse events
#else
// Handle touch events
#endif
```

## Migration Guide

### From Direct Platform Types

```swift
// Before
#if canImport(AppKit)
let color = NSColor.labelColor
let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
#else
let color = UIColor.label
let font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
#endif

// After
let color = PlatformColors.label
let font = PlatformFonts.monospacedSystemFont(ofSize: 14, weight: .regular)
```

### From Manual Feature Detection

```swift
// Before
#if canImport(AppKit)
if #available(macOS 12.0, *) {
    // Use TextKit2
}
#endif

// After
if PlatformCapabilities.shared.supportsTextKit2 {
    // Use TextKit2
}
```

## API Reference

### PlatformColors

| Property | Description | macOS | iOS |
|----------|-------------|-------|-----|
| `label` | Primary text color | `NSColor.labelColor` | `UIColor.label` |
| `secondaryLabel` | Secondary text color | `NSColor.secondaryLabelColor` | `UIColor.secondaryLabel` |
| `systemBackground` | Main background | `NSColor.windowBackgroundColor` | `UIColor.systemBackground` |
| `controlBackground` | Control background | `NSColor.controlBackgroundColor` | `UIColor.systemGray6` |

### PlatformFonts

| Method | Description |
|--------|-------------|
| `monospacedSystemFont(ofSize:weight:)` | Creates monospaced font |
| `systemFont(ofSize:weight:)` | Creates system font |
| `systemFontSize` | Returns system default font size |

### PlatformCapabilities

| Property | Description |
|----------|-------------|
| `supportsTextKit2` | TextKit2 availability |
| `supportsHardwareAcceleration` | GPU acceleration support |
| `supportsSmoothScrolling` | Smooth scrolling availability |
| `recommendedPerformanceConfiguration` | Optimal performance settings |

## Testing Platform Code

```swift
// Test platform-specific behavior
func testPlatformColors() {
    let labelColor = PlatformColors.label
    XCTAssertNotNil(labelColor)
    
    #if canImport(AppKit)
    XCTAssertTrue(labelColor == NSColor.labelColor)
    #else
    XCTAssertTrue(labelColor == UIColor.label)
    #endif
}

// Test capability detection
func testCapabilities() {
    let capabilities = PlatformCapabilities.shared
    
    // These should always be available
    XCTAssertTrue(capabilities.supportsBasicTextEditing)
    XCTAssertTrue(capabilities.supportsColorCustomization)
}
```

## Conclusion

The CodeEditorPlugin platform abstraction system provides a robust foundation for cross-platform development while maintaining access to platform-specific optimizations. By using these abstractions, developers can write code once and deploy across macOS and iOS with confidence that the appropriate platform behaviors will be used.