# REVIEW 3

# Code Review Summary

## 1. API Design & Ergonomics

### 1.1 Missing theme builder method

The documentation for `EditorConfigurationBuilder` suggests the existence of a `.theme()` modifier:

```swift
23  ///     .theme(.dark)
...
418  ///     .theme(.monokai)
```

However, no such method is implemented in `EditorConfigurationBuilder`. Developers following the documentation may look for a nonexistent API.

**Suggested task:** Add theme modifier to `EditorConfigurationBuilder`

### 1.2 TODO placeholders in public APIs

`CrossPlatformCoordinator+AppKit.swift` and `CrossPlatformCoordinator+UIKit.swift` contain multiple TODO comments for important functionality (e.g., keyboard shortcuts, undo/redo, toggle comment):

```swift
35              // TODO: Implement these keyboard shortcuts when needed
...
93          // TODO: Implement toggle comment functionality
...
107      // TODO: Implement these actions when needed
```

Similar TODOs appear in the iOS implementation:

```swift
44              // TODO: Implement undo/redo/find functionality
...
90              // TODO: Implement find functionality
...
153          // TODO: Implement these actions when needed
```

Leaving these TODOs in production code means essential features are either incomplete or misleading.

**Suggested task:** Handle or remove TODO placeholders in `CrossPlatformCoordinator`

## 2. Architecture & Scalability

### 2.1 Inconsistent configuration application

`EditorConfiguration.apply(to:)` sets `view.configuration = self` only when different, then re-applies some settings manually:

```swift
public func apply(to view: CodeEditorView) {
    if view.configuration != self {
        view.configuration = self   // triggers applyConfiguration()
    }
    ...
    view.font = PlatformFonts.monospacedSystemFont(ofSize: display.fontSize, weight: .regular)
}
```

Setting `view.configuration` already invokes `applyConfiguration`. The extra manual application could diverge from the internal logic if future changes occur.

**Suggested task:** Streamline `EditorConfiguration.apply(to:)`

### 2.2 Exposure of @unchecked Sendable types

Utilities such as `LRUCache` and `RangeProcessor` are marked `@unchecked Sendable` but also annotated `@MainActor`:

```swift
@MainActor
public final class LRUCache<Key: Hashable, Value>: @unchecked Sendable {
```

Using `@unchecked Sendable` while the entire type is `@MainActor` is redundant and may hide thread‑safety issues.

**Suggested task:** Review `@unchecked Sendable` usage

## 3. Code Quality & Best Practices

### 3.1 Large log output in annotation updates

`updateAnnotationView(for:)` emits many debug logs:

```swift
Self.logger.debug("updateAnnotationView called for annotation: \(annotation.id)")
Self.logger.debug("- annotation range: \(String(describing: annotation.range))")
...
```

Such verbose logging may clutter production logs.

**Suggested task:** Reduce verbose logging in annotation handling

### 3.2 Mismatch of property names

The `Display` struct in `EditorConfiguration` contains both `enableSyntaxHighlighting` and an alias `syntaxHighlighting`:

```swift
public var enableSyntaxHighlighting: Bool = true
public var syntaxHighlighting: Bool {
    get { enableSyntaxHighlighting }
    set { enableSyntaxHighlighting = newValue }
}
```

Having two names for the same setting may confuse API users.

**Suggested task:** Consolidate syntax highlighting property

## 4. Testing & Reliability

### 4.1 No tests for theme selection

While `EditorConfigurationBuilder` has extensive tests, none cover theme application because the builder lacks a theme modifier. When added, tests should verify that theme settings propagate to `CodeEditorView` and `CodeEditor` (SwiftUI).

**Suggested task:** Add theme-related tests

### 4.2 Concurrency stress tests

Actors such as `BackgroundProcessor` and `RangeProcessor` manage asynchronous work, but no tests exercise high‑contention scenarios.

**Suggested task:** Introduce concurrency stress tests

## 5. Documentation & Clarity

### 5.1 Keep documentation in sync with API

Several DocC articles and README snippets reference builder APIs (e.g., `.theme`) that aren't implemented. This may mislead users.

**Suggested task:** Synchronize documentation with actual API

### 5.2 Clarify AGENTS usage

The AGENTS documentation provides numerous guidelines. Ensure contributors understand that TODO markers in source files are discouraged in this production-ready codebase.

**Suggested task:** Add contribution note on TODO usage

## Additional Suggestions

- Consider providing a high-level architectural diagram in `Documentation.docc` to complement the textual explanation.
- Explore reducing the number of public members in internal utility classes to minimize API surface.
- Investigate whether `MainActor.assumeIsolated` calls in SwiftUI coordinators can be replaced with structured concurrency to improve maintainability.

These improvements should help refine the API surface, strengthen reliability, and keep documentation accurate and approachable.
