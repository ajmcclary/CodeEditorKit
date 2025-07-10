# REVIEW 1

## Summary

### API Design & Ergonomics

**File Notes**

- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` (lines 150‑184):  
  Core properties include a public `configuration` value that applies settings whenever changed. `language` and other key properties are simple to modify.

- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift` (lines 45‑75):  
  The SwiftUI wrapper exposes clear modifiers such as `.codeLanguage` and `.lineNumbers`, supporting environment-based configuration.

- `Sources/CodeEditorPlugin/Configuration/EditorConfiguration+Presets.swift` (lines 5‑65):  
  Presets (default, minimal, readOnly, markdown, presentation, platform‑specific) are organized in one place and easy to apply.

### Architecture & Scalability

**File Notes**

- `Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformSpecific.swift` (lines 65‑84):  
  Uses `Task { @MainActor … }` to delay text-color application for Mac Catalyst, but the task isn’t stored for cancellation.

- `Sources/CodeEditorPlugin/Performance/MemoryMonitor.swift` (lines 205‑255):  
  Memory monitor spawns long‑lived monitoring tasks without explicit cancellation on deinit beyond `Task` cancellation.

### Testing & Documentation

**File Notes**

- `README.md` (lines 431‑468):  
  States "**532 Total Tests**" and lists individual counts.

- `AGENTS.md` (lines 8‑12 and 146‑148):  
  Mentions **319** tests earlier, then states “Main Package: 390 tests”.

---

## Recommendations

### 1. Reconcile Test Count Documentation

**Issue:**  
`README.md` advertises 532 tests while `AGENTS.md` lists 319 and 390. This discrepancy can confuse contributors.

**Suggestion:**  
Align documentation to a single authoritative test count and update all locations.

**Suggested task:** Update documentation with accurate test numbers

---

### 2. Persist Delayed Task for Catalyst Initialization

**Issue:**  
`CodeEditorView+PlatformSpecific.swift` (lines 65‑84) launches a detached `Task` to apply colors after a short delay. The task is not stored or cancelled if the view disappears early.

```swift
Task { @MainActor [weak self] in
    do {
        try await Task.sleep(nanoseconds: 100_000_000)
        self?.applyTextColorForMacCatalyst()
    } catch { }
}
```

**Suggestion:**  
Store this task in a property and cancel it in `removeFromSuperview()` or `deinit`. This prevents orphaned tasks and potential leaks.

**Suggested task:** Manage Catalyst color application task

---

### 3. Clarify MemoryMonitor Lifecycle

**Issue:**  
`MemoryMonitor` starts monitoring tasks in `startMonitoring()` and only cancels them in `stopMonitoring()`, but the monitor may be deinitialized without an explicit stop.

```swift
monitoringTask = Task { [weak self] in
    while !Task.isCancelled { ... }
}
```

**Suggestion:**  
Document that `stopMonitoring()` should be called when the monitor is no longer needed, or automatically stop in `deinit` using `Task {}` to ensure cleanup on the main actor.

**Suggested task:** Ensure MemoryMonitor tasks cancel on deinit

---

### 4. Expand Integration Tests for Advanced Features

**Issue:**  
Current tests cover basic operations, but high‑level features like the plugin system, LSP integration, and SmartEditingEngine have limited direct tests.

**Suggestion:**  
Introduce integration tests that simulate real editing scenarios:

- LSP interactions for completion and diagnostics
- Multi-cursor editing from `SmartEditingEngine`
- MemoryMonitor triggering automatic cleanup

**Suggested task:** Add integration tests for advanced subsystems

---

### 5. Improve Documentation Consistency

**Issue:**  
Some docs still reference the deprecated `MemoryMonitor.shared` (e.g., `Articles/MemoryMonitor-Injection.md` line 340).

**Suggestion:**  
Remove or update deprecated usage examples to match the recommended dependency‑injection approach.

**Suggested task:** Remove deprecated MemoryMonitor.shared examples

---

### 6. Optional: Provide Public Convenience API for Code Folding

**Suggestion:**  
`CodeEditorView` exposes methods to fold/unfold regions internally (e.g., `fold(_:)`, `unfold(_:)`). Consider a small public API to trigger folding via line numbers, giving end users more control.

**Suggested task:** Expose public folding methods

---

### 7. Audit Long Files for Potential Splitting

Some files such as `PlatformColors.swift` and `SmartEditingEngine.swift` exceed a few hundred lines. Breaking them into focused submodules (e.g., color groups or editing features) could improve maintainability.

**Suggested task:** Refactor large files

---

### 8. Clarify Actor Isolation for AsyncTextProcessor

`AsyncTextProcessor` manages a queue of tasks. Ensure all public APIs specify actor isolation to avoid accidental calls from the wrong context. Document expected usage.

**Suggested task:** Document AsyncTextProcessor actor isolation

---

### 9. Minor API Enhancement: EditorConfigurationBuilder

Provide a `mutating func` variant to allow building via value semantics rather than chained copying.

**Suggested task:** Offer mutable EditorConfigurationBuilder

---

## Testing

_No tests were run since this review is read-only._
