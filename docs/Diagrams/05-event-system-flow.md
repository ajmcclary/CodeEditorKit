# Event System Flow Diagram

This diagram illustrates the enhanced unified event system with modern async processing and performance monitoring.

```mermaid
flowchart TB
    %% Event Sources
    subgraph "Event Sources"
        UI[UI Actions<br/>Clicks, Keys, Gestures]
        TEXT[Text Changes<br/>Insert, Delete, Replace]
        SYS[System Events<br/>Memory, Focus, Resize]
        SERV[Service Events<br/>Completion, Highlight]
        CONF[Configuration<br/>Theme, Settings]
    end

    %% Event Creation & Injection
    subgraph "Event System Injection"
        INJECT[EditorConfiguration<br/>Dependency Injection]
        CREATE[Event Factory<br/>Type-safe Creation]
        EVENT[EditorEvent Enum<br/>Type-safe Event Creation]
    end

    %% Enhanced Event System Core
    subgraph "UnifiedEventSystem"
        PUBLISH["publish(_:)"]
        BATCH_PUB["publishBatch(_:)"]
        TYPED[Typed Publishers<br/>@Published Properties]
        FILTER[Smart Event Filters<br/>- PlatformEventFilter<br/>- PerformanceEventFilter<br/>- Custom Filters]
        THROTTLE["Throttling System<br/>- configureThrottling()<br/>- 60 events/sec default<br/>- Per-event-type limits"]
        HISTORY[Event History<br/>- CircularBuffer<br/>- 100 events capacity<br/>- Typed queries]
    end

    %% Metrics & Performance
    subgraph "Performance Monitoring"
        METRICS[EventMetrics<br/>- publishedCount<br/>- filteredCount<br/>- eventsPerSecond]
        PERF_SYS[UnifiedPerformanceSystem<br/>Integration]
        INSIGHTS[Performance Insights<br/>Automatic Generation]
    end

    %% Advanced Handler Registration
    subgraph "Handler Management"
        HANDLER_REG["EventHandler Protocol<br/>- canHandle(_:)<br/>- handle(_:)"]
        TOKEN[EventHandlerToken<br/>Safe Unregistration]
        COMBINE["Combine Integration<br/>- subscribe(to:handler:)<br/>- AnyPublisher&lt;EditorEvent&gt;"]
        TYPE_SAFE[Type-safe Subscriptions<br/>EditorEventType Protocol]
    end

    %% Smart Processing Pipeline
    subgraph "Intelligent Processing"
        DEBOUNCE[Smart Debouncing<br/>- TypingPatternAnalyzer<br/>- Dynamic delays<br/>- Priority queuing]
        COMPLETION[CompletionDebouncer<br/>- Smart throttling<br/>- Priority-based execution<br/>- Queue management]
        ASYNC_MGR[AsyncOperationManager<br/>- Throttling extensions<br/>- Concurrency control<br/>- Operation scheduling]
    end

    %% Event Types (Expanded)
    subgraph "Event Type Hierarchy"
        CORE_EVENTS[Core Events<br/>textDidChange<br/>textSelectionDidChange<br/>completionRequested<br/>performanceWarning]
        TYPED_EXTRACT[Type Extraction<br/>TextDidChangeEvent<br/>TextSelectionDidChangeEvent<br/>Custom Event Types]
    end

    %% Cross-Platform Coordination
    subgraph "CrossPlatformCoordinator"
        INPUT_COORD[InputCoordinator<br/>Platform Input Events]
        TOOLBAR_COORD[ToolbarCoordinator<br/>Toolbar Events]
        CONTEXT_COORD[ContextMenuCoordinator<br/>Menu Events]
        PLATFORM_EVENTS[Platform-specific<br/>Event Handling]
    end

    %% Enhanced Flow
    UI --> CREATE
    TEXT --> CREATE
    SYS --> CREATE
    SERV --> CREATE
    CONF --> CREATE

    INJECT --> CREATE
    CREATE --> EVENT

    EVENT --> PUBLISH
    EVENT --> BATCH_PUB

    PUBLISH --> FILTER
    BATCH_PUB --> FILTER
    FILTER -->|Pass| THROTTLE
    FILTER -->|Block| METRICS

    THROTTLE --> HISTORY
    THROTTLE --> TYPED
    THROTTLE --> METRICS

    HISTORY --> HANDLER_REG
    TYPED --> COMBINE
    COMBINE --> TYPE_SAFE

    HANDLER_REG --> TOKEN
    HANDLER_REG --> DEBOUNCE
    DEBOUNCE --> COMPLETION
    COMPLETION --> ASYNC_MGR

    ASYNC_MGR --> CORE_EVENTS
    CORE_EVENTS --> TYPED_EXTRACT

    %% Performance Integration
    METRICS --> PERF_SYS
    PERF_SYS --> INSIGHTS
    INSIGHTS -.->|Optimization| THROTTLE

    %% Cross-platform Integration
    INPUT_COORD -.->|Events| EVENT
    TOOLBAR_COORD -.->|Events| EVENT
    CONTEXT_COORD -.->|Events| EVENT
    PLATFORM_EVENTS -.->|Events| EVENT

    %% Feedback Loops
    ASYNC_MGR -.->|New Events| CREATE
    INSIGHTS -.->|Config Changes| CONF

    %% Enhanced Styling
    classDef source fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef system fill:#30D15820,stroke:#30D158,stroke-width:2px,color:#1D1D1F
    classDef handler fill:#34C75920,stroke:#34C759,stroke-width:2px,color:#1D1D1F
    classDef process fill:#AF52DE20,stroke:#AF52DE,stroke-width:2px,color:#1D1D1F
    classDef performance fill:#FF9F0A20,stroke:#FF9F0A,stroke-width:2px,color:#1D1D1F
    classDef coordination fill:#FF375F20,stroke:#FF375F,stroke-width:2px,color:#1D1D1F

    class UI,TEXT,SYS,SERV,CONF source
    class INJECT,CREATE,EVENT system
    class PUBLISH,BATCH_PUB,TYPED,FILTER,THROTTLE,HISTORY system
    class HANDLER_REG,TOKEN,COMBINE,TYPE_SAFE handler
    class DEBOUNCE,COMPLETION,ASYNC_MGR process
    class METRICS,PERF_SYS,INSIGHTS performance
    class INPUT_COORD,TOOLBAR_COORD,CONTEXT_COORD,PLATFORM_EVENTS coordination
```

