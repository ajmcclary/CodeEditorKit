# Duration API Migration

Learn how CodeEditorPlugin uses Swift's modern Duration type for time-based operations.

## Overview

CodeEditorPlugin has migrated from `TimeInterval` to Swift's modern `Duration` type for all time-based operations. This provides better type safety, more expressive APIs, and seamless integration with Swift concurrency.

## What Changed

### Before (TimeInterval)
```swift
// Old API using TimeInterval (Double)
let highlighter = AsyncSyntaxHighlighter(
    debounceInterval: 0.3  // 300 milliseconds as Double
)

// Ambiguous unit
config.performance.cacheTimeout = 3600  // Is this seconds? milliseconds?
```

### After (Duration)
```swift
// New API using Duration
let highlighter = AsyncSyntaxHighlighter(
    memoryMonitor: memoryMonitor,
    debounceInterval: .milliseconds(300)  // Clear and type-safe
)

// Unambiguous units
config.performance.cacheTimeout = .hours(1)
```

## Basic Usage

### Creating Durations

```swift
import CodeEditorPlugin

// Various ways to create durations
let instant = Duration.zero
let fast = Duration.milliseconds(100)
let normal = Duration.seconds(1)
let slow = Duration.seconds(2.5)
let long = Duration.minutes(5)
let veryLong = Duration.hours(1)

// Nanosecond precision
let precise = Duration.nanoseconds(123_456_789)
let micro = Duration.microseconds(500)
```

### Using Duration in Configuration

```swift
// Configure async syntax highlighter
let highlighter = AsyncSyntaxHighlighter(
    memoryMonitor: memoryMonitor,
    debounceInterval: .milliseconds(300)
)

// Configure memory monitor intervals
memoryMonitor.monitoringInterval = .seconds(5)
memoryMonitor.periodicCleanupInterval = .minutes(10)

// Configure cache settings
await syntaxHighlighter.configureCacheSettings(
    maxCacheSize: 100,
    maxMemoryUsageMB: 50.0,
    staleThreshold: .hours(1)
)
```

## Conversion Utilities

CodeEditorPlugin provides a convenient extension for Duration conversion:

```swift
// Convert Duration to TimeInterval when needed
let duration = Duration.seconds(2.5)
let timeInterval = duration.timeInterval  // 2.5

// Use in APIs that still require TimeInterval
Timer.scheduledTimer(
    withTimeInterval: duration.timeInterval,
    repeats: false
) { _ in
    // Timer fired
}
```

## Common Patterns

### Debouncing Operations

```swift
class DebouncedSearch {
    private var searchTask: Task<Void, Never>?
    private let debounceInterval = Duration.milliseconds(500)
    
    func search(query: String) {
        searchTask?.cancel()
        
        searchTask = Task {
            do {
                try await Task.sleep(for: debounceInterval)
                await performSearch(query)
            } catch {
                // Task cancelled
            }
        }
    }
}
```

### Performance Measurement

```swift
// Measure operation duration
let startTime = ContinuousClock.now
await expensiveOperation()
let elapsed = ContinuousClock.now - startTime

print("Operation took: \(elapsed)")

// Compare with threshold
if elapsed > .seconds(1) {
    print("Warning: Operation took longer than expected")
}
```

### Cache Expiration

```swift
actor TokenCache {
    struct CacheEntry {
        let tokens: [Token]
        let timestamp: ContinuousClock.Instant
        let computationTime: Duration
    }
    
    private let staleThreshold = Duration.hours(1)
    private var cache: [String: CacheEntry] = [:]
    
    func getCachedTokens(for key: String) -> [Token]? {
        guard let entry = cache[key] else { return nil }
        
        let age = ContinuousClock.now - entry.timestamp
        if age > staleThreshold {
            cache.removeValue(forKey: key)
            return nil
        }
        
        return entry.tokens
    }
}
```

## Task Sleep Patterns

### Simple Delays

```swift
// Old way with DispatchQueue
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    // Delayed code
}

// New way with Task.sleep
Task {
    try await Task.sleep(for: .milliseconds(500))
    // Delayed code
}
```

### Periodic Operations

```swift
class PeriodicMonitor {
    private let interval = Duration.seconds(5)
    private var monitoringTask: Task<Void, Never>?
    
    func startMonitoring() {
        monitoringTask = Task {
            while !Task.isCancelled {
                await performCheck()
                
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    break  // Task cancelled
                }
            }
        }
    }
    
    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
}
```

## Integration with CodeEditorPlugin

### Syntax Highlighting

