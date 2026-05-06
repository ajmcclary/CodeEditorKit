# IOSLargeFileOptimizer

@Metadata {
    @PageColor(orange)
}

Optimizes large file handling specifically for iOS devices with limited memory, providing adaptive rendering and aggressive memory management.

## Overview

`IOSLargeFileOptimizer` implements iOS-specific optimizations for handling large text files on memory-constrained devices. It provides viewport-based syntax highlighting, aggressive memory management, adaptive rendering modes, and automatic optimization based on file size and memory pressure. This ensures smooth performance even with multi-megabyte files on iOS devices.

## Key Features

- **Adaptive Optimization Modes**: Normal, Large File, and Extreme Optimization
- **Viewport-Based Highlighting**: Only highlights visible text portions
- **Memory Pressure Response**: Aggressive cleanup on memory warnings
- **Reduced Visual Effects**: Disables expensive rendering for large files
- **Configuration Preservation**: Restores settings when optimizations are disabled

## Optimization Modes

### Normal Mode
No optimizations applied for files under 1MB.

### Large File Mode (1MB - 10MB)
- Disables automatic syntax highlighting
- Enables viewport-based highlighting
- Reduces undo stack to 10 levels
- Disables spell checking

### Extreme Optimization Mode (10MB+)
All large file optimizations plus:
- Minimal undo history (3 levels)
- Simplified text rendering
- Disabled text attachments
- Non-contiguous layout for better scrolling

## Basic Usage

### Creating an Optimizer

```swift
let optimizer = IOSLargeFileOptimizer(
    textView: codeEditorView,
    memoryMonitor: memoryMonitor,
    performanceMonitor: performanceSystem
)

// Enable optimizations based on current text
optimizer.enableOptimizations()

// Disable when switching to smaller files
optimizer.disableOptimizations()
```

### Configuration

```swift
// Customize optimization thresholds
optimizer.optimizationThreshold = 500_000  // 500KB
optimizer.maxHighlightingRange = 50_000   // 50KB chunks
optimizer.viewportExpansion = 0.3         // 30% viewport expansion

// Set memory pressure response mode
optimizer.memoryPressureMode = .aggressive
```

## Memory Pressure Modes

### Ignore Mode
Optimizations based only on file size, not memory pressure.

### Adaptive Mode (Default)
Balances performance with memory usage:
```swift
// Automatically enables optimizations when:
// - Memory usage > 100MB and file > 1MB
// - Memory usage > 200MB and file > 500KB
```

### Aggressive Mode
Most aggressive memory management for severely constrained devices.

## Monitoring Optimization Metrics

```swift
// Published properties for UI binding
optimizer.$isOptimizing  // Currently optimizing
optimizer.$currentMode   // Current optimization mode
optimizer.$metrics       // Performance metrics

// Access metrics
print("Chunks processed: \(optimizer.metrics.chunksProcessed)")
print("Memory reclaimed: \(optimizer.metrics.memoryReclaimed) bytes")
print("Average chunk time: \(optimizer.metrics.averageChunkTime)s")
```

## SwiftUI Integration

```swift
struct EditorView: View {
    @StateObject private var optimizer: IOSLargeFileOptimizer
    
    var body: some View {
        VStack {
            CodeEditor(text: $content)
                .iOSLargeFileOptimization(content.count > 500_000)
            
            if optimizer.isOptimizing {
                HStack {
                    Image(systemName: "speedometer")
                    Text("Optimized Mode: \(optimizer.currentMode.rawValue)")
                }
                .foregroundColor(.orange)
            }
        }
    }
}
```

## Viewport-Based Highlighting

The optimizer implements smart viewport highlighting:

```swift
// Highlighting happens in chunks around the visible area
// - Visible viewport is calculated
// - Expanded by viewportExpansion factor (default 50%)
// - Only this region gets syntax highlighting
// - Updates as user scrolls with configurable delay
```

## Memory Cleanup Strategy

When memory pressure is detected:

1. **Syntax Highlighting Cache**: Cleared (est. 5MB)
2. **Undo Stack**: Cleared (est. 2MB)
3. **Layout Manager**: Forced cleanup (est. 3MB)

```swift
// The optimizer registers a critical priority cleanup handler
memoryMonitor.registerCleanupHandler(
    identifier: "ios-large-file",
    priority: .critical
) { 
    // Performs aggressive cleanup
}
```

## Configuration Preservation

The optimizer preserves original settings:

```swift
// Original values are stored when optimizations begin:
// - maxSyntaxHighlightingLength
// - isSyntaxHighlightingEnabled
// - adaptivePerformanceMode

// When disabled, all settings are restored
optimizer.disableOptimizations()
// Original configuration is restored
```

## Platform-Specific Optimizations

### iOS vs macOS Differences

| Feature | iOS | macOS |
|---------|-----|--------|
| Optimization Threshold | 1MB | 10MB |
| Viewport Expansion | 50% | 150% |
| Max Highlighting Range | 100KB | 1MB |
| Memory Threshold | 100MB | 1GB |

### TextKit Optimizations

```swift
// iOS-specific TextKit settings for large files:
textView.layoutManager.allowsNonContiguousLayout = true
textView.layoutManager.showsInvisibleCharacters = false
textView.layoutManager.showsControlCharacters = false
```

## Best Practices

1. **Memory Monitoring**: Always provide a MemoryMonitor instance
2. **Performance Tracking**: Use UnifiedPerformanceSystem for metrics
3. **Threshold Tuning**: Adjust thresholds based on target devices
4. **User Feedback**: Show optimization status in UI
5. **Testing**: Test with files at boundary sizes (1MB, 10MB)

## Common Issues and Solutions

### Highlighting Not Working
```swift
// Ensure viewport highlighting is active
if optimizer.currentMode != .normal {
    // Viewport highlighting is active
    // Check viewportExpansion setting
}
```

### Settings Not Restored
```swift
// Force restoration if needed
optimizer.disableOptimizations()

// Verify restoration
assert(codeEditorView.configuration.display.isSyntaxHighlightingEnabled)
```

## Performance Tips

1. **Preemptive Optimization**: Enable before loading large files
2. **Batch Operations**: Disable during bulk edits, re-enable after
3. **Memory Monitoring**: Watch `memoryMonitor.memoryStats` for pressure
4. **Scroll Performance**: Increase viewport delay for smoother scrolling

## See Also

- ``MemoryMonitor``
- ``UnifiedPerformanceSystem``
- ``AdaptivePerformanceMode``
- ``EditorConfiguration/Performance``