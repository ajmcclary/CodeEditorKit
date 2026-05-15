# EditorState Mirror Completion — Design

**Status:** Ready for implementation plan.
**Date:** 2026-05-15
**Closes:** `NEXT.md` B.3 — `EditorState.isDirty` and `EditorState.hardwareAccelerationActive` are documented as editor-written but have no writer in `Sources/CodeEditorPlugin/`. Chrome views read them and get a constant `false`.

## Problem

`EditorState` (`Sources/CodeEditorPlugin/Core/EditorState.swift:18`) is the `@MainActor @Observable` mirror that chrome views (`EditorStatusBar`, `EditorBreadcrumbView`, `EditorTitleBar`) observe via the SwiftUI environment. Its docstring says the editor target writes `selection`, `language`, `isDirty`, `hardwareAccelerationActive`, and `lineCount`. Three of those five are wired through `CodeEditorBaseCoordinator.updateState(_:language:configuration:)` and `handleSelectionChange(_:)` in `SwiftUI/CodeEditor+CoordinatorsExtensions.swift`. The remaining two have no writer anywhere in the framework target.

A related ghost: `EditorConfiguration.Performance.useHardwareAcceleration` (`Configuration/EditorConfiguration+PerformanceExtensions.swift:25`) defaults to `true` but is never read. `wantsLayer = true` is set unconditionally in four sites (see Surface changes below). The knob doesn't gate anything.

## Goal

Make both unwritten fields publish accurate values. Make the hardware-acceleration knob actually do something. Tighten the docstrings so the contracts are honest.

## Non-goals

