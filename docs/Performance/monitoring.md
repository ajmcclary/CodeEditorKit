# Performance Monitoring

CodeEditorPlugin exposes performance instrumentation through actor-based monitors, memory cleanup hooks, budget checks, and optional SwiftUI insight views.

## Runtime Monitoring

Use `PerformanceMonitor` to measure named operations:

```swift
let monitor = PerformanceMonitor()
let token = await monitor.startMeasuring("syntax-highlighting")

// Perform the operation.

await monitor.endMeasuring(token)
let report = await monitor.generateReport()

CrossPlatformLogger.logger().debug(report.summary)
```

For scoped measurement:

```swift
let tokens = try await monitor.measure("highlight-visible-range") {
    try await highlighter.highlightVisibleRange()
}
```

`PerformanceMonitor` retains the most recent 1,000 metrics or one hour of data, whichever limit is reached first. Operations over 100 ms are logged as warnings.

## Performance Insights UI

`PerformanceInsights` aggregates a `PerformanceMonitor`, `MemoryMonitor`, and TextKit2 summary data into a SwiftUI-readable model:

```swift
@StateObject private var memoryMonitor = MemoryMonitor()
@State private var insights: PerformanceInsights?

var body: some View {
    VStack {
        CodeEditor(text: $code)

        if let insights {
            PerformanceInsightsPanel(insights: insights)
        }
    }
    .task { @MainActor in
        insights = PerformanceInsights(memoryMonitor: memoryMonitor)
    }
}
```

The insight panel surfaces status, active issues, recommendations, and a detailed report. Some real-time fields are intentionally coarse; use `PerformanceMonitor` and `PerformanceBudgetReporter` for precise operation timing.

## Memory Monitoring

Inject a shared `MemoryMonitor` through configuration when multiple editor instances should share cleanup pressure:

```swift
let memoryMonitor = MemoryMonitor()

var configuration = EditorConfiguration()
configuration.performance.memoryMonitor = memoryMonitor

CodeEditor(text: $code)
    .environment(\.codeEditorConfiguration, configuration)
```

Components such as caches and LSP managers can register cleanup handlers with the same monitor. See [memory monitor](memory-monitor.md) for pressure handling examples.

## Performance Budgets

`PerformanceBudget` defines operation budgets and `PerformanceBudgetReporter` records measurements:

```swift
let reporter = PerformanceBudgetReporter()
await reporter.record(operation: "syntax_highlighting", duration: 0.018)

let report = await reporter.generateReport()
CrossPlatformLogger.logger().debug(report.summary)
```

The package also provides XCTest helpers in `Tests/CodeEditorPluginTests/XCTestCase+PerformanceBudget.swift` for enforcing budgets in performance regression tests.

## Production Metrics

`ProductionPerformanceMetrics` records high-level runtime events such as syntax highlighting, text layout, memory cleanup, and code folding. `AdaptivePerformanceMode` can then derive a lower-cost configuration when the active document or device characteristics demand it.

## Practical Tuning

Prefer the public `EditorConfiguration.Performance` properties for app-level tuning:

```swift
var configuration = EditorConfiguration()
configuration.performance.maxSyntaxHighlightingLength = 1_000_000
configuration.performance.textChangeDebounceInterval = .milliseconds(150)
configuration.performance.highlightingDebounceInterval = .milliseconds(150)
configuration.performance.renderingUpdateStrategy = .adaptive
configuration.performance.usesRangeBasedHighlighting = true
```

On iOS, large-file behavior is controlled by:

```swift
configuration.performance.enableIOSOptimizations = true
configuration.performance.iOSLargeFileThreshold = 1_048_576
configuration.performance.iOSMaxHighlightingChunk = 100_000
```

## Debugging Slow Paths

- Measure the exact operation with `PerformanceMonitor`.
- Check budget status with `PerformanceBudgetReporter`.
- Inspect memory pressure and cleanup counts with `MemoryMonitor`.
- Use Instruments for UI frame pacing, allocations, and TextKit2 layout details.
- Avoid adding new global monitors; inject monitors through configuration or initializers.

## See Also

- [Performance optimizations](optimizations.md)
- [Memory monitor](memory-monitor.md)
- [Test performance configuration](test-config.md)
- [Swift 6 concurrency](../Concurrency/swift6.md)
