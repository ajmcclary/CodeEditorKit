# REVIEW 3

## Code Review

### API Design & Ergonomics

#### 1. `textChangeDebounceInterval` Not Utilized

- **Files:**
  - `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift` – debounce interval is only set via initializer
  - `Sources/CodeEditorPlugin/Configuration/EditorConfiguration+Performance.swift` – property declared but never used by `CodeEditor`

**Issue:**  
`EditorConfiguration.Performance` exposes `textChangeDebounceInterval`, yet `CodeEditor` ignores this value and only accepts a debounce interval in its initializer. This leads to inconsistent configuration behavior.

**Recommendation:**  
Leverage `configuration.performance.textChangeDebounceInterval` when setting up the SwiftUI coordinator. Add a builder method and a view modifier so the debounce interval can be changed without recreating the view.

**Suggested task:** Honor EditorConfiguration.textChangeDebounceInterval

---

#### 2. Lack of `deselectAll()` Convenience API

- **File:** `Sources/CodeEditorPlugin/Core/CodeEditorView+CodeEditorAPI.swift` – includes `selectAll()` but no counterpart for deselection

**Issue:**  
There is no public method to clear the current selection, forcing clients to manipulate `selectedRange` directly.

**Recommendation:**  
Provide a `deselectAll()` method in the same extension for symmetry.

**Suggested task:** Add deselectAll() to CodeEditorView

---

#### 3. Global `UnifiedEventSystem.shared`

- **File:** `Sources/CodeEditorPlugin/Core/UnifiedEventSystem.swift` – singleton instance used by `CodeEditorView`

**Issue:**  
Relying on a global singleton hampers testability and makes multiple editors share the same event bus unintentionally.

**Recommendation:**  
Allow dependency injection of `UnifiedEventSystem` through `EditorConfiguration` or SwiftUI environment, removing the implicit singleton.

**Suggested task:** Inject UnifiedEventSystem instead of singleton

---

### Architecture & Scalability

#### 4. Inconsistent Test Count in Documentation

- **Files:**
  - `README.md` mentions 532 tests
  - `AGENTS.md` lists 319 tests
  - `GEMINI.md` states 425 tests
  - `CLAUDE.md` references 532 tests

**Issue:**  
Different documents advertise conflicting numbers of tests, which may confuse contributors.

**Recommendation:**  
Determine the correct count (currently ~533 test methods) and update all documentation files consistently.

**Suggested task:** Normalize reported test counts

---

## Additional Suggestions

- The platform abstraction layer and builder pattern are well executed, but exposing the debounce interval via modifiers would further improve ergonomics.
- Consider adding UI/performance tests for features like the minimap and folding controls to increase confidence in cross‑platform behavior.

---

## Summary

Overall, the project demonstrates strong architecture, comprehensive documentation, and a rich API. Addressing the debounce interval handling, avoiding global singletons, providing complementary convenience APIs, and tidying documentation inconsistencies will make the component even more polished.
