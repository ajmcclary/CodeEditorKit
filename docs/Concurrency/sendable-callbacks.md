# Thread-Safe Callbacks with @Sendable

`CodeEditor`'s SwiftUI callback modifiers accept `@Sendable` closures so they remain compatible with Swift 6 strict concurrency.

## Current Callback Surface

```swift
CodeEditor(text: $code)
    .onTextChange { @Sendable newText in
        // newText: String
    }
    .onSelectionChange { @Sendable selection in
        // selection: Range<String.Index>?
    }
```

`onTextChange` receives the complete current text. `onSelectionChange` receives a `String.Index` range when text is selected, or `nil` for an insertion point / no active selection. Internal AppKit/UIKit bridges still use `NSRange`, but the public SwiftUI callback is string-index based.

## Why @Sendable Matters

Swift 6 rejects captures that could create data races:

```swift
var counter = 0

CodeEditor(text: $text)
    .onTextChange { @Sendable _ in
        counter += 1 // Not safe to capture and mutate from a Sendable closure.
    }
```

Move mutable state behind an actor, or hop to the main actor for UI state:

```swift
actor ChangeCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}

let counter = ChangeCounter()

CodeEditor(text: $text)
    .onTextChange { @Sendable newText in
        Task {
            await counter.increment()
            await saveDraft(newText)
        }
    }
```

## Updating SwiftUI State

Use `Task { @MainActor in ... }` before touching view-model or UI state from a Sendable callback.

```swift
@MainActor
final class EditorViewModel: ObservableObject {
    @Published var wordCount = 0
    let analytics: AnalyticsActor

    init(analytics: AnalyticsActor) {
        self.analytics = analytics
    }

    func editor(text: Binding<String>) -> some View {
        CodeEditor(text: text)
            .onTextChange { @Sendable newText in
                Task { @MainActor in
                    self.wordCount = newText.split(separator: " ").count
                }

                Task {
                    await self.analytics.logTextChange(length: newText.count)
                }
            }
    }
}
```

## Selection Handling

Selection ranges are valid for the current bound string. Convert them immediately if you need selected text:

```swift
CodeEditor(text: $code)
    .onSelectionChange { @Sendable selection in
        Task { @MainActor in
            if selection != nil {
                statusText = "Selection active"
            } else {
                statusText = "No selection"
            }
        }
    }
```

## Debouncing Work

Store debounce tasks in a main-actor model rather than mutating `@State` directly inside the Sendable closure.

```swift
@MainActor
final class SearchModel: ObservableObject {
    private var task: Task<Void, Never>?

    func scheduleSearch(for query: String) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch(query)
        }
    }

    private func performSearch(_ query: String) async {
        // Search implementation.
    }
}

struct SearchBackedEditor: View {
    @State private var text = ""
    @StateObject private var search = SearchModel()

    var body: some View {
        CodeEditor(text: $text)
            .onTextChange { @Sendable newText in
                Task { @MainActor in
                    search.scheduleSearch(for: newText)
                }
            }
    }
}
```

## Combining Work

Capture Sendable dependencies, then fan out with tasks:

```swift
struct AdvancedEditor: View {
    @State private var text = ""
    let documentManager: DocumentManager
    let syntaxChecker: SyntaxChecker

    var body: some View {
        CodeEditor(text: $text)
            .onTextChange { @Sendable newText in
                Task {
                    async let save = documentManager.autoSave(newText)
                    async let check = syntaxChecker.validate(newText)

                    let (saveResult, checkResult) = await (save, check)

                    await MainActor.run {
                        handleResults(saveResult, checkResult)
                    }
                }
            }
    }
}
```

## Best Practices

1. Keep callback bodies small; start a `Task` for async or expensive work.
2. Capture immutable `Sendable` values, actors, or main-actor view models.
3. Hop to `@MainActor` before mutating SwiftUI-visible state.
4. Convert selection ranges immediately if later text changes could invalidate them.
5. Prefer framework debouncing (`CodeEditor(text:debounceInterval:)`) for text-change frequency, and app-level models for domain-specific debouncing.

## See Also

- [Swift 6 concurrency](swift6.md)
- [SwiftUI integration](../SwiftUI/integration.md)
- [Swift Concurrency documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- `CodeEditor/onTextChange(perform:)`
- `CodeEditor/onSelectionChange(perform:)`
