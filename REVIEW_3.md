# REVIEW 3

# Code Review

## 1. API Design & Ergonomics

### 1.1 `CodeEditor` initializer is overly minimal

The SwiftUI wrapper only exposes an initializer that accepts text binding and a debounce interval:

```swift
public init(
    text: Binding<String>,
    debounceInterval: Duration = .milliseconds(100)
)
```

There is no convenience initializer for common parameters such as language or theme. Developers must always chain modifiers or environment values, which adds boilerplate.

#### Recommendation

Provide additional initializers, e.g.:

```swift
public init(
    text: Binding<String>,
    language: Language,
    theme: CodeEditorSwiftUITheme = .default,
    debounceInterval: Duration = .milliseconds(100)
)
```

This would simplify basic usage, especially in sample code.

> **Task:** Add convenience initializers for CodeEditor
>
> Create additional initializers in `SwiftUI/CodeEditor.swift` that accept common parameters such as `language` and `theme`. Ensure existing modifier-based configuration still works. Update documentation and tests to cover the new initializers.

### 1.2 Redundant public entry point

`CodeEditorPluginModule.initialize()` is public but empty:

```swift
public enum CodeEditorPluginModule {
    /// Initialize the CodeEditorPlugin module with default configuration
    public static func initialize() {
        // Perform any necessary module initialization
        // This could include registering default themes, languages, etc.
    }
}
```

Exposing this function suggests additional setup is required, yet it currently does nothing.

#### Recommendation

Either implement real initialization tasks (register themes, preload languages) or remove the method to avoid confusion.

> **Task:** Clarify or remove CodeEditorPluginModule.initialize
>
> Decide whether module initialization is necessary. _If needed_: implement actions like registering default themes and call it from documentation. _If not needed_: delete `CodeEditorPluginModule.initialize()` and update docs to remove any references.

### 1.3 `EditorConfiguration.with()` methods lack documentation

`EditorConfiguration` uses a copy builder approach:

```swift
public func with(layout: Layout) -> Self { ... }
public func with(display: Display) -> Self { ... }
```

However, the documentation does not clarify that these return a new struct (immutability) and do not mutate the original instance.

#### Recommendation

Document the semantics ("returns a new configuration with the given changes") and include examples showing chaining.

> **Task:** Improve documentation for EditorConfiguration.with()
>
> Extend doc comments in `EditorConfiguration.swift` to describe that each `with` method returns a new configuration instance. Provide a short example demonstrating chaining and immutability. Update DocC if needed.

### 1.4 Builder preset coverage

`EditorConfigurationBuilder` offers quick presets (`swift()`, `web()`, etc.), but there is no preset for cross-platform preview or large-file editing. Consider adding more presets for common scenarios, such as read‑only large file viewing.

> **Task:** Add additional presets to EditorConfigurationBuilder
>
> Introduce new builder convenience methods—e.g., `.largeFileViewer()`—in `EditorConfigurationBuilder.swift`. Configure them with disabled highlighting and readonly behavior. Add unit tests validating these presets.

## 2. Architecture & Scalability

### 2.1 Empty cleanup in `CodeEditorView`

`removeFromSuperview()` unregisters the memory monitor but there is no call to remove other observers or cancel tasks. Deinitialization comments mention that cleanup was moved here, but there may still be lingering asynchronous tasks.

```swift
override public func removeFromSuperview() {
    // Perform cleanup before removing from superview
    unregisterFromMemoryMonitor()
    super.removeFromSuperview()
}
```

#### Recommendation

Audit all async tasks (syntax highlighter, LSP manager) and ensure they are cancelled here. Document the lifecycle expectations.

> **Task:** Ensure async cleanup in CodeEditorView.removeFromSuperview
>
> Review tasks started by `CodeEditorView` (syntax highlighter, LSP manager, etc.). Cancel or invalidate them in `removeFromSuperview()` to avoid work after the view disappears. Add unit tests verifying that no tasks remain active after removal.

### 2.2 Large `CoordinateSystemHelper`

`CoordinateSystemHelper` contains over 500 lines and mixes geometry helpers, drawing, and event translation. Splitting it into focused types (e.g., `CoordinateConverter`, `DrawingContext`) would improve maintainability.

> **Task:** Refactor CoordinateSystemHelper into smaller types
>
> Break `CoordinateSystemHelper.swift` into separate files:
>
> - `CoordinateConverter` for coordinate conversions
> - `LayoutMetricsCalculator` for layout calculations
> - `DrawingContext` (already present) in its own file
>
> Update imports and adjust tests accordingly.

