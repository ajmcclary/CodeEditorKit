# Review 4

## Key Quality Issues

### Unsafe Force Unwraps in Caching Logic

- Several cache helpers force unwrap the oldest cache key, risking crashes with empty caches.
- Example: `LineNumberCalculationService`, `GutterSizingService`, `EditorLayoutService`, `CompletionViewModel`.

### Extension Files Missing the `+Extensions` Suffix

- Several extension files do not follow the required naming convention:
  - `Layout/CodeEditorContainerView+Configuration.swift`
  - `Layout/CodeEditorContainerView+Keyboard.swift`
  - `Layout/CodeEditorContainerView+Minimap.swift`
  - `Features/DebuggerIntegration+Evaluation.swift`
  - `Features/DebuggerIntegration+Execution.swift`
  - `Features/DebuggerIntegration+Breakpoints.swift`

### Unimplemented TODOs in Core View Models

- Outstanding TODOs in:
  - `GutterViewModel` (breakpoint/diagnostics integration, line selection)
  - `MinimapViewModel` (scroll position updates)
  - `CompletionViewModel` (integration with `LanguageProviderFactory`)

### Parameter Named `extension` in `LanguageRegistry`

- Using a keyword as a parameter (escaped with backticks) decreases readability:
  - `public func provider(forFileExtension extension: String) -> (any LanguageProvider)?`

### Platform-Specific Duplication in TextKit Bridge

- `enumerateLineFragmentsTextKit1` has nearly identical logic for AppKit and UIKit, differing only in API calls.

## Recommended Improvements

- Replace force unwraps in cache helpers with safe optional binding.
- Rename extension files to use the `+Extensions` suffix.
- Implement or track outstanding TODOs in view models.
- Rename parameters to avoid backtick keywords.
- Refactor `TextKitBridge.enumerateLineFragmentsTextKit1` for shared logic.