## Event System Code Examples

### Modern Event Definition
```swift
// Type-safe EditorEvent enum
public enum EditorEvent: Sendable {
    case textDidChange(String)
    case textWillChange(range: NSRange, replacement: String)
    case textSelectionDidChange(NSRange)
    case completionRequested(context: CompletionContext)
    case completionItemSelected(any CompletionItemView)
    case performanceWarning(message: String)
    case error(Error)
}
```

### Dependency Injection Setup
```swift
// Modern dependency injection approach
let eventSystem = UnifiedEventSystem()
var config = EditorConfiguration()
config.eventSystem = eventSystem

// SwiftUI integration
CodeEditor(text: $code)
    .eventSystem(eventSystem)
    .environment(\.codeEditorConfiguration, config)
```

### Type-Safe Event Handling
```swift
// Type-safe event subscription
let cancellable = eventSystem.subscribe(to: TextDidChangeEvent.self) { event in
    print("Text changed: \(event.text)")
}

// Protocol-based handler registration
struct MyEventHandler: EventHandler {
    func canHandle(_ event: EditorEvent) -> Bool {
        switch event {
        case .textDidChange, .textSelectionDidChange:
            return true
        default:
            return false
        }
    }

    func handle(_ event: EditorEvent) {
        switch event {
        case .textDidChange(let text):
            // Handle text change
            break
        case .textSelectionDidChange(let range):
            // Handle selection change
            break
        default:
            break
        }
    }
}

let token = eventSystem.registerHandler(MyEventHandler())
```

