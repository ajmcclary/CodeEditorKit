# MemoryMonitor Dependency Injection

Learn how to properly inject and use MemoryMonitor for memory management in CodeEditorKit.

## Overview

The `MemoryMonitor` class provides memory tracking and automatic cleanup capabilities for the code editor. Instead of using the deprecated singleton pattern, CodeEditorKit now supports proper dependency injection of MemoryMonitor instances, allowing for better testability and resource management.

## Basic Usage

### Creating a MemoryMonitor

```swift
import CodeEditorKit

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
let setup = EditorSetup(runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: customMonitor))

// Apply to editor view
let editor = CodeEditorView()
config.apply(to: editor)
```

### Using Direct Configuration

Assign runtime dependencies directly on the configuration:

```swift
let monitor = MemoryMonitor()
monitor.startMonitoring()

var config = EditorConfiguration()
let setup = EditorSetup(runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: monitor))
config.display.isLineNumbersEnabled = true
config.display.fontSize = 14

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
let setup = EditorSetup(runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: sharedMonitor))

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

When using CodeEditor in SwiftUI, you have two options for injecting MemoryMonitor:

#### Option 1: Using the Dedicated Environment Key (Recommended)

```swift
import SwiftUI
import CodeEditorKit

struct ContentView: View {
    @State private var code = "// Your code here"
    let memoryMonitor = MemoryMonitor()
    
    var body: some View {
        CodeEditor(text: $code)
            .memoryMonitor(memoryMonitor)  // Direct modifier
    }
}
```

#### Option 2: Through Configuration

```swift
import SwiftUI
import CodeEditorKit

struct ContentView: View {
    @State private var code = "// Your code here"
    let memoryMonitor = MemoryMonitor()
    private var configuration: EditorConfiguration {
        var config = EditorConfiguration()
        let setup = EditorSetup(runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: memoryMonitor))
        return config
    }
    
    var body: some View {
        CodeEditor(text: $code)
            .environment(\.codeEditorConfiguration, configuration)
    }
}
```

#### Using Environment Values

Access the memory monitor from child views:

```swift
struct ChildView: View {
    @Environment(\.codeEditorMemoryMonitor) var memoryMonitor
    
    var body: some View {
        Button("Force Cleanup") {
            Task {
                if let monitor = memoryMonitor {
                    await monitor.performCleanup()
                }
            }
        }
    }
}
```

### Testing with Mock MemoryMonitor

`MemoryMonitor` is `final`; use the built-in mock factory and cleanup handlers in tests instead of subclassing:

```swift
func testMemoryCleanup() async {
    let monitor = MemoryMonitor.mock(memoryUsage: 250, memoryPressure: .warning)
    let counter = CleanupCounter()
    
    monitor.registerCleanupHandler(identifier: "test-cache") { @MainActor in
        counter.count += 1
        return CleanupResult(memoryFreedMB: 50, description: "Cleared test cache")
    }
    
    var config = EditorConfiguration()
    let setup = EditorSetup(runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: monitor))
    
    let editor = CodeEditorView()
    config.apply(to: editor)
    
    let freed = await monitor.performCleanup()
    
    XCTAssertEqual(await counter.count, 1)
    XCTAssertEqual(freed, 50)
}