- **No new event types.** `UnifiedEventSystem` does not get a `TextDirtyEvent`. Chrome already observes `editorState.isDirty` through `@Observable` and re-renders.
- **No host override of `editorState.isDirty`.** Framework owns it; the host computes its own document-level dirty separately (the sample's `TabModel.isDirty` is unchanged).
- **No content fingerprinting for very large files.** Baseline comparison is O(n) string equality. Hash-based optimization is a future tweak with no API change.
- **No live config re-application for hardware acceleration.** The knob is read at mount; not re-watched.
- **No iOS-simulator build gate.** That's a B.1 concern; not in scope here.
- **No retroactive change to the three currently-mirrored fields.** Just adds the two new writes.
- **No rendering-correctness verification with `wantsLayer = false`.** This work makes the knob real; verifying the CPU-rendered path is correct under all view-tree conditions is a separate effort.

## Approach

Two threads share one spec. They touch the same coordinator and ship together.

### Thread 1: `isDirty` — framework computes against a baseline

`EditorState.isDirty` becomes "the editor view has observed an edit since its current bound content was installed." Explicitly **view-local**, not document-level. The sample's `TabModel.isDirty` continues to track cross-tab persistence dirty independently. The two coexist; the docstring will say so.

A small value-type `DirtyTracker` owns the baseline string. `CodeEditorBaseCoordinator` holds one instance and writes `editorState.isDirty` from the tracker on every text/selection/language sync (i.e., the existing `updateState` pass). Baseline resets:

1. **Initial text install at mount** (`setupContainer`) — set baseline, write `isDirty = false`.
2. **Host-driven binding swap** (`updateContainer` branch that detects `text != storage`) — set baseline to the new text, write `isDirty = false`. By construction this branch is host-driven; user edits write to storage via the delegate before the binding update propagates back through SwiftUI.
3. **Explicit `markClean()`** — new public method on `EditorController`. Hosts call it after a successful save.
4. **Undo back to baseline content** — falls out for free. Undo lands in the text-mutation delegate path, which fires `updateState`, which re-evaluates `tracker.isDirty(currentText:)`. If current matches baseline, the mirror flips back to `false`.

### Thread 2: `hardwareAccelerationActive` — wire the config knob, sticky at mount

A new `HardwareAcceleration` helper namespace replaces the unconditional `wantsLayer = true` writes at four sites. AppKit gates `wantsLayer` on `useHardwareAcceleration`; UIKit is a no-op (UIView is always layer-backed). The coordinator writes `editorState.hardwareAccelerationActive` once during `setupContainer`: `useHardwareAcceleration` on AppKit, hard-coded `true` on UIKit. The mirror is **sticky at mount** — live config changes do not toggle it. The docstring will say so.

## Surface changes

### New file: `Sources/CodeEditorPlugin/Core/DirtyTracker.swift`

```swift
/// View-local dirty tracker. The framework's coordinator owns one instance per
/// editor and asks it after every text-mutation sync whether the current content
/// differs from the baseline.
///
/// Baseline is set on initial text install, on host-driven binding swap, and
/// on explicit `markClean(currentText:)`. Returns `false` when no baseline has
/// been set (pre-mount initial state).
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

Internal to the framework. Not public surface.

### New file: `Sources/CodeEditorPlugin/Performance/HardwareAcceleration.swift`

```swift
/// Gate hardware-accelerated rendering on a platform view. AppKit only — UIKit
/// views are always layer-backed by definition.
///
/// Returns the effective value (the input on AppKit, `true` on UIKit). The
/// caller uses the return value to record what was actually applied.
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

### Modified: `Sources/CodeEditorPlugin/Core/EditorState.swift`

Docstring on `isDirty` tightened from:

> True when the active document has unsaved changes.

to:

> True when the editor view has observed an edit since its current bound
> content was installed. View-local — the host owns document-level dirty
> tracking (e.g., across tabs). See `DirtyTracker` for the reset triggers.

Docstring on `hardwareAccelerationActive` tightened from:

> Reflects the editor's *actual* hardware-acceleration state — what's running,
> not what's configured. Status bar reads this so the UI shows truth.

to:

> Reflects the editor's hardware-acceleration state applied at mount. iOS:
> always `true` (UIView is layer-backed). macOS: reflects
> `EditorConfiguration.Performance.useHardwareAcceleration` at the time the
> editor mounted; live config changes after mount do not toggle this field.

### Modified: `Sources/CodeEditorPlugin/Configuration/EditorConfiguration+PerformanceExtensions.swift`

Docstring on `useHardwareAcceleration` updated to:

> Gates `wantsLayer` on the editor's `NSView` instances at mount (macOS). No
> effect on iOS — `UIView` is always layer-backed. The applied outcome is
> published via `EditorState.hardwareAccelerationActive`.

No default change. Stays `true`.

### Modified: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift`

`CodeEditorBaseCoordinator` gains:

```swift
private var dirtyTracker = DirtyTracker()
```

`setupContainer` (existing — currently calls `updateState` on initial text install):

- After the initial text is installed in storage, call `dirtyTracker.setBaseline(text)`.
- During the existing `updateState` pass, write `editorState.isDirty = false` (baseline was just set; current == baseline).
- Add the new mirror write:

  ```swift
  #if canImport(AppKit)
  hostEditorState.hardwareAccelerationActive = configuration.performance.useHardwareAcceleration
  #else
  hostEditorState.hardwareAccelerationActive = true
  #endif
  ```

`updateContainer` (existing — currently has a branch that detects `text != storage` and applies):

- Inside the existing apply branch, call `dirtyTracker.setBaseline(newText)` after the text is written into storage. The subsequent `updateState` call will see `isDirty == false`.

`updateState` (existing — currently writes `language` and `lineCount`):

- Reuse the pass that already walks the new text for `lineCount` to evaluate the tracker:

  ```swift
  let dirty = dirtyTracker.isDirty(currentText: text)
  if hostEditorState.isDirty != dirty {
      hostEditorState.isDirty = dirty
  }
  ```

  Same equality-gated write pattern the existing three mirrors use.

### Modified: `Sources/CodeEditorPlugin/Core/EditorController.swift`

New public method:

```swift
/// Reset the framework's view-local dirty tracker. Hosts call this after a
/// successful save, or any other time the current text should be treated as
/// the new clean baseline. Writes `editorState.isDirty = false`. No-op if the
/// editor is not currently mounted.
public func markClean()
```

Forwards to the coordinator, which calls `dirtyTracker.markClean(currentText: storage.currentText)` and writes `editorState.isDirty = false`.

### Modified: four `wantsLayer = true` sites

Each `view.wantsLayer = true` (and the scroll-view's adjacent `canDrawSubviewsIntoLayer = true`) is rewritten as `HardwareAcceleration.apply(useHardwareAcceleration, to: view)`. The bool comes from `configuration.performance.useHardwareAcceleration` at the caller.

| File | Today | After |
|---|---|---|
| `CodeEditorView+PerformanceExtensions.swift:37-40` | `scrollView.wantsLayer = true`; `scrollView.canDrawSubviewsIntoLayer = true`; `wantsLayer = true` | All three gated on `configuration.performance.useHardwareAcceleration` |
| `Layout/ContainerViewInitializer.swift:72-73` | `wantsLayer = true` | `HardwareAcceleration.apply(useHardwareAcceleration, to: container)` |
| `Layout/GutterView.swift:11` | `wantsLayer = true` in init | Init gains `useHardwareAcceleration: Bool` parameter; helper called from init |
| `Layout/MinimapView.swift:22-23` | `wantsLayer = true` in init | Init gains `useHardwareAcceleration: Bool` parameter; helper called from init |

`GutterView` and `MinimapView` need the value threaded in from their construction site (the container). One-line constructor-signature change per view, plus the container forwards the existing `configuration.performance.useHardwareAcceleration` it already holds.

## Data flow & lifecycle

**Mount (`setupContainer`):**
1. Initial text is installed in storage (existing path).
2. `dirtyTracker.setBaseline(text)`.
3. Mirror writes: `selection`, `language`, `lineCount` (existing), `isDirty = false` (new), `hardwareAccelerationActive = effectiveHWValue` (new).

**Host binding swap (`updateContainer`, `text != storage` branch):**
1. New text written into storage (existing).
2. `dirtyTracker.setBaseline(newText)`.
3. `updateState` runs (existing) and writes `isDirty = false`.

**User edit (delegate path):**
1. Storage mutates (existing).
2. `updateState` runs (existing) and writes `isDirty = tracker.isDirty(currentText:)` (new). If the edit happens to land back on baseline content, the mirror flips back to `false` without any special case.

**Save (`editorController.markClean()`):**
1. Host calls `markClean()` after persisting.
2. Coordinator: `dirtyTracker.markClean(currentText: storage.currentText)`; writes `editorState.isDirty = false`.

**Config knob flipped mid-session:** ignored for hardware acceleration. `editorState.hardwareAccelerationActive` does not change. (Documented; tested.)

**Tab switch in the sample:** the sample binds a new tab's text into the editor's binding → SwiftUI propagates → `updateContainer` detects `text != storage` → baseline reset to the new tab's content → `isDirty = false`. The sample's `TabModel.isDirty` continues to publish the document-level state for the tab bar; the two are independent and intentionally so.

## Error handling

Neither thread introduces new error surfaces.

- `DirtyTracker` is total: every method is defined for every input. No throwing.
- `HardwareAcceleration.apply` is total. No throwing.
- `markClean()` is a no-op if the editor is not currently mounted (mirrors how other controller methods handle unmounted state — no error, no log spam).

No changes to `CodeEditorError` or any other error type.

## Testing

Four new test files. Conventions follow existing tests under `Tests/CodeEditorPluginTests/Core/`.

### 1. `Tests/CodeEditorPluginTests/Core/DirtyTrackerTests.swift` — Swift Testing, pure unit

- Initial state (no baseline set): `isDirty(currentText:)` returns `false` regardless of input.
- `setBaseline("hello")` then `isDirty(currentText: "hello")` → `false`.
- `setBaseline("hello")` then `isDirty(currentText: "world")` → `true`.
- Undo-back-to-baseline: `setBaseline("a")`, dirty for `"ab"`, clean again for `"a"`.
- `markClean(currentText: "world")` after baseline `"hello"`: dirty for `"hello"`, clean for `"world"`.
- `setBaseline` overwrites a prior baseline.

### 2. `Tests/CodeEditorPluginTests/Core/EditorStateDirtyMirrorTests.swift` — Swift Testing `@MainActor`

Integration through `CodeEditorBaseCoordinator`. Builds a coordinator with a fresh `EditorState` and exercises each reset trigger.

- After `setupContainer` with known initial text → `editorState.isDirty == false`.
- Simulated user edit through the text-mutation seam → `editorState.isDirty == true`.
- Subsequent edit that returns content to baseline → `editorState.isDirty == false`.
- `updateContainer` with new text after a dirty edit → `editorState.isDirty == false`; tracker accepts new baseline.
- `editorController.markClean()` after a dirty edit → `editorState.isDirty == false`; the next edit flips back to `true`.

### 3. `Tests/CodeEditorPluginTests/Performance/HardwareAccelerationTests.swift` — Swift Testing

Conditional on platform.

- `#if canImport(AppKit)`: `HardwareAcceleration.apply(true, to: NSView())` returns `true`, view's `wantsLayer == true`. Same with `false` → returns `false`, view's `wantsLayer == false`.
- `#else`: `HardwareAcceleration.apply(false, to: UIView())` returns `true` (no-op + UIView is always layer-backed).

### 4. `Tests/CodeEditorPluginTests/Core/EditorStateHardwareMirrorTests.swift` — Swift Testing `@MainActor`

Integration through `CodeEditorBaseCoordinator`. Sticky-at-mount contract.

- macOS, mount with `useHardwareAcceleration: true` → `editorState.hardwareAccelerationActive == true`.
- macOS, mount with `useHardwareAcceleration: false` → `editorState.hardwareAccelerationActive == false`.
- iOS (`#if !canImport(AppKit)`), mount with `useHardwareAcceleration: false` → `editorState.hardwareAccelerationActive == true`.
- After mount, a subsequent `updateContainer` with a flipped config → mirror does **not** change (sticky-at-mount contract).

### Existing tests

The three mirror writes (`selection`, `language`, `lineCount`) are unchanged. Any test that constructs a fresh `EditorState` and asserts `isDirty == false` or `hardwareAccelerationActive == false` based on the initial-value contract continues to pass (the defaults in `EditorState.init()` are unchanged). Any test that asserted "always false" after edits would need updating, but a code search did not find any.

## Verification

- `swift build` — green.
- `swift build --target CodeEditorPlugin` — green.
- `swift build --target CodeEditorSample` — green.
- `swiftlint --fix && swiftlint` — green (no new violations; strict mode is on).
- `swift test --parallel` — no regressions beyond the pre-existing failures documented in `NEXT.md` § D.

## Open questions

None. The two semantic choices are locked (framework-owned baseline with the four reset triggers; wire-the-knob plus sticky-at-mount mirror). The test surface is enumerated. The new files and modified sites are listed.

## Risk register

- **`wantsLayer = false` opts users into a CPU-rendered path that is currently untested.** The gate is correct (tested), but the *consequences* of running with it off — gutter alignment, scroll smoothness, minimap rendering — have never been exercised together. The default stays `true`, so this affects only users who explicitly opt out. Out of scope to verify the off-path; in scope to make it reachable.
- **`EditorState.isDirty` and `TabModel.isDirty` are different beasts.** Future contributors could wire the framework's mirror directly to a tab indicator and be surprised when it resets on tab switch. Mitigation: the tightened docstring + this spec record the semantic clearly.
- **`markClean()` reachability via `EditorController`.** Assumes `EditorController` can route to the coordinator that owns the tracker, consistent with how other controller methods reach the coordinator today. If that wiring needs a new seam, it surfaces in the plan; not a design re-do.
- **Sticky-at-mount HW accel may surprise.** Users who flip the config knob mid-session see no effect. Recorded contract; documented in both docstrings; tested.
