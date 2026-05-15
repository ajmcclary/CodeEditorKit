# `CodeEditorPlugin/ActorCoordinator`

Central coordinator for managing specialized actors across the editor, providing unified access to concurrent services with proper lifecycle management.

## Overview

`ActorCoordinator` serves as the central hub for all actor-based services in CodeEditorPlugin. It manages specialized actors for text processing, caching, file operations, performance metrics, document state, and error recovery. By centralizing actor management, it ensures proper dependency injection, lifecycle management, and provides convenient methods for common operations with automatic error recovery.

## Architecture

The coordinator manages these specialized actors:

- **TextProcessingActor**: Handles text manipulation operations
- **CacheCoordinatorActor**: Manages all caching systems
- **FileSystemActor**: Performs file I/O operations
- **PerformanceMetricsActor**: Tracks and aggregates performance data
- **DocumentStateActor**: Manages document lifecycle and state
- **ErrorRecoveryCoordinator**: Handles error recovery strategies

## Basic Usage

### Creating a Coordinator

```swift
// Recommended: Create new instances via dependency injection
let coordinator = ActorCoordinator.create()

// Inject through EditorSetup / EditorRuntimeDependencies
var config = EditorConfiguration()
let setup = EditorSetup(
    runtimeDependencies: EditorRuntimeDependencies(actorCoordinator: coordinator)
)
```

`ActorCoordinator` has no singleton. Always pass an instance through `EditorRuntimeDependencies`.

### Accessing from CodeEditorView

```swift
// The editor view exposes the coordinator it was set up with.
let coordinator = codeEditorView.actorCoordinator

// Process the current buffer using the integrated actor system.
try await codeEditorView.processText(
    with: .whitespaceNormalization,
    priority: .high
)
```

## Text Processing

### Basic Text Processing

```swift
// Process text with automatic error recovery
let processed = try await coordinator.processText(
    "    func example() {  }",
    processorType: .whitespaceNormalization,
    priority: .high
)

// Available processor types (TextProcessingActor.TextProcessor.ProcessorType):
// - .indentation                  Indent / re-indent
// - .bracketMatching              Bracket-pair processing
// - .lineWrapping                 Soft-wrap normalization
// - .whitespaceNormalization      Collapse / clean whitespace
// - .encoding(String.Encoding)    Re-encode to a target encoding
```

### Error Recovery

```swift
// The coordinator automatically retries recoverable errors via ErrorRecoveryCoordinator.
do {
    let result = try await coordinator.processText(
        text,
        processorType: .whitespaceNormalization
    )
} catch {
    // Only non-recoverable errors reach here.
    // Recoverable errors are retried inside processText().
}
```

## Performance Tracking

### Recording Metrics

```swift
// Track performance metrics
let startTime = ContinuousClock.now
// ... perform operation ...
let duration = ContinuousClock.now - startTime

await coordinator.trackPerformance(
    name: "syntax-highlighting",
    duration: duration,
    metadata: [
        "language": "swift",
        "lineCount": "1000"
    ]
)
```

### Accessing Metrics

```swift
// Get aggregated stats from the performance actor.
if let stats = await coordinator.performanceMetrics.getStats(for: "syntax-highlighting") {
    CrossPlatformLogger.logger().info("Average duration: \(stats.averageDuration)")
    CrossPlatformLogger.logger().info("Total samples: \(stats.count)")
}

// Or read every recorded category at once.
let all = await coordinator.performanceMetrics.getAllStats()
```

## Document Management

### Creating/Updating Documents

```swift
// Create or update a document
let documentId = await coordinator.createOrUpdateDocument(
    content: "// Swift code",
    url: fileURL,
    language: .swift
)

// The method intelligently:
// - Updates existing documents at the URL
// - Creates new documents if none exist
// - Tracks document state and history
```

### Document State Tracking

```swift
// Access document state
let document = await coordinator.documentState.getDocument(at: fileURL)

// Update content
await coordinator.documentState.updateContent(
    for: documentId,
    content: newContent
)

// Mark as saved or close when the host app is done with the document.
await coordinator.documentState.markSaved(documentId)
await coordinator.documentState.closeDocument(documentId)
```

## Cache Integration

