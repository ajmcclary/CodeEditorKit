# REVIEW 4

# Code Review Summary

## API Design & Ergonomics

### 1. Make callback closures @Sendable

**Files:**

- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+Modifiers.swift`

`onTextChange` and `onSelectionChange` store closures that may cross actor boundaries. Marking these callbacks as `@Sendable` will prevent accidental data races when used from async contexts.

```swift
public func onTextChange(
    perform action: @escaping @Sendable (String) -> Void
) -> CodeEditor { ... }

public func onSelectionChange(
    perform action: @escaping @Sendable (Range<String.Index>?) -> Void
) -> CodeEditor { ... }
```

**Categorization:** Suggestion

**Suggested task:** Add @Sendable annotations to CodeEditor callbacks

### 2. Review necessity of open access level

**Files:**

- `Sources/CodeEditorPlugin/Completion/CompletionCellConfigurator.swift`
- `Sources/CodeEditorPlugin/Completion/CompletionViewControllerBase.swift`

Several classes are declared `open`, allowing external subclassing. If subclassing outside the package isn't required, change them to `public` to reduce API surface area.

**Categorization:** Suggestion

**Suggested task:** Reduce open access where subclassing isn't needed

### 3. Make builder modifiers chainable with better mutability

**File:** `Sources/CodeEditorPlugin/Configuration/EditorConfigurationBuilder.swift`

The builder currently copies `EditorConfiguration` on each call using a private `with` helper. Chaining many modifiers may allocate repeatedly. Consider storing the configuration as a mutable `var` and returning `Self` without extra copies. This will reduce temporary allocations and improve clarity.

**Categorization:** Suggestion

**Suggested task:** Streamline EditorConfigurationBuilder mutability

### 4. Provide typed convenience for theme/language configuration

Users set initial language and theme via optional parameters or environment. The API could expose initializers like:

```swift
public init(
    text: Binding<String>,
    configuration: EditorConfiguration = .default,
    language: Language = .plainText,
    theme: CodeEditorSwiftUITheme = .default,
    debounceInterval: Duration = .milliseconds(100)
)
```

This removes the `withLanguage` factory and offers a single entry point.

**Categorization:** Suggestion

**Suggested task:** Unify CodeEditor initializer parameters

## Architecture & Scalability

### 5. Isolate platform‐specific code paths

The platform layer mostly relies on `#if canImport`, but some files use repeated `targetEnvironment(macCatalyst)` checks. Consolidating these into helper functions inside `PlatformCapabilities` would reduce scattered compilation conditions.

**Categorization:** Suggestion

**Suggested task:** Centralize targetEnvironment checks

### 6. Split EditorConfigurationBuilder into feature-focused extensions

`EditorConfigurationBuilder.swift` exceeds 900 lines. Organize into multiple files by concern (Display, Layout, Behavior, Performance). This will improve maintainability.

**Categorization:** Suggestion

**Suggested task:** Refactor EditorConfigurationBuilder into extensions

## Code Quality & Best Practices

### 7. Minor naming improvements

`Language` contains a case `.c` and disables SwiftLint's `identifier_name`. Consider renaming to `.cLang` or `.cLanguage` for consistency and remove the lint suppression.

**File:** `SyntaxHighlightingCoordinator.swift`

**Categorization:** Suggestion

**Suggested task:** Rename Language.c to avoid lint suppression

### 8. Use @MainActor for public UI-affecting methods

Some methods in `CodeEditorView+Completion.swift` and `CodeEditorView+Configuration.swift` interact with UI but aren't explicitly `@MainActor`. Marking them clarifies caller expectations.

**Categorization:** Suggestion

**Suggested task:** Audit CodeEditorView public API for MainActor

### 9. Consider Set instead of array for event handlers

`EditorEventPublisher` holds handlers in a dictionary keyed by `ObjectIdentifier`. Using a `Set<ObjectIdentifier>` plus an array of weak references would simplify removal operations.

**File:** `Sources/CodeEditorPlugin/Core/EditorEvent.swift`

**Categorization:** Suggestion

**Suggested task:** Simplify EditorEventPublisher handler storage

## Testing & Reliability

### 10. Add integration tests covering preset configurations

While unit tests exist for configuration validation, there are no integration tests ensuring each preset correctly configures a `CodeEditorView`.

**Categorization:** Suggestion

**Suggested task:** Create integration tests for EditorConfiguration presets

## Documentation & Clarity

### 11. Document platform abstractions in DocC

The DocC folder references platform guides but doesn't show examples of converting existing code to the abstraction layer. Add a short article demonstrating typical `#if os()` code replaced with Platform utilities.

**Categorization:** Suggestion

**Suggested task:** Add DocC article on Platform abstraction usage

### 12. Clarify AI helper docs

`AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` are helpful but partly redundant. Cross-reference them to avoid divergence and briefly explain when each should be read.

**Categorization:** Suggestion

**Suggested task:** Cross-reference AI helper guides

---

These recommendations focus on tightening the public API, improving concurrency safety, and clarifying documentation while keeping the overall architecture intact. Implementing them should enhance the usability and maintainability of CodeEditorPlugin without altering its fundamental design.
