# Performance Optimizations

Comprehensive performance enhancements implemented across syntax highlighting, test execution, and memory management.

## Overview

This article describes the extensive performance optimizations implemented in CodeEditorPlugin, including advanced syntax highlighting algorithms, parallel test execution strategies, and intelligent memory management improvements that ensure smooth 60fps performance even with large files.

## Syntax Highlighting Optimizations

### Incremental Highlighting

The `IncrementalSyntaxHighlighter` provides efficient partial updates for text changes:

**Key Features:**

```swift
// The system automatically uses incremental highlighting
editorView.highlightingMode = .incremental

// Performance metrics are tracked automatically
let metrics = await highlighter.getPerformanceMetrics()
print("Incremental highlights: \(metrics.incrementalHighlights)")
print("Full highlights: \(metrics.fullHighlights)")
```

### Background Queue Optimizations

The `BackgroundSyntaxHighlighter` implements a sophisticated priority system:

#### Priority Levels

| Priority | Value | Use Case |
|----------|-------|----------|
| Critical | 3 | Immediate viewport updates |
| High | 2 | Near viewport or important updates |
| Normal | 1 | Standard highlighting |
| Low | 0 | Background pre-highlighting |

#### Features

```swift
// Submit highlighting request with priority
let request = HighlightingRequest(
    text: documentText,
    language: .swift,
    priority: .critical // For viewport content
)

let result = await backgroundHighlighter.highlight(request)
```

### Optimized Syntax Highlighting Coordinator

The `OptimizedSyntaxHighlightingCoordinator` provides advanced performance features:

```swift
let config = HighlightingConfiguration(
    enableViewportOptimization: true,
    viewportPadding: 500,           // Characters around viewport
    maxChunkSize: 5000,             // Chunk size for large files
    enableIncrementalHighlighting: true,
    cacheWarmingEnabled: true,
    circuitBreakerThreshold: 0.1    // 100ms threshold
)

coordinator.configuration = config
```

**Features:**

## Test Performance Optimizations

### Parallel Test Execution

Three test execution plans optimize test running:

1. **CodeEditorPlugin-Parallel.xctestplan**: Basic parallel execution
2. **CodeEditorPlugin-SmartParallel.xctestplan**: Groups tests by shared resources
3. **run-parallel-tests.sh**: Script for running tests in parallel

```bash
# Run tests in parallel
./Scripts/run-parallel-tests.sh

# Using swift test directly
swift test --parallel --num-workers auto

# Using xcodebuild with test plan
xcodebuild test \
  -scheme CodeEditorPlugin \
  -testPlan CodeEditorPlugin-SmartParallel \
  -parallel-testing-enabled YES \
  -maximum-concurrent-test-device-destinations 4
```

### Test Timeouts

Prevent runaway tests with configurable timeouts:

```swift
func testWithTimeout() async throws {
    try await withTimeout(seconds: 10) {
        // Test code that must complete within 10 seconds
    }
}

// Run async test with timeout
try await runAsyncTest(timeout: 10.0) {
    // Test code here
}

// Assert operation completes within timeout
await assertCompletesWithin(5.0) {
    try await someAsyncOperation()
}
```

**Timeout Categories:**

### Performance Budgets

Enforce performance targets across operations:

```swift
// Define performance budget
let budget = Budget(
    operation: "syntax_highlighting",
    targetTime: 0.016,  // 60fps
    warningTime: 0.033, // 30fps
    criticalTime: 0.1   // 100ms
)

// Measure against budget
measureAgainstBudget("syntax_highlighting") {
    // Code to measure
}
```

**Predefined Budgets:**

| Operation | Target | Warning | Critical |
|-----------|--------|---------|----------|
| Syntax highlighting | 16ms | 33ms | 100ms |
| File open (small) | 100ms | 200ms | 500ms |
| File open (large) | 2s | 5s | 10s |
| Completion request | 50ms | 100ms | 200ms |
| Search | 100ms | 200ms | 500ms |

### Memory Optimizations

#### TestMemoryOptimizer

Efficient test data generation and management:

```swift
// Generate memory-efficient test data
let testData = TestMemoryOptimizer.generateTestData(
    size: .large,
    pattern: .realistic
)

// Shared test data caching
let cachedData = TestMemoryOptimizer.shared.getCachedData(key: "largeFile")
```

#### Memory Leak Detection

```swift
func testMemoryLeak() {
    let object = MyClass()
    trackForMemoryLeaks(object)
    // Object should be deallocated after test
}
```

## Configuration Performance

### ConfigurationBatchUpdater

Batch configuration updates to minimize change notifications:

```swift
let batcher = ConfigurationBatchUpdater(updateDelay: 0.1) { config in
    // Apply batched updates
    self.applyConfiguration(config)
}

// Queue multiple updates
batcher.queueUpdate { config in
    config.display.fontSize = 16
    return config
}

batcher.queueUpdate { config in
    config.display.isLineNumbersEnabled = true
    return config
}

// Updates are automatically batched and applied after delay
```

### Lazy Evaluation

The `@LazyComputed` property wrapper defers expensive computations:

```swift
class ExpensiveComponent {
    @LazyComputed
    var expensiveValue = computeExpensiveValue()
    
    func computeExpensiveValue() -> ComplexResult {
        // This is only called when first accessed
        return performComplexCalculation()
    }
}
```

### Configuration Validation Caching

```swift
// Validation results are cached
let isValid = config.validateWithCache() // First call validates
let isStillValid = config.validateWithCache() // Uses cache
```

## Performance Monitoring

### SyntaxHighlightingPerformanceTracker

Track highlighting performance with detailed metrics:

```swift
let tracker = SyntaxHighlightingPerformanceTracker()

// Automatic tracking
await tracker.trackHighlighting(
    operation: "swift_file",
    duration: 0.05,
    tokenCount: 1500,
    cacheHit: false
)

// Generate performance report
let report = await tracker.generateReport()
print(report.summary)
// Output:
// Average highlighting time: 45ms
// Cache hit rate: 85%
// Tokens per second: 30,000
```

### PerformanceBudgetReporter

Generate comprehensive performance reports:

```swift
let reporter = PerformanceBudgetReporter()

// Record operations
await reporter.record(operation: "file_open", duration: 0.15)
await reporter.record(operation: "syntax_highlighting", duration: 0.018)

// Generate report
let report = await reporter.generateReport()
print(report.summary)
// Output:
// Performance Budget Report
// Total Operations: 2
// Violations: 1
// ⚠️ Warning file_open: 0.15s (50% over budget)
// ✅ Within Budget syntax_highlighting: 0.018s
```

## Best Practices

### For Syntax Highlighting

1. **Use incremental highlighting** for text changes
2. **Submit background requests** with appropriate priorities
3. **Cancel unnecessary requests** when viewport changes
4. **Monitor highlighting performance** with budgets

### For Tests

1. **Use parallel execution plans** for faster CI/CD
2. **Set appropriate timeouts** to catch hanging tests
3. **Track memory usage** in performance-critical tests
4. **Use TestMemoryOptimizer** for large test data

### For Configuration

1. **Batch multiple configuration changes**
2. **Use lazy evaluation** for expensive properties
3. **Cache validation results**
4. **Monitor configuration change frequency**

## Performance Targets

The optimized helpers below have been measured against the pre-optimization baselines:

| Operation | Before | After | Speedup |
|---|---|---|---|
| Debouncing (500 ops) | 1.17 s | ~0.05 s | 23× |
| Fuzzy matching (10k items) | 0.20 s | ~0.02 s | 10× |
| Symbol navigation | 0.52 s | ~0.05 s | 10× |
| Memory benchmark | 11 s | < 1 s | 11× |

## Optimized Components

Three drop-in helpers ship for the hottest paths. All preserve the original APIs and are safe to enable behind a feature flag.

### `AsyncOperationManager` — debouncing & throttling

`Sources/CodeEditorPlugin/Utilities/AsyncOperationManager+OptimizedDebouncing.swift`

Three new entry points:

- `debounceOptimized(key:delay:_:)` — same shape as `debounce`, but lower overhead when you actually need the result.
- `debounceFireAndForget(key:delay:_:)` — much faster when you don't need to await the result.
- `batchDebounce(operations:delay:)` — coalesce multiple keys into a single coalesced flush.

