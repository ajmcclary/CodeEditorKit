# REVIEW 3

# Code Review of CodeEditorPlugin

## API Design & Ergonomics

### Asynchronous cleanup in CodeEditorView.deinit

**File:** `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`  
**Lines showing Task creation in deinit:**

```swift
262      deinit {
...
267          var hasher = Hasher()
...
271              Task { @MainActor in
272                  MemoryMonitor.shared.unregisterCleanupHandler(identifier: identifier)
273              }
```

**Issue (Suggestion):** Starting a new Task while the instance is being deallocated may leave work unfinished if the task outlives the object. Consider removing the asynchronous call or moving this cleanup responsibility outside of deinit.

**Category:** Suggestion

### Duplicate Representable implementations

**Files:** `SwiftUI/CodeEditor+AppKit.swift` and `SwiftUI/CodeEditor+UIKit.swift`  
Both files implement nearly identical CodeEditorRepresentable structs with platform-specific types, e.g.:

```swift
struct CodeEditorRepresentable: NSViewRepresentable { ... }

struct CodeEditorRepresentable: UIViewRepresentable { ... }
```

**Issue (Suggestion):** Large portions of these implementations are the same. Consider creating a shared generic representable (e.g., `CodeEditorRepresentable<ViewType: PlatformView>`) and factor out the common logic to reduce duplication.

**Category:** Suggestion

### Theme method in EditorConfigurationBuilder

**File:** `Configuration/EditorConfigurationBuilder.swift`  
The `theme(_:)` method only toggles a couple of settings and does not apply theme colors:

```swift
public func theme(_ theme: CodeEditorSwiftUITheme) -> Self {
    var builder = self
    if theme.name == "dark" {
        builder = builder
          .highlightSelectedLine(true)
          .enableSyntaxHighlighting(true)
    } else if theme.name == "default" {
        builder = builder
          .highlightSelectedLine(true)
          .enableSyntaxHighlighting(true)
    }
    return builder
}
```

**Issue (Suggestion):** This function doesn't adjust colors or other presentation details. Exposing a way for callers to supply a full theme (e.g., text color, gutter color) would make the builder more useful.

**Category:** Suggestion

### Default focus behavior

**File:** `SwiftUI/CodeEditorTheme.swift`  
Environment key `CodeEditorBecomeFirstResponderKey` defaults to true:

```swift
public struct CodeEditorBecomeFirstResponderKey: EnvironmentKey {
    public static let defaultValue: Bool = true
}
```

**Issue (Question):** Automatically making every CodeEditor the first responder may surprise host apps. Should the default value be false with an explicit modifier to request focus?

**Category:** Question

### Verbose validation logic

**File:** `Configuration/EditorConfiguration.swift`  
`validate()` manually appends errors for each property:

```swift
if layout.tabWidth <= 0 {
    errors.append(ValidationError(field: "layout.tabWidth",
                                  value: layout.tabWidth,
                                  constraint: "must be greater than 0"))
}
```

**Issue (Suggestion):** Consider factoring common checks into helper methods or property wrappers to reduce repetition and make adding new validations easier.

**Category:** Suggestion

## Architecture & Scalability

### Complex switch in PlatformCapabilities.getFeatureAvailability

**File:** `Platform/PlatformCapabilities.swift`  
Starting at line 328, a large switch handles all feature cases:

```swift
public func getFeatureAvailability(_ feature: EditorFeature) -> FeatureAvailability {
    switch feature {
    // Features with partial support on some platforms
    case .findReplace:
        return currentPlatform == .macOS ? .full : .partial
    ...
    }
}
```

**Issue (Suggestion):** This lengthy switch is difficult to maintain. Breaking it into focused helper methods (e.g., `availabilityForInputFeatures`, `availabilityForUIFeatures`) would improve readability and make future additions simpler.

**Category:** Suggestion

### Platform-specific constants

**File:** `Platform/PlatformCapabilities.swift`  
In `recommendedConfiguration()` a hard-coded 4 GB check is used:

```swift
if ProcessInfo.processInfo.physicalMemory < 4 * 1_024 * 1_024 * 1_024 {
    config.performance.maxSyntaxHighlightingLength = 100_000
}
```

**Issue (Suggestion):** Adjusting performance based on a fixed 4 GB threshold may be outdated on modern hardware. Consider exposing memory thresholds as configuration constants or deriving them dynamically from PlatformConstants.

**Category:** Suggestion

## Code Quality & Best Practices

### Debounce logic in AsyncSyntaxHighlighter.scheduleHighlighting

**File:** `SyntaxHighlighting/AsyncSyntaxHighlighter.swift`

```swift
debounceTask = Task { [weak self] in
    do {
        guard let self else { return }
        try await Task.sleep(for: .seconds(self.debounceInterval))
        await MainActor.run { [weak self] in
            guard let self else { return }
            Task {
                await self.performHighlighting(for: textView, language: language, visibleRange: visibleRange)
            }
        }
    } catch {
        // Task was cancelled
    }
}
```

**Issue (Suggestion):** The nested Task inside `MainActor.run` starts another task that isn't captured or cancelled. Consider performing the highlighting directly after `await Task.sleep` to avoid extra task creation.

**Category:** Suggestion

### Heavy duplication in test observers

**File:** `SwiftUI/CodeEditor+Coordinators.swift`  
`setupTextChangeObservers(for:)` contains nearly identical blocks for AppKit and UIKit (lines 38‑70 & 72‑88).

**Issue (Suggestion):** Extract the common observer setup logic into a helper to avoid two large `#if` blocks.

**Category:** Suggestion

## Testing & Reliability

### Limited cross-platform UI tests

Existing tests (`Tests/CodeEditorPluginTests`) largely focus on unit behaviour. There are few integration or UI-level tests verifying SwiftUI modifiers or AppKit/UIKit interactions.

**Suggestion:** Add UI tests exercising:

- Focus management and environment propagation on each platform.
- Interaction with the configuration presets (e.g., ensuring `.minimal` actually disables annotations).
- Performance tests for large files across macOS, iOS, and Catalyst.

**Category:** Suggestion

## Documentation & Clarity

### Environment keys documented but discovery can be improved

`CodeEditorTheme.swift` documents environment keys, but they aren't linked from the DocC guides. New users might miss them.

**Suggestion:** Cross-reference these keys from the SwiftUI integration tutorial (`Documentation.docc/SwiftUI-Integration.md`) so developers know they exist.

**Category:** Suggestion

### AI assistant guides

The `CLAUDE.md` and `GEMINI.md` files provide a high-level overview and key commands. They successfully orient an assistant to the repository. No changes needed.

**Category:** Acknowledgment

---

Overall the project demonstrates strong architecture and extensive documentation. Addressing the points above—particularly simplifying platform-specific code and tightening asynchronous cleanup—would further refine this already solid component.