### Enhanced Event Publishing
```swift
// Modern event publishing
eventSystem.publish(.textDidChange("new text content"))

// Batch publishing for efficiency
let events: [EditorEvent] = [
    .textDidChange("content"),
    .textSelectionDidChange(NSRange(location: 0, length: 7))
]
eventSystem.publishBatch(events)

// Direct publishing from CodeEditorView
codeEditorView.publishEvent(.completionRequested(context: context))
```

### Smart Event Filtering and Throttling
```swift
// Configure throttling for performance
eventSystem.configureThrottling(maxEventsPerSecond: 30)

// Custom event filters
struct DebugEventFilter: EventFilter {
    func shouldAllow(_ event: EditorEvent) -> Bool {
        #if DEBUG
        return true
        #else
        // Filter out debug events in release builds
        switch event {
        case .performanceWarning:
            return false
        default:
            return true
        }
        #endif
    }
}

eventSystem.addFilter(DebugEventFilter())
```

### Completion System Integration
```swift
// Smart debouncing with typing pattern analysis
let debouncer = CompletionDebouncer()
debouncer.enableSmartDebouncing = true
debouncer.debounceDelay = 0.3

debouncer.requestCompletions(
    for: context,
    priority: .high
) { result in
    switch result {
    case .success(let completions):
        // Handle completions
        break
    case .failure(let error):
        // Handle error
        break
    }
}
```

### Performance Monitoring Integration
```swift
// Event metrics tracking
let metrics = eventSystem.getMetrics()
print("Events per second: \(metrics.eventsPerSecond)")
print("Total published: \(metrics.publishedCount)")
print("Filtered count: \(metrics.filteredCount)")

// Event history queries
let recentTextEvents = eventSystem.getEvents(
    ofType: TextDidChangeEvent.self,
    limit: 5
)

// Performance optimization based on metrics
if metrics.eventsPerSecond > 50 {
    eventSystem.configureThrottling(maxEventsPerSecond: 30)
}
```

## Enhanced Key Features

### Core Event System
1. **Type-Safe Events**: Strongly-typed `EditorEvent` enum with associated values
2. **Dependency Injection**: Event system injected via `EditorConfiguration.eventSystem`
3. **Combine Integration**: Native support for reactive programming patterns
4. **Batch Publishing**: Efficient `publishBatch(_:)` for multiple events

### Performance & Throttling
5. **Smart Throttling**: Configurable per-event-type throttling (default: 60 events/sec)
6. **Event History**: Circular buffer storing last 100 events with typed queries
7. **Performance Metrics**: Real-time tracking of event throughput and filtering
8. **Memory-Efficient**: Automatic cleanup and bounded history storage

### Advanced Processing
9. **Smart Debouncing**: Typing pattern analysis with dynamic delay adjustment
10. **Priority Queuing**: Completion requests with `immediate`, `high`, `normal`, `low` priorities
11. **Async Operation Management**: Integration with `AsyncOperationManager` for concurrency control
12. **Error Recovery**: Comprehensive error handling with recoverable error patterns

### Cross-Platform Support
13. **Platform Event Filtering**: `PlatformEventFilter` for platform-specific event handling
14. **Coordinator Integration**: Events from `InputCoordinator`, `ToolbarCoordinator`, `ContextMenuCoordinator`
15. **Platform Abstraction**: Unified event handling across macOS and iOS

### Developer Experience
16. **Token-Based Unregistration**: Safe handler cleanup with `EventHandlerToken`
17. **Type Extraction**: `EditorEventType` protocol for type-safe event filtering
18. **Debugging Support**: Event history inspection and performance insights
19. **SwiftUI Integration**: Environment-based configuration and typed publishers

### Performance Optimization
20. **Automatic Optimization**: Integration with `UnifiedPerformanceSystem` for adaptive throttling
21. **Smart Filtering**: Multiple filter layers including performance and platform filters
22. **Typing Pattern Analysis**: Dynamic debouncing based on user typing behavior
23. **Resource Management**: Automatic cleanup and memory management for long-running applications