@MainActor
final class CleanupCounter {
    var count = 0
}
```

## Component-Level Injection

Many internal components accept MemoryMonitor as a parameter:

### CompletionManager

```swift
let completionManager = CompletionManager(
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
CrossPlatformLogger.logger().info("Current usage: \(stats.currentUsageMB)MB")
CrossPlatformLogger.logger().info("Peak usage: \(stats.peakUsageMB)MB")
CrossPlatformLogger.logger().info("Average usage: \(stats.averageUsageMB)MB")

// Monitor cleanup effectiveness
CrossPlatformLogger.logger().info("Total cleanups: \(stats.totalCleanupOperations)")
CrossPlatformLogger.logger().info("Total memory freed: \(stats.totalMemoryFreed)MB")
CrossPlatformLogger.logger().info("Cleanup effectiveness: \(stats.cleanupEffectiveness)MB per operation")
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

## Migration from Singleton-Style Wiring

If older app code or docs used a shared monitor, replace that global access with an instance your app owns:

```swift
// Old shape: globally shared monitor owned outside the editor

// New way (recommended)
let monitor = MemoryMonitor()
monitor.startMonitoring()
var config = EditorConfiguration()
let setup = EditorSetup(runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: monitor))
config.apply(to: editor)
```

## Troubleshooting

### Memory Monitor Not Working

If cleanup handlers aren't being called:

1. Verify the monitor is properly injected
2. Check that monitoring is started when you need periodic threshold checks
3. Ensure thresholds are appropriately set

```swift
// Debug memory monitor
let monitor = editor.memoryMonitor
CrossPlatformLogger.logger().info("Monitoring active: \(monitor.memoryStats.lastUpdateTime)")
CrossPlatformLogger.logger().info("Threshold: \(monitor.memoryThresholdMB)MB")
CrossPlatformLogger.logger().info("Current usage: \(monitor.getCurrentMemoryUsage())MB")
```

### Testing Considerations

Monitoring does not need to run for cleanup-handler tests. Trigger cleanup directly for deterministic assertions:

```swift
func testCleanup() async {
    let monitor = MemoryMonitor.mock(memoryUsage: 100)
    let result = await monitor.performCleanup()
    XCTAssertGreaterThanOrEqual(result, 0)
}
```

## Advanced Injection Patterns

### Factory Pattern for MemoryMonitor

Create a factory for consistent MemoryMonitor configuration:

```swift
enum MemoryMonitorFactory {
    static func createDefault() -> MemoryMonitor {
        let monitor = MemoryMonitor()
        monitor.memoryThresholdMB = 150.0
        monitor.enableAutomaticCleanup = true
        return monitor
    }
    
    static func createForTesting() -> MemoryMonitor {
        let monitor = MemoryMonitor()
        monitor.memoryThresholdMB = 50.0 // Lower threshold for testing
        monitor.enableAutomaticCleanup = false // Manual control in tests
        return monitor
    }
    
    static func createForProduction() -> MemoryMonitor {
        let monitor = MemoryMonitor()
        monitor.memoryThresholdMB = 300.0
        monitor.enableAutomaticCleanup = true
        monitor.enablePeriodicCleanup = true
        monitor.periodicCleanupInterval = 300.0 // 5 minutes
        return monitor
    }
}

// Usage
let editor = CodeEditorView()
var config = EditorConfiguration()
let setup = EditorSetup(runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: MemoryMonitorFactory.createDefault()))
config.apply(to: editor)
```

### Dependency Container Pattern

Use a dependency container for complex applications:

```swift
class DependencyContainer {
    private(set) lazy var memoryMonitor: MemoryMonitor = {
        let monitor = MemoryMonitor()
        configureMemoryMonitor(monitor)
        return monitor
    }()
    
    private(set) lazy var eventSystem = UnifiedEventSystem()
    
    private func configureMemoryMonitor(_ monitor: MemoryMonitor) {
        // Configure based on environment
        #if DEBUG
        monitor.memoryThresholdMB = 100.0
        #else
        monitor.memoryThresholdMB = 300.0
        #endif
        
        // Register app-wide cleanup handlers
        registerGlobalCleanupHandlers(monitor)
    }
    
    private func registerGlobalCleanupHandlers(_ monitor: MemoryMonitor) {
        monitor.registerCleanupHandler(
            identifier: "image-cache",
            priority: .high
        ) { @MainActor in
            // Clear image caches
            return CleanupResult(memoryFreedMB: 20.0, description: "Cleared image cache")
        }
    }
    
    func createEditorConfiguration() -> EditorConfiguration {
        var config = EditorConfiguration()
        let setup = EditorSetup(runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: memoryMonitor))
        let setup = EditorSetup(runtimeDependencies: EditorRuntimeDependencies(eventSystem: eventSystem))
        return config
    }
}

// Usage in app
@main
struct MyApp: App {
    @StateObject private var dependencies = DependencyContainer()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencies)
        }
    }
}
```

### Hierarchical Injection

Create parent-child relationships for memory monitoring:

```swift
class DocumentWindowController {
    let rootMemoryMonitor = MemoryMonitor()
    var documentMonitors: [String: MemoryMonitor] = [:]
    
    func createDocumentEditor(for documentID: String) -> CodeEditorView {
        // Create a child monitor that reports to the parent
        let documentMonitor = MemoryMonitor()
        documentMonitor.memoryThresholdMB = 50.0 // Per-document limit
        
        // Register cleanup that considers document priority
        documentMonitor.registerCleanupHandler(
            identifier: "document-\(documentID)",
            priority: .normal
        ) { @MainActor [weak self] in
            guard let self else { return CleanupResult(memoryFreedMB: 0, description: "Controller deallocated") }
            
            // Clean up based on document importance
            let freed = self.cleanupDocument(documentID)
            return CleanupResult(memoryFreedMB: freed, description: "Cleaned document \(documentID)")
        }
        
        documentMonitors[documentID] = documentMonitor
        
        // Create editor with document-specific monitor
        let editor = CodeEditorView()
        var config = EditorConfiguration()
        let setup = EditorSetup(runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: documentMonitor))
        config.apply(to: editor)
        return editor
    }
    
    private func cleanupDocument(_ documentID: String) -> Double {
        // Implement document-specific cleanup logic
        return 10.0
    }
}
```

### Protocol-Based Injection

Define protocols for flexible memory monitoring:

```swift
protocol MemoryManageable {
    var memoryMonitor: MemoryMonitor { get }
    func configureMemoryManagement()
}

extension MemoryManageable {
    func configureMemoryManagement() {
        memoryMonitor.registerCleanupHandler(
            identifier: "\(type(of: self))",
            priority: .normal
        ) { @MainActor [weak self] in
            guard let self else { 
                return CleanupResult(memoryFreedMB: 0, description: "Object deallocated")
            }
            
            let freed = self.performCleanup()
            return CleanupResult(memoryFreedMB: freed, description: "Cleanup completed")
        }
    }
    
    func performCleanup() -> Double {
        // Default implementation
        return 0.0
    }
}

// Adopt in your classes
class SyntaxHighlightingManager: MemoryManageable {
    let memoryMonitor: MemoryMonitor
    
    init(memoryMonitor: MemoryMonitor) {
        self.memoryMonitor = memoryMonitor
        configureMemoryManagement()
    }
    
    func performCleanup() -> Double {
        // Clear syntax caches
        return 15.0
    }
}
```

### SwiftUI Environment Propagation

Propagate MemoryMonitor through SwiftUI environment:

```swift
// Define environment key
private struct MemoryMonitorEnvironmentKey: EnvironmentKey {
    static let defaultValue: MemoryMonitor? = nil
}

extension EnvironmentValues {
    var appMemoryMonitor: MemoryMonitor? {
        get { self[MemoryMonitorEnvironmentKey.self] }
        set { self[MemoryMonitorEnvironmentKey.self] = newValue }
    }
}

// Root view
struct AppRootView: View {
    @StateObject private var memoryMonitor = MemoryMonitor()
    
    var body: some View {
        NavigationView {
            DocumentListView()
        }
        .environment(\.appMemoryMonitor, memoryMonitor)
    }
}

// Child views can access it
struct DocumentEditView: View {
    @Environment(\.appMemoryMonitor) var appMemoryMonitor
    @State private var code = ""
    
    var body: some View {
        CodeEditor(text: $code)
            .memoryMonitor(appMemoryMonitor ?? MemoryMonitor())
    }
}
```

### Combine Integration

Monitor memory changes reactively:

```swift
import Combine

extension MemoryMonitor {
    var memoryUsagePublisher: AnyPublisher<Double, Never> {
        Timer.publish(every: monitoringInterval, on: .main, in: .common)
            .autoconnect()
            .map { _ in self.getCurrentMemoryUsage() }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

// Use in SwiftUI
struct MemoryStatusView: View {
    @ObservedObject var memoryMonitor: MemoryMonitor
    @State private var currentUsage: Double = 0
    
    var body: some View {
        HStack {
            Image(systemName: "memorychip")
            Text("\(Int(currentUsage))MB")
                .foregroundColor(currentUsage > memoryMonitor.memoryThresholdMB ? .red : .primary)
        }
        .onReceive(memoryMonitor.memoryUsagePublisher) { usage in
            currentUsage = usage
        }
    }
}
```

## Real-World Examples

### Multi-Tab Editor

```swift
class MultiTabEditorController {
    private let sharedMemoryMonitor = MemoryMonitor()
    private var tabMonitors: [UUID: MemoryMonitor] = [:]
    
    init() {
        configureSharedMonitor()
    }
    
    private func configureSharedMonitor() {
        sharedMemoryMonitor.memoryThresholdMB = 500.0
        
        // Global cleanup affects all tabs
        sharedMemoryMonitor.registerCleanupHandler(
            identifier: "all-tabs",
            priority: .high
        ) { @MainActor [weak self] in
            guard let self else { return CleanupResult(memoryFreedMB: 0, description: "Controller deallocated") }
            
            var totalFreed = 0.0
            
            // Clean up inactive tabs first
            for (tabID, monitor) in self.tabMonitors {
                if !self.isTabActive(tabID) {
                    totalFreed += await monitor.performCleanup()
                }
            }
            
            return CleanupResult(
                memoryFreedMB: totalFreed,
                description: "Cleaned \(self.tabMonitors.count) tabs"
            )
        }
    }
    
    func createTab() -> (UUID, CodeEditorView) {
        let tabID = UUID()
        let tabMonitor = MemoryMonitor()
        
        // Configure per-tab limits
        tabMonitor.memoryThresholdMB = 100.0
        tabMonitors[tabID] = tabMonitor
        
        var config = EditorConfiguration()
        let setup = EditorSetup(runtimeDependencies: EditorRuntimeDependencies(memoryMonitor: tabMonitor))
        
        let editor = CodeEditorView()
        config.apply(to: editor)
        
        return (tabID, editor)
    }
    
    private func isTabActive(_ tabID: UUID) -> Bool {
        // Implementation depends on your UI
        return true
    }
}
```

## See Also

- [Configuration-System](../Configuration/system.md)
- [Performance-Monitoring](monitoring.md)
- [Unified-Event-System](../Concurrency/unified-events.md)
- `MemoryMonitor`
- `EditorConfiguration/Performance`
- `CleanupResult`
- `CleanupPriority`
