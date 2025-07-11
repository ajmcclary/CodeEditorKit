# REVIEW 2

## Code Review for CodeEditorPlugin

### API Design & Ergonomics

#### 1. AsyncSyntaxHighlighter cleanup visibility

The async highlighter relies on callers to invoke `cleanup()` before deallocation, but this isn’t obvious from the public API. Lines 13–45 define initialization and tasks, yet there’s no mention of cleanup in `deinit` or documentation aside from comments.

```swift
13  private let coordinator: SyntaxHighlightingCoordinator
...
42  setupPeriodicCacheOptimization()
44  registerCacheWithMemoryMonitor()
```

- **Suggestion**: Expose `cleanup()` in documentation and provide a convenience `deinit` that logs a warning if `cleanup()` was not called. This helps integrators avoid memory leaks.
  - Suggested task: Warn if AsyncSyntaxHighlighter.cleanup() was not called
  - Start task

#### 2. Configuration builder naming consistency

The SwiftUI modifier `.lineNumbers()` configures `display.showLineNumbers`. The counterpart API on `CodeEditorView` uses `isLineNumbersEnabled`. This mismatch can confuse users:

```swift
62  public func lineNumbers(_ visible: Bool = true) -> some View {
63      transformEnvironment(\.codeEditorConfiguration) { config in
64          config.display.showLineNumbers = visible
65      }
}
```

- **Suggestion**: Rename the underlying `EditorConfiguration.Display` property from `showLineNumbers` to `isLineNumbersEnabled` (with a deprecated alias) to match `CodeEditorView`. Update modifiers accordingly.
  - Suggested task: Rename display.showLineNumbers to isLineNumbersEnabled
  - Start task

#### 3. MemoryMonitor injection

`CodeEditorView` allows overriding `memoryMonitor`, but there is no public API to inject one during initialization except via convenience initializers. Exposing a designated initializer accepting a monitor would simplify dependency injection.

Relevant section:

```swift
186      internal var memoryMonitor = MemoryMonitor() {
187          didSet {
188              updateMemoryMonitorReferences()
189          }
190      }
```

- **Suggestion**: Add a public initializer `init(frame: CGRect, memoryMonitor: MemoryMonitor)` (and macOS equivalent) to let clients inject their own monitor directly.
  - Suggested task: Expose public initializer for custom MemoryMonitor
  - Start task

#### 4. Clarify recommendedConfiguration

`PlatformCapabilities.recommendedConfiguration()` simply delegates to `PlatformConfigurations.recommended()`, but users have no insight into what that returns or how to customize it.

```swift
166      public func recommendedConfiguration() -> EditorConfiguration {
167          PlatformConfigurations.recommended()
168      }
```

- **Suggestion**: Document in DocC what “recommended” entails, and consider exposing customization hooks (e.g., parameters for device class or performance profile) to make the API more transparent.
  - Suggested task: Document and parameterize recommendedConfiguration
  - Start task

### Architecture & Scalability

#### 1. Async highlighting task handling

`AsyncSyntaxHighlighter.scheduleHighlighting` cancels and recreates `Tasks` frequently. While debouncing helps, overlapping calls could still occur. Consider using actor state to track the currently highlighted range and avoid redundant work.

Lines controlling task creation:

```swift
56      debounceTask?.cancel()
...
60      debounceTask = Task { [weak self] in
...
```

- **Suggestion**: Maintain a `currentRequestID` in the actor and ignore duplicate requests for the same text + visible range.
  - Suggested task: Avoid redundant async highlight tasks
  - Start task

#### 2. Memory monitor updates across components

`CodeEditorView.updateMemoryMonitorReferences()` recreates several components whenever the monitor changes, which might cause heavy allocation if called often.

```swift
187      internal var memoryMonitor = MemoryMonitor() {
188          didSet {
189              updateMemoryMonitorReferences()
190          }
191      }
...
223      private func updateMemoryMonitorReferences() {
224          completionManager = CompletionManager(memoryMonitor: memoryMonitor)
225          asyncHighlighter = AsyncSyntaxHighlighter(memoryMonitor: memoryMonitor)
226          renderingOptimizer = TextKit2RenderingOptimizer(memoryMonitor: memoryMonitor)
227          lspManager = LSPManager(memoryMonitor: memoryMonitor)
228      }
```

- **Suggestion**: Consider only recreating components when the new monitor differs from the old one to avoid unnecessary re-instantiation.
  - Suggested task: Only recreate subsystems when memoryMonitor actually changes
  - Start task

### Code Quality & Best Practices

#### 1. Duplicate removal code for Mac Catalyst

`applyTextColorForMacCatalyst()` duplicates attribute removal logic each time it runs.

```swift
315          textStorage.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: textStorage.length))
316          textStorage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: textStorage.length))
```

- **Suggestion**: Extract a helper to clear color attributes and reuse it across methods to avoid code repetition.
  - Suggested task: Refactor color attribute clearing into helper method
  - Start task

#### 2. OptionSet documentation

`FindOptions` enumerates options but the `OptionSet` raw values are simple bit shifts. Documenting expected combinations or providing convenience constants would aid usability.

```swift
21  public struct FindOptions: OptionSet, Sendable {
...
46      public static let wrapAround = Self(rawValue: 1 << 3)
```

- **Suggestion**: Introduce compound options such as `.caseInsensitiveWholeWords` and document them in DocC.
  - Suggested task: Add compound FindOptions for common searches
  - Start task

### Testing & Reliability

#### 1. Integration tests for large-file handling

While there are extensive unit tests, there’s little evidence of end‑to‑end tests ensuring performance with large files (>500 KB).

- **Suggestion**: Create a new suite that loads large sample files, performs basic editing, and measures highlighting latency.
  - Suggested task: Add integration tests for large file performance
  - Start task

#### 2. UI tests around SwiftUI modifiers

SwiftUI modifiers like `.becomeFirstResponder()` rely on environment keys. There are basic SwiftUI tests, but focusing on these modifiers would help catch regressions.

- **Suggestion**: Expand `SwiftUITests` with UI-level tests verifying that focus and configuration modifiers behave correctly on each platform.
  - Suggested task: Extend SwiftUITests for modifier behavior
  - Start task

### Documentation & Clarity

#### 1. Highlight cleanup requirements in DocC

The documentation for `AsyncSyntaxHighlighter` does not explicitly state that `cleanup()` must be called.

- **Suggestion**: Update the `Syntax-Highlighting.md` DocC article to mention this lifecycle requirement and include example code.
  - Suggested task: Document AsyncSyntaxHighlighter cleanup requirement
  - Start task

#### 2. AI assistant guides

`CLAUDE.md`, `GEMINI.md`, and `AGENTS.md` give a good overview but lack a troubleshooting section for common build failures (e.g., missing SwiftSyntax version). Adding that would make onboarding smoother.

- Suggested task: Add troubleshooting section to AI assistant guides
- Start task

---

These improvements target API clarity, architectural robustness, code quality, and documentation. Implementing them will further polish the CodeEditorPlugin for external developers and maintainers.
