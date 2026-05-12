# Performance Optimizations

This page summarizes the optimization paths that exist in the current package: syntax-highlighting coordination, range-based invalidation, memory-aware caches, iOS large-file handling, and performance regression tests.

## Syntax Highlighting

### Optimized Coordinator

`OptimizedSyntaxHighlightingCoordinator` wraps the base `SyntaxHighlightingCoordinator` with cache lookup, viewport slicing, chunking, cache warming, and circuit-breaker behavior:

```swift
let memoryMonitor = MemoryMonitor()

let coordinator = OptimizedSyntaxHighlightingCoordinator(
    memoryMonitor: memoryMonitor,
    configuration: .performance
)

let tokens = await coordinator.highlight(
    text: source,
    language: .swift,
    visibleRange: NSRange(location: 0, length: min(source.utf16.count, 5_000))
)
```

Tune it directly when you own the coordinator:

```swift
var configuration = OptimizedSyntaxHighlightingCoordinator.HighlightingConfiguration.performance
configuration.viewportPadding = 200
configuration.maxChunkSize = 2_000
configuration.circuitBreakerThreshold = 0.05

coordinator.updateConfiguration(configuration)
```

### Background and Streaming Paths

`AsyncSyntaxHighlighter` owns debouncing and cancellation for editor updates. It delegates background work to `BackgroundSyntaxHighlighter`, while `StreamingHighlighter` supports chunked highlighting for large inputs. App code usually configures these through `EditorConfiguration.Performance` rather than constructing requests manually.

```swift
var config = EditorConfiguration()
config.performance.highlightingDebounceInterval = .milliseconds(150)
config.performance.textChangeDebounceInterval = .milliseconds(150)
config.performance.maxSyntaxHighlightingLength = 1_000_000
```

### Range-Based Highlighting

The range-based pipeline is opt-in and experimental:

```swift
var config = EditorConfiguration()
config.performance.usesRangeBasedHighlighting = true
```

Internally this uses `RangeBasedHighlightingController`, `RangeHighlightProviding`, and `RangeStore` to invalidate and query visible ranges without forcing every consumer through attributed-text mutation.

### Tree-sitter Spike

The Tree-sitter-shaped provider remains internal architecture only. The core package does not expose a runtime Tree-sitter switch and does not ship C grammar binaries; syntax highlighting uses SwiftSyntax for Swift and regex definitions for the rest of the language catalog. Real C grammar packaging is tracked in [Tree-sitter packaging](../TreeSitterPackaging.md).

## Memory and Cache Behavior

Use injected `MemoryMonitor` instances to coordinate cleanup across editors, caches, and LSP managers:

```swift
let memoryMonitor = MemoryMonitor()

var config = EditorConfiguration()
config.performance.memoryMonitor = memoryMonitor
```

Memory-aware components register cleanup handlers and report freed memory estimates. Avoid global monitors; inject one through configuration or initializers.

## iOS Large-File Handling

iOS-specific large-file settings live in `EditorConfiguration.Performance`:

```swift
var config = EditorConfiguration.iOS
config.performance.enableIOSOptimizations = true
config.performance.iOSLargeFileThreshold = 1_048_576
config.performance.iOSMaxHighlightingChunk = 100_000
```

`IOSLargeFileOptimizer` applies chunk sizing and feature reduction appropriate for memory-constrained devices.

## Performance Budgets

Runtime and test code share the `PerformanceBudget` definitions:

```swift
let reporter = PerformanceBudgetReporter()
await reporter.record(operation: "completion_request", duration: 0.043)

let report = await reporter.generateReport()
CrossPlatformLogger.logger().debug(report.summary)
```

Predefined operation keys include:

| Key | Target |
|---|---:|
| `syntax_highlighting` | 16 ms |
| `text_layout` | 16 ms |
| `scrolling` | 8 ms |
| `completion_request` | 50 ms |
| `find_in_file` | 50 ms |
| `fuzzy_search` | 100 ms |
| `memory_pressure_recovery` | 500 ms |

## Test Execution

The repository ships parallel test plans and a helper script:

```bash
swift test --parallel
./Scripts/run-parallel-tests.sh
```

For Xcode-driven test plans:

```bash
xcodebuild test \
  -scheme CodeEditorPlugin \
  -testPlan CodeEditorPlugin-SmartParallel \
  -parallel-testing-enabled YES \
  -maximum-concurrent-test-device-destinations 4
```

`Tests/CodeEditorPluginTests/TestMemoryOptimizer.swift` provides bounded data generation for memory-sensitive tests:

```swift
let source = MemoryBoundedTestData.swiftCode(lines: 1_000)
```

`Tests/CodeEditorPluginTests/XCTestCase+PerformanceBudget.swift` adds `measureAgainstBudget` and `measureAsyncAgainstBudget` helpers for regression coverage.

## Debugging Slow Paths

- Use `PerformanceMonitor` for precise operation timing.
- Use `PerformanceBudgetReporter` when a named budget exists.
- Use Instruments for UI frame pacing, allocation spikes, and TextKit2 layout behavior.
- Check `SyntaxHighlightingPerformanceTracker.generateReport()` when investigating tokenization or cache-hit behavior.
- Prefer `CrossPlatformLogger.logger()` for diagnostic output.

## See Also

- [Performance monitoring](monitoring.md)
- [Memory monitor](memory-monitor.md)
- [Test performance configuration](test-config.md)
- [Syntax highlighting](../Features/syntax-highlighting.md)
- [Text pipeline performance baselines](../Architecture/TextPipelinePerformanceBaselines.md)
