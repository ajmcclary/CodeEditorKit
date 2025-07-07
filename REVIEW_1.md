# REVIEW 1

# Code Review Summary

## API Design & Ergonomics

### 1. onTextChange modifier reinitializes view

**File:** `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift`

The modifier re-creates the CodeEditor view when a custom debounce interval is supplied:

```swift
public func onTextChange(
    debounce: Duration? = nil,
    perform action: @escaping (String) -> Void
) -> Self {
    var copy = self
    copy.onTextChange = action
    if let debounce {
        copy = Self(text: _text, debounceInterval: debounce)
        copy.onTextChange = action
    }
    return copy
}
```

Reinitializing may drop other modifier state or environment values.

**Suggestion:** Store onTextChange and debounceInterval as mutable properties and return copy without creating a new instance.

**Suggested task:** Avoid view recreation in `onTextChange`

### 2. Unimplemented iOS toolbar actions

**File:** `Sources/CodeEditorPlugin/Platform/CrossPlatformCoordinator+UIKit.swift`

The iOS accessory toolbar contains TODOs for undo, redo, and find buttons.

**Suggestion:** Either implement these actions or remove the placeholder comments to keep the API consistent.

**Suggested task:** Implement or remove iOS toolbar TODOs

### 3. Missing context menu actions on macOS

**File:** `Sources/CodeEditorPlugin/Platform/CrossPlatformCoordinator+AppKit.swift`

Mac-specific context menu items are placeholders.

**Suggestion:** Implement real actions (e.g., toggle comment, format selection) or omit them until ready.

**Suggested task:** Finalize macOS context menu actions

### 4. applyAnimatedTransitions empty implementation

**File:** `Sources/CodeEditorPlugin/Configuration/ConfigurationHotReload.swift`

The method meant to animate configuration changes is empty.

**Suggestion:** Provide actual animation logic or document that animations are currently unsupported.

**Suggested task:** Complete `applyAnimatedTransitions`

## Architecture & Scalability

### 5. Repeated language(\_:) mapping in builder

**File:** `Sources/CodeEditorPlugin/Configuration/EditorConfigurationBuilder.swift`

Adding a new language requires updating this large switch.

**Suggestion:** Refactor to use a data-driven mapping (dictionary of presets) so new languages can be added without editing the builder's source.

**Suggested task:** Refactor `language(_:)` switch to data-driven mapping

### 6. Platform capability duplication

**Files:** `PlatformImports.swift`, `PlatformColors.swift`, `CrossPlatformCoordinator.swift`

Several platform-specific values (fonts, colors, metrics) are duplicated across files.

**Suggestion:** Centralize platform constants to reduce redundancy and ensure consistency.

**Suggested task:** Centralize platform constants

## Code Quality & Best Practices

### 7. Performance monitor cleanup task

**File:** `Sources/CodeEditorPlugin/Performance/PerformanceMonitor.swift`

The periodic cleanup Task runs indefinitely until deinit cancels it. If PerformanceMonitor.shared persists for app lifetime, the task remains active even when monitoring is disabled.

**Suggestion:** Provide an explicit stopMonitoring() API to cancel the cleanup task when monitoring isn't needed.

**Suggested task:** Add explicit stop/start for `PerformanceMonitor` cleanup

### 8. Encoding of selectedLineHighlightColor

**File:** `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift`

selectedLineHighlightColor isn't encoded/decoded. Restoring a saved configuration loses this setting.

**Suggestion:** Include the color in CodingKeys using a cross-platform codable wrapper.

**Suggested task:** Persist `selectedLineHighlightColor` in configuration

### 9. Large switch statements for file extensions

**File:** `SyntaxHighlightingCoordinator.swift`

Language.fileExtensions uses extensive switches. This can be condensed into a static dictionary for maintainability.

**Suggested task:** Use dictionary for language file extensions

## Testing & Reliability

### 10. No tests for async hot-reload animations

Current test suite (e.g., Tests/CodeEditorPluginTests) lacks coverage for ConfigurationHotReload.

**Suggestion:** Add unit tests verifying history navigation, validation failures, and (once implemented) animation behavior.

**Suggested task:** Add `ConfigurationHotReload` tests

### 11. Limited performance tests for large files

The provided performance tests focus on core components but don't stress extremely large files or highlight asynchronous behavior.

**Suggested task:** Introduce large-file performance tests

## Documentation & Clarity

### 12. TODO comments in production code

Multiple TODOs remain in platform coordinator files (see items 2 and 3). They imply unfinished features.

**Suggestion:** Convert outstanding TODOs into tracked issues or remove them from source comments.

**Suggested task:** Track or remove TODO comments

### 13. DocC examples omit Mac Catalyst notes

Documentation such as GettingStarted.md highlights macOS and iOS but rarely mentions Catalyst-specific considerations.

**Suggested task:** Expand DocC with Catalyst integration notes

## Overall Assessment

The project demonstrates a well-structured, feature-based architecture with extensive documentation and testing. Refining the public API (particularly SwiftUI modifiers), finishing incomplete platform features, and adding targeted tests will further elevate the component's reliability and usability.
