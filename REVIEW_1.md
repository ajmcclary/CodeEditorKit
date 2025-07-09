# REVIEW 1

# Code Review

## API Design & Ergonomics

### 1. Logging Overhead in Syntax Highlighting

**File:** `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlighting.swift`

Lines showing interpolation in debug logs:

```swift
62  internal func applySyntaxHighlighting() {
63      Self.logger.debug("🎨 applySyntaxHighlighting called - enabled: \(self.isSyntaxHighlightingEnabled), language: \(self.language.name)")
...
71      Self.logger.debug("✅ Scheduling syntax highlighting for language: \(self.language.name)")
```

The log strings interpolate values unconditionally, causing work even when logging is disabled.

**Suggestion:** Use the structured logging API to defer interpolation:

```swift
Self.logger.debug("applySyntaxHighlighting(enabled:\(self.isSyntaxHighlightingEnabled, privacy: .public), language:\(self.language.name, privacy: .public))")
```

**Suggested task:** Use structured logging to avoid interpolation overhead

### 2. Exposing Internal Views

**File:** `Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformSpecific.swift`

```swift
58  public var gutterView: GutterView? {
59      gutterViewStorage
60  }
```

`gutterView` exposes an internal implementation detail of `CodeEditorView`. This can limit future refactoring.

**Suggestion:** Consider restricting this to `internal` or providing a read‑only API that exposes only necessary information.

**Suggested task:** Restrict `gutterView` exposure

### 3. Builder Language Customization

The language helper dictionary in `EditorConfigurationBuilder.language()` is private. Developers extending the editor with custom languages must modify internal code.

Relevant section:

```swift
375    private static let languageSettings: [Language: LanguageSettings] = {
...
400    }()
...
408    public func language(_ language: Language) -> Self {
409      guard let settings = Self.languageSettings[language] else {
```

**Suggestion:** Expose a controlled way to register additional language presets (e.g., `registerLanguageSettings`).

**Suggested task:** Allow registration of custom language presets

### 4. Incomplete Validation Logic

`ConfigurationValidator` contains commented‑out cases for properties that no longer exist:

```swift
213  // Note: lineHeightMultiplier and fontName properties not available in current Display structure
214  // case ("display", "lineHeightMultiplier"):
215  //     ...
220  // case ("display", "fontName"):
221  //     ...
```

These comments may confuse contributors.

**Suggested task:** Clean up outdated validation cases

## Architecture & Scalability

### 5. Auto‑Scroll Feature Missing Tests

The new `autoScrollToCursor` option in `EditorConfiguration.Behavior` lacks test coverage.

**Suggested task:** Add tests for auto-scroll behavior

### 6. Performance Testing for Large Files

While large‑file optimization is mentioned, there is no explicit benchmark covering files near the `maxSyntaxHighlightingLength`.

**Suggested task:** Benchmark large-file highlighting

## Documentation & Clarity

### 7. MemoryMonitor Usage

`MemoryMonitor` is injectable but the documentation does not clearly show how to provide a custom instance.

**Suggested task:** Document MemoryMonitor injection

---

These targeted improvements should further refine the API surface, enhance scalability, and strengthen test coverage for `CodeEditorPlugin`.
