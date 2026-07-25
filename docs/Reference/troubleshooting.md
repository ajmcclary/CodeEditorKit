# Troubleshooting

Common issues and their solutions when using CodeEditorKit.

## Overview

This guide helps you resolve common issues that may arise when integrating or using CodeEditorKit in your applications.

## Build Issues

### Swift Version Requirements

**Issue**: Build errors about unavailable APIs or syntax errors.

**Solution**: Ensure you're using Swift 6.3+ and Xcode 26.3+:
```bash
swift --version  # Should show Swift version 6.3 or higher
```

### Missing Dependencies

**Issue**: "No such module 'SwiftSyntax'" error.

**Solution**: Clean and rebuild:
```bash
swift package clean
swift build
```

Or in Xcode:
1. **Product → Clean Build Folder** (⇧⌘K)
2. **File → Packages → Reset Package Caches**

## Performance Issues

### Large File Handling

**Issue**: Editor becomes slow with files over 1MB.

**Solution**: Enable performance optimizations:
```swift
var config = EditorConfiguration()
config.performance.useHardwareAcceleration = true
config.performance.maxSyntaxHighlightingLength = 500_000 // Limit to 500KB
config.performance.usesRangeBasedHighlighting = true
config.performance.maxVisibleLines = 1_000
```

### Memory Usage

**Issue**: High memory usage with multiple editors.

**Solution**: Use memory-aware configuration:
```swift
let monitor = MemoryMonitor()
monitor.memoryThresholdMB = 250

var config = EditorConfiguration.default
let setup = EditorSetup(runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: monitor))
config.performance.maxFileSize = 5_000_000 // 5MB limit
```

### Syntax Highlighting Lag

**Issue**: Syntax highlighting lags behind typing.

**Solution**: Adjust debounce timing:
```swift
config.performance.highlightingDebounceInterval = .milliseconds(100)
```

## Layout Issues

### Double Line Numbers (macOS)

**Issue**: Line numbers appear twice on macOS.

**Solution**: Use either `CodeEditorView` directly OR `CodeEditorContainerView`, not both:
```swift
// Option 1: Direct view (macOS handles gutter internally)
let editor = CodeEditorView()
editor.isLineNumbersEnabled = true

// Option 2: Container view (manages gutter separately)
let container = CodeEditorContainerView()
container.configuration.display.isLineNumbersEnabled = true
```

### Gutter line numbers stop part-way down after scrolling (macOS)

**Issue**: After scrolling a document past the initial viewport, only the top ~10–15 rows of the visible viewport show line numbers in the gutter; the rest of the visible code area renders without numbers. The pattern is consistent regardless of scroll position.

**Cause**: A previous revision hosted the macOS gutter as a floating document subview via `scrollView.addFloatingSubview(_:for:)`. AppKit's floating-document-subview compositor only presented a partial strip of the floating view after vertical scrolling, so the renderer drew every visible line but most draw calls were discarded at compositing time. Diagnostic instrumentation in `GutterViewRenderer.draw` confirmed the renderer issued ~37 line-number draws per scrolled frame while only ~11 reached the screen.

**Solution**: The macOS gutter is now hosted by `LineNumberRulerView` (an `NSRulerView` subclass) and installed through `scrollView.verticalRulerView` with `hasVerticalRuler = true` / `rulersVisible = true`. The scroll view's ruler slot owns the gutter width; the macOS text container's leading inset only carries internal editor padding. If you see this symptom return after a host-level refactor, verify that `CodeEditorContainerView` is still using the vertical-ruler path rather than re-introducing `addFloatingSubview`.

The full investigation log (diagnostic data, ruled-out hypotheses, the layer/compositing anomaly that pointed at the host rather than the renderer) is preserved in [`../archive/Gutter-Line-Numbers-After-Scroll.md`](../archive/Gutter-Line-Numbers-After-Scroll.md).

### iOS Keyboard Overlap

**Issue**: Keyboard covers the editor on iOS.

**Solution**: The container view handles this automatically:
```swift
// Use CodeEditorContainerView for iOS
let container = CodeEditorContainerView()
// Keyboard avoidance is built-in
```

### Text Clipping

**Issue**: Text appears cut off at edges.

**Solution**: Ensure proper content insets:
```swift
editor.setUnifiedTextContainerInsets(EdgeInsets(uniform: 8))
if let documentRange = editor.textLayoutManager?.documentRange {
    editor.textLayoutManager?.ensureLayout(for: documentRange)
}
```

## Platform-Specific Issues

### LSP Not Working on iOS

**Issue**: Language Server Protocol features unavailable on iOS.

**Solution**: Local process-backed LSP is macOS-only because `Process` is unavailable on iOS. Keep local completion enabled, or connect to a remote language server with `LSPClient` and `WebSocketTransport`:
```swift
config.behavior.isCodeCompletionEnabled = true
```

## Configuration Issues

### Changes Not Applied

**Issue**: Configuration changes don't take effect.

**Solution**: Always apply configuration after changes:
```swift
var config = editor.configuration
config.display.fontSize = 16
editor.configuration = config  // Triggers update
```

### SwiftUI State Updates

**Issue**: Editor doesn't update when @State changes.

**Solution**: Use proper binding:
```swift
@State private var configuration = EditorConfiguration()

var body: some View {
    CodeEditor(text: $code)
        .environment(\.codeEditorConfiguration, configuration)
}
```

## Common Errors

### Invalid Text Ranges

**Issue**: "Invalid range" error when manipulating text.

**Solution**: Validate ranges before operations:
```swift
let utf16Length = editor.string.utf16.count
let requestedRange = NSRange(location: 0, length: 10)
let validRange = requestedRange.clamped(to: NSRange(location: 0, length: utf16Length))

if let textRange = NSTextRange(validRange) {
    editor.replaceCharacters(in: textRange, with: "new text")
}
```

### TextKit2 (always on)

As of 0.2.0 the framework is TextKit2-only on every supported platform — the legacy layout fallback was retired along with Catalyst. `PlatformCapabilities.supportsRequiredTextKit2Surface` always returns `true` on macOS / iOS 26.0+. If you have older code that branches on it, you can simplify the call site.

## Debugging Tips

### Enable Verbose Logging

```swift
let metrics = editor.configuration.eventSystem?.getMetrics()
CrossPlatformLogger.logger().info("Published events: \(metrics?.publishedCount ?? 0)")
```

### Check Platform Capabilities

```swift
let capabilities = PlatformCapabilities()
CrossPlatformLogger.logger().info("TextKit2: \(capabilities.supportsRequiredTextKit2Surface)")
CrossPlatformLogger.logger().info("Hardware acceleration: \(capabilities.supportsHardwareAcceleration)")
CrossPlatformLogger.logger().info("Touch Bar: \(capabilities.supportsTouchBar)")
```

### Monitor Memory

```swift
// Add memory monitoring
editor.memoryMonitor.startMonitoring()
let stats = editor.memoryMonitor.getMemoryStatistics()
CrossPlatformLogger.logger().info("Memory usage: \(stats.currentUsageMB)MB")
```

## Getting Help

If you encounter issues not covered here:

1. Check the comprehensive documentation in `CLAUDE.md`
2. Review the sample application for working examples
3. Search existing [GitHub issues](https://github.com/ajmcclary/CodeEditorKit/issues)
4. File a new issue with:
   - Platform and version information
   - Minimal reproduction code
   - Expected vs actual behavior
   - Any error messages

## See Also

- [Platform-Abstraction](../Platform/platform-abstraction.md)
- [Performance-Monitoring](../Performance/monitoring.md)
- [Configuration-System](../Configuration/system.md)
