# Review 1

# Code Review Report

This repository contains a Swift package (CodeEditorPlugin) and a sample app (CodeEditorSample). The project aims to provide a cross-platform code editor component that integrates with AppKit, UIKit, and SwiftUI.

## 1. Cross-Platform Compatibility

### 1.1 Platform Abstraction Layer

The Platform directory defines typealiases and capability checks to abstract AppKit/UIKit differences. Example from PlatformImports.swift:

```swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
...
#else
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
...
#endif
```

This approach is correct and keeps platform checks localized.

### 1.2 Conditional Compilation

Source files use `#if canImport(AppKit) && !targetEnvironment(macCatalyst)` and `#if canImport(UIKit)` consistently. No remaining `#if os(...)` directives were found.

### 1.3 UI Components

GutterView supplies separate drawing implementations in GutterView+AppKit.swift and GutterView+UIKit.swift. Both versions register NotificationCenter observers using closure-based APIs but the returned tokens are not stored. Example:

```swift
NotificationCenter.default.addObserver(
    forName: NSText.didChangeNotification,
    object: textView,
    queue: .main
) { [weak self] _ in
    Task { @MainActor in
        self?.setNeedsDisplayLineNumbers()
    }
}
```

Because the observer tokens are not retained, these observers can never be removed, leading to leaks.

#### Suggested Fix

Store the tokens and remove them in deinit:

```swift
private var observers: [Any] = []

func observeTextView() {
    guard let textView else { return }
    let token = NotificationCenter.default.addObserver(
        forName: NSText.didChangeNotification,
        object: textView,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor in
            self?.setNeedsDisplayLineNumbers()
        }
    }
    observers.append(token)
}

deinit {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
}
```

This ensures observers are released on both platforms.

**Suggested task:** Retain and remove NotificationCenter tokens in GutterView

### 1.4 CodeEditorContainerView

setupKeyboardObservers() on iOS registers closure observers and stores them in keyboardObservers, but they are never removed:

```swift
let willShow = NotificationCenter.default.addObserver( ... )
let willHide = NotificationCenter.default.addObserver( ... )
keyboardObservers = [willShow, willHide]
...
deinit {
    // Observers are automatically removed when deallocated
}
```

However, observers created with the closure API are not automatically released. The deinitializer should explicitly remove them.

**Suggested task:** Remove keyboard observers in CodeEditorContainerView

### 1.5 Abstraction in SwiftUI

SwiftUI wrappers expose environment keys for configuration and theme. Example:

```swift
public struct CodeEditorBecomeFirstResponderKey: EnvironmentKey {
    public static let defaultValue: Bool = true
}
...
extension View {
    public func codeEditorBecomeFirstResponder(_ become: Bool = true) -> some View {
        environment(\.codeEditorBecomeFirstResponder, become)
    }
}
```

This is an idiomatic way to control editor behavior from SwiftUI.

## 2. SwiftUI Integration

### 2.1 CodeEditor View

CodeEditor (SwiftUI-native API) uses environment values and state to manage text and focus:

```swift
@FocusState private var isFocused: Bool
...
CodeEditorRepresentable(
    text: $internalText,
    language: language,
    theme: theme,
    configuration: configuration,
    isFocused: Binding(
        get: { isFocused },
        set: { isFocused = $0 }
    ),
    onTextChange: handleTextChange,
    onSelectionChange: handleSelectionChange
)
```

This design is idiomatic, but the bridging via CodeEditorRepresentable duplicates similar logic for both platforms.

#### Improvement

Create a platform-agnostic wrapper using a protocol or generic to reduce duplication between the macOS and iOS implementations.

**Suggested task:** Unify CodeEditorRepresentable implementations

### 2.2 Minimap Support

MinimapSupport uses associated objects and NotificationCenter observers (closure-based) to keep the minimap in sync with text changes. These observers are also not removed.

**Suggested task:** Manage minimap observers properly

## 3. Architecture and API Design

### 3.1 EditorConfiguration System

EditorConfiguration offers nested structs (Layout, Display, Behavior, Performance) and a builder API. Preset configurations are easily created:

```swift
public static let minimal: EditorConfiguration = {
    var display = Display()
    display.showLineNumbers = false
    display.enableSyntaxHighlighting = false
    ...
    return Self(display: display, behavior: behavior)
}()
```

The design is flexible and follows Swift API Design Guidelines.

### 3.2 Delegates and Protocols

CodeEditorViewDelegate defines optional methods with default implementations. This is intuitive for clients.

### 3.3 PlatformCapabilities

PlatformCapabilities centralizes feature detection:

```swift
public var currentPlatform: Platform {
    #if targetEnvironment(macCatalyst)
    return .catalyst
    #elseif canImport(AppKit)
    return .macOS
    #else
    return .iOS
    #endif
}
```

This API is clear. Consider exposing @available checks in computed properties so that the compiler can warn about unavailable features.

## 4. Code Quality & Performance

### 4.1 Notification Observer Leakage

As mentioned above, multiple components register closure-based NotificationCenter observers without retaining tokens or removing them. This leaks memory and may execute callbacks after deallocation.

### 4.2 Keyboard Handling on iOS

updateContentInsets() modifies contentSize directly:

```swift
if textView.contentSize.height < minContentHeight {
    textView.contentSize = CGSize(width: textView.contentSize.width, height: minContentHeight)
}
```

Directly setting contentSize on UITextView may conflict with Auto Layout. Consider adjusting only contentInset and scrollIndicatorInsets.

### 4.3 Observer Removal in CodeEditorView

CodeEditorView uses both selector-based and closure-based observers. Only selector-based observers are removed (removeObserver(self) in deinit). Any closure observers added later should also be tracked and removed.

### 4.4 Repeated Code for Language Detection

Several sample views implement their own detectLanguage(from:). This could be a shared helper in CodeEditorPlugin or the sample app's utilities.

### 4.5 Unification of SwiftUI Representations

Both CodeEditorSwiftUIView and the older CodeEditorViewWrapper exist in parallel. This can confuse users about the recommended API.

## 5. Sample Application (Best-Practice Reference)

CodeEditorSample demonstrates the plugin through SampleCodeEditorView. The sample relies on the plugin's configuration presets and uses cross-platform wrappers appropriately. No direct AppKit/UIKit calls are present in the sample except where the platform wrapper requires them.

### Improvement

The wrapper CodeEditorViewWrapper could simply use CodeEditor (the modern SwiftUI API) once accessibility issues are resolved. This would reduce duplication and show best practice more clearly.

## Overall Assessment

The project demonstrates a strong attempt at cross-platform support using a dedicated abstraction layer. SwiftUI integration is mostly idiomatic with environment-driven configuration. The configuration system and protocol-oriented design follow Swift best practices.

The main issues identified relate to NotificationCenter observer management and some code duplication in SwiftUI wrappers. Addressing these will improve memory safety and maintainability.

## Testing

Build and test commands failed because the environment lacked network access and certain tools:

```
error: Failed to clone repository https://github.com/apple/swift-syntax.git: CONNECT tunnel failed, response 403
bash: swiftlint: command not found
```

Codex couldn't run certain commands due to environment limitations. Consider configuring a setup script or internet access in your Codex environment to install dependencies.