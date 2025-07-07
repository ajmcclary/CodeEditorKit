# REVIEW 2

# Code Review

## API Design & Ergonomics

### 1. Duplicate theme and language types in the builder

The `EditorConfigurationBuilder` defines its own `EditorTheme` and `LanguageType` enums instead of reusing `CodeEditorSwiftUITheme` and `Language`. This duplication may confuse users and requires additional conversions.

```swift
public enum EditorTheme {
    case light
    case dark
    case minimal
}

public enum LanguageType {
    case swift
    case python
    case javascript
    case markdown
    case plainText
}
```

**Recommendation:** Replace these enums with the existing `CodeEditorSwiftUITheme` and `Language` types so the builder aligns with the rest of the API.

**Suggested task:** Reuse existing theme and language enums in EditorConfigurationBuilder

### 2. Selected-line highlight color not part of configuration

`CodeEditorView` exposes `selectedLineHighlightColor` directly, separate from `EditorConfiguration` or the theme system:

```swift
public var selectedLineHighlightColor = PlatformColors.selectedLineHighlight {
    didSet {
        updateSelectedLineHighlight()
    }
}
```

**Recommendation:** Move this color into `EditorConfiguration.Display` (or `CodeEditorSwiftUITheme`) so the entire appearance is controlled through configuration and environment modifiers.

**Suggested task:** Add selected line highlight color to configuration/theme

### 3. Global logger constant

A global `kLogger` constant is defined outside of `CodeEditorView`:

```swift
internal let kLogger = Logger(subsystem: "com.codeeditor.plugin", category: "CodeEditorView")
```

**Recommendation:** Convert this to a static property within `CodeEditorView` to reduce global state and improve discoverability.

**Suggested task:** Make CodeEditorView logger a static property

### 4. Stubbed methods in CrossPlatformCoordinator

Several internal functions log "not yet implemented", which can mislead maintainers:

```swift
internal func selectNextOccurrence(in _: CodeEditorView) {
    logger.debug("selectNextOccurrence not yet implemented")
}
```

**Recommendation:** Either implement these actions or remove them from the codebase until ready.

**Suggested task:** Remove or implement CrossPlatformCoordinator stubs

### 5. Unstructured task for display-link throttling

`GutterView` launches an unstructured Task every frame to pause its display link:

```swift
Task { @MainActor [weak self] in
    try? await Task.sleep(nanoseconds: 500_000_000)
    if self?.lastContentOffset == scrollView.contentOffset {
        self?.displayLink?.isPaused = true
    }
}
```

Spawning a new task each time `displayLinkFired` runs may create many short-lived tasks.

**Recommendation:** Use a single throttling mechanism (e.g., Task stored property or a timer) instead of launching a new task on every callback.

**Suggested task:** Throttle GutterView display link without repeated Task creation

## Architecture & Scalability

### 6. Consolidate configuration application

`applyConfiguration()` in `CodeEditorView+Configuration.swift` manually updates many properties with repeated `#if` blocks. This makes the code harder to maintain.

**Recommendation:** Extract platform-specific settings into helper methods or use the platform abstraction layer for more concise code.

**Suggested task:** Refactor applyConfiguration for readability

## Code Quality & Best Practices

### 7. Avoid exposing partial implementations

Some features are referenced in documentation (e.g., "multiple cursors coming in v1.5") but stubbed in code. Ensure incomplete APIs remain internal until ready or include proper TODO markers.

### 8. Documentation for AI assistants

`CLAUDE.md`, `GEMINI.md`, and `AGENTS.md` are comprehensive and provide clear instructions. Consider adding links to key source files or a brief troubleshooting section for common build/test issues, but overall they are sufficient.

## Testing & Reliability

### 9. Increase coverage for platform abstractions

While tests cover many areas, there are few end-to-end checks verifying that `PlatformCapabilities.recommendedConfiguration()` returns sensible values for each platform.

**Recommendation:** Add tests that simulate different platform environments and assert that the recommended settings match expectations.

**Suggested task:** Add tests for recommendedConfiguration across platforms

### 10. Performance tests around syntax highlighting cancellation

`SyntaxHighlightingCoordinator` supports task cancellation, but there are no explicit tests that verify cancelled highlighting tasks don't update the UI.

**Suggested task:** Test syntax highlighting task cancellation

## Summary

The project demonstrates a strong foundation with modern Swift, cross-platform abstractions, and extensive documentation. Addressing the above items—especially unifying configuration types, cleaning up global state, and refining unfinished APIs—will further polish the component and simplify future maintenance. The testing suggestions will help ensure platform differences and async behaviors remain reliable.
