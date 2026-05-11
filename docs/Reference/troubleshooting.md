# Troubleshooting

Common issues and their solutions when using CodeEditorPlugin.

## Overview

This guide helps you resolve common issues that may arise when integrating or using CodeEditorPlugin in your applications.

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
config.performance.useViewportRendering = true
```

### Memory Usage

**Issue**: High memory usage with multiple editors.

**Solution**: Use memory-aware configuration:
```swift
let memoryConfig = PlatformCapabilities.shared.recommendedMemoryConfiguration

if memoryConfig.availableMemory < 4_000_000_000 { // 4GB
    config.performance.maxFileSize = 5_000_000 // 5MB limit
}
```

### Syntax Highlighting Lag

**Issue**: Syntax highlighting lags behind typing.

**Solution**: Adjust debounce timing:
```swift
config.behavior.syntaxHighlightingDebounce = 100 // milliseconds
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
editor.textContainerInset = NSSize(width: 5, height: 5)
editor.layoutManager?.ensureLayout(for: editor.textContainer!)
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

### CodeEditorError.invalidRange

**Issue**: "Invalid range" error when manipulating text.

**Solution**: Validate ranges before operations:
```swift
do {
    let range = NSRange(location: 0, length: 10)
    try editor.replaceTextSafe(in: range, with: "new text")
} catch CodeEditorError.invalidRange(let range, let length) {
    print("Range \(range) exceeds text length \(length)")
}
```

### TextKit2 (always on)

As of 0.2.0 the framework is TextKit2-only on every supported platform — the TextKit1 fallback was retired along with Catalyst. `PlatformCapabilities.supportsTextKit2` always returns `true` on macOS / iOS 26.3+. If you have older code that branches on it, you can simplify the call site.

## Debugging Tips

### Enable Verbose Logging

```swift
// Enable performance monitoring
let stats = editor.performanceStatistics
print("Average render time: \(stats.averageRenderTime)ms")
print("Syntax highlighting time: \(stats.syntaxHighlightingTime)ms")
```

### Check Platform Capabilities

```swift
let capabilities = PlatformCapabilities.shared
print("TextKit2: \(capabilities.supportsTextKit2)")
print("Hardware acceleration: \(capabilities.supportsHardwareAcceleration)")
print("Touch Bar: \(capabilities.supportsTouchBar)")
```

### Monitor Memory

```swift
// Add memory monitoring
editor.memoryMonitor.startMonitoring { stats in
    print("Memory usage: \(stats.residentMemory / 1024 / 1024)MB")
}
```

## Getting Help

If you encounter issues not covered here:

1. Check the comprehensive documentation in `CLAUDE.md`
2. Review the sample application for working examples
3. Search existing [GitHub issues](https://github.com/ajmcclary/CodeEditorPlugin/issues)
4. File a new issue with:
   - Platform and version information
   - Minimal reproduction code
   - Expected vs actual behavior
   - Any error messages

## See Also

- [Platform-Abstraction](../Platform/platform-abstraction.md)
- [Performance-Monitoring](../Performance/monitoring.md)
- [Configuration-System](../Configuration/system.md)
