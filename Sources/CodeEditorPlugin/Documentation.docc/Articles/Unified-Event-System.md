# Unified Event System

@Metadata {
    @PageKind(article)
    @PageImage(purpose: card, source: "advanced-features-hero")
}

Learn how to use the UnifiedEventSystem for decoupled event handling and advanced editor customization.

## Overview

The `UnifiedEventSystem` provides a powerful, type-safe publish-subscribe mechanism for handling events in CodeEditorPlugin. It enables loose coupling between components while maintaining Swift's strong type safety and modern concurrency patterns.

## Key Features

- **Type-Safe Events**: Define custom event types with associated data
- **Async/Await Support**: Modern Swift concurrency for event handling
- **Thread-Safe**: Built with actors for safe concurrent access
- **Weak References**: Automatic cleanup of deallocated subscribers
- **Priority Handling**: Process events in priority order
- **Event History**: Optional event logging for debugging
- **Dependency Injection**: No singleton pattern for better testability

## Basic Usage

### Creating an Event System

```swift
// Create a custom event system instance
let eventSystem = UnifiedEventSystem()

// Or inject via configuration
var config = EditorConfiguration()
config.eventSystem = eventSystem

// Apply to editor
let editor = CodeEditorView()
config.apply(to: editor)
```

### Defining Custom Events

```swift
// Define your custom event types
struct TextChangeEvent: EditorEvent {
    let identifier = UUID()
    let timestamp = Date()
    let oldText: String
    let newText: String
    let range: NSRange
}

struct SelectionChangeEvent: EditorEvent {
    let identifier = UUID()
    let timestamp = Date()
    let selectedRange: NSRange
    let affinity: NSSelectionAffinity
}

struct AutocompleteEvent: EditorEvent {
    let identifier = UUID()
    let timestamp = Date()
    let prefix: String
    let position: Int
    let suggestions: [String]
}
```

### Publishing Events

```swift
// Publish events from your components
@MainActor
func textDidChange(in editor: CodeEditorView) {
    guard let eventSystem = editor.configuration.eventSystem else { return }
    
    let event = TextChangeEvent(
        oldText: previousText,
        newText: editor.text,
        range: changedRange
    )
    
    eventSystem.publish(event)
}
```

### Subscribing to Events

```swift
// Subscribe with async handlers
let subscription = eventSystem.subscribe(to: TextChangeEvent.self) { event in
    print("Text changed from '\(event.oldText)' to '\(event.newText)'")
    
    // Perform async operations
    await validateSyntax(event.newText)
    await updateAutocompleteSuggestions(event.newText)
}

// Subscribe with priority
let prioritySubscription = eventSystem.subscribe(
    to: SelectionChangeEvent.self,
    priority: .high
) { event in
    // High-priority handlers execute first
    await updateSelectionIndicators(event.selectedRange)
}
```

### Managing Subscriptions

```swift
// Store subscriptions to manage lifecycle
class EditorViewController {
    private var subscriptions: Set<SubscriptionToken> = []
    
    func setupEventHandlers() {
        // Subscribe to multiple event types
        subscriptions.insert(
            eventSystem.subscribe(to: TextChangeEvent.self) { event in
                await self.handleTextChange(event)
            }
        )
        
        subscriptions.insert(
            eventSystem.subscribe(to: SelectionChangeEvent.self) { event in
                await self.handleSelectionChange(event)
            }
        )
    }
    
    func cleanup() {
        // Unsubscribe all handlers
        subscriptions.forEach { eventSystem.unsubscribe($0) }
        subscriptions.removeAll()
    }
}
```

## Advanced Patterns

### Event Filtering

```swift
// Subscribe only to specific events
eventSystem.subscribe(to: TextChangeEvent.self) { event in
    // Only handle significant changes
    guard event.newText.count > 10 else { return }
    guard event.newText != event.oldText else { return }
    
    await processSignificantChange(event)
}
```

### Event Aggregation

```swift
// Collect multiple events before processing
actor EventAggregator {
    private var pendingEvents: [TextChangeEvent] = []
    private var processTask: Task<Void, Never>?
    
    func add(_ event: TextChangeEvent) {
        pendingEvents.append(event)
        
        // Cancel existing task
        processTask?.cancel()
        
        // Debounce processing
        processTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            
            await processBatch(pendingEvents)
            pendingEvents.removeAll()
        }
    }
    
    private func processBatch(_ events: [TextChangeEvent]) async {
        // Process aggregated events
        let totalChanges = events.count
        let finalText = events.last?.newText ?? ""
        
        print("Processed \(totalChanges) changes, final text: \(finalText)")
    }
}
```

### Cross-Component Communication

```swift
// Syntax highlighter publishes completion
struct SyntaxHighlightingCompleteEvent: EditorEvent {
    let identifier = UUID()
    let timestamp = Date()
    let language: Language
    let tokenCount: Int
    let duration: TimeInterval
}

// Minimap subscribes to update
class MinimapView {
    func setupEventHandling(_ eventSystem: UnifiedEventSystem) {
        eventSystem.subscribe(to: SyntaxHighlightingCompleteEvent.self) { event in
            await MainActor.run {
                self.updateSyntaxOverlay(
                    language: event.language,
                    tokenCount: event.tokenCount
                )
            }
        }
    }
}
```

### Event History and Debugging

