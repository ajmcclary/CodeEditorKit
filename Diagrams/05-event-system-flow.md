# Event System Flow Diagram

This diagram illustrates the unified event system that enables decoupled communication between components.

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

    %% Event Creation
    subgraph "Event Creation"
        CREATE[Event Factory]
        EVENT[Event Object<br/>- type: EventType<br/>- source: Any<br/>- timestamp: Date<br/>- data: Dictionary]
    end

    %% Event System Core
    subgraph "UnifiedEventSystem"
        EMIT[emit Event]
        FILTER[Event Filters<br/>- Type Filter<br/>- Source Filter<br/>- Data Filter]
        QUEUE[Event Queue<br/>Priority-based]
        DISPATCH[Event Dispatcher]
    end

    %% Event Registration
    subgraph "Handler Registration"
        REG[Handler Registry<br/>Dictionary&lt;EventType, Array of Handlers&gt;]
        PRIORITY[Priority Management<br/>High, Normal, Low]
    end

    %% Event Handlers
    subgraph "Event Handlers"
        SYNC[Synchronous Handlers<br/>- UI Updates<br/>- Validation]
        ASYNC[Asynchronous Handlers<br/>- Highlighting<br/>- Completion<br/>- File I/O]
        BATCH[Batch Handlers<br/>- Multiple Changes<br/>- Bulk Operations]
    end

    %% Event Processing
    subgraph "Processing Pipeline"
        PRE[Pre-processing<br/>- Validation<br/>- Transformation]
        EXEC[Handler Execution<br/>- Error Handling<br/>- Timeout Management]
        POST[Post-processing<br/>- Cleanup<br/>- Logging]
    end

    %% Event Types
    subgraph "Event Types"
        direction LR
        TYPES[TextChanged<br/>SelectionChanged<br/>LanguageChanged<br/>ConfigurationChanged<br/>MemoryWarning<br/>CompletionRequested<br/>HighlightingCompleted]
    end

    %% Flow
    UI --> CREATE
    TEXT --> CREATE
    SYS --> CREATE
    SERV --> CREATE
    CONF --> CREATE
    
    CREATE --> EVENT
    EVENT --> EMIT
    
    EMIT --> FILTER
    FILTER -->|Pass| QUEUE
    FILTER -->|Block| END1[Discarded]
    
    QUEUE --> DISPATCH
    DISPATCH --> REG
    
    REG --> PRIORITY
    PRIORITY --> PRE
    
    PRE --> EXEC
    EXEC --> SYNC
    EXEC --> ASYNC
    EXEC --> BATCH
    
    SYNC --> POST
    ASYNC --> POST
    BATCH --> POST
    
    POST --> COMPLETE[Complete]
    
    %% Feedback Loop
    ASYNC -.->|New Events| CREATE
    BATCH -.->|New Events| CREATE

    %% Styling - Dark mode friendly colors
    classDef source fill:#3b82f620,stroke:#3b82f6,stroke-width:2px,color:#fff
    classDef system fill:#6366f120,stroke:#6366f1,stroke-width:2px,color:#fff
    classDef handler fill:#10b98120,stroke:#10b981,stroke-width:2px,color:#fff
    classDef process fill:#8b5cf620,stroke:#8b5cf6,stroke-width:2px,color:#fff
    classDef types fill:#06b6d420,stroke:#06b6d4,stroke-width:2px,color:#fff
    
    class UI source
    class TEXT source
    class SYS source
    class SERV source
    class CONF source
    class EMIT system
    class FILTER system
    class QUEUE system
    class DISPATCH system
    class REG system
    class PRIORITY system
    class SYNC handler
    class ASYNC handler
    class BATCH handler
    class PRE process
    class EXEC process
    class POST process
    class TYPES types
```

## Event System Code Examples

### Event Definition
```swift
struct Event {
    let type: EventType
    let source: Any
    let timestamp: Date
    let data: [String: Any]
}

enum EventType {
    case textChanged
    case selectionChanged
    case languageChanged
    case configurationChanged
    case memoryWarning
    case completionRequested
    case highlightingCompleted
}
```

### Handler Registration
```swift
eventSystem.register(.textChanged, priority: .high) { event in
    // Handle text change
    guard let range = event.data["range"] as? NSRange else { return }
    // Process change...
}
```

### Event Emission
```swift
eventSystem.emit(Event(
    type: .textChanged,
    source: self,
    timestamp: Date(),
    data: ["range": range, "text": newText]
))
```

### Event Filtering
```swift
eventSystem.addFilter { event in
    // Only process events from specific sources
    return event.source is CodeEditorView
}
```

## Key Features

1. **Priority-based Processing**: High-priority events processed first
2. **Asynchronous Support**: Long-running handlers don't block UI
3. **Event Filtering**: Reduce unnecessary processing
4. **Batch Processing**: Efficient handling of multiple related events
5. **Error Isolation**: Handler errors don't crash the system
6. **Event Chaining**: Handlers can emit new events
7. **Performance Monitoring**: Track handler execution times