# Unified Event System

Use `UnifiedEventSystem` when host applications need a shared, injectable event stream across one or more editors.

## Overview

`UnifiedEventSystem` is a `@MainActor` `ObservableObject` that publishes the framework's `EditorEvent` enum through Combine. It is intentionally dependency-injected: create an instance where your app owns editor coordination, then pass it through `EditorConfiguration.eventSystem` or SwiftUI's `.eventSystem(_:)` modifier.

The current event model is closed over the built-in `EditorEvent` cases. Custom event types are not added by conforming to `EditorEvent`; instead, app-specific events should live in the host app's own publisher or wrapper.

## Event Cases

`EditorEvent` currently includes:

- `textDidChange(String)`
- `textWillChange(range: NSRange, replacement: String)`
- `textSelectionDidChange(NSRange)`
- `didBecomeFirstResponder`
- `didResignFirstResponder`
- `completionRequested(context: CompletionContext)`
- `completionItemSelected(any CompletionItemView)`
- `annotationHovered(annotationId: String)`
- `annotationClicked(annotationId: String)`
- `performanceWarning(message: String)`
- `error(Error)`

Typed extraction helpers exist for text events:

- `TextDidChangeEvent`
- `TextSelectionDidChangeEvent`

## Creating and Injecting

```swift
let eventSystem = UnifiedEventSystem()

var configuration = EditorConfiguration()
configuration.eventSystem = eventSystem

let editor = CodeEditorView()
configuration.apply(to: editor)
```

SwiftUI:

```swift
struct EventBackedEditor: View {
    @State private var code = ""
    @State private var eventSystem = UnifiedEventSystem()

    var body: some View {
        CodeEditor(text: $code)
            .eventSystem(eventSystem)
    }
}
```

## Publishing Events

```swift
eventSystem.publish(.textDidChange(source))
eventSystem.publish(.textSelectionDidChange(NSRange(location: 12, length: 0)))
eventSystem.publish(.performanceWarning(message: "Highlighting exceeded budget"))
```

Use `publishBatch(_:)` when a component has already accumulated multiple events:

```swift
eventSystem.publishBatch([
    .textWillChange(range: changedRange, replacement: replacement),
    .textDidChange(updatedText)
])
```

## Subscribing with Combine

`subscribe(to:handler:)` filters the enum stream through an `EditorEventType` extractor and returns `AnyCancellable`.

```swift
final class EditorObserver {
    private var cancellables: Set<AnyCancellable> = []

    @MainActor
    func attach(to eventSystem: UnifiedEventSystem) {
        eventSystem.subscribe(to: TextDidChangeEvent.self) { event in
            // `event.text` is the complete current editor text.
            self.handleTextChange(event.text)
        }
        .store(in: &cancellables)

        eventSystem.subscribe(to: TextSelectionDidChangeEvent.self) { event in
            self.handleSelection(event.range)
        }
        .store(in: &cancellables)
    }

    private func handleTextChange(_ text: String) {}
    private func handleSelection(_ range: NSRange) {}
}
```

You can also subscribe to the raw stream:

```swift
eventSystem.events
    .sink { event in
        switch event {
        case .error(let error):
            CrossPlatformLogger.logger().error("Editor error: \(error)")
        default:
            break
        }
    }
    .store(in: &cancellables)
```

## Registered Handlers

For handler objects, use `EventHandler` and keep the returned `EventHandlerToken` alive. Releasing the token unregisters the handler.

```swift
struct ErrorHandler: EventHandler {
    func canHandle(_ event: EditorEvent) -> Bool {
        if case .error = event { return true }
        return false
    }

    func handle(_ event: EditorEvent) {
        guard case .error(let error) = event else { return }
        CrossPlatformLogger.logger().error("Editor error: \(error)")
    }
}

let token = eventSystem.registerHandler(ErrorHandler())
```

Manual unregistering is also available:

```swift
token.unregister()
```

## Filtering and Throttling

Filters can drop events before they reach subscribers and handlers:

```swift
struct ErrorOnlyFilter: EventFilter {
    func shouldAllow(_ event: EditorEvent) -> Bool {
        if case .error = event { return true }
        return false
    }
}

eventSystem.addFilter(ErrorOnlyFilter())
```

`clearFilters()` restores the built-in platform and performance filters. To adjust the high-frequency throttling filter:

```swift
eventSystem.configureThrottling(maxEventsPerSecond: 30)
```

## Event History and Metrics

`UnifiedEventSystem` keeps a fixed-size recent history for debugging.

```swift
let recentEvents = eventSystem.getRecentEvents(count: 20)
let textEvents = eventSystem.getEvents(ofType: TextDidChangeEvent.self, limit: 10)
let metrics = eventSystem.getMetrics()

eventSystem.clearHistory()
```

## SwiftUI Event Log

```swift
struct EventLogEditor: View {
    @State private var code = ""
    @State private var eventSystem = UnifiedEventSystem()
    @State private var cancellable: AnyCancellable?
    @State private var eventLog: [String] = []

    var body: some View {
        VStack {
            CodeEditor(text: $code)
                .eventSystem(eventSystem)
                .onAppear(perform: attachLogger)

            List(eventLog, id: \.self) { entry in
                Text(entry).font(.caption)
            }
            .frame(height: 120)
        }
    }

    private func attachLogger() {
        guard cancellable == nil else { return }
        cancellable = eventSystem.subscribe(to: TextDidChangeEvent.self) { event in
            eventLog.append("Text length: \(event.text.count)")
            if eventLog.count > 50 {
                eventLog.removeFirst()
            }
        }
    }
}
```

## Best Practices

1. **Inject explicitly**: create event systems at app or document scope rather than relying on global state.
2. **Store cancellables**: Combine subscriptions end when the returned `AnyCancellable` is released.
3. **Keep handlers cheap**: publish happens on the main actor; dispatch expensive work to a task or background actor.
4. **Use filters sparingly**: filters affect all downstream subscribers for that `UnifiedEventSystem` instance.
5. **Use app publishers for app events**: the framework event enum is not an extension point for arbitrary host-app events.

## Testing

```swift
@MainActor
func testTextChangeEventHandling() {
    let eventSystem = UnifiedEventSystem()
    var receivedText: String?

    let cancellable = eventSystem.subscribe(to: TextDidChangeEvent.self) { event in
        receivedText = event.text
    }

    eventSystem.publish(.textDidChange("Hello"))

    XCTAssertEqual(receivedText, "Hello")
    _ = cancellable
}
```

## See Also

- [Configuration system](../Configuration/system.md)
- [Memory monitor](../Performance/memory-monitor.md)
- [Swift 6 concurrency](swift6.md)
- `UnifiedEventSystem`
- `EditorEvent`
