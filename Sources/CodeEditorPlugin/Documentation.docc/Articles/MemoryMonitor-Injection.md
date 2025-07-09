# MemoryMonitor Dependency Injection

Learn how to properly inject and use MemoryMonitor for memory management in CodeEditorPlugin.

## Overview

The `MemoryMonitor` class provides memory tracking and automatic cleanup capabilities for the code editor. Instead of using the deprecated singleton pattern, CodeEditorPlugin now supports proper dependency injection of MemoryMonitor instances, allowing for better testability and resource management.

## Basic Usage

### Creating a MemoryMonitor

```swift
import CodeEditorPlugin

// Create a new memory monitor instance
let memoryMonitor = MemoryMonitor()

// Configure thresholds and behavior
memoryMonitor.memoryThresholdMB = 150.0  // Trigger cleanup at 150MB
memoryMonitor.enableAutomaticCleanup = true
memoryMonitor.monitoringInterval = 5.0  // Check every 5 seconds
```

### Injecting via Configuration

The recommended way to inject a MemoryMonitor is through `EditorConfiguration`:

```swift
// Create a custom memory monitor
let customMonitor = MemoryMonitor()
customMonitor.memoryThresholdMB = 200.0

// Create configuration with the monitor
var config = EditorConfiguration()
config.performance.memoryMonitor = customMonitor

// Apply to editor view
let editor = CodeEditorView()
config.apply(to: editor)
```

### Using EditorConfigurationBuilder

For a fluent API, use the configuration builder:

```swift
let monitor = MemoryMonitor()

let config = EditorConfigurationBuilder()
    .memoryMonitor(monitor)
    .showLineNumbers(true)
    .fontSize(14)
    .build()

let editor = CodeEditorView()
config.apply(to: editor)
```

## Advanced Patterns

### Shared MemoryMonitor

Share a single MemoryMonitor across multiple editor instances:

```swift
// Create a shared monitor for the application
let sharedMonitor = MemoryMonitor()
sharedMonitor.memoryThresholdMB = 300.0

// Use in multiple editors
let editor1 = CodeEditorView()
let editor2 = CodeEditorView()

var config = EditorConfiguration()
config.performance.memoryMonitor = sharedMonitor

config.apply(to: editor1)
config.apply(to: editor2)

// Both editors now share the same memory monitor
```

### Custom Cleanup Handlers

Register custom cleanup handlers for specific resources:

```swift
let monitor = MemoryMonitor()

// Register a cleanup handler for syntax highlighting cache
monitor.registerCleanupHandler(
    identifier: "syntax-cache",
    priority: .high
) { @MainActor in
    // Clear syntax highlighting cache
    let freedMemory = 10.5  // MB freed
    return CleanupResult(
        memoryFreedMB: freedMemory,
        description: "Cleared syntax highlighting cache"
    )
}

// Register a cleanup handler for undo history
monitor.registerCleanupHandler(
    identifier: "undo-history",
    priority: .normal
) { @MainActor in
    // Trim undo history
    let freedMemory = 5.2  // MB freed
    return CleanupResult(
        memoryFreedMB: freedMemory,
        description: "Trimmed undo history"
    )
}
```

### SwiftUI Integration

When using CodeEditor in SwiftUI, inject MemoryMonitor through the environment:

```swift
import SwiftUI
import CodeEditorPlugin

struct ContentView: View {
    @State private var code = "// Your code here"
    let memoryMonitor = MemoryMonitor()
    
    var body: some View {
        CodeEditor(text: $code)
            .environment(\.codeEditorConfiguration, 
                EditorConfigurationBuilder()
                    .memoryMonitor(memoryMonitor)
                    .build()
            )
    }
}
```

### Testing with Mock MemoryMonitor

Create a mock MemoryMonitor for testing:

```swift
class MockMemoryMonitor: MemoryMonitor {
    var cleanupCallCount = 0
    var registeredHandlers: [String] = []
    
    override func performCleanup(targetReduction: Double? = nil) async -> Double {
        cleanupCallCount += 1
        return 50.0  // Always return 50MB freed
    }
    
    override func registerCleanupHandler(
        identifier: String,
        priority: CleanupPriority = .normal,
        handler: @escaping @MainActor @Sendable () async -> CleanupResult
    ) {
        registeredHandlers.append(identifier)
        super.registerCleanupHandler(
            identifier: identifier,
            priority: priority,
            handler: handler
        )
    }
}

// Use in tests
func testMemoryCleanup() async {
    let mockMonitor = MockMemoryMonitor()
    
    var config = EditorConfiguration()
    config.performance.memoryMonitor = mockMonitor
    
    let editor = CodeEditorView()
    config.apply(to: editor)
    
    // Trigger cleanup
    await mockMonitor.performCleanup()
    
    XCTAssertEqual(mockMonitor.cleanupCallCount, 1)
}
```

