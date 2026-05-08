# Thread-Safe Callbacks with @Sendable

Learn how to use @Sendable callbacks in CodeEditorPlugin for guaranteed thread safety with Swift 6 concurrency.

## Overview

All callbacks in CodeEditorPlugin are now marked with `@Sendable`, ensuring they can be safely called across actor boundaries. This enhancement provides compile-time guarantees of thread safety and full compatibility with Swift 6's strict concurrency checking.

## Why @Sendable Matters

In Swift 6, the compiler enforces strict concurrency checking to prevent data races. The `@Sendable` attribute indicates that a closure can be safely passed across concurrency domains without risk of data races.

```swift
// Without @Sendable - potential data race
var counter = 0
CodeEditor(text: $text)
    .onTextChange { newText in
        counter += 1  // ❌ Data race - counter accessed from different contexts
    }

// With @Sendable - compiler enforces safety
CodeEditor(text: $text)
    .onTextChange { @Sendable newText in
        // ✅ Compiler ensures only Sendable data is captured
        print("Text changed to: \(newText.count) characters")
    }
```

## Basic Usage

### Text Change Callbacks

Monitor text changes with thread-safe callbacks:

```swift
import SwiftUI
import CodeEditorPlugin

struct EditorView: View {
    @State private var code = ""
    @State private var lastSaved = Date()
    
    var body: some View {
        CodeEditor(text: $code)
            .onTextChange { @Sendable newText in
                // This closure is guaranteed thread-safe
                Task {
                    await autoSave(newText)
                }
            }
    }
    
    @MainActor
    func autoSave(_ text: String) async {
        // Save logic here
        lastSaved = Date()
    }
}
```

### Selection Change Callbacks

Handle selection changes safely:

```swift
CodeEditor(text: $code)
    .onSelectionChange { @Sendable range in
        // Thread-safe selection handling
        Task { @MainActor in
            updateStatusBar(with: range)
        }
    }
    
@MainActor
func updateStatusBar(with range: NSRange) {
    // Update UI with selection info
    statusText = "Line: \(getLineNumber(for: range.location))"
}
```

## Advanced Patterns

### Capturing State Safely

When you need to capture state in callbacks, ensure it's Sendable:

```swift
struct EditorConfiguration: Sendable {
    let autoSaveInterval: TimeInterval
    let syntaxHighlighting: Bool
}

struct ConfigurableEditor: View {
    let config: EditorConfiguration  // Sendable type
    @State private var text = ""
    
    var body: some View {
        CodeEditor(text: $text)
            .onTextChange { @Sendable newText in
                // Safe to capture 'config' because it's Sendable
                if config.autoSaveInterval > 0 {
                    Task {
                        try await Task.sleep(for: .seconds(config.autoSaveInterval))
                        await save(newText)
                    }
                }
            }
    }
}
```

### Actor Integration

Integrate callbacks with custom actors:

```swift
@MainActor
final class EditorViewModel: ObservableObject {
    @Published var text = ""
    @Published var wordCount = 0
    
    private let analytics: AnalyticsActor
    
    init(analytics: AnalyticsActor) {
        self.analytics = analytics
    }
    
    var editorView: some View {
        CodeEditor(text: $text)
            .onTextChange { @Sendable newText in
                // Update word count on MainActor
                Task { @MainActor in
                    self.wordCount = newText.split(separator: " ").count
                }
                
                // Send analytics on background actor
                Task {
                    await self.analytics.logTextChange(length: newText.count)
                }
            }
    }
}

actor AnalyticsActor {
    func logTextChange(length: Int) {
        // Thread-safe analytics logging
    }
}
```

## Error Handling in Callbacks

Handle errors safely in async contexts:

```swift
struct SafeEditor: View {
    @State private var text = ""
    @State private var lastError: String?
    
    var body: some View {
        VStack {
            if let error = lastError {
                Text(error)
                    .foregroundColor(.red)
            }
            
            CodeEditor(text: $text)
                .onTextChange { @Sendable newText in
                    Task { @MainActor in
                        do {
                            try await validateSyntax(newText)
                            lastError = nil
                        } catch {
                            lastError = error.localizedDescription
                        }
                    }
                }
        }
    }
    
    func validateSyntax(_ text: String) async throws {
        // Validation logic that might throw
    }
}
```

## Debouncing with @Sendable

Implement debounced callbacks while maintaining thread safety:

```swift
final class DebouncedEditor: View {
    @State private var text = ""
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        CodeEditor(text: $text)
            .onTextChange { @Sendable newText in
                // Cancel previous search
                searchTask?.cancel()
                
                // Start new debounced search
                searchTask = Task {
                    do {
                        try await Task.sleep(for: .milliseconds(300))
                        await performSearch(newText)
                    } catch {
                        // Task cancelled
                    }
                }
            }
    }
    
    @MainActor
    func performSearch(_ query: String) async {
        // Search implementation
    }
}
```

## Combining Multiple Callbacks

Chain multiple thread-safe operations:

```swift
struct AdvancedEditor: View {
    @State private var text = ""
    let documentManager: DocumentManager
    let syntaxChecker: SyntaxChecker
    
    var body: some View {
        CodeEditor(text: $text)
            .onTextChange { @Sendable newText in
                // Multiple async operations
                Task {
                    async let save = documentManager.autoSave(newText)
                    async let check = syntaxChecker.validate(newText)
                    
                    // Wait for both to complete
                    let (saveResult, checkResult) = await (save, check)
                    
                    await MainActor.run {
                        handleResults(saveResult, checkResult)
                    }
                }
            }
            .onSelectionChange { @Sendable range in
                Task {
                    await highlightMatchingBrackets(at: range)
                }
            }
    }
}
```

## Testing @Sendable Callbacks

Write tests for callbacks with proper async handling:

```swift
@MainActor
final class CallbackTests: XCTestCase {
    func testTextChangeCallback() async {
        let expectation = XCTestExpectation(description: "Text change callback")
        var capturedText: String?
        
        let editor = CodeEditor(text: .constant(""))
            .onTextChange { @Sendable newText in
                capturedText = newText
                expectation.fulfill()
            }
        
        // Simulate text change
        editor.coordinator.handleTextChange("Hello, World!")
        
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(capturedText, "Hello, World!")
    }
    
    func testConcurrentCallbacks() async {
        let editor = CodeEditor(text: .constant(""))
        var callCount = 0
        let lock = NSLock()
        
        // Set up callback with thread-safe counter
        editor.onTextChange { @Sendable _ in
            Task {
                lock.withLock {
                    callCount += 1
                }
            }
        }
        
        // Trigger multiple concurrent changes
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    editor.coordinator.handleTextChange("Change \(i)")
                }
            }
        }
        
        // Verify thread safety
        XCTAssertEqual(callCount, 100)
    }
}
```

## Migration Guide

If you're upgrading from a version without @Sendable callbacks:

### Before (Not Thread-Safe)
```swift
var sharedState = 0

CodeEditor(text: $text)
    .onTextChange { newText in
        sharedState += 1  // ⚠️ Potential data race
        processText(newText)
    }
```

### After (Thread-Safe)
```swift
// Option 1: Use actor for shared state
actor StateManager {
    private(set) var changeCount = 0
    
    func incrementChangeCount() {
        changeCount += 1
    }
}

let stateManager = StateManager()

CodeEditor(text: $text)
    .onTextChange { @Sendable newText in
        Task {
            await stateManager.incrementChangeCount()
            await processText(newText)
        }
    }

// Option 2: Use @MainActor for UI state
@MainActor
final class ViewModel: ObservableObject {
    @Published var changeCount = 0
    
    var editor: some View {
        CodeEditor(text: .constant(""))
            .onTextChange { @Sendable newText in
                Task { @MainActor in
                    self.changeCount += 1
                }
            }
    }
}
```

## Best Practices

1. **Always use Task for async operations** - Don't perform blocking operations in callbacks
2. **Minimize captured state** - Only capture Sendable types or use actors
3. **Use @MainActor for UI updates** - Ensure UI modifications happen on the main thread
4. **Handle cancellation** - Check for task cancellation in long-running operations
5. **Test concurrency** - Write tests that verify thread safety

## Common Patterns

### Analytics Tracking
```swift
let analytics = AnalyticsService.shared

CodeEditor(text: $text)
    .onTextChange { @Sendable newText in
        Task.detached(priority: .background) {
            await analytics.track("text_changed", [
                "length": newText.count,
                "timestamp": Date().timeIntervalSince1970
            ])
        }
    }
```

### Real-time Collaboration
```swift
let collaborationService = CollaborationService()

CodeEditor(text: $text)
    .onTextChange { @Sendable newText in
        Task {
            try await collaborationService.broadcast(
                TextChangeEvent(content: newText, timestamp: Date())
            )
        }
    }
    .onSelectionChange { @Sendable range in
        Task {
            try await collaborationService.broadcastCursor(
                position: range.location
            )
        }
    }
```

## See Also

- <doc:Swift6-Concurrency>
- <doc:SwiftUI-Integration>
- [Swift Concurrency Documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- ``CodeEditor/onTextChange(perform:)``
- ``CodeEditor/onSelectionChange(perform:)``