# Performance Monitoring

Monitor and optimize your editor's performance with built-in tools.

## Overview

CodeEditorPlugin includes comprehensive performance monitoring tools that provide real-time insights into rendering performance, memory usage, and syntax highlighting efficiency.

> Tip: For detailed optimization techniques, see [Performance-Optimizations](optimizations.md). For test-specific performance configuration, see [Test-Performance-Configuration](test-config.md).

## Enabling Performance Monitoring

### SwiftUI

```swift
struct MonitoredEditor: View {
    @State private var config = EditorConfiguration()
    @State private var showMetrics = false
    
    var body: some View {
        VStack {
            CodeEditor(text: $code)
                .environment(\.codeEditorConfiguration, config)
                .onAppear {
                    config.performance.enableMetrics = true
                }
            
            if showMetrics {
                PerformanceMetricsView()
            }
        }
    }
}
```

### Programmatic Access

```swift
let monitor = editor.performanceMonitor
monitor.startMonitoring()

// Get current metrics
let fps = monitor.currentFrameRate
let memory = monitor.memoryUsage
let highlightTime = monitor.lastHighlightDuration
```

## Available Metrics

### Frame Rate Analysis

Monitor rendering performance:

```swift
monitor.frameRateHandler = { fps in
    if fps < 30 {
        print("Performance warning: \(fps) FPS")
    }
}
```

Metrics:
- Current FPS
- Average FPS
- Minimum FPS
- Frame drops

### Memory Profiling

Track memory usage:

```swift
monitor.memoryHandler = { usage in
    print("Memory: \(usage.used / 1024 / 1024) MB")
    if usage.percentage > 80 {
        print("High memory usage warning")
    }
}
```

Metrics:
- Current usage
- Peak usage
- Available memory
- Leak detection

### Syntax Highlighting Performance

Measure highlighting efficiency:

```swift
monitor.highlightingHandler = { metrics in
    print("Highlighted \(metrics.lineCount) lines in \(metrics.duration)ms")
    print("Average: \(metrics.averagePerLine)ms per line")
}
```

Metrics:
- Total duration
- Lines processed
- Cache hit rate
- Tokens generated

### Large File Handling

Special metrics for large files:

```swift
if file.size > 500_000 {
    monitor.enableLargeFileMetrics()
    // Additional metrics:
    // - Viewport rendering time
    // - Progressive loading progress
    // - Memory mapping efficiency
}
```

## Performance Optimization

### Automatic Optimizations

The editor automatically optimizes based on metrics:

```swift
config.performance.autoOptimize = true
// Automatically enables:
// - Viewport rendering for large files
// - Reduced animation complexity under load
// - Aggressive caching when memory allows
```

### Manual Optimization

Fine-tune performance settings:

```swift
// For large files
config.performance.maxSyntaxHighlightingLength = 1_000_000
config.performance.viewportExpansion = 50 // lines

// For smooth scrolling
config.performance.smoothScrolling = true
config.performance.scrollingDebounce = 16 // ms

// For responsiveness
config.performance.backgroundProcessingDelay = 100 // ms
config.performance.useHardwareAcceleration = true
```

## Performance Best Practices

### 1. Monitor Key Metrics

```swift
// Set up alerts for critical metrics
monitor.setThreshold(.frameRate, value: 30) { metric in
    print("FPS dropped below 30: \(metric.value)")
}
```

### 2. Use Viewport Rendering

```swift
// Enable for files over 100KB
if file.size > 100_000 {
    config.performance.enableViewportRendering = true
}
```

### 3. Optimize Highlighting

```swift
// Cache commonly used patterns
config.performance.enablePatternCache = true
config.performance.patternCacheSize = 1000
```

### 4. Manage Memory

```swift
// Set memory limits
config.performance.maxMemoryUsage = 100 // MB
config.performance.enableMemoryWarnings = true
```

## Debugging Performance Issues

### Performance Logs

Enable detailed logging:

```swift
PerformanceLogger.level = .verbose
PerformanceLogger.categories = [
    .rendering,
    .highlighting,
    .memory,
    .io
]
```

### Bottleneck Detection

Identify performance bottlenecks:

```swift
let analyzer = PerformanceAnalyzer()
analyzer.analyze(editor) { report in
    print("Bottlenecks found:")
    for issue in report.bottlenecks {
        print("- \(issue.description): \(issue.impact)")
    }
}
```

## Export Performance Data

Save metrics for analysis:

```swift
// Export as JSON
let data = monitor.exportMetrics(format: .json)
try data.write(to: metricsURL)

// Export as CSV for spreadsheet analysis
let csv = monitor.exportMetrics(format: .csv)
try csv.write(to: csvURL)
```

## See Also

- [Configuration-System](../Configuration/system.md)
- [Swift6-Concurrency](../Concurrency/swift6.md)
- [Architecture-Overview](../Internals/architecture-overview.md)
- [Performance-Optimization-Integration](optimizations.md)
- [Performance-Optimizations](optimizations.md)
- [Test-Performance-Configuration](test-config.md)