## Component-Level Injection

Many internal components accept MemoryMonitor as a parameter:

### AsyncTextProcessor

```swift
let processor = AsyncTextProcessor(
    memoryMonitor: customMonitor,
    maxConcurrentOperations: 4
)
```

### SmartCompletionEngine

```swift
let completionEngine = SmartCompletionEngine(
    memoryMonitor: customMonitor
)
```

### LSPManager

```swift
let lspManager = LSPManager(
    memoryMonitor: customMonitor
)
```

### AsyncSyntaxHighlighter

```swift
let highlighter = AsyncSyntaxHighlighter(
    memoryMonitor: customMonitor
)
```

## Memory Management Best Practices

### 1. Configure Appropriate Thresholds

Set memory thresholds based on your application's needs:

```swift
let monitor = MemoryMonitor()

// For desktop applications with ample memory
monitor.memoryThresholdMB = 500.0
monitor.enablePeriodicCleanup = true
monitor.periodicCleanupInterval = 600.0  // 10 minutes

// For mobile or resource-constrained environments
monitor.memoryThresholdMB = 100.0
monitor.enableAutomaticCleanup = true
monitor.monitoringInterval = 10.0  // Check frequently
```

### 2. Monitor Memory Statistics

Track memory usage over time:

```swift
let monitor = MemoryMonitor()

// Get current statistics
let stats = monitor.getMemoryStatistics()
print("Current usage: \(stats.currentUsageMB)MB")
print("Peak usage: \(stats.peakUsageMB)MB")
print("Average usage: \(stats.averageUsageMB)MB")

// Monitor cleanup effectiveness
print("Total cleanups: \(stats.totalCleanupOperations)")
print("Total memory freed: \(stats.totalMemoryFreed)MB")
print("Cleanup effectiveness: \(stats.cleanupEffectiveness)MB per operation")
```

### 3. Respond to Memory Pressure

React to memory pressure notifications:

```swift
class EditorViewController {
    let memoryMonitor = MemoryMonitor()
    
    func setupMemoryHandling() {
        // Register high-priority cleanup for critical memory situations
        memoryMonitor.registerCleanupHandler(
            identifier: "emergency-cleanup",
            priority: .critical
        ) { @MainActor in
            // Clear all non-essential caches
            self.clearAllCaches()
            return CleanupResult(
                memoryFreedMB: 100.0,
                description: "Emergency cleanup completed"
            )
        }
        
        // Force cleanup when needed
        Task {
            if memoryMonitor.getCurrentMemoryUsage() > 400.0 {
                await memoryMonitor.performCleanup(targetReduction: 100.0)
            }
        }
    }
}
```

## Migration from Singleton

If you're migrating from the deprecated singleton pattern:

```swift
// Old way (deprecated)
let editor = CodeEditorView()
editor.memoryMonitor = MemoryMonitor.shared  // ⚠️ Deprecated

// New way (recommended)
let monitor = MemoryMonitor()
var config = EditorConfiguration()
config.performance.memoryMonitor = monitor
config.apply(to: editor)
```

## Troubleshooting

### Memory Monitor Not Working

If cleanup handlers aren't being called:

1. Verify the monitor is properly injected
2. Check that monitoring is started (automatic unless in tests)
3. Ensure thresholds are appropriately set

```swift
// Debug memory monitor
let monitor = editor.memoryMonitor
print("Monitoring active: \(monitor.memoryStats.lastUpdateTime)")
print("Threshold: \(monitor.memoryThresholdMB)MB")
print("Current usage: \(monitor.getCurrentMemoryUsage())MB")
```

### Testing Considerations

MemoryMonitor automatically disables monitoring in test environments to avoid interference:

```swift
// In tests, monitoring is disabled by default
// You can manually trigger cleanup for testing
func testCleanup() async {
    let monitor = MemoryMonitor()
    let result = await monitor.performCleanup()
    XCTAssertGreaterThanOrEqual(result, 0)
}
```

## See Also

- <doc:Configuration-System>
- <doc:Performance-Monitoring>
- ``MemoryMonitor``
- ``EditorConfiguration/Performance``