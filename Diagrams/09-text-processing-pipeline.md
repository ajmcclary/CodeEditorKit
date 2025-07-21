# Text Processing Pipeline

This diagram illustrates the text processing pipeline, from input to rendering, including TextKit2 integration and performance optimizations.

```mermaid
flowchart TB
    %% Input Layer
    subgraph "Input Sources"
        KEYBOARD[Keyboard Input]
        PASTE[Paste Operations]
        API[API Calls<br/>setText, insertText]
        UNDO[Undo/Redo]
    end

    %% Text Storage
    subgraph "Text Storage Layer"
        TS[NSTextStorage<br/>Main text buffer]
        TSN[Text Storage Notifications<br/>willProcessEditing<br/>didProcessEditing]
        ATTR[Attribute Management<br/>Syntax highlighting<br/>Text attributes]
    end

    %% TextKit2 Components
    subgraph "TextKit2 Engine"
        TC[NSTextContainer<br/>Layout boundaries]
        LM[NSLayoutManager<br/>Text layout]
        TLF[Text Layout Fragment<br/>Line fragments]
        GLYPH[Glyph Generation<br/>Font rendering]
    end

    %% Processing Pipeline
    subgraph "Text Processing"
        VAL[Input Validation<br/>Unicode normalization<br/>Character validation]
        TRANS[Text Transformation<br/>Tab expansion<br/>Auto-indentation]
        RANGE[Range Calculation<br/>Affected ranges<br/>Line mapping]
    end

    %% Line Management
    subgraph "Line Index System"
        LIC[LineIndexCache<br/>Line → Range mapping]
        LICALC[Line Calculator<br/>Newline detection<br/>Line boundaries]
        LIUPD[Incremental Updates<br/>Partial invalidation]
    end

    %% Performance Layer
    subgraph "Performance Optimizations"
        BATCH[Batch Processing<br/>Coalesce changes]
        ASYNC[Async Processing<br/>Background tasks]
        VIEWPORT[Viewport Culling<br/>Visible range only]
        CACHE[Layout Cache<br/>Reuse calculations]
    end

    %% Rendering Pipeline
    subgraph "Rendering"
        DRAW[Drawing Context<br/>Core Graphics]
        LAYERS[Layer Management<br/>Text layer<br/>Selection layer<br/>Cursor layer]
        COMP[Compositing<br/>Final output]
    end

    %% Event System
    subgraph "Event Notifications"
        EVENTS[Event Emission<br/>textChanged<br/>selectionChanged<br/>layoutChanged]
    end

    %% Flow - Input to Storage
    KEYBOARD --> VAL
    PASTE --> VAL
    API --> VAL
    UNDO --> VAL
    
    VAL --> TRANS
    TRANS --> TS
    
    %% Storage Processing
    TS --> TSN
    TSN --> ATTR
    ATTR --> RANGE
    
    %% Line Index Updates
    RANGE --> LICALC
    LICALC --> LIC
    LIC --> LIUPD
    
    %% TextKit2 Flow
    TS --> TC
    TC --> LM
    LM --> TLF
    TLF --> GLYPH
    
    %% Performance Integration
    TRANS --> BATCH
    BATCH --> ASYNC
    
    RANGE --> VIEWPORT
    VIEWPORT --> CACHE
    
    %% Rendering Flow
    GLYPH --> DRAW
    CACHE --> DRAW
    DRAW --> LAYERS
    LAYERS --> COMP
    
    %% Event Flow
    TSN --> EVENTS
    LIUPD --> EVENTS
    COMP --> EVENTS

    %% Styling - Dark mode friendly colors
    classDef input fill:#3b82f620,stroke:#3b82f6,stroke-width:2px,color:#fff
    classDef storage fill:#8b5cf620,stroke:#8b5cf6,stroke-width:2px,color:#fff
    classDef textkit fill:#10b98120,stroke:#10b981,stroke-width:2px,color:#fff
    classDef process fill:#6366f120,stroke:#6366f1,stroke-width:2px,color:#fff
    classDef perf fill:#f59e0b20,stroke:#f59e0b,stroke-width:2px,color:#fff
    classDef render fill:#06b6d420,stroke:#06b6d4,stroke-width:2px,color:#fff
    
    class KEYBOARD input
    class PASTE input
    class API input
    class UNDO input
    class TS storage
    class TSN storage
    class ATTR storage
    class TC textkit
    class LM textkit
    class TLF textkit
    class GLYPH textkit
    class VAL process
    class TRANS process
    class RANGE process
    class LIC process
    class LICALC process
    class LIUPD process
    class BATCH perf
    class ASYNC perf
    class VIEWPORT perf
    class CACHE perf
    class DRAW render
    class LAYERS render
    class COMP render
    class EVENTS render
```

## Detailed Processing Steps

### 1. Input Validation
```swift
func validateInput(_ text: String) -> String {
    // Unicode normalization
    let normalized = text.precomposedStringWithCanonicalMapping
    
    // Remove control characters
    let cleaned = normalized.filter { !$0.isControl }
    
    return cleaned
}
```

### 2. Line Index Management
```swift
class LineIndexCache {
    private var lineStarts: [Int] = []
    private var version: Int = 0
    
    func updateForTextChange(range: NSRange, delta: Int) {
        // Incremental update algorithm
        let startLine = lineContaining(location: range.location)
        // Update only affected lines...
    }
}
```

### 3. Batch Processing
```swift
class BatchProcessor {
    private var pendingChanges: [TextChange] = []
    private var timer: Timer?
    
    func addChange(_ change: TextChange) {
        pendingChanges.append(change)
        scheduleBatchProcessing()
    }
    
    private func processBatch() {
        textStorage.beginEditing()
        pendingChanges.forEach { apply($0) }
        textStorage.endEditing()
    }
}
```

## Performance Characteristics

| Operation | Complexity | Optimization |
|-----------|------------|--------------|
| Text Insertion | O(n) | Batch updates |
| Line Lookup | O(1) | Cached indices |
| Syntax Highlight | O(n) | Viewport only |
| Layout | O(visible) | Virtualization |
| Scrolling | O(1) | Pre-calculated |

## Key Optimizations

1. **Incremental Updates**: Only process changed regions
2. **Line Caching**: O(1) line number lookups
3. **Viewport Rendering**: Only layout visible text
4. **Batch Processing**: Coalesce rapid changes
5. **Async Highlighting**: Non-blocking syntax updates
6. **Glyph Caching**: Reuse font measurements
7. **Layer Composition**: Separate layers for different elements