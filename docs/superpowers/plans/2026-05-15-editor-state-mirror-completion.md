# EditorState Mirror Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `EditorState.isDirty` and `EditorState.hardwareAccelerationActive` publish accurate values (currently both stuck at `false`), and make `EditorConfiguration.Performance.useHardwareAcceleration` actually gate `wantsLayer` instead of being a ghost knob.

**Architecture:** A new internal value-type `DirtyTracker` lives on `CodeEditorView` and is driven by the existing `CodeEditorBaseCoordinator` mirror path (`setupContainer`, `updateContainer`, `updateState`). A new `HardwareAcceleration.apply(_:to:)` helper replaces unconditional `wantsLayer = true` writes at the editor's view-tree boundary. `EditorController` gets a `markClean()` public API for hosts to call after saves.

**Tech Stack:** Swift 6.3, SwiftUI, AppKit + UIKit (cross-platform), Swift Testing (`import Testing`) for new tests.

**Spec:** `docs/superpowers/specs/2026-05-15-editor-state-mirror-completion-design.md`

---

## Notes on the spec's file-path imprecision

The spec listed four `wantsLayer = true` sites with line numbers that were drawn from an earlier exploration; the actual code has the same conceptual surfaces but at different lines, and one extra duplicate write per visual surface:

| Conceptual surface | Spec line ref | Actual line ref(s) |
|---|---|---|
| Main editor view + scroll view | `CodeEditorView+PerformanceExtensions.swift:37-40` | `Core/CodeEditorView+PerformanceExtensions.swift:37,40` AND `Core/TextKitSetupHelper.swift:147,150` (same conceptual sites, second setup entry point) |
| Container view | `ContainerViewInitializer.swift:72-73` | `Layout/ContainerViewInitializer.swift:109` |
| Gutter | `Layout/GutterView.swift:11` | `Layout/GutterView.swift:144` (inside init) |
| Minimap | `Layout/MinimapView.swift:22-23` | `Layout/MinimapView.swift:255` (inside init) AND `Layout/ContainerViewInitializer.swift:157` AND `Layout/CodeEditorContainerView+AppKitExtensions.swift:165` |

The plan gates all seven source lines that touch this conceptual surface. Out of scope: `wantsLayer = true` on overlay/chrome views (`LineHighlightView`, `_GlassSurface`, `InsertionPointView`, `ContentView`, completion popups, annotation views, etc.) — those are tightly-coupled visual overlays whose layer-backing is part of their own rendering contract, not the editor's hardware-acceleration knob.

---

## Task 1: `DirtyTracker` value type with unit tests (TDD)

**Files:**
- Create: `Sources/CodeEditorPlugin/Core/DirtyTracker.swift`
- Create: `Tests/CodeEditorPluginTests/Core/DirtyTrackerTests.swift`

- [ ] **Step 1: Write the failing test file**

```swift
// Tests/CodeEditorPluginTests/Core/DirtyTrackerTests.swift
import Testing
@testable import CodeEditorPlugin

@Suite("DirtyTracker")
struct DirtyTrackerTests {
    @Test("Returns false when no baseline is set")
    func returnsFalseWithoutBaseline() {
        let tracker = DirtyTracker()
        #expect(tracker.isDirty(currentText: "") == false)
        #expect(tracker.isDirty(currentText: "anything") == false)
    }

    @Test("Returns false when current matches baseline")
    func returnsFalseWhenMatchingBaseline() {
        var tracker = DirtyTracker()
        tracker.setBaseline("hello")
        #expect(tracker.isDirty(currentText: "hello") == false)
    }

    @Test("Returns true when current differs from baseline")
    func returnsTrueWhenDiffersFromBaseline() {
        var tracker = DirtyTracker()
        tracker.setBaseline("hello")
        #expect(tracker.isDirty(currentText: "world") == true)
    }

    @Test("Undo back to baseline returns to clean")
    func undoBackToBaselineGoesClean() {
        var tracker = DirtyTracker()
        tracker.setBaseline("a")
        #expect(tracker.isDirty(currentText: "ab") == true)
        #expect(tracker.isDirty(currentText: "a") == false)
    }

    @Test("markClean adopts current text as new baseline")
    func markCleanAdoptsCurrent() {
        var tracker = DirtyTracker()
        tracker.setBaseline("hello")
        tracker.markClean(currentText: "world")
        #expect(tracker.isDirty(currentText: "world") == false)
        #expect(tracker.isDirty(currentText: "hello") == true)
    }

    @Test("setBaseline overwrites a prior baseline")
    func setBaselineOverwrites() {
        var tracker = DirtyTracker()
        tracker.setBaseline("first")
        tracker.setBaseline("second")
        #expect(tracker.isDirty(currentText: "second") == false)
        #expect(tracker.isDirty(currentText: "first") == true)
    }
}
```

- [ ] **Step 2: Run tests to verify failure (compile error)**

Run: `swift test --filter DirtyTrackerTests 2>&1 | tail -20`
Expected: FAIL — `error: cannot find 'DirtyTracker' in scope`.

- [ ] **Step 3: Create the implementation file**

