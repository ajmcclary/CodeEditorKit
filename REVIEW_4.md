# REVIEW 4

# API Design & Ergonomics

## 1. Incomplete cancellation in `BackgroundProcessor`

`cancelPendingOperations()` only resets `pendingCount` and does not cancel active tasks, which can leave operations running unexpectedly. Lines 76‑80 show the issue:

```swift
/// Cancel any pending operations
func cancelPendingOperations() {
    // Reset pending count since we're cancelling all operations
    pendingCount = 0
}
```

**Recommendation:** Track active `Task` objects and call `cancel()` on them when cancelling.

_Suggested task: Ensure BackgroundProcessor cancels running tasks_

## 2. Deprecated singleton still exposed publicly

`CrossPlatformCoordinator` advertises a `shared` singleton, though it is deprecated. This remains part of the public API:

```swift
/// Shared instance for backward compatibility
/// - Warning: This property is deprecated. Use dependency injection instead.
@available(*, deprecated, message: "Use dependency injection instead of the singleton pattern")
public static let shared = CrossPlatformCoordinator()
```

**Recommendation:** Make this property `internal` or remove it entirely in the next major release to encourage dependency injection.

_Suggested task: Remove public access to CrossPlatformCoordinator.shared_

# Architecture & Scalability

## 1. Redundant platform-specific branches in configuration application

`EditorConfiguration.apply(to:)` repeats almost identical code for AppKit and UIKit (setting font, text color, and wrapping behavior). Lines 240‑255 contain duplicated logic:

```swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    view.font = PlatformFonts.monospacedSystemFont(ofSize: display.fontSize, weight: .regular)
    view.textColor = PlatformColors.label
    ...
#elseif canImport(UIKit)
    view.font = PlatformFonts.monospacedSystemFont(ofSize: display.fontSize, weight: .regular)
    view.textColor = PlatformColors.label
#endif
```

**Recommendation:** Move these shared assignments outside the conditional and keep only the truly platform‑specific parts, improving maintainability.

_Suggested task: Deduplicate font/color setup in apply(to:)_

# Code Quality & Best Practices

## 1. Potentially exposed implementation details

Many methods in `CodeEditorView+LineNumbers.swift` are `public` even though they are mostly implementation helpers (e.g., `updateGutterVisibility()`, `removeGutter()`). Example lines 14‑31:

```swift
public func updateGutterVisibility() {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if showsLineNumbers {
            createGutterIfNeeded()
        } else {
            removeGutter()
        }
    #else
        // On iOS, gutter is handled by the container view
    #endif
}
```

**Recommendation:** Audit which of these helpers need to be exposed. Consider marking them `internal` to reduce the public API surface.

_Suggested task: Limit visibility of line‑number helper methods_

# Testing & Reliability

## 1. No UI tests for SwiftUI integration

The test suite focuses on unit and performance tests but lacks SwiftUI-level UI tests. Adding such tests would catch regressions in view modifiers and environment behaviors.

_Suggested task: Add basic SwiftUI UI tests_

# Documentation & Clarity

## 1. Clarify custom language/plugin workflow

The docs mention a "plugin architecture (preview)" but do not show how to add a new language. Including a short guide would make the extension points clearer.

_Suggested task: Document custom language registration_

---

These targeted adjustments will further streamline the public API, harden concurrency handling, and expand testing and documentation for contributors.
