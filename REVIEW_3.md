# REVIEW 3

# Key Feedback

## 1. Async delay uses `TimeInterval`

`AsyncSyntaxHighlighter` stores its debounce interval as `TimeInterval` and accepts a `TimeInterval` in its initializer:

```swift
21      private let debounceInterval: TimeInterval
...
38      public init(memoryMonitor: MemoryMonitor, debounceInterval: TimeInterval = 0.3) {
```

Using `Duration` (available since Swift 5.7) would clarify time semantics and avoid conversion boilerplate.

**Suggested task:** Switch AsyncSyntaxHighlighter to use Duration

## 2. Debounce task cancellation

In `CodeEditorBaseCoordinator.handleTextChange`, the old debounce task is cancelled but not awaited:

```swift
90          // Cancel any existing debounce task
91          textUpdateTask?.cancel()
...
97          textUpdateTask = Task { [weak self] in
```

Cancelling without awaiting may leave work running. Use `cancel()` then `await` the task's completion.

**Suggested task:** Await textUpdateTask termination after cancellation

## 3. Configuration preset clarity

`EditorConfiguration.minimal` disables annotations and code folding, but `behavior.isEditable` remains true. For purely read‑only scenarios, developers might choose `readOnly` instead, yet the difference is subtle.

```swift
10    public static let minimal: EditorConfiguration = {
11        var config = EditorConfiguration()
12        config.display.showLineNumbers = false
13        config.display.enableSyntaxHighlighting = false
14        config.display.enableAnnotations = false
15        config.display.enableCodeFolding = false
16        config.display.showMinimap = false
17        config.behavior.enableCodeCompletion = false
18        return config
19    }()
```

Consider documenting that `minimal` is still editable while `readOnly` disables editing.

**Suggested task:** Clarify preset documentation for minimal vs. readOnly

## 4. Builder does not validate intermediate values

`EditorConfigurationBuilder` directly modifies fields without validation. A user may set invalid values (e.g., negative `tabWidth`) and only discover issues later.

```swift
public func tabWidth(_ width: Int) -> Self {
  with { $0.layout.tabWidth = width }
}
```

Injecting the `ConfigurationValidator` into the builder would catch mistakes earlier.

**Suggested task:** Integrate validation into EditorConfigurationBuilder

## 5. `CodeEditorTheme.swift` lacks doc comments for environment keys

Environment keys in `CodeEditorTheme.swift` provide important integration points, but they have minimal inline documentation:

```swift
@available(macOS 12.0, iOS 16.0, *)
public struct CodeEditorThemeKey: EnvironmentKey {
```

Adding brief explanations would help users understand these values when browsing generated documentation.

**Suggested task:** Document SwiftUI environment keys

## Testing

Codex couldn't run certain commands due to environment limitations. Consider configuring a setup script or internet access in your Codex environment to install dependencies.