```swift
// Configure debounce timing
let syntaxHighlighter = AsyncSyntaxHighlighter(
    memoryMonitor: memoryMonitor,
    debounceInterval: .milliseconds(300)
)

// Schedule highlighting with custom delay
syntaxHighlighter.scheduleHighlighting(
    for: textView,
    language: .swift,
    visibleRange: visibleRange
)
```

### Memory Monitoring

```swift
// Configure memory monitor with Duration
let monitor = MemoryMonitor()
monitor.monitoringInterval = .seconds(10)
monitor.periodicCleanupInterval = .minutes(5)

// Set cache expiration
await highlighter.configureCacheSettings(
    maxCacheSize: 50,
    maxMemoryUsageMB: 100.0,
    staleThreshold: .minutes(30)
)
```

### Performance Tracking

```swift
// Track highlighting performance
let stats = await highlighter.performanceMonitor.getAverageTime(for: .syntaxHighlighting)
if let avgTime = stats {
    print("Average highlighting time: \(avgTime)")
    
    if avgTime > .milliseconds(100) {
        print("Performance warning: Highlighting is slow")
    }
}
```

## Duration Arithmetic

```swift
// Basic arithmetic
let total = Duration.seconds(5) + Duration.milliseconds(500)  // 5.5 seconds
let difference = Duration.minutes(2) - Duration.seconds(30)   // 1.5 minutes

// Scaling
let doubled = Duration.seconds(2) * 2                         // 4 seconds
let halved = Duration.seconds(10) / 2                         // 5 seconds

// Comparisons
let fast = Duration.milliseconds(100)
let slow = Duration.seconds(1)

if fast < slow {
    print("Fast is indeed faster")
}

// Use in timeout logic
let timeout = Duration.seconds(30)
let elapsed = Duration.seconds(25)

if elapsed > timeout * 0.8 {
    print("Warning: Approaching timeout")
}
```

## Error Handling with Timeouts

```swift
extension Task where Failure == Error {
    // Run with timeout
    static func withTimeout<T>(
        _ duration: Duration,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(for: duration)
                throw TimeoutError()
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// Usage
do {
    let result = try await Task.withTimeout(.seconds(5)) {
        try await slowOperation()
    }
} catch is TimeoutError {
    print("Operation timed out")
}
```

## Testing with Duration

```swift
final class DurationTests: XCTestCase {
    func testDebouncedOperation() async throws {
        let debouncer = DebouncedOperation(delay: .milliseconds(100))
        var callCount = 0
        
        // Rapid calls
        for _ in 0..<5 {
            debouncer.execute {
                callCount += 1
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        
        // Wait for debounce
        try await Task.sleep(for: .milliseconds(200))
        
        // Should only execute once
        XCTAssertEqual(callCount, 1)
    }
    
    func testCacheExpiration() async throws {
        let cache = ExpiringCache(ttl: .milliseconds(100))
        
        cache.set("key", value: "value")
        
        // Should be present immediately
        XCTAssertEqual(cache.get("key"), "value")
        
        // Wait for expiration
        try await Task.sleep(for: .milliseconds(150))
        
        // Should be expired
        XCTAssertNil(cache.get("key"))
    }
}
```

## Migration Tips

### Converting Existing Code

```swift
// Old code with TimeInterval
class OldDebouncer {
    let delay: TimeInterval = 0.3
    
    func schedule() {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Action
        }
    }
}

// New code with Duration
class NewDebouncer {
    let delay = Duration.milliseconds(300)
    
    func schedule() {
        Task {
            try await Task.sleep(for: delay)
            // Action
        }
    }
}
```

### Bridging with Legacy APIs

```swift
// When you need TimeInterval for legacy APIs
extension LegacyTimer {
    func schedule(after duration: Duration, action: @escaping () -> Void) {
        schedule(after: duration.timeInterval, action: action)
    }
}

// When receiving TimeInterval from legacy APIs
extension ModernScheduler {
    func schedule(after timeInterval: TimeInterval) async throws {
        let duration = Duration.seconds(timeInterval)
        try await Task.sleep(for: duration)
    }
}
```

## Best Practices

1. **Use specific units** - `.milliseconds(500)` is clearer than `.seconds(0.5)`
2. **Avoid magic numbers** - Define constants for repeated durations
3. **Handle cancellation** - Always catch errors from `Task.sleep`
4. **Use ContinuousClock** - For measuring elapsed time
5. **Test with time** - Use shorter durations in tests for speed

## See Also

- [Performance-Monitoring](../Performance/monitoring.md)
- [Swift6-Concurrency](../Concurrency/swift6.md)
- `AsyncSyntaxHighlighter`
- [Swift Evolution: Duration](https://github.com/apple/swift-evolution/blob/main/proposals/0329-clock-instant-duration.md)