```swift
// Sources/CodeEditorPlugin/Core/DirtyTracker.swift
import Foundation

/// View-local dirty tracker. The framework's coordinator owns one instance per
/// editor (stored on `CodeEditorView`) and asks it after every text-mutation
/// sync whether the current content differs from the baseline.
///
/// Baseline is set on initial text install (`setupContainer`), on host-driven
/// binding swap (`updateContainer` with `text != storage`), and on explicit
/// `markClean(currentText:)`. Returns `false` when no baseline has been set
/// (pre-mount initial state).
struct DirtyTracker: Sendable {
    private var baseline: String?

    mutating func setBaseline(_ text: String) {
        baseline = text
    }

    func isDirty(currentText: String) -> Bool {
        guard let baseline else { return false }
        return baseline != currentText
    }

    mutating func markClean(currentText: String) {
        baseline = currentText
    }
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `swift test --filter DirtyTrackerTests 2>&1 | tail -10`
Expected: PASS — 6 tests pass.

- [ ] **Step 5: Lint**

Run: `swiftlint --fix Sources/CodeEditorPlugin/Core/DirtyTracker.swift Tests/CodeEditorPluginTests/Core/DirtyTrackerTests.swift && swiftlint Sources/CodeEditorPlugin/Core/DirtyTracker.swift Tests/CodeEditorPluginTests/Core/DirtyTrackerTests.swift`
Expected: 0 violations.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/Core/DirtyTracker.swift Tests/CodeEditorPluginTests/Core/DirtyTrackerTests.swift
git commit -m "$(cat <<'EOF'
DirtyTracker: view-local dirty baseline value type

First slice of NEXT.md B.3 — the framework-side value type that the
coordinator will use to compute EditorState.isDirty against a baseline
that resets on initial text install, host-driven binding swap, and
explicit markClean.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `HardwareAcceleration` helper with unit tests (TDD)

**Files:**
- Create: `Sources/CodeEditorPlugin/Performance/HardwareAcceleration.swift`
- Create: `Tests/CodeEditorPluginTests/Performance/HardwareAccelerationTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorPluginTests/Performance/HardwareAccelerationTests.swift
import Testing
@testable import CodeEditorPlugin

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
@Suite("HardwareAcceleration")
struct HardwareAccelerationTests {
    #if canImport(AppKit)
    @Test("AppKit: apply(true) sets wantsLayer true and returns true")
    func appKitApplyTrueEnablesLayer() {
        let view = NSView()
        let result = HardwareAcceleration.apply(true, to: view)
        #expect(result == true)
        #expect(view.wantsLayer == true)
    }

    @Test("AppKit: apply(false) sets wantsLayer false and returns false")
    func appKitApplyFalseDisablesLayer() {
        let view = NSView()
        view.wantsLayer = true
        let result = HardwareAcceleration.apply(false, to: view)
        #expect(result == false)
        #expect(view.wantsLayer == false)
    }
    #else
    @Test("UIKit: apply is a no-op and always returns true")
    func uiKitApplyIsNoOp() {
        let view = UIView()
        let result = HardwareAcceleration.apply(false, to: view)
        #expect(result == true)
    }
    #endif
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test --filter HardwareAccelerationTests 2>&1 | tail -20`
Expected: FAIL — `error: cannot find 'HardwareAcceleration' in scope`.

- [ ] **Step 3: Create the implementation file**

```swift
// Sources/CodeEditorPlugin/Performance/HardwareAcceleration.swift
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Gates hardware-accelerated (layer-backed) rendering on a platform view.
///
/// AppKit: sets `wantsLayer = enabled`. UIKit: no-op — `UIView` instances are
/// always layer-backed by definition. Returns the effective value (the input
/// on AppKit, `true` on UIKit). Callers use the return value to record what
/// was actually applied (see `EditorState.hardwareAccelerationActive`).
@MainActor
enum HardwareAcceleration {
    @discardableResult
    static func apply(_ enabled: Bool, to view: PlatformView) -> Bool {
        #if canImport(AppKit)
        view.wantsLayer = enabled
        return enabled
        #else
        _ = (enabled, view)
        return true
        #endif
    }
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `swift test --filter HardwareAccelerationTests 2>&1 | tail -10`
Expected: PASS.

- [ ] **Step 5: Lint**

Run: `swiftlint --fix Sources/CodeEditorPlugin/Performance/HardwareAcceleration.swift Tests/CodeEditorPluginTests/Performance/HardwareAccelerationTests.swift && swiftlint Sources/CodeEditorPlugin/Performance/HardwareAcceleration.swift Tests/CodeEditorPluginTests/Performance/HardwareAccelerationTests.swift`
Expected: 0 violations.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/Performance/HardwareAcceleration.swift Tests/CodeEditorPluginTests/Performance/HardwareAccelerationTests.swift
git commit -m "$(cat <<'EOF'
HardwareAcceleration: helper that gates wantsLayer on PlatformView

Replaces unconditional wantsLayer = true writes. AppKit gates on the
input; UIKit no-ops because UIView is always layer-backed. Caller uses
the return value to record the applied state for EditorState.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add coordinator back-pointer storage to `CodeEditorView`

`DirtyTracker` itself lives on the coordinator (Task 5 adds it there). The view only needs a back-pointer to the coordinator so `EditorController.markClean()` can route through it.

**Files:**
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` (near the existing stored properties around line 410-465)

- [ ] **Step 1: Add the weak back-pointer**

Open `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`. After the existing `internal var lastGutterLineCount: Int = -1` declaration (around line 415), add:

```swift
/// Weak back-pointer to the coordinator that mounted this view. Set
/// during `CodeEditorBaseCoordinator.setupContainer` so host-facing
/// controller methods (`EditorController.markClean()`) can route
/// through the coordinator that owns the dirty tracker.
internal weak var coordinator: CodeEditorBaseCoordinator?
```

- [ ] **Step 2: Build to verify**

Run: `swift build --target CodeEditorPlugin 2>&1 | tail -10`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/CodeEditorPlugin/Core/CodeEditorView.swift
git commit -m "$(cat <<'EOF'
CodeEditorView: weak back-pointer to mounting coordinator

Lets EditorController.markClean() route through the coordinator that
owns the dirty tracker, without exposing the tracker on the view.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Write `isDirty` integration tests (red)

**Files:**
- Create: `Tests/CodeEditorPluginTests/Core/EditorStateDirtyMirrorTests.swift`

These tests will fail until Task 5 lands the coordinator wiring.

- [ ] **Step 1: Write the integration test file**

```swift
// Tests/CodeEditorPluginTests/Core/EditorStateDirtyMirrorTests.swift
import Testing
import SwiftUI
@testable import CodeEditorPlugin

@MainActor
@Suite("EditorState.isDirty mirror")
struct EditorStateDirtyMirrorTests {
    private func makeFixture(
        initialText: String = "hello"
    ) -> (CodeEditorBaseCoordinator, CodeEditorContainerView, EditorState) {
        let coordinator = CodeEditorBaseCoordinator()
        let editorState = EditorState()
        coordinator.hostEditorState = editorState
        let container = CodeEditorContainerView(frame: .zero)
        coordinator.setupContainer(
            container,
            text: initialText,
            language: .plainText,
            theme: .defaultLight,
            configuration: .default,
            runtimeDependencies: EditorRuntimeDependencies()
        )
        return (coordinator, container, editorState)
    }

    @Test("Initial mount leaves isDirty false")
    func initialMountIsClean() {
        let (_, _, state) = makeFixture()
        #expect(state.isDirty == false)
    }

    @Test("User edit through updateState flips isDirty true")
    func userEditFlipsDirtyTrue() {
        let (coordinator, _, state) = makeFixture(initialText: "hello")
        coordinator.updateState(
            text: "hello world",
            language: .plainText,
            configuration: .default
        )
        #expect(state.isDirty == true)
    }

    @Test("Edit back to baseline returns isDirty to false")
    func editBackToBaselineCleans() {
        let (coordinator, _, state) = makeFixture(initialText: "hello")
        coordinator.updateState(
            text: "hello world",
            language: .plainText,
            configuration: .default
        )
        #expect(state.isDirty == true)
        coordinator.updateState(
            text: "hello",
            language: .plainText,
            configuration: .default
        )
        #expect(state.isDirty == false)
    }

    @Test("Host-driven binding swap resets baseline")
    func hostBindingSwapResetsBaseline() {
        let (coordinator, container, state) = makeFixture(initialText: "alpha")
        coordinator.updateState(
            text: "alpha-edit",
            language: .plainText,
            configuration: .default
        )
        #expect(state.isDirty == true)

        coordinator.updateContainer(
            container,
            text: "BETA",
            language: .plainText,
            theme: .defaultLight,
            configuration: .default,
            runtimeDependencies: EditorRuntimeDependencies()
        )
        #expect(state.isDirty == false)
    }

