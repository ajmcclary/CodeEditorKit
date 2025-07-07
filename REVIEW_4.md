# REVIEW 4

# Code Review

## API Design & Ergonomics

### Unused ObjectiveC imports

**Files:** `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` lines 1‑3 and `CodeEditorView+Core.swift` lines 1‑3

The main editor files import ObjectiveC, yet no Objective‑C runtime APIs are used:

```swift
import Foundation
import ObjectiveC
import os.log
```

Removing these imports avoids unnecessary linkage.

### Builder Pattern Duplication

**File:** `Sources/CodeEditorPlugin/Configuration/EditorConfigurationBuilder.swift`

The builder re‑implements every configuration property, leading to ~200 lines of repetitive code (e.g. `.fontSize(_:)`, `.showLineNumbers(_:)`, `.tabWidth(_:)`). See lines around 50‑120 and 160‑240. This duplication makes maintenance harder if `EditorConfiguration` changes.

### Ambiguous Notification Name

**File:** `Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformSpecific.swift` lines 155‑160

The custom selection notification uses the prefix `st`, which isn't clear to API consumers:

```swift
public static let stTextViewDidChangeSelectionNotification = Notification
    .Name("CodeEditorViewDidChangeSelectionNotification")
```

A more descriptive name (e.g. `selectionDidChangeNotification`) improves discoverability.

### Platform Representables Duplication

**Files:** `CodeEditor+AppKit.swift` and `CodeEditor+UIKit.swift`

Both wrappers implement nearly identical logic (initialization, update, sizeThatFits, coordinator). This duplication increases maintenance cost.

## Architecture & Scalability

### Complex Builder Maintenance

The feature-based directory structure is clear, but `EditorConfigurationBuilder` manually mirrors every configuration field. A key‑path driven approach could drastically simplify the builder and ensure future configuration properties are automatically available.

### PlatformCapabilities Complexity

**File:** `Sources/CodeEditorPlugin/Platform/PlatformCapabilities.swift`

The `PlatformCapabilities` class is quite large (~300+ lines). Splitting sub‑capabilities into smaller, focused types (e.g. `RenderingCapabilities`, `InputCapabilities`) would improve readability and maintainability.

## Code Quality & Best Practices

### Potential Redundant Task

In `CodeEditorView` deinitializer (around line 260), a Task is spawned solely to unregister a cleanup handler. Since deinit already runs on the main actor, the async task may be unnecessary:

```swift
Task { @MainActor in
    MemoryMonitor.shared.unregisterCleanupHandler(identifier: identifier)
}
```

Consider a synchronous call if already on the main actor.

### Event Publisher Exposure

`CodeEditorView` exposes `public let eventPublisher = EditorEventPublisher()`. Verify whether external consumers truly need direct access or if specific events should be relayed via delegate methods to keep the API minimal.

## Testing & Reliability

### Missing Builder Tests

There are many tests for the editor view and configuration, but no unit tests specifically verifying `EditorConfigurationBuilder`. Adding tests that build configurations and compare against expected `EditorConfiguration` values would increase confidence.

### Hot Reload Edge Cases

`ConfigurationHotReload` handles undo/redo and batching. Consider tests covering simultaneous observer updates, invalid configurations, and persistence of history across multiple instances.

## Documentation & Clarity

### Environment Key Reference

The DocC articles explain the configuration system but barely mention the `codeEditorConfiguration` environment key. Adding a short section demonstrating environment-based configuration would help SwiftUI users.

### Notification Documentation

`CodeEditorView+PlatformSpecific.swift` defines a custom selection notification, but there is no DocC entry or inline reference. Documenting this notification (purpose, when it fires, thread context) will aid consumers.

## Recommended Tasks

### Suggested task

**Remove unused ObjectiveC imports**

### Suggested task

**Simplify EditorConfigurationBuilder with key-path based API**

### Suggested task

**Rename selection change notification for clarity**

### Suggested task

**Unify CodeEditorRepresentable wrappers**

### Suggested task

**Add unit tests for EditorConfigurationBuilder**

These changes will streamline the public API, reduce duplication, and strengthen test coverage while preserving the plugin's cross‑platform focus.
