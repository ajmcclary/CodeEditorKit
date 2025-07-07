# REVIEW 2

# Code Review of CodeEditorPlugin

## 1. API Design & Ergonomics

### 1. Documentation References Undeclared APIs

`Documentation.docc/Advanced-Patterns.md` references methods `requestHoverSafe` and `requestCompletionSafe`, but the API surface only exposes `requestHover` and `requestCompletion`. File excerpt:

**Suggested task:** Remove or implement `requestHoverSafe`/`requestCompletionSafe`

### 2. Inconsistent Modifier Chaining in `CodeEditor`

Many modifiers (e.g., `.lineNumbers`, `.highlightSelectedLine`) return `some View`, while handlers like `.onTextChange` return `Self`. Mixing these patterns forces the caller to apply `.onTextChange` before any of the `some View` modifiers or lose access to further modifiers. Example methods:

**Suggested task:** Standardize return types for `CodeEditor` modifiers

### 3. Redundant Property Aliases in `CodeEditorView`

`CodeEditorView+Core.swift` exposes both `isSyntaxHighlightingEnabled` and `showsSyntaxHighlighting`, `highlightSelectedLine` and `showsSelectedLineHighlight`, etc., which increases the public API surface without clear benefit. Excerpt:

**Suggested task:** Trim duplicate convenience properties

## 2. Architecture & Scalability

### 1. `onTextChange` Reinitializes `CodeEditor`

The `onTextChange` modifier recreates the `CodeEditor` struct to change `textDebounceInterval`, potentially discarding earlier environment modifications. Code snippet:

**Suggested task:** Refactor `onTextChange` without reinitializing `CodeEditor`

### 2. Large `EditorConfiguration` File

`EditorConfiguration.swift` is ~760 lines and mixes data models, presets, validation, and application logic, making it difficult to navigate. Example section:

**Suggested task:** Split `EditorConfiguration` into focused files

## 3. Code Quality & Best Practices

### 1. Missing Safe Hover API

As noted earlier, the documentation suggests a safer hover API but none exists. This may confuse users. See task 1 above.

### 2. Potential Overexposure of Internal Types

Several platform helper enums (e.g., `PlatformAnimation.AnimationOptions`) are `public` even though the current code only uses them internally. Example:

**Suggested task:** Audit and reduce unnecessary public access

## 4. Testing & Reliability

### 1. No Tests for SwiftUI Modifiers

Existing tests cover many core features, but there are no tests verifying SwiftUI modifier behaviour (e.g., `.lineNumbers`, `.editable`).

**Suggested task:** Add SwiftUI modifier tests

## 5. Documentation & Clarity

### 1. Update Documentation for Removed Methods

Ensure DocC and README do not mention obsolete APIs such as `requestHoverSafe`. (See task 1.)

### 2. Add Contributor Notes on Architecture Split

While `AGENTS.md` covers repo guidelines, contributor documentation could explain the feature-based layout and platform abstraction more clearly.

**Suggested task:** Expand contributor docs

---

These changes will further streamline the API surface, clarify documentation, and improve maintainability without altering the overall design philosophy of the CodeEditorPlugin.