```swift
// Enable event history for debugging
let eventSystem = UnifiedEventSystem(maxEventHistory: 100)

// Retrieve recent events
let recentTextChanges = eventSystem.getEventHistory(
    ofType: TextChangeEvent.self,
    limit: 10
)

// Debug event flow
for event in recentTextChanges {
    print("[\(event.timestamp)] Text changed: \(event.oldText) → \(event.newText)")
}

// Get all event types that have been published
let activeEventTypes = eventSystem.getAllEventTypes()
print("Active event types: \(activeEventTypes)")
```

## Integration with SwiftUI

### Environment-Based Event System

```swift
struct ContentView: View {
    @State private var code = ""
    @State private var eventSystem = UnifiedEventSystem()
    @State private var eventLog: [String] = []
    
    var body: some View {
        VStack {
            CodeEditor(text: $code)
                .eventSystem(eventSystem)
                .onAppear {
                    setupEventMonitoring()
                }
            
            // Event log display
            List(eventLog, id: \.self) { log in
                Text(log)
                    .font(.caption)
            }
            .frame(height: 100)
        }
    }
    
    private func setupEventMonitoring() {
        eventSystem.subscribe(to: TextChangeEvent.self) { event in
            await MainActor.run {
                eventLog.append("Text changed at \(event.timestamp)")
                
                // Keep only recent logs
                if eventLog.count > 50 {
                    eventLog.removeFirst()
                }
            }
        }
    }
}
```

### Custom View Modifiers

```swift
extension View {
    func onCodeEditorEvent<T: EditorEvent>(
        _ eventType: T.Type,
        perform action: @escaping (T) async -> Void
    ) -> some View {
        self.onReceive(NotificationCenter.default.publisher(
            for: .init("CodeEditorEvent.\(eventType)")
        )) { notification in
            guard let event = notification.object as? T else { return }
            Task {
                await action(event)
            }
        }
    }
}

// Usage
CodeEditor(text: $code)
    .onCodeEditorEvent(TextChangeEvent.self) { event in
        await validateCode(event.newText)
    }
    .onCodeEditorEvent(SelectionChangeEvent.self) { event in
        await updateStatusBar(selection: event.selectedRange)
    }
```

## Best Practices

### 1. Define Clear Event Contracts

```swift
// Good: Specific, well-documented events
/// Published when the user triggers code completion
struct CodeCompletionRequestedEvent: EditorEvent {
    let identifier = UUID()
    let timestamp = Date()
    
    /// The text position where completion was requested
    let position: Int
    
    /// The partial word being completed
    let prefix: String
    
    /// The language context for completion
    let language: Language
}

// Avoid: Generic, unclear events
struct SomethingHappenedEvent: EditorEvent {
    let identifier = UUID()
    let timestamp = Date()
    let data: Any // Too generic!
}
```

### 2. Use Weak References

```swift
class EditorPlugin {
    weak var editor: CodeEditorView?
    private var subscription: SubscriptionToken?
    
    init(editor: CodeEditorView, eventSystem: UnifiedEventSystem) {
        self.editor = editor
        
        // Capture self weakly in closures
        subscription = eventSystem.subscribe(to: TextChangeEvent.self) { [weak self] event in
            guard let self = self else { return }
            await self.processTextChange(event)
        }
    }
}
```

### 3. Handle Errors Gracefully

```swift
eventSystem.subscribe(to: TextChangeEvent.self) { event in
    do {
        try await riskyOperation(event.newText)
    } catch {
        // Log error but don't crash
        print("Error processing text change: \(error)")
        
        // Optionally publish error event
        let errorEvent = EditorErrorEvent(
            originalEvent: event,
            error: error
        )
        eventSystem.publish(errorEvent)
    }
}
```

### 4. Consider Performance

```swift
// For high-frequency events, use debouncing
class DebouncedEventHandler {
    private var task: Task<Void, Never>?
    private let delay: Duration
    
    init(delay: Duration = .milliseconds(100)) {
        self.delay = delay
    }
    
    func handle(_ event: TextChangeEvent) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            
            await processEvent(event)
        }
    }
}
```

## Migration from Singleton

If you're migrating from the deprecated singleton pattern:

```swift
// Old (deprecated)
UnifiedEventSystem.shared.publish(event)

// New (dependency injection)
class MyComponent {
    private let eventSystem: UnifiedEventSystem
    
    init(eventSystem: UnifiedEventSystem) {
        self.eventSystem = eventSystem
    }
    
    func doWork() {
        eventSystem.publish(event)
    }
}
```

## Testing with Event System

```swift
class EditorEventTests: XCTestCase {
    func testTextChangeEventHandling() async {
        let eventSystem = UnifiedEventSystem()
        let expectation = expectation(description: "Event handled")
        var receivedEvent: TextChangeEvent?
        
        let subscription = eventSystem.subscribe(to: TextChangeEvent.self) { event in
            receivedEvent = event
            expectation.fulfill()
        }
        
        let event = TextChangeEvent(
            oldText: "Hello",
            newText: "Hello, World!",
            range: NSRange(location: 5, length: 8)
        )
        
        eventSystem.publish(event)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedEvent?.newText, "Hello, World!")
        
        // Cleanup
        eventSystem.unsubscribe(subscription)
    }
}
```

## See Also

- <doc:Configuration-System>
- <doc:MemoryMonitor-Injection>
- <doc:Swift6-Concurrency>
- ``UnifiedEventSystem``
- ``EditorEvent``