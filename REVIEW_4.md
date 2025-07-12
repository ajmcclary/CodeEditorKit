# Review 4

## Issues & Recommendations

---

### 1. Stop Default Memory Monitor When the SwiftUI View Disappears

`CodeEditor` creates a `MemoryMonitor` and starts it in `.onAppear` but never stops monitoring. If the view is removed, the monitoring task continues running unnecessarily.

**Relevant code snippet:**

```swift
@State private var defaultMemoryMonitor = MemoryMonitor()
// ...
.onAppear {
    if environment.memoryMonitor == nil {
        defaultMemoryMonitor.startMonitoring()
    }
}
```

Add a corresponding `.onDisappear` that calls `defaultMemoryMonitor.stopMonitoring()` when the monitor was started by the view.

**Suggested Task:**  
Stop default MemoryMonitor when CodeEditor disappears.

---

### 2. Replace NSLock-Based Caches with Actors

`LineIndexCache` and `ParagraphStyleCache` rely on `NSLock` for thread safety. Converting them into actors would simplify the synchronization logic and align with the Swift 6 concurrency model.

**Current locking pattern example:**

```swift
private var cache: [CacheKey: NSParagraphStyle] = [:]
private let cacheLock = NSLock()

private var cache: CacheEntry?
private let cacheLock = NSLock()
```

Implement these caches as isolated actors to avoid manual locking and provide safer concurrent access.

**Suggested Task:**  
Refactor caches to actors.

---

### 3. Split the Large PerformanceInsights.swift File for Maintainability

`PerformanceInsights.swift` is over 800 lines long:

- 817 Sources/CodeEditorPlugin/Performance/PerformanceInsights.swift

Breaking this file into smaller, focused components will improve discoverability and maintainability. Consider separating models, view code, and analytics logic into distinct files.

**Suggested Task:**  
Break up PerformanceInsights implementation.

---

### 4. (Optional) Consider Decomposing EditorEvent.swift

`EditorEvent.swift` contains 656 lines of mixed enums, protocols, publisher logic, and Combine interoperability.

- 656 Sources/CodeEditorPlugin/Core/EditorEvent.swift

Splitting this file into separate concerns (event definitions, publisher, subscription helpers) would aid navigation and readability.

**Suggested Task:**  
Separate EditorEvent components.
