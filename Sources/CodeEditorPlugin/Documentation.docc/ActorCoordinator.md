# ``CodeEditorPlugin/ActorCoordinator``

@Metadata {
    @PageColor(red)
}

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

// Configure in EditorConfiguration
var config = EditorConfiguration()
config.actorCoordinator = coordinator

// Deprecated: Avoid using the singleton
// let coordinator = ActorCoordinator.shared  // ⚠️ Deprecated
```

### Accessing from CodeEditorView

```swift
// The editor view provides convenient access
let coordinator = codeEditorView.actorCoordinator

// Process text through the coordinator
try await codeEditorView.processText(
    with: .formatter,
    priority: .high
)
```

## Text Processing

### Basic Text Processing

```swift
// Process text with automatic error recovery
let processed = try await coordinator.processText(
    "func example() { print(\"Hello\") }",
    processorType: .formatter,
    priority: .high
)

// Available processor types:
// - .tokenizer: Tokenize for syntax highlighting
// - .formatter: Format code
// - .linter: Lint for issues
// - .minifier: Minify code
// - .prettifier: Pretty print
```

### Error Recovery

```swift
// The coordinator automatically handles recoverable errors
do {
    let result = try await coordinator.processText(
        text,
        processorType: .formatter
    )
} catch {
    // Only non-recoverable errors reach here
    // Recoverable errors are automatically retried
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
// Get aggregated metrics from the performance actor
let metrics = await coordinator.performanceMetrics.getMetrics(
    for: "syntax-highlighting"
)

print("Average duration: \(metrics.averageDuration)")
print("Total operations: \(metrics.count)")
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

// Track document lifecycle
await coordinator.documentState.markAsModified(documentId)
```

## Cache Integration

### Using the Cache System

```swift
// The cache coordinator manages all caches
let cache = coordinator.cacheCoordinator

// Cache syntax tokens
await cache.cacheTokens(tokens, for: cacheKey)

// Retrieve cached data
let cachedTokens = await cache.getCachedTokens(for: cacheKey)
```

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

// Write with automatic backup
try await coordinator.fileSystem.writeFile(
    content: content,
    to: url,
    createBackup: true
)

// List directory contents
let files = try await coordinator.fileSystem.listDirectory(at: directoryURL)
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
- macOS 13.0+ / iOS 16.0+
- Swift Concurrency support
- Uses modern Swift 6 concurrency features

## Best Practices

### Dependency Injection

```swift
// ✅ Good: Pass coordinator through configuration
class MyEditorViewController {
    let coordinator: ActorCoordinator
    
    init(configuration: EditorConfiguration) {
        self.coordinator = configuration.actorCoordinator ?? ActorCoordinator.create()
    }
}

// ❌ Bad: Using deprecated singleton
class MyEditorViewController {
    let coordinator = ActorCoordinator.shared  // Deprecated!
}
```

### Lifecycle Management

```swift
// Coordinators are lightweight, create as needed
func createEditor() -> CodeEditorView {
    var config = EditorConfiguration()
    config.actorCoordinator = ActorCoordinator.create()
    return CodeEditorView(configuration: config)
}
```

### Error Handling

```swift
// Let the coordinator handle recoverable errors
do {
    let result = try await coordinator.processText(
        text,
        processorType: .formatter
    )
} catch {
    // Only handle non-recoverable errors
    logger.error("Unrecoverable error: \(error)")
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
@MainActor
class EditorViewModel: ObservableObject {
    let coordinator: ActorCoordinator
    @Published var processedText = ""
    
    init(coordinator: ActorCoordinator) {
        self.coordinator = coordinator
    }
    
    func formatCode(_ code: String) async {
        do {
            processedText = try await coordinator.processText(
                code,
                processorType: .formatter
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

- ``TextProcessingActor``
- ``CacheCoordinatorActor``
- ``FileSystemActor``
- ``PerformanceMetricsActor``
- ``DocumentStateActor``
- ``ErrorRecoveryCoordinator``
- ``EditorConfiguration``