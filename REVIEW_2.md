# REVIEW 2

# Code Review Summary

## 1. API Design & Ergonomics

**Misleading Builder Comment** - `EditorConfigurationBuilder.showLineNumbers(_:)` mentions a `gutterWidth(_:)` method that does not exist. This can confuse developers trying to adjust gutter width. Source: `EditorConfigurationBuilder.swift` lines 130‑137

**Verbose Catalyst Color Handling** - The Mac Catalyst text-color logic in `CodeEditor+Coordinators.swift` is lengthy and repeated in both setup and update paths. Consolidating this into a helper would simplify the coordinator and reduce duplication. Source: `CodeEditor+Coordinators.swift` lines 282‑328

## 2. Architecture & Scalability

**Unnecessary Task Creation in Combine Pipelines** - `ViewportManager.setupObservers()` spawns `Task { @MainActor … }` inside `sink` closures. Because the publishers already operate on the main run loop, this adds overhead and extra tasks. Source: `ViewportManager.swift` lines 64‑99

## 3. Testing & Reliability

**Minimap Feature Coverage** - The minimap view is configurable via `showMinimap(_:)` but only a handful of tests check the view's presence. Consider adding integration tests verifying minimap updates when scrolling or resizing. Source: `CodeEditor.swift` lines 496‑514

## 4. Documentation & Clarity

**Outdated Reference** - The comment referencing `gutterWidth(_:)` in `EditorConfigurationBuilder` should be removed or the method implemented. Source: same as first issue above.

## Suggested Task Stubs

- **Implement gutterWidth(\_:) in EditorConfigurationBuilder**
- **Extract Mac Catalyst color logic into helper**
- **Avoid spawning Tasks in ViewportManager observers**
- **Add integration tests for minimap behavior**

These focused updates will improve API clarity, reduce code duplication, and strengthen reliability.