### Using the Cache System

```swift
// The cache coordinator routes through any number of registered caches.
let cache = coordinator.cacheCoordinator

// Register a cache (e.g. SmartTokenCache implements CacheProtocol).
await cache.registerCache(tokenCache, identifier: "syntax-tokens")

// Clear a specific cache by identifier.
await cache.clearCache("syntax-tokens")
```

Individual caches (such as `SmartTokenCache`) handle the actual `getValue` / `setValue` plumbing through `CacheProtocol`.

### Smart Token Cache Integration

```swift
// SmartTokenCache integrates with CacheCoordinatorActor
extension SmartTokenCache: CacheProtocol {
    // Automatic integration with the cache coordinator
    // Provides unified cache management
}
```

## File System Operations

### Safe File Operations

```swift
// Perform file operations through the actor
let content = try await coordinator.fileSystem.readFile(at: url)

// Write to disk
try await coordinator.fileSystem.writeFile(content, to: url)

// Open / close handles
try coordinator.fileSystem.openFile(at: url)
coordinator.fileSystem.closeFile(at: url)

// Observe changes to a file
try await coordinator.fileSystem.watchFile(at: url) { event in
    // ...
}
```

## Error Recovery

### Automatic Recovery

```swift
// Define recoverable errors
struct NetworkError: RecoverableAsyncError {
    let isRecoverable = true
    let retryDelay: Duration = .seconds(1)
    let maxRetries = 3
}

// Errors are automatically retried
let result = try await coordinator.errorRecovery.recover(from: error) {
    // Retry operation
    try await performNetworkOperation()
}
```

## Platform Requirements

ActorCoordinator requires:
- macOS 26.3+ / iOS 26.3+
- Swift Concurrency support
- Uses modern Swift 6 concurrency features

## Best Practices

### Dependency Injection

```swift
// ✅ Good: Pass coordinator explicitly through EditorRuntimeDependencies.
class MyEditorViewController {
    let coordinator: ActorCoordinator

    init(coordinator: ActorCoordinator) {
        self.coordinator = coordinator
    }
}

// ❌ Bad: There is no singleton. Don't invent one.
//   `ActorCoordinator.shared` does not exist.
```

### Lifecycle Management

```swift
// Coordinators are lightweight, create as needed
func createEditor() -> CodeEditorView {
    var config = EditorConfiguration()
    let setup = EditorSetup(runtimeDependencies: EditorRuntimeDependencies(actorCoordinator: ActorCoordinator.create()))
    return CodeEditorView(configuration: config)
}
```

### Error Handling

```swift
// Let the coordinator handle recoverable errors.
do {
    let result = try await coordinator.processText(
        text,
        processorType: .whitespaceNormalization
    )
} catch {
    // Only handle non-recoverable errors.
    CrossPlatformLogger.logger().error("Unrecoverable error: \(error)")
}
```

## Performance Considerations

1. **Actor Isolation**: Each actor runs independently, preventing bottlenecks
2. **Automatic Caching**: Results are cached where appropriate
3. **Priority Support**: High-priority tasks are processed first
4. **Error Recovery**: Automatic retries don't block other operations

## Integration Examples

### SwiftUI Integration

```swift
class EditorViewModel: ObservableObject {
    let coordinator: ActorCoordinator
    @Published var processedText = ""
    
    init(coordinator: ActorCoordinator) {
        self.coordinator = coordinator
    }
    
    func normalizeWhitespace(_ code: String) async {
        do {
            processedText = try await coordinator.processText(
                code,
                processorType: .whitespaceNormalization
            )
        } catch {
            // Handle error
        }
    }
}
```

### Performance Monitoring

```swift
// Track all operations
func performOperation() async {
    let start = ContinuousClock.now
    defer {
        let duration = ContinuousClock.now - start
        Task {
            await coordinator.trackPerformance(
                name: "operation",
                duration: duration
            )
        }
    }
    
    // Perform operation
}
```

## See Also

- `TextProcessingActor`
- `CacheCoordinatorActor`
- `FileSystemActor`
- `PerformanceMetricsActor`
- `DocumentStateActor`
- `ErrorRecoveryCoordinator`
- `EditorConfiguration`