```swift
// Before
try await manager.debounce(key: "search", delay: 0.3) { await performSearch() }

// After (need result)
try await manager.debounceOptimized(key: "search", delay: 0.3) { await performSearch() }

// After (don't need result — much faster)
await manager.debounceFireAndForget(key: "search", delay: 0.3) { await performSearch() }

// Batch
let operations = ["op1": { await op1() }, "op2": { await op2() }]
let results = try await manager.batchDebounce(operations: operations, delay: 0.1)
```

### `OptimizedFuzzyMatcher` — completion ranking

`Sources/CodeEditorPlugin/Completion/OptimizedFuzzyMatcher.swift`

Parallel processing for large candidate sets, pre-computed word boundaries, character-frequency rejection, and two-phase scoring (cheap then detailed).

```swift
let matcher = OptimizedFuzzyMatcher(
    configuration: .init(
        enableParallelProcessing: true,
        parallelThreshold: 50,   // candidates needed before going parallel
        maxResults: 100
    )
)
let results = matcher.match(pattern: query, candidates: completionItems)
```

### `OptimizedSymbolNavigator` — symbol navigation

`Sources/CodeEditorPlugin/Features/OptimizedSymbolNavigator.swift`

Interval-tree backed symbol lookup with aggressive caching of flattened symbols. Drop-in replacement for `SymbolNavigator`.

```swift
let navigator = OptimizedSymbolNavigator()
navigator.attach(to: textView)
navigator.updateSymbols()
navigator.navigate(to: symbol)
```

Lookups go from O(n) to O(log n). Breadcrumb updates ~10× faster for large files.

### Rollout

Gate each helper behind a flag during migration:

```swift
enum FeatureFlags {
    static let useOptimizedDebouncing = true
    static let useOptimizedFuzzyMatcher = true
    static let useOptimizedSymbolNavigator = true
}
```

Toggle off and revert if regressions appear. All three preserve API shape and Sendable/thread-safety guarantees.

## Advanced Optimization Techniques

### Smart Prefetching

```swift
// Prefetch highlighting for predicted scroll
let prefetcher = HighlightingPrefetcher()
prefetcher.predictedDirection = .down
prefetcher.prefetchDistance = 1000 // characters

await prefetcher.prefetchHighlighting(
    around: currentViewport,
    in: document
)
```

### Adaptive Performance Mode

```swift
// Automatically adjust performance based on device
let adaptiveMode = AdaptivePerformanceMode()
adaptiveMode.currentDevice = .lowEnd

// Automatically reduces:
// - Chunk sizes
// - Cache sizes
// - Concurrent operations
// - Prefetch distance
```

### Memory Pressure Handling

```swift
// Automatic cleanup on memory pressure
memoryMonitor.onMemoryPressure = { level in
    switch level {
    case .low:
        // Reduce cache sizes
        tokenCache.reduceCacheSize(by: 0.2)
    case .medium:
        // Clear non-essential caches
        tokenCache.clearNonEssential()
    case .high:
        // Emergency cleanup
        tokenCache.clearAll()
        cancelBackgroundOperations()
    }
}
```

## Debugging Performance Issues

### Enable Performance Logging

```swift
// Enable detailed performance logging
PerformanceLogger.shared.level = .verbose
PerformanceLogger.shared.categories = [.highlighting, .rendering]
```

### Profile with Instruments

```swift
// Add signposts for profiling
let signpost = OSSignposter()
let state = signpost.beginInterval("highlighting")
// ... perform highlighting ...
signpost.endInterval("highlighting", state)
```

### Performance Diagnostics

```swift
// Generate performance diagnostic report
let diagnostics = await PerformanceDiagnostics.generate()
print(diagnostics.bottlenecks)
print(diagnostics.recommendations)
```

## See Also

- [Performance-Monitoring](monitoring.md)
- [Test-Performance-Configuration](test-config.md)
- `PerformanceBudget`
- `SyntaxHighlightingPerformanceTracker`
- `ConfigurationBatchUpdater`