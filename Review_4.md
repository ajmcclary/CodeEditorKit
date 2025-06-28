# Review 4

# Cross-Platform Compatibility (AppKit/UIKit)

## Duplicate Line Range Computation in GutterView

**File:** `Sources/CodeEditorPlugin/Layout/GutterView+AppKit.swift`
**File:** `Sources/CodeEditorPlugin/Layout/GutterView+UIKit.swift`

Both platform‑specific files contain the same `getLineRanges(for:in:)` helper. Duplicating logic increases maintenance cost.

```swift
private func getLineRanges(for text: String, in range: NSRange) -> [(Int, NSRange)] {
    var lineRanges: [(Int, NSRange)] = []
    var lineNumber = 1
    var currentIndex = text.startIndex
    …
    return lineRanges
}
```

**Suggestion:** Move this function into `GutterView.swift` (or a shared extension) and call it from both implementations.

**Suggested task:** Unify line range calculation

---

## Unused Orientation Handler

**File:** `Sources/CodeEditorPlugin/Platform/CrossPlatformCoordinator.swift`

`orientationDidChange()` is registered for notifications but contains only a comment.

```swift
@objc private func orientationDidChange() {
    // Adjust UI for new orientation
}
```

**Suggestion:** Implement necessary layout updates or remove the observer to avoid unnecessary work.

**Suggested task:** Implement or remove empty orientation handler

---

## Memory Leak from Notification Tokens

**File:** `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView.swift` – observers are stored but never removed.

Creation of observers:
```swift
let willHide = NotificationCenter.default.addObserver(…)
…
keyboardObservers = [willShow, willHide]
```

`deinit` lacks cleanup:
```swift
deinit {
    // Observers are automatically removed when deallocated
}
```

Block-based observers must be removed manually; otherwise they persist after deinit.

**Suggestion:** Remove observers in `deinit`.

**Suggested task:** Remove keyboard observers on deinit

---

## ContextMenuAction Initializer

**File:** `Sources/CodeEditorPlugin/Platform/ContextMenuAction.swift`

The `.separator` factory creates an instance and calls an internal `withSeparator()` helper, which then creates yet another instance.

```swift
public static var separator: Self {
    Self(
        title: "",
        keyEquivalent: nil,
        isEnabled: false
    ) {}.withSeparator()
}
```

This double initialization is unnecessary.

**Suggestion:** Provide a dedicated private initializer for separators.

**Suggested task:** Simplify ContextMenuAction.separator

---

# SwiftUI Integration

## Debounced Text Update in `CodeEditor`

`CodeEditor` debounces external text updates using `.task(id:)`. The logic relies on `isUpdatingText` to avoid recursion, which is correct. No major issues were observed.

## Coordinator Memory Management

In `CodeEditorSwiftUIView` (iOS branch) the tap gesture added to the editor references the coordinator strongly. This is released when the coordinator is deallocated, so no leak is present. Implementation appears idiomatic.

---

# Architecture and API Design

## Observer Cleanup in Builder Pattern

The `EditorConfigurationBuilder` exposes many modifiers but lacks methods for all configuration properties (e.g., some `Behavior` options). Expanding its API would provide a more complete builder.

**Suggested task:** Extend EditorConfigurationBuilder

---

# Code Quality and Performance

## NotificationCenter Observer Removal

As noted above, `CodeEditorContainerView` retains keyboard observers. Removing them prevents leaks and unintended callbacks.

## Combine Integration TODOs

`EditorEventPublisher` contains commented Combine support with several TODOs. If Combine support is planned, these sections should either be completed or removed to reduce confusion.

**Suggested task:** Finalize or drop Combine publisher

---

# Sample Application Practices

`CodeEditorSample` demonstrates using the plugin but still relies on platform-specific wrappers (e.g., `CodeEditorViewWrapper`) that duplicate initialization logic. Consider using the modern SwiftUI `CodeEditor` view directly to show best practice.

**Suggested task:** Simplify sample to use `CodeEditor`

---

These changes would improve maintainability, prevent leaks, and keep platform abstractions consistent across the project.