# REVIEW 1

# Code Review

## API Design & Ergonomics

### 1. CodeEditorPluginModule.initialize() is Public but Empty

**File:** `Sources/CodeEditorPlugin/CodeEditorPlugin.swift`  
**Lines:** 115–120

```swift
public enum CodeEditorPluginModule {
    /// Initialize the CodeEditorPlugin module with default configuration
    public static func initialize() {
        // Perform any necessary module initialization
        // This could include registering default themes, languages, etc.
    }
}
```

**Issue (Suggestion):** The initializer is exposed publicly but currently performs no work. This may confuse integrators and clutters the public API surface.

**Suggested task:** Remove or implement CodeEditorPluginModule.initialize()

### 2. Incomplete Builder Coverage

**File:** `Sources/CodeEditorPlugin/Configuration/EditorConfigurationBuilder.swift`

The builder offers many convenience methods but lacks options for features such as minimap or folding controls. Example snippet showing existing builder methods:

```swift
@discardableResult
public func showInvisibleCharacters(_ show: Bool) -> Self {
    with { $0.display.showInvisibleCharacters = show }
}
```

**Issue (Suggestion):** Users cannot configure showMinimap, enableCodeFolding, or showFoldingControls via the builder.

**Suggested task:** Add missing builder methods for display options

### 3. Environment Keys: Limited API to Request First Responder

**File:** `Sources/CodeEditorPlugin/SwiftUI/CodeEditorTheme.swift`  
**Lines:** 61–67

```swift
public struct CodeEditorBecomeFirstResponderKey: EnvironmentKey {
    public static let defaultValue: Bool = false
    public typealias Value = Bool
}
```

**Issue (Question):** The environment key is named codeEditorBecomeFirstResponder, but CodeEditor only checks for this value once when updating the view. Consider providing a dedicated modifier `.becomeFirstResponder()` for clearer API.

**Suggested task:** Provide a SwiftUI modifier to request focus

## Architecture & Scalability

### 4. PlatformCapabilities Version Checks Use Major Version Only

**File:** `Sources/CodeEditorPlugin/Platform/PlatformCapabilities+TextKit.swift`  
**Lines:** 58–66

```swift
public var supportsTextKit2: Bool {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    return systemVersionComponents.major >= 13
    #elseif canImport(UIKit)
    return systemVersionComponents.major >= 16
    #else
    return false
    #endif
}
```

**Issue (Suggestion):** Relying solely on the major version may incorrectly report support on early minor releases. Minor version checks would provide more accuracy.

**Suggested task:** Include minor version checks for TextKit2 support

### 5. Deprecated Singleton Pattern Still Public

**File:** `Sources/CodeEditorPlugin/Platform/CrossPlatformCoordinator.swift`  
**Lines:** 27–31

```swift
@available(*, deprecated, message: "Use dependency injection instead of the singleton pattern")
public static let shared = CrossPlatformCoordinator()
```

**Issue (Suggestion):** Although marked deprecated, the singleton remains public and may continue to be used. This undermines the move toward dependency injection.

**Suggested task:** Limit usage of CrossPlatformCoordinator.shared

## Code Quality & Best Practices

### 6. Potential Redundant Task Creation

**File:** `Sources/CodeEditorPlugin/SyntaxHighlighting/AsyncSyntaxHighlighter.swift`  
**Lines:** 57–73

```swift
debounceTask = Task { [weak self] in
    do {
        guard let self else { return }
        try await Task.sleep(for: .seconds(self.debounceInterval))
        await self.performHighlighting(for: textView, language: language, visibleRange: visibleRange)
    } catch {
        // Task was cancelled
    }
}
```

**Issue (Suggestion):** Spawning a new Task merely to sleep may be unnecessary. A lighter-weight await on Task.sleep from the actor itself could simplify the code.

**Suggested task:** Simplify debouncing in AsyncSyntaxHighlighter

## Testing & Reliability

### 7. No Tests for CodeEditor SwiftUI View

Current tests focus on CodeEditorView and container views, but the SwiftUI wrapper lacks coverage.

**Issue (Suggestion):** Add SwiftUI unit or UI tests to verify environment propagation and modifier behavior.

**Suggested task:** Add SwiftUI tests for CodeEditor

## Documentation & Clarity

### 8. Documenting Platform Abstraction Usage

The documentation explains platform abstractions but does not explicitly state that `#if os()` should be avoided throughout the codebase.

**Issue (Suggestion):** Reinforce this guideline in Platform-Abstraction.md and the root README.md.

**Suggested task:** Clarify platform abstraction guidelines in docs

### 9. Missing DocC Examples for Builder Presets

While `EditorConfiguration+Presets.swift` defines presets, DocC articles don't show how to extend or customize them.

**Issue (Suggestion):** Provide a short DocC section demonstrating advanced customization starting from a preset.

**Suggested task:** Expand documentation on configuration presets

---

These improvements aim to refine the public API, strengthen platform abstractions, and enhance overall usability and reliability. Implementing them should help elevate CodeEditorPlugin from a great component to an exceptional one.
