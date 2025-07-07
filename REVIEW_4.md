# REVIEW 4

# Code Review Summary

## 1. API Design & Ergonomics

### Consistency of time types

`CodeEditor` uses Swift `Duration` for text debouncing, but the corresponding performance settings use `TimeInterval`:

```swift
public var highlightingDebounceInterval: TimeInterval = PlatformConstants.defaultHighlightingDebounceInterval
public var textChangeDebounceInterval: TimeInterval = 0.1
```

Consider adopting `Duration` throughout the configuration API for uniformity.

### Redundant platform-specific overrides

`removeFromSuperview()` is duplicated for AppKit and UIKit with identical logic:

```swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
override public func removeFromSuperview() {
    unregisterFromMemoryMonitor()
    super.removeFromSuperview()
}
#else
override public func removeFromSuperview() {
    unregisterFromMemoryMonitor()
    super.removeFromSuperview()
}
#endif
```

A single override guarded by `#if canImport(AppKit)` is sufficient.

### Use of `DispatchQueue.main.async`

SwiftUI wrappers still rely on GCD to set focus:

```swift
if context.environment.codeEditorBecomeFirstResponder {
    DispatchQueue.main.async {
        nsView.window?.makeFirstResponder(nsView.textView)
    }
}
```

Replace with `Task { @MainActor in … }` for Swift-concurrency consistency.

## 2. Architecture & Scalability

### Visibility of internal state

`annotationViews` is declared `internal` in `CodeEditorView`:

```swift
internal var annotationViews: [String: PlatformView] = [:]
```

No code outside the module uses it directly. Making it `private` would reduce the public surface and prevent misuse.

### Coordinator subclassing

`CodeEditorBaseCoordinator` is declared `open`:

```swift
open class CodeEditorBaseCoordinator: NSObject, ObservableObject {
```

If external subclassing is not required, consider `final` to enable compiler optimizations and clarify intent.

## 3. Code Quality & Best Practices

### Legacy GCD usage in event handling

`EditorEvent` uses `DispatchQueue.main.async` for subscription setup and teardown:

```swift
DispatchQueue.main.async { [weak self] in
    guard let self else { return }
    ...
}
```

Switching to `Task { @MainActor in … }` avoids thread-hopping and follows modern concurrency patterns.

## 4. Testing & Reliability

Existing tests cover initialization and configuration extensively (e.g. `CodeEditorViewTests`), but there are few integration tests for platform-specific features such as context menus or `PlatformCapabilities`. Adding UI tests to verify context menu content across platforms would strengthen confidence.

## 5. Documentation & Clarity

DocC articles like `GettingStarted.md` clearly explain usage. Ensure documentation covers advanced topics such as the platform capability system (`PlatformCapabilities`) so developers understand how to query feature availability.

---

## Suggested Task Stubs

### Unify configuration API to use `Duration`

Replace `TimeInterval` properties (`highlightingDebounceInterval` and `textChangeDebounceInterval`) in `EditorConfiguration.Performance` with Swift `Duration`. Update any call sites or tests that rely on `TimeInterval`.

### Deduplicate `removeFromSuperview` implementation

In `CodeEditorView.swift`, consolidate the platform-specific `removeFromSuperview` methods into a single override guarded by `#if canImport(AppKit)` where needed, eliminating duplicated code.

### Use `Task` for main-thread dispatch

Replace `DispatchQueue.main.async` usages in `CodeEditor+AppKit.swift`, `CodeEditor+UIKit.swift`, and `EditorEvent.swift` with `Task { @MainActor in … }` to align with Swift concurrency best practices.

### Restrict `annotationViews` visibility

Change `annotationViews` in `CodeEditorView.swift` from `internal` to `private` and adjust related code if necessary.

### Finalize `CodeEditorBaseCoordinator`

Make `CodeEditorBaseCoordinator` `final` unless external subclassing is required. Update derived classes accordingly.

### Add cross-platform context menu tests

Introduce UI tests validating that `ContextMenuCoordinator` builds appropriate menus on macOS and iOS. Check presence of key actions (e.g., "Go to Definition," "Replace All") using environment-specific test targets.

These refinements would improve API consistency, reduce exposed surface area, modernize concurrency usage, and enhance test coverage.
