# REVIEW 1

# Code Review

## API Design & Ergonomics

### Selected line highlight color is not configurable

The highlight color is a property of CodeEditorView but is not part of EditorConfiguration. This prevents configuring the highlight color via the configuration system or SwiftUI environment.

```swift
/// The color for highlighting the selected line
public var selectedLineHighlightColor = PlatformColors.selectedLineHighlight {
    didSet {
        updateSelectedLineHighlight()
    }
}
```

**Recommendation – Critical**

Expose selectedLineHighlightColor inside EditorConfiguration.Display so it can be adjusted through .with() or SwiftUI modifiers.

> **Suggested task**  
> Allow customizing line highlight color via configuration

### Builder language() method sets heuristics only

EditorConfigurationBuilder.language(\_:) tweaks configuration values but does not store the language anywhere, which may confuse users expecting the configuration to record the language.

```swift
@discardableResult
public func language(_ language: LanguageType) -> Self {
    switch language {
    case .swift:
        return enableSyntaxHighlighting(true)
            .enableCodeCompletion(true)
            .autoIndent(true)
            .tabWidth(4)
            .insertSpacesForTabs(true)
...
```

**Recommendation – Suggestion**

Rename the method to applyDefaults(for:) or document clearly that it only adjusts other fields. Alternatively, add an optional language property to EditorConfiguration and propagate it from the builder.

### Unimplemented coordinator actions

Several helper methods in CrossPlatformCoordinator only log messages.

```swift
internal func selectNextOccurrence(in _: CodeEditorView) {
    logger.debug("selectNextOccurrence not yet implemented")
}

internal func selectLine(in _: CodeEditorView) {
    logger.debug("selectLine not yet implemented")
}
...
```

**Recommendation – Suggestion**

Either implement these actions or remove the stubs to avoid confusion.

> **Suggested task**  
> Implement or remove placeholder actions

## Architecture & Scalability

### Mac Catalyst color workaround is complex

The method applyTextColorForMacCatalyst() applies color attributes to the entire text storage and forces layout invalidation.

```swift
textStorage.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: textStorage.length))
textStorage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: textStorage.length))
...
self.setNeedsDisplay()
self.setNeedsLayout()
layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textStorage.length))
```

This could be expensive on large documents.

**Recommendation – Suggestion**

Investigate a lighter‐weight approach, e.g. using a text view subclass with a fixed text color or applying attributes only on visible ranges.

> **Suggested task**  
> Optimize Mac Catalyst text color application

## Code Quality & Best Practices

### Logging proliferation

CodeEditorView and other classes create local Logger instances and output detailed debug messages. Excessive logging can hurt performance if left enabled.

**Recommendation – Suggestion**

Consider centralizing logging behind a feature flag or using os_log with appropriate log levels so debug statements can be disabled in release builds.

### EditorConfigurationBuilder is a class

EditorConfigurationBuilder is a final class. Since it only holds value-type data, a struct would provide value semantics and avoid unexpected reference sharing.

**Recommendation – Suggestion**

Convert the builder to a struct unless reference semantics are intentionally required.

> **Suggested task**  
> Change EditorConfigurationBuilder to a struct

## Testing & Reliability

### Missing tests for Mac Catalyst rendering

The Catalyst-specific text color method has no tests.

**Recommendation – Critical**

Add tests verifying that text color is correctly applied on Mac Catalyst and does not regress.

> **Suggested task**  
> Add Mac Catalyst text color tests

### Verify recommended configuration logic

PlatformCapabilities.recommendedConfiguration() dynamically adjusts options based on hardware characteristics.

Currently there are no tests ensuring these heuristics work as expected on different platforms.

**Recommendation – Suggestion**

Introduce unit tests that simulate various platform environments (e.g., low memory) to confirm that the recommended configuration adjusts appropriately.

## Documentation & Clarity

The DocC articles and AGENTS.md provide thorough guidance. However, consider documenting that EditorConfigurationBuilder.language(\_:) does not change the editor's language—only its related settings—to avoid confusion for integrators.

Overall the inline documentation is excellent.

---

By addressing the configuration gap for line highlight color, finalizing or removing stub methods, optimizing Catalyst behavior, and reinforcing tests, the component will become even more robust and intuitive.