### 2.3 `PlatformCapabilities` recommended configuration

`PlatformCapabilities.recommendedConfiguration()` adjusts font sizes and gutter widths but does not expose hooks for customization:

```swift
switch currentPlatform {
case .iOS:
    config.display.fontSize = 16.0
    config.layout.gutterWidth = 50.0
```

Allowing clients to supply their own strategy would make this more flexible.

> **Task:** Allow customization of recommended configuration
>
> Add a closure property or protocol to `PlatformCapabilities` for customizing the recommended `EditorConfiguration`. Provide default behavior matching the current implementation. Document how clients can override it.

## 3. Code Quality & Best Practices

### 3.1 Explicit numeric literals

Several constants (e.g., `EditorConfiguration.validate()` line limits) use "magic numbers," such as `fontSize > 100` or `tabWidth > 32`. Replacing these with named constants in `PlatformConstants` would centralize constraints.

> **Task:** Replace magic numbers with named constants
>
> Create constants in `PlatformConstants.swift` for validation thresholds (max font size, max tab width, etc.). Use these constants in `EditorConfiguration.validate()` and related tests.

### 3.2 Unused imports and commented sections

Files like `Platform/module.swift` contain commented-out code and minimal content:

```swift
// This file previously imported separate package modules...
```

Consider removing this file or expanding it with meaningful exports.

> **Task:** Clean up Platform/module.swift
>
> Remove stale comments and either delete `Platform/module.swift` or document its purpose (e.g., re-exporting modules). Ensure no build warnings remain.

### 3.3 Missing Sendable annotations

Actors like `SyntaxHighlightingCoordinator` hold non‑`Sendable` properties (`PerformanceMonitor.shared`) without `@preconcurrency` annotations. Explicitly documenting thread-safety or marking them `nonisolated` would clarify concurrency guarantees.

> **Task:** Audit Sendable compliance in actors
>
> Review actor properties across `SyntaxHighlighting/` and `Utilities/`. Annotate shared singletons with `@preconcurrency` or mark members `nonisolated` where appropriate. Update concurrency tests to cover these cases.

## 4. Testing & Reliability

### 4.1 Integration tests for SwiftUI wrapper

Most tests cover lower-level functionality. There is limited coverage of the SwiftUI `CodeEditor` view, especially for modifier chains and environment interactions.

> **Task:** Add SwiftUI integration tests
>
> Create UI tests (using `XCTest` + `ViewInspector` or similar) that instantiate `CodeEditor` with various modifiers. Verify that configuration and language changes propagate correctly to the underlying `CodeEditorView`. Include cross-platform targets.

### 4.2 Stress tests for syntax highlighting cache

`SmartTokenCache` implements advanced eviction logic, but there are no dedicated stress tests to verify cache behavior under heavy load.

> **Task:** Create stress tests for SmartTokenCache
>
> Add tests that rapidly highlight large files, exceed cache limits, and check eviction statistics. Validate memory usage via `TokenCacheStatistics`.

### 4.3 Performance benchmarks for rendering

The repository references performance monitoring but does not include targeted benchmarks for rendering or large file scrolling.

> **Task:** Introduce performance benchmarks for large file rendering
>
> Use `XCTest`'s performance testing APIs to measure scrolling and highlighting times with files ~500 KB. Assert that rendering stays below predefined thresholds.

## 5. Documentation & Clarity

### 5.1 Explain immutability and presets in DocC

While `EditorConfiguration` presets exist, the documentation could better show how to extend presets with `with()` or the builder.

> **Task:** Enhance configuration documentation
>
> Update `Documentation.docc/Configuration-System.md` and `Configuration-Presets.md` with examples of extending presets via `with()` and the builder. Include a table of all presets and their differences.

### 5.2 Clarify AI assistant guidelines

`CLAUDE.md`, `GEMINI.md`, and `AGENTS.md` provide helpful context, but they lack a short "getting started for AIs" section summarizing the main workflow commands and directory layout.

> **Task:** Add quick-start section for AI assistants
>
> Add a concise section to the existing guideline files summarizing:
>
> - primary build/test commands
> - where to find key targets (Core/, SwiftUI/, Tests/)
> - how to regenerate DocC documentation
>
> This will help future AI tools work more effectively.

---

By addressing these areas, the project can further improve its API ergonomics, maintainability, concurrency safety, and overall developer experience.