    @Test("markClean on EditorController resets the baseline")
    func markCleanResetsBaseline() {
        let (coordinator, container, state) = makeFixture(initialText: "hello")
        coordinator.updateState(
            text: "hello world",
            language: .plainText,
            configuration: .default
        )
        #expect(state.isDirty == true)

        let controller = EditorController()
        controller.attach(to: container.textView)
        controller.markClean()
        #expect(state.isDirty == false)

        coordinator.updateState(
            text: "hello world more",
            language: .plainText,
            configuration: .default
        )
        #expect(state.isDirty == true)
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter EditorStateDirtyMirrorTests 2>&1 | tail -20`
Expected: Some compile errors (e.g., `controller.markClean()` may not exist yet) and/or the four assertions about `state.isDirty == true` will fail because the mirror is never written. Capture the exact failures — they're the red light Task 5 turns green.

- [ ] **Step 3: Commit the failing tests**

```bash
git add Tests/CodeEditorPluginTests/Core/EditorStateDirtyMirrorTests.swift
git commit -m "$(cat <<'EOF'
Tests: EditorState.isDirty mirror integration (red)

Red tests for the five reset triggers — initial mount, edit, undo back
to baseline, host binding swap, and EditorController.markClean().
Coordinator wiring lands in the next commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Coordinator + controller wiring to flip isDirty tests green

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift`
- Modify: `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift` (or any existing `CodeEditorView` extension file)

- [ ] **Step 1: Add `dirtyTracker` storage to the coordinator**

In `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift`, inside `CodeEditorBaseCoordinator` (around line 50-77, near the other private stored properties), add:

```swift
/// Tracks the view's content against its baseline. Coordinator writes
/// the baseline on initial text install (`setupContainer`) and on
/// host-driven binding swaps (`updateContainer`); reads in
/// `updateState` to write `EditorState.isDirty`. `markClean(view:)`
/// resets the baseline to the current text.
private var dirtyTracker = DirtyTracker()
```

- [ ] **Step 2: Wire `setupContainer` baseline seed + coordinator back-pointer**

Still in `CodeEditor+CoordinatorsExtensions.swift`, edit the `setupContainer` method (around line 327-377). Locate:

```swift
// Set initial text
platformAdapter.setText(text, in: textView, preserveSelection: false)
```

Immediately after that line, add:

```swift
// Seed the dirty tracker against the initial content. Coordinator
// owns the tracker; the view holds a weak back-pointer so
// `EditorController.markClean()` can route through.
dirtyTracker.setBaseline(text)
textView.coordinator = self
```

- [ ] **Step 3: Wire `updateContainer` host-swap detection**

In the same file, inside `updateContainer` (around line 380-421), locate:

```swift
// Update text if changed
platformAdapter.setText(text, in: textView, preserveSelection: true)
```

Replace that single line with the host-swap detection + baseline reset:

```swift
// Detect host-driven binding swap: when the binding's text differs
// from the view's current storage, the host has installed new content
// (e.g., tab switch, file load). User edits write to storage via the
// delegate before they propagate back here, so storage already
// matches `text` on the edit re-render path.
let storageText = platformAdapter.text(from: textView)
let isHostBindingSwap = (storageText != text)

// Update text if changed
platformAdapter.setText(text, in: textView, preserveSelection: true)

if isHostBindingSwap {
    dirtyTracker.setBaseline(text)
}
```

Note: `platformAdapter.text(from:)` is already used at line 237 of the same file (`text(from textView:)`), so the API is in scope.

- [ ] **Step 4: Wire `updateState` isDirty mirror write**

In `updateState(text:language:configuration:)` (around line 116-140), locate the existing `if let hostEditorState { ... }` block (around line 131-139). Inside that block, after the existing `lineCount` mirror write, add:

```swift
let dirty = dirtyTracker.isDirty(currentText: text)
if hostEditorState.isDirty != dirty {
    hostEditorState.isDirty = dirty
}
```

- [ ] **Step 5: Add coordinator `markClean(view:)` helper**

Still in `CodeEditor+CoordinatorsExtensions.swift`, add a method on `CodeEditorBaseCoordinator` (place it after `updateState`):

```swift
/// Reset the dirty baseline to the view's current content. Called by
/// `EditorController.markClean()` via `CodeEditorView.applyMarkClean()`.
func markClean(view: CodeEditorView) {
    let currentText = platformAdapter.text(from: view)
    dirtyTracker.markClean(currentText: currentText)
    if let hostEditorState, hostEditorState.isDirty != false {
        hostEditorState.isDirty = false
    }
}
```

- [ ] **Step 6: Add `applyMarkClean()` extension on `CodeEditorView`**

Add to `Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift`:

```swift
extension CodeEditorView {
    /// Bridge between `EditorController.markClean()` and the coordinator
    /// that owns the dirty tracker. No-op when the view is not mounted
    /// (no coordinator attached).
    func applyMarkClean() {
        coordinator?.markClean(view: self)
    }
}
```

- [ ] **Step 7: Add `markClean()` public API on `EditorController`**

In `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`, after the `clearSearch` method (around line 296), add:

```swift
// MARK: - Dirty tracking

/// Reset the framework's view-local dirty baseline. Hosts call this
/// after a successful save (or any other moment when the current text
/// should be treated as the new clean baseline). Writes
/// `EditorState.isDirty = false`. No-op when the controller is
/// unattached.
///
/// Note: `EditorState.isDirty` is view-local — it tracks whether the
/// editor view has observed an edit since its current bound content
/// was installed. Hosts that track document-level dirty across tabs
/// (e.g., the sample app's `TabModel.isDirty`) continue to do so
/// independently.
public func markClean() {
    codeEditorView?.applyMarkClean()
}
```

- [ ] **Step 8: Run the integration tests — expect green**

Run: `swift test --filter EditorStateDirtyMirrorTests 2>&1 | tail -10`
Expected: PASS — 5 tests pass.

Also re-run the unit tests to verify nothing else broke:

Run: `swift test --filter DirtyTrackerTests 2>&1 | tail -10`
Expected: PASS — 6 tests pass.

- [ ] **Step 9: Build full target + lint**

Run: `swift build --target CodeEditorPlugin 2>&1 | tail -5`
Expected: build succeeds.

Run: `swiftlint --fix && swiftlint 2>&1 | tail -5`
Expected: 0 violations.

- [ ] **Step 10: Commit**

```bash
git add Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift \
        Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift \
        Sources/CodeEditorPlugin/SwiftUI/EditorController.swift
git commit -m "$(cat <<'EOF'
EditorState: wire isDirty mirror via DirtyTracker + EditorController.markClean

Coordinator owns the tracker; view holds a weak back-pointer for the
markClean route. Mirror writes happen in the existing updateState pass
(O(n) overlap with lineCount). markClean() is public on EditorController
and no-op when unattached.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Write `hardwareAccelerationActive` integration tests (red)

**Files:**
- Create: `Tests/CodeEditorPluginTests/Core/EditorStateHardwareMirrorTests.swift`

- [ ] **Step 1: Write the integration test file**

```swift
// Tests/CodeEditorPluginTests/Core/EditorStateHardwareMirrorTests.swift
import Testing
@testable import CodeEditorPlugin

@MainActor
@Suite("EditorState.hardwareAccelerationActive mirror")
struct EditorStateHardwareMirrorTests {
    private func makeFixture(
        useHardwareAcceleration: Bool
    ) -> (CodeEditorBaseCoordinator, CodeEditorContainerView, EditorState) {
        var config: EditorConfiguration = .default
        config.performance.useHardwareAcceleration = useHardwareAcceleration

        let coordinator = CodeEditorBaseCoordinator()
        let editorState = EditorState()
        coordinator.hostEditorState = editorState
        let container = CodeEditorContainerView(frame: .zero)
        coordinator.setupContainer(
            container,
            text: "",
            language: .plainText,
            theme: .defaultLight,
            configuration: config,
            runtimeDependencies: EditorRuntimeDependencies()
        )
        return (coordinator, container, editorState)
    }

    #if canImport(AppKit)
    @Test("AppKit mount with useHardwareAcceleration true publishes true")
    func appKitMountWithKnobOn() {
        let (_, _, state) = makeFixture(useHardwareAcceleration: true)
        #expect(state.hardwareAccelerationActive == true)
    }

    @Test("AppKit mount with useHardwareAcceleration false publishes false")
    func appKitMountWithKnobOff() {
        let (_, _, state) = makeFixture(useHardwareAcceleration: false)
        #expect(state.hardwareAccelerationActive == false)
    }
    #else
    @Test("UIKit mount publishes true regardless of knob")
    func uiKitMountIgnoresKnob() {
        let (_, _, state) = makeFixture(useHardwareAcceleration: false)
        #expect(state.hardwareAccelerationActive == true)
    }
    #endif

    #if canImport(AppKit)
    @Test("Sticky at mount: later updateContainer with flipped knob does not toggle the mirror")
    func stickyAtMount() {
        let (coordinator, container, state) = makeFixture(useHardwareAcceleration: true)
        #expect(state.hardwareAccelerationActive == true)

        var flipped: EditorConfiguration = .default
        flipped.performance.useHardwareAcceleration = false
        coordinator.updateContainer(
            container,
            text: "",
            language: .plainText,
            theme: .defaultLight,
            configuration: flipped,
            runtimeDependencies: EditorRuntimeDependencies()
        )
        #expect(state.hardwareAccelerationActive == true)
    }
    #endif
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter EditorStateHardwareMirrorTests 2>&1 | tail -20`
Expected: FAIL — the mirror is still `false` after mount (`hardwareAccelerationActive == false` on the AppKit-true case).

- [ ] **Step 3: Commit failing tests**

```bash
git add Tests/CodeEditorPluginTests/Core/EditorStateHardwareMirrorTests.swift
git commit -m "$(cat <<'EOF'
Tests: EditorState.hardwareAccelerationActive mirror integration (red)

Red tests for the sticky-at-mount contract — knob on/off on AppKit,
always-true on UIKit, and no live-flip via subsequent updateContainer.
Wiring lands next.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Wire the `hardwareAccelerationActive` mirror write

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift`

- [ ] **Step 1: Add the mirror write in `setupContainer`**

In `setupContainer`, after the existing `updateState(...)` call (around line 368), add:

```swift
// Mirror the effective hardware-acceleration state once at mount.
// Sticky — live config changes do not toggle this field. UIKit views
// are always layer-backed by definition; AppKit reflects the knob.
if let hostEditorState {
    #if canImport(AppKit)
    let effective = configuration.performance.useHardwareAcceleration
    #else
    let effective = true
    #endif
    if hostEditorState.hardwareAccelerationActive != effective {
        hostEditorState.hardwareAccelerationActive = effective
    }
}
```

- [ ] **Step 2: Run the integration tests — expect green**

Run: `swift test --filter EditorStateHardwareMirrorTests 2>&1 | tail -10`
Expected: PASS — 3 tests pass (AppKit), or 1 test passes (UIKit).

- [ ] **Step 3: Re-run the dirty mirror tests for regression**

Run: `swift test --filter EditorStateDirtyMirrorTests 2>&1 | tail -10`
Expected: PASS — 5 tests pass.

- [ ] **Step 4: Build + lint**

Run: `swift build --target CodeEditorPlugin && swiftlint --fix && swiftlint 2>&1 | tail -5`
Expected: build succeeds; 0 violations.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift
git commit -m "$(cat <<'EOF'
EditorState: write hardwareAccelerationActive once at mount

Sticky-at-mount mirror — AppKit reflects useHardwareAcceleration,
UIKit always true. updateContainer ignores subsequent knob flips.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Gate `wantsLayer` on the main text view + scroll view

**Files:**
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+PerformanceExtensions.swift:37,40`
- Modify: `Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift:147,150`

These two files set `wantsLayer = true` on the same conceptual surfaces (text view + its scroll view) from different setup entry points.

- [ ] **Step 1: Inspect both files to confirm context**

Run:
```bash
sed -n '30,45p' Sources/CodeEditorPlugin/Core/CodeEditorView+PerformanceExtensions.swift
echo "---"
sed -n '140,160p' Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift
```

Expected: Each shows a `wantsLayer = true` write with surrounding context. Note whether `configuration` is in scope.

- [ ] **Step 2: Replace `wantsLayer = true` in `CodeEditorView+PerformanceExtensions.swift`**

Find the block around line 37-40:

```swift
if let scrollView = enclosingScrollView {
    scrollView.wantsLayer = true
    scrollView.canDrawSubviewsIntoLayer = true
}
wantsLayer = true
```

Replace with:

```swift
let useHWAccel = configuration.performance.useHardwareAcceleration
if let scrollView = enclosingScrollView {
    HardwareAcceleration.apply(useHWAccel, to: scrollView)
    scrollView.canDrawSubviewsIntoLayer = useHWAccel
}
HardwareAcceleration.apply(useHWAccel, to: self)
```

(If `configuration` is not in scope at this method, read the method's `configuration` parameter from its signature — `setupTextKit2Optimization()` is usually called with a `configuration` argument. Check the actual signature with `grep -n "setupTextKit2Optimization" Sources/CodeEditorPlugin/Core/CodeEditorView+PerformanceExtensions.swift`. If it doesn't take config, use `self.configuration.performance.useHardwareAcceleration` since `CodeEditorView` has `public var configuration: EditorConfiguration` at line 249.)

- [ ] **Step 3: Replace `wantsLayer = true` in `TextKitSetupHelper.swift`**

Find lines 147 and 150 — they set `scrollView.wantsLayer = true` and `textView.wantsLayer = true` respectively. Replace with `HardwareAcceleration.apply` calls. The TextKitSetupHelper takes a configuration parameter (verify with `grep -n "func setup\|func configure\|config:" Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift | head -10`).

Use the configuration's `performance.useHardwareAcceleration`:

```swift
HardwareAcceleration.apply(configuration.performance.useHardwareAcceleration, to: scrollView)
// ...
HardwareAcceleration.apply(configuration.performance.useHardwareAcceleration, to: textView)
```

- [ ] **Step 4: Build + run hardware-mirror tests**

Run: `swift build --target CodeEditorPlugin && swift test --filter EditorStateHardwareMirrorTests 2>&1 | tail -10`
Expected: build succeeds; tests still pass.

- [ ] **Step 5: Lint**

Run: `swiftlint --fix && swiftlint 2>&1 | tail -5`
Expected: 0 violations.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/Core/CodeEditorView+PerformanceExtensions.swift \
        Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift
git commit -m "$(cat <<'EOF'
Gate wantsLayer on main text view + scroll view via HardwareAcceleration

The two setup entry points (PerformanceExtensions.setupTextKit2Optimization,
TextKitSetupHelper) both unconditionally set wantsLayer = true. Now they
gate on useHardwareAcceleration and canDrawSubviewsIntoLayer rides
alongside the same gate.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Gate `wantsLayer` on the container view

**Files:**
- Modify: `Sources/CodeEditorPlugin/Layout/ContainerViewInitializer.swift:109`

- [ ] **Step 1: Inspect the call site**

Run: `sed -n '100,115p' Sources/CodeEditorPlugin/Layout/ContainerViewInitializer.swift`
Expected: see `container.wantsLayer = true` at line 109, in `performCommonSetup` or similar. Note whether `container.configuration` is accessible (it is — `container` is the `CodeEditorContainerView` and has `var configuration: EditorConfiguration`).

- [ ] **Step 2: Replace the assignment**

Change line 109 from:
```swift
container.wantsLayer = true
```
to:
```swift
HardwareAcceleration.apply(container.configuration.performance.useHardwareAcceleration, to: container)
```

- [ ] **Step 3: Build + lint + commit**

```bash
swift build --target CodeEditorPlugin && swiftlint --fix && swiftlint
git add Sources/CodeEditorPlugin/Layout/ContainerViewInitializer.swift
git commit -m "$(cat <<'EOF'
Gate wantsLayer on container view via HardwareAcceleration

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Gate `wantsLayer` on minimap and gutter (multiple sites)

**Files:**
- Modify: `Sources/CodeEditorPlugin/Layout/GutterView.swift:144`
- Modify: `Sources/CodeEditorPlugin/Layout/MinimapView.swift:255`
- Modify: `Sources/CodeEditorPlugin/Layout/ContainerViewInitializer.swift:157`
- Modify: `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift:165`

GutterView and MinimapView set `wantsLayer = true` from inside their own AppKit `init` paths — at construction time the configuration is not yet known. The container sets it again on these views after construction (via ContainerViewInitializer:157 and CodeEditorContainerView+AppKitExtensions:165) once the configuration *is* known.

The strategy:
1. **Leave the in-init `wantsLayer = true` writes alone** — they're harmless because the default knob is `true`, and removing them creates a transient layer-less window during construction.
2. **Gate the post-construction writes** (ContainerViewInitializer:157, CodeEditorContainerView+AppKitExtensions:165) so they can flip layer-backing off when the knob is `false`.
3. **Make the in-init writes themselves go through the helper** for consistency and so the return value can be ignored uniformly.

- [ ] **Step 1: Inspect each line of context**

Run:
```bash
sed -n '140,150p' Sources/CodeEditorPlugin/Layout/GutterView.swift
echo "---"
sed -n '250,260p' Sources/CodeEditorPlugin/Layout/MinimapView.swift
echo "---"
sed -n '150,165p' Sources/CodeEditorPlugin/Layout/ContainerViewInitializer.swift
echo "---"
sed -n '160,170p' Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift
```

- [ ] **Step 2: In `GutterView.swift:144`, replace**

```swift
wantsLayer = true
```
with:
```swift
HardwareAcceleration.apply(true, to: self)
```

(Inside the init, no config is in scope; defaulting to `true` mirrors the prior unconditional behavior. The container's later write — gated by config — overrides.)

- [ ] **Step 3: In `MinimapView.swift:255`, do the same substitution**

```swift
wantsLayer = true
```
→
```swift
HardwareAcceleration.apply(true, to: self)
```

- [ ] **Step 4: In `ContainerViewInitializer.swift:157`, replace**

```swift
components.minimapView.wantsLayer = true
```
with:
```swift
HardwareAcceleration.apply(
    container.configuration.performance.useHardwareAcceleration,
    to: components.minimapView
)
```

Also, in the same function, find the gutter view (`components.gutterView`) and add the same call alongside (it currently inherits its layer-backing only from its own init):

```swift
HardwareAcceleration.apply(
    container.configuration.performance.useHardwareAcceleration,
    to: components.gutterView
)
```

(Verify the assignment fits the surrounding scope — `container` should be available since this function operates on a container in `performCommonSetup`. If not, plumb it or move the gutter call to a site that has both.)

- [ ] **Step 5: In `CodeEditorContainerView+AppKitExtensions.swift:165`, replace**

```swift
minimapView.wantsLayer = true
```
with:
```swift
HardwareAcceleration.apply(configuration.performance.useHardwareAcceleration, to: minimapView)
```

(`configuration` is on the container via `self.configuration`. Use `self.configuration.performance.useHardwareAcceleration` if the bare `configuration` is ambiguous.)

- [ ] **Step 6: Build + run all integration tests for regression**

Run: `swift build --target CodeEditorPlugin && swift test --filter EditorState 2>&1 | tail -15`
Expected: build succeeds; all mirror tests still pass.

- [ ] **Step 7: Lint + commit**

```bash
swiftlint --fix && swiftlint
git add Sources/CodeEditorPlugin/Layout/GutterView.swift \
        Sources/CodeEditorPlugin/Layout/MinimapView.swift \
        Sources/CodeEditorPlugin/Layout/ContainerViewInitializer.swift \
        Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift
git commit -m "$(cat <<'EOF'
Gate wantsLayer on gutter + minimap via HardwareAcceleration

In-init writes default to true (preserves prior behavior). Container's
post-construction writes flow useHardwareAcceleration through, so flipping
the knob off actually disables layer-backing on the editor view family.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Tighten docstrings

**Files:**
- Modify: `Sources/CodeEditorPlugin/Core/EditorState.swift` (lines 25-30 area)
- Modify: `Sources/CodeEditorPlugin/Configuration/EditorConfiguration+PerformanceExtensions.swift:25 area`

- [ ] **Step 1: Update `EditorState.isDirty` docstring**

In `Sources/CodeEditorPlugin/Core/EditorState.swift`, find:

```swift
/// True when the active document has unsaved changes.
public var isDirty: Bool
```

Replace the docstring with:

```swift
/// True when the editor view has observed an edit since its current
/// bound content was installed. View-local — the host owns
/// document-level dirty tracking (e.g., across tabs). Resets on
/// initial mount, on host-driven binding swap, on
/// `EditorController.markClean()`, and on edits that return content
/// to the baseline (covers undo).
public var isDirty: Bool
```

- [ ] **Step 2: Update `EditorState.hardwareAccelerationActive` docstring**

In the same file, find:

```swift
/// Reflects the editor's *actual* hardware-acceleration state — what's
/// running, not what's configured. Status bar reads this so the UI
/// shows truth.
public var hardwareAccelerationActive: Bool
```

Replace with:

```swift
/// Reflects the editor's hardware-acceleration state applied at mount.
/// iOS: always `true` (UIView is layer-backed by definition). macOS:
/// reflects `EditorConfiguration.Performance.useHardwareAcceleration`
/// at the time the editor mounted; live config changes after mount do
/// not toggle this field.
public var hardwareAccelerationActive: Bool
```

- [ ] **Step 3: Update `useHardwareAcceleration` docstring**

In `Sources/CodeEditorPlugin/Configuration/EditorConfiguration+PerformanceExtensions.swift`, find the existing declaration around line 25:

```bash
grep -n "useHardwareAcceleration" Sources/CodeEditorPlugin/Configuration/EditorConfiguration+PerformanceExtensions.swift
```

Update the docstring above the property to:

```swift
/// Gates `wantsLayer` on the editor's `NSView` instances at mount
/// (macOS). No effect on iOS — `UIView` is always layer-backed. The
/// applied outcome is published via
/// `EditorState.hardwareAccelerationActive`.
public var useHardwareAcceleration: Bool = true
```

(Preserve the existing default `= true` exactly.)

- [ ] **Step 4: Update the top-of-file editor-written contract on `EditorState`**

Still in `Sources/CodeEditorPlugin/Core/EditorState.swift`, find the docstring block on lines 4-15:

```swift
/// Chrome views (`EditorStatusBar`, `EditorBreadcrumbView`, `EditorTitleBar`)
/// observe this object via `\.editorState` in the SwiftUI environment and
/// re-render when fields they read mutate. The editor target writes
/// `selection`, `language`, `isDirty`, `hardwareAccelerationActive`, and
/// `lineCount`; the host writes the rest (`documentName`, `documentURL`,
/// `tabs`, `activeTabID`, `breadcrumbPath`, `workspaceName`).
```

The contract sentence is now true (all five fields are written), so no edit is required to this paragraph. Just verify it remains accurate.

- [ ] **Step 5: Lint + commit**

```bash
swiftlint --fix && swiftlint
git add Sources/CodeEditorPlugin/Core/EditorState.swift \
        Sources/CodeEditorPlugin/Configuration/EditorConfiguration+PerformanceExtensions.swift
git commit -m "$(cat <<'EOF'
Docstrings: tighten EditorState.isDirty + hardwareAccelerationActive + knob contract

isDirty is view-local with four reset triggers; hardwareAccelerationActive
is sticky at mount and platform-aware. Knob docstring records the actual
behavior on AppKit vs UIKit and points consumers at the mirror.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Final verification sweep

- [ ] **Step 1: Full build**

Run: `swift build 2>&1 | tail -5`
Expected: build succeeds.

- [ ] **Step 2: Sample-app build**

Run: `swift build --target CodeEditorSample 2>&1 | tail -5`
Expected: build succeeds.

- [ ] **Step 3: Strict lint**

Run: `swiftlint --fix && swiftlint 2>&1 | tail -10`
Expected: 0 violations.

- [ ] **Step 4: Full test suite**

Run: `swift test --parallel 2>&1 | tail -30`
Expected:
- All new tests pass (`DirtyTrackerTests`, `HardwareAccelerationTests`, `EditorStateDirtyMirrorTests`, `EditorStateHardwareMirrorTests`).
- No regressions in existing tests beyond the pre-existing failures documented in `NEXT.md` § D (`LineGeometryStoreBenchmarkTests.testFuzzIncrementalEditCorrectness`, `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap`, `SyntaxHighlightingTests.testRegexHighlighter*`, `EditorStatusBarSnapshots/*`, `PerformanceObservationTests.restartAfterStopResumesRefreshTicks`, `PerformanceInsightsRealMetricsTests.currentFPSReflectsInjectedMonitor`).

- [ ] **Step 5: Update NEXT.md to mark B.3 done**

Edit `NEXT.md` § B.3 (around line 84) to strike through the entry and link to the design + plan:

```markdown
### ~~B.3 `EditorState.isDirty` and `EditorState.hardwareAccelerationActive` never written~~ — done
Closed. `EditorState.isDirty` now flows from a `DirtyTracker` driven by
`CodeEditorBaseCoordinator` with four reset triggers (initial mount,
host binding swap, `EditorController.markClean()`, edit back to baseline).
`EditorState.hardwareAccelerationActive` is now written once at mount
from `EditorConfiguration.Performance.useHardwareAcceleration` on macOS
(always `true` on iOS — UIView is layer-backed) and the knob actually
gates `wantsLayer` across the editor's view family. Sticky at mount.
Spec: `docs/superpowers/specs/2026-05-15-editor-state-mirror-completion-design.md`;
plan: `docs/superpowers/plans/2026-05-15-editor-state-mirror-completion.md`.
```

- [ ] **Step 6: Final commit**

```bash
git add NEXT.md
git commit -m "$(cat <<'EOF'
NEXT.md: mark B.3 (EditorState mirror completion) done

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Notes

**Spec coverage:**
- Thread 1 (`isDirty` framework-computed with baseline + 4 reset triggers): Tasks 1, 3, 4, 5 cover the type, the storage, the test surface, and the wiring across `setupContainer` / `updateContainer` / `updateState` / `markClean`.
- Thread 2 (`hardwareAccelerationActive` wire-the-knob, sticky at mount): Tasks 2, 6, 7, 8, 9, 10 cover the helper, the mirror write, and the four conceptual call sites (expanded to seven actual source lines).
- Docstring tightenings: Task 11.
- Verification commands (spec § Verification): Task 12.

**Type / signature consistency:**
- `DirtyTracker` methods called identically across Task 1 (tests + impl), Task 5 step 1 (coordinator property), step 2 (`setBaseline`), step 3 (`setBaseline`), step 4 (`isDirty(currentText:)`), step 5 (`markClean(currentText:)`).
- `HardwareAcceleration.apply(_:to:)` signature consistent across Task 2 (def), Tasks 8/9/10 (call sites).
- `EditorController.markClean()` signature is `public func markClean()` everywhere it's referenced (Task 4 test, Task 5 step 7 declaration, Task 12 NEXT.md prose).
- `CodeEditorView.coordinator` weak ref + `applyMarkClean()` extension method: declared in Task 3 and Task 5 step 6, called in Task 5 step 7.

**Placeholder scan:** No "TBD" / "TODO" / "etc." / "and so on" tokens in any step. Each code block is concrete and copy-pasteable. The single "verify line is correct via `grep`" cases (Task 8 step 2, Task 11 step 3) are explicit instructions to run a real command, not placeholders for missing details.

**Plan deviation from spec, documented:** The spec said "tracker lives on the view" (Surface changes → "Modified: `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`"). The plan moves the tracker to the coordinator instead, because `CodeEditorBaseCoordinator.updateState` — the existing mirror site that already writes `selection` / `language` / `lineCount` — does not take a view parameter. Putting the tracker on the coordinator lets the existing mirror pass evaluate it directly. The view holds only a weak back-pointer (`CodeEditorView.coordinator`) so `EditorController.markClean()` can route through. Behavior identical to the spec; storage location different.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-15-editor-state-mirror-completion.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
