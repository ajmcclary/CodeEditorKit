# Review 3

# Code Review Report

This review focuses on the CodeEditorPlugin and CodeEditorSample targets.
Line numbers reference the files in this repository.

## 1. Cross‑Platform Compatibility (AppKit/UIKit)

### 1.1 Unused observeTextView() in GutterView

**File:** `Sources/CodeEditorPlugin/Layout/GutterView+AppKit.swift`

**Lines:** 8‑35 show a helper to observe text/scroll changes, but the function is never called.

```swift
extension GutterView {
    /// Track text view changes
    func observeTextView() {            // ...
        NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setNeedsDisplayLineNumbers()
            }
        }
        ...
    }
}
```

**Issue:** Without invoking `observeTextView()`, line numbers may not update when the text view scrolls or edits.

**Suggested Fix:** Call `gutterView.observeTextView()` from `CodeEditorContainerView.setupViews()` after assigning `gutterView.textView`.

**Before:**
```swift
gutterView.textView = textView
setupMinimap()
```

**After:**
```swift
gutterView.textView = textView
gutterView.observeTextView()          // start listening for changes
setupMinimap()
```

### 1.2 Duplicated platform logic in CodeEditorView

**File:** `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`

**Lines:** 329‑341 contain macOS‑only sizing code while the UIKit branch is empty.

```swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
isVerticallyResizable = true
isHorizontallyResizable = false
textContainer?.widthTracksTextView = true
textContainer?.heightTracksTextView = false
#else
// UITextView doesn't have these properties - it handles scrolling differently
#endif
```

**Issue:** The comment indicates no UIKit equivalent. Consider creating platform abstractions for these adjustments (e.g., via `PlatformTextViewExtensions`) so that the UIKit code path explicitly documents what happens. This improves readability and maintainability.

### 1.3 Context menu creation has duplicate code

**File:** `Sources/CodeEditorPlugin/Platform/CrossPlatformCoordinator.swift`

**Lines:** 324‑373 show nearly identical "Cut/Copy/Paste" actions for both platforms, only differing in API calls.

**Suggestion:** Abstract the platform‑specific implementations into helper functions inside `ContextMenuBuilder` or extensions on `CodeEditorView`. This would reduce conditional compilation blocks and unify the menu logic.

### 1.4 ContentView iOS gestures not mirrored on macOS

`Sources/CodeEditorPlugin/Layout/ContentView.swift` defines rich gesture handling for iOS (double/triple tap, long press) but macOS's ContentView only forwards basic mouse events.

**Recommendation:** Document which gestures are intentionally unsupported on macOS or consider adding equivalent trackpad/mouse gestures to achieve feature parity.

## 2. SwiftUI Integration

### 2.1 SwiftUI wrappers rely solely on NotificationCenter

**File:** `Sources/CodeEditorPlugin/SwiftUI/CodeEditorSwiftUICommon.swift`

**Lines:** 112‑141 show `setupTextChangeObservers` adding `NotificationCenter` observers.

**Observation:** Because observers are block‑based, they retain the coordinator until the text view is deallocated. Although `NotificationCenter` removes them automatically, explicit removal in `Coordinator.cleanup()` could prevent unexpected retention in complex SwiftUI hierarchies.

### 2.2 CodeEditorSwiftUIView environment modifiers

**File:** `Sources/CodeEditorPlugin/SwiftUI/CodeEditorSwiftUIView.swift`

**Lines:** 238‑269 implement `becomeFirstResponder(_:)` only on iOS by using an environment key.

**Issue:** When this modifier is used on macOS, it's silently ignored. Document this behavior or gate the API with `@available` to avoid confusion.

### 2.3 Potential asynchronous update loops

**File:** `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift`

**Lines:** 25‑50 implement a `task(id: text)` with an async sleep to debounce updates.

**Concern:** If external changes to `text` occur frequently, this asynchronous task may overlap, causing outdated updates. Consider using `Task.cancel(id:)` or a dedicated debouncer actor to manage state more predictably.

## 3. Architecture and API Design

### 3.1 EditorConfiguration.apply(to:) duplicates work

**File:** `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift`

**Lines:** 290‑327 apply fonts and wrap‑line settings directly.

**Issue:** The same settings are later reapplied within `CodeEditorView.applyConfiguration()` (lines 847‑882). This double application may cause redundant layout passes.

**Suggestion:** Keep `EditorConfiguration` responsible only for high‑level property updates and let `CodeEditorView` handle view-specific adjustments.

### 3.2 Public API alias clutter

**File:** `Sources/CodeEditorPlugin/CodeEditorPlugin.swift`

**Lines:** 15‑45 expose numerous typealiases.

**Issue:** Many aliases (e.g., `LayoutCoord`, `PerfMonitor`) are abbreviations that obscure the original type names, contrary to Swift API Design Guidelines. Reducing the exported aliases or giving them clear names will make the public API easier to understand.

## 4. Code Quality and Performance

### 4.1 CADisplayLink paused logic

**File:** `Sources/CodeEditorPlugin/Layout/GutterView+UIKit.swift`

**Lines:** 20‑24 pause the display link each time it fires.

**Concern:** Continually pausing/unpausing the display link for every scroll event might cause missed frames on rapid scrolling. Consider keeping the link active while scrolling and pausing only when idle.

### 4.2 Potential memory pressure from annotation views

**File:** `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`

**Lines:** 1036‑1076 update annotation views and keep them in `annotationViews` dictionary.

**Issue:** Annotation views are recreated every time `updateAnnotationView(for:)` runs, which may lead to many detached views lingering during heavy editing. Implement view reuse or an LRU cache for annotation views to reduce allocations.

### 4.3 Lack of unit tests for SwiftUI environment behaviors

The test suite covers many features but does not verify the custom environment keys (`codeEditorTheme`, `codeEditorConfiguration`, etc.). Adding tests ensures the environment propagation works correctly across platforms.

## 5. Suggested Task Stubs

Below are concise task descriptions for implementing key fixes.

- **Suggested task:** Invoke GutterView.observeTextView during container setup
- **Suggested task:** Refactor platform-specific layout flags
- **Suggested task:** Simplify ContextMenu creation
- **Suggested task:** Clarify becomeFirstResponder modifier on macOS
- **Suggested task:** Improve annotation view reuse

## Testing

`swift build && swiftlint && swift test` failed because the container cannot fetch swift-syntax from GitHub due to network restrictions.

`swift test` in CodeEditorSample failed for the same reason.

Codex couldn't run certain commands due to environment limitations. Consider configuring a setup script or internet access in your Codex environment to install dependencies.