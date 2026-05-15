# EventLog Panel — Design

**Status:** Approved, ready for implementation plan.
**Date:** 2026-05-14
**Closes:** `NEXT.md` § A.1 ("Event stream invisible — the natural next headline gap"), with partial coverage of § A.3 #7 (iOS feature parity) for the inspector surface.

## Problem

The framework exposes a `UnifiedEventSystem` and an `.eventSystem(_:)` SwiftUI modifier as first-class API for observing editor events (`textDidChange`, `textSelectionDidChange`, `didBecome/ResignFirstResponder`, completion, annotation, error). The sample app's three existing inspector panels (LSP, Completion, Performance) demonstrate every other framework subsystem but the event stream — a consumer reading the sample has no way to see what `.eventSystem(_:)` actually delivers.

Two compounding issues make the gap worse than "missing UI":

1. **The `.eventSystem(_:)` modifier is decorative today.** It writes a `UnifiedEventSystem` into the `\.codeEditorEventSystem` environment, and `CodeEditorView.publishEvent(_:)` is the fan-out hub that delivers events to it (`runtime.dependencies.eventSystem?.publish(event)`). But the three places in the framework that emit events use `eventPublisher.publishSync(...)` directly — bypassing the fan-out. The customer-supplied `UnifiedEventSystem` never receives an event.
2. **Only two of the ten `EditorEvent` cases are emitted anywhere.** `textDidChange` and `textSelectionDidChange` fire from `CodeEditorView+SyntaxHighlightingExtensions.swift` / `+ConfigurationExtensions.swift`. `didBecome/ResignFirstResponder` exist in the enum but no responder hook publishes them. Annotation and error cases are likewise unfired.

A panel that consumes `UnifiedEventSystem.events` today would render nothing. Building one without fixing (1) and (2) would ship a feature that confirms the user's suspicion that the event API is dead code.

## Goal

Land a sample-side **EventLog panel** that demonstrates `UnifiedEventSystem` as a live, useful API surface, and make the framework-side wiring honest enough to support it.

Concretely:

- **Sample**: `EventLogSampleCoordinator` + `EventLogPanel`, cross-platform (macOS + iOS), surfaced in `InspectorSidebar` on macOS and `IOSRootView` on iOS. Subscribes to `UnifiedEventSystem.events` (Combine) and `controller.completionEvents()` (AsyncSequence), maintains a 200-entry ring with category filter pills + Pause + Clear, and renders a virtualized timeline.
- **Framework**: convert three existing `eventPublisher.publishSync(...)` call sites to use the fan-out `publishEvent(_:)`, and add `publishEvent(.didBecomeFirstResponder)` / `publishEvent(.didResignFirstResponder)` in the responder hooks. Internal-only; no public API change.

## Non-goals

- **Wiring annotation events** (`annotationHovered`, `annotationClicked`). The enum cases exist but require routing decisions inside `AnnotationsHub` and the hit-test paths. Tracked separately. The `.annotation` event-log category is reserved for v2.
- **Wiring `error(SendableError)` / `performanceWarning`**. Same story — defined but unfired. `IssueReporting` already routes errors elsewhere; deciding whether `UnifiedEventSystem` should also receive them is a policy call outside this spec.
- **Converging `CompletionEventBroadcaster` onto `UnifiedEventSystem`** at the framework level. The two channels serve different consumers (typed AsyncSequence for completion-aware code, generic Combine for observers). The sample's coordinator bridges them in the UI; the framework's separation stays.
- **Refactoring `AppState`**. `AppState` already owns three coordinators; adding a fourth follows the existing god-object pattern. NEXT.md § A.3 #1 (AppState decomposition) is a separate spec.
- **Public API for the panel itself**. `EventLogSampleCoordinator` and `EventLogPanel` live in `Sources/CodeEditorSample/`. Promoting either to `CodeEditorUI` is a follow-up if a consumer asks.
- **Event detail drill-in / export / search**. The row `summary` field is the v1 surface. Tap-to-expand and export are deferred.

## Approach

Five changes, in three layers.

### Framework (internal, four edits)

1. **Convert call sites to `publishEvent(_:)`.** The fan-out helper already exists at `Sources/CodeEditorPlugin/Core/UnifiedEventSystem.swift:390`:

   ```swift
   extension CodeEditorView {
       public func publishEvent(_ event: EditorEvent) {
           eventPublisher.publishSync(event)
           runtime.dependencies.eventSystem?.publish(event)
       }
   }
   ```

   Three sites flip from `eventPublisher.publishSync(...)` to `publishEvent(...)`:

   - `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift:112` — macOS `.textDidChange(self.string)`.
   - `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift:114` — iOS `.textDidChange(self.text ?? "")`.
   - `Sources/CodeEditorPlugin/Core/CodeEditorView+ConfigurationExtensions.swift:121` — selection change.

2. **Publish focus transitions.** Override `becomeFirstResponder()` / `resignFirstResponder()` on `CodeEditorView` (both AppKit and UIKit specializations). After the super call returns true, fire `publishEvent(.didBecomeFirstResponder)` / `publishEvent(.didResignFirstResponder)`. Guard with the super-return check so the events match AppKit's actual responder state.

   On AppKit, `NSTextView` already overrides `becomeFirstResponder()`; `CodeEditorView` extends that override. On UIKit, `UITextView`'s versions live in its `UIResponder` ancestry. Both are main-thread by contract; `publishEvent` is safe to call directly.

### Sample (new code; cross-platform)

3. **`Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift`** — `@MainActor @Observable`. Owns the ring, subscriptions, and observable snapshot. Cross-platform (no `#if canImport(AppKit)` gate). See "Surface changes" below.

4. **`Sources/CodeEditorSample/Sidebars/EventLogPanel.swift`** — stateless SwiftUI view. Cross-platform. Takes flat snapshot fields plus action callbacks; no direct coordinator reference (mirrors `CompletionInspectorPanel`).

5. **Sidebar wiring.** `InspectorSidebar.swift` (macOS) adds an `eventLogPanel` between `AnnotationsInspectorPanel` and the config render block. `IOSRootView.swift` adds an "Events" entry inside its existing Inspectors tab. `AppState` gains `let eventSystem = UnifiedEventSystem()` and `let eventLog = EventLogSampleCoordinator()`, both ungated. `WindowBody.editorPane` and the iOS editor host both apply `.eventSystem(appState.eventSystem)` to the `CodeEditor` view.

## Surface changes

### `Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift` (new)

```swift
@MainActor
@Observable
final class EventLogSampleCoordinator {
    /// Source of an entry — drives the filter pills.
    enum EventCategory: String, CaseIterable, Sendable, Hashable {
        case text, selection, focus, completion
    }

    struct LoggedEvent: Identifiable, Sendable, Hashable {
        let id: UUID
        let timestamp: Date
        let category: EventCategory
        let summary: String
        let detail: String?   // populated for completion failures
    }

    struct Snapshot: Sendable {
        var entries: [LoggedEvent]                // newest-first, post-filter
        var totals: [EventCategory: Int]          // category → running count (pre-filter)
        var ringCount: Int                        // pre-filter ring size (≤ 200)
    }

    private static let ringCapacity = 200

    // MARK: - Observable surface
    private(set) var snapshot: Snapshot = .empty
    private(set) var paused: Bool = false
    private(set) var mutedCategories: Set<EventCategory> = []

    // MARK: - Lifecycle
    func attach(controller: EditorController, eventSystem: UnifiedEventSystem) { … }
    func detach() { … }

    // MARK: - Actions
    func setMuted(_ category: EventCategory, _ muted: Bool) { … }
    func setPaused(_ paused: Bool) { … }
    func clear() { … }
}
```

`attach` establishes two subscriptions:

- A Combine `sink` on `eventSystem.events` mapping `EditorEvent` → `LoggedEvent`. Stored as `AnyCancellable` (`@ObservationIgnored`).
- A `Task { @MainActor … for await event in controller.completionEvents() { … } }` mapping `CompletionEvent` → `LoggedEvent`. Task is cancelled in `detach()`.

Ring append semantics:

- Each subscription call goes through `private func append(_ entry: LoggedEvent)`.
- If `paused`, drop on the floor (do not buffer — pause means "freeze the view").
- Otherwise insert at end of internal `ring: [LoggedEvent]`; if `ring.count > ringCapacity`, drop oldest.
- Increment `totals[category]` (pre-filter; survives clear of the visible snapshot for the session — see Clear semantics).
- Recompute `snapshot.entries = ring.reversed().filter { !mutedCategories.contains($0.category) }`.
- Publish the new snapshot observably.

Clear semantics: `clear()` empties `ring` and `snapshot.entries` and resets `totals` to zero. This is "start fresh", not "clear the visible filter only" — matching the existing `CompletionInspectorPanel` Clear button.

`LoggedEvent.summary` is built per case (examples):

| Event | Summary |
|---|---|
| `.textDidChange(let text)` | `"textDidChange (len=\(text.utf16.count))"` |
| `.textSelectionDidChange(let r)` | `"selection=[loc=\(r.location), len=\(r.length)]"` |
| `.didBecomeFirstResponder` | `"didBecomeFirstResponder"` |
| `.didResignFirstResponder` | `"didResignFirstResponder"` |
| `CompletionEvent (succeeded)` | `"\(language.rawValue) → \(itemCount) items · \(ms)ms"` + trigger as detail |
| `CompletionEvent (failed)` | `"\(language.rawValue) failed"` + error description as `detail` |

### `Sources/CodeEditorSample/Sidebars/EventLogPanel.swift` (new)

Stateless SwiftUI view. Inputs (matching `CompletionInspectorPanel`'s shape):

```swift
struct EventLogPanel: View {
    let entries: [EventLogSampleCoordinator.LoggedEvent]
    let totals: [EventLogSampleCoordinator.EventCategory: Int]
    let mutedCategories: Set<EventLogSampleCoordinator.EventCategory>
    let paused: Bool

    var onToggleCategory: (EventLogSampleCoordinator.EventCategory) -> Void
    var onTogglePause: () -> Void
    var onClear: () -> Void
    var onAppear: () -> Void = {}
    var onDisappear: () -> Void = {}
    …
}
```

Body structure (single `VStack(alignment: .leading, spacing: 0)`):

1. `header` — "Events" title row.
2. `Divider`.
3. `pillsRow` — `HStack` of `CategoryPill` views (one per `EventCategory.allCases`), plus a trailing `Spacer`, plus Pause + Clear.
4. `Divider`.
5. `entriesList` — `List(entries)` (uses SwiftUI `List` for row virtualization; the other inspector panels use `VStack` because they cap at ≤20 items, but this panel routinely hits 200).
6. `emptyState` overlay when `entries.isEmpty`.

`CategoryPill` is a private nested view: capsule shape, dot + label + count (`"Text · 142"`), filled when active and outlined when muted. Active fill uses `Tokens.Color.EditorColors.accent` from `CodeEditorDesignTokens` so the panel incidentally exercises a design-token swatch — closes part of NEXT.md A.1 "design tokens" gap in passing.

Row format (monospaced 11pt; mirrors `CompletionInspectorPanel`):

```
HH:mm:ss.SSS  ●Text       textDidChange (len=42)
HH:mm:ss.SSS  ●Sel        selection=[loc=12, len=0]
HH:mm:ss.SSS  ●Focus      didBecomeFirstResponder
HH:mm:ss.SSS  ●Completion swift → 12 items · 4.3ms   tabs.toMain
```

Failed completion rows render a leading `Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)` and a `.help(detail ?? "")` tooltip — same pattern as `CompletionInspectorPanel.recentActivityView`.

Empty state: `"No events yet. Type to see textDidChange fire."`

### `Sources/CodeEditorSample/App/AppState.swift` (modified)

Add (ungated; cross-platform):

```swift
let eventSystem = UnifiedEventSystem()
let eventLog = EventLogSampleCoordinator()
```

In `init()`, after `editorController` is constructed, call:

```swift
eventLog.attach(controller: editorController, eventSystem: eventSystem)
```

`detach` is called from the coordinator's `deinit` path; `AppState` itself lives for the lifetime of the app.

### `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift` (modified, macOS)

(`InspectorSidebar` is `#if canImport(AppKit)`-only — the iOS sample renders the panel through `IOSRootView` instead.)

Insert between `AnnotationsInspectorPanel(...)` and the config `Text(rendered)` block:

```swift
EventLogPanel(
    entries: appState.eventLog.snapshot.entries,
    totals: appState.eventLog.snapshot.totals,
    mutedCategories: appState.eventLog.mutedCategories,
    paused: appState.eventLog.paused,
    onToggleCategory: { cat in
        appState.eventLog.setMuted(cat, !appState.eventLog.mutedCategories.contains(cat))
    },
    onTogglePause: { appState.eventLog.setPaused(!appState.eventLog.paused) },
    onClear: { appState.eventLog.clear() }
)
```

### `Sources/CodeEditorSample/iOS/IOSRootView.swift` (modified, iOS)

Add an "Events" row to the Inspectors tab list, pushing a `NavigationLink` to `EventLogPanel` configured the same way. The panel is layout-agnostic so no iOS-specific view variant is needed.

### `Sources/CodeEditorSample/App/WindowBody.swift` (macOS) and the iOS editor host (modified)

Add `.eventSystem(appState.eventSystem)` to the `CodeEditor` view modifier chain in `WindowBody.editorPane` (macOS) and the equivalent `CodeEditor` site in `IOSRootView` (iOS). This is what actually causes the framework to fan events out — without the modifier, `runtime.dependencies.eventSystem` stays nil and the new `publishEvent` calls noop on the fan-out side.

### Framework edits (internal)

`Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift`:

```swift
// Before
self.eventPublisher.publishSync(.textDidChange(self.string))
// After
self.publishEvent(.textDidChange(self.string))
```

(Two sites, macOS + iOS branches.)

`Sources/CodeEditorPlugin/Core/CodeEditorView+ConfigurationExtensions.swift:121`:

```swift
// Before
self.eventPublisher.publishSync(.textSelectionDidChange(currentSelection))
// After
self.publishEvent(.textSelectionDidChange(currentSelection))
```

Focus transitions — added overrides on `CodeEditorView` (file: `CodeEditorView+Responder.swift`, new):

```swift
#if canImport(AppKit)
extension CodeEditorView {
    open override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { publishEvent(.didBecomeFirstResponder) }
        return became
    }
    open override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { publishEvent(.didResignFirstResponder) }
        return resigned
    }
}
#elseif canImport(UIKit)
extension CodeEditorView {
    open override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { publishEvent(.didBecomeFirstResponder) }
        return became
    }
    open override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { publishEvent(.didResignFirstResponder) }
        return resigned
    }
}
#endif
```

The branches share an identical body shape but are platform-gated because `super` resolves to a different base class (`NSTextView` vs `UITextView`) under each compile path. Mirrors the existing `CodeEditorView` extension layout.

## Data flow

```
                            ┌────────────────────────┐
NSTextView responder ──────►│ publishEvent(focus*)   │──┐
publishEvent call sites ───►│ CodeEditorView         │  │
                            └────────────────────────┘  │
                                                        ▼
                            ┌────────────────────────┐
                            │ EditorEventPublisher   │ (local, Combine)
                            │ runtime.dependencies   │
                            │   .eventSystem?.publish│
                            └───────────┬────────────┘
                                        │
                                        ▼
                            ┌────────────────────────┐
                            │ UnifiedEventSystem     │ (sample-owned)
                            │ .events publisher      │
                            └───────────┬────────────┘
                                        │ Combine sink
                                        ▼
CompletionEventBroadcaster              │
   (controller.completionEvents)        │
              │ for-await Task          │
              └──────────┬──────────────┘
                         ▼
                ┌────────────────────────┐
                │ EventLogSampleCoordinator │
                │  ring (200) + totals       │
                │  mutedCategories + paused  │
                └───────────┬────────────────┘
                            ▼
                ┌────────────────────────┐
                │ EventLogPanel          │ (SwiftUI, virtualized List)
                └────────────────────────┘
```

Filter pills mutate `mutedCategories` post-hoc — events always enter the ring; pills only hide them from the snapshot. Pause is the only thing that drops events.

## Testing strategy

Three layers.

### Coordinator tests — `Tests/CodeEditorSampleTests/EventLog/EventLogSampleCoordinatorTests.swift`

Pure XCTest + swift-custom-dump. Each test constructs a fresh `EventLogSampleCoordinator`, a fresh `UnifiedEventSystem`, and a minimal `EditorController` stub. No SwiftUI.

- `appendsEditorEventsFromUnifiedSystem` — publish `.textDidChange("hello")`, assert one entry with `category == .text` and `summary == "textDidChange (len=5)"`.
- `appendsCompletionEvents` — feed a `CompletionEvent` via the controller stub's `AsyncStream` continuation, assert it lands in `.completion`.
- `ringCapsAt200` — publish 250 selection events; assert `snapshot.ringCount == 200` and the oldest dropped.
- `mutedCategoryHiddenFromSnapshotButTotalsUpdate` — publish 5 text events, call `setMuted(.text, true)`, assert `snapshot.entries.isEmpty` and `snapshot.totals[.text] == 5`.
- `pausedDropsEvents` — `setPaused(true)`, publish 10, `setPaused(false)`, publish 1; assert ring contains 1 entry.
- `clearEmptiesRingAndTotals` — populate, call `clear()`, assert all snapshot fields reset.

### Panel snapshot tests — `Tests/CodeEditorSampleTests/EventLog/EventLogPanelSnapshotTests.swift`

swift-snapshot-testing. Five states under `__Snapshots__/`:

- `default` — populated mix of all four categories.
- `withTextMuted` — same data, `.text` muted; pill shows `Text · N` outlined.
- `paused` — Pause active, banner copy reflects state.
- `empty` — no events yet, empty-state copy.
- `withFailedCompletion` — one failed `CompletionEvent` with warning glyph + tooltip.

Recorded once with `isRecording: true`, then committed.

### Framework integration tests — `Tests/CodeEditorPluginTests/Core/PublishEventFanOutTests.swift`

XCTest. Wire a real `CodeEditorView` with a `UnifiedEventSystem` through `runtime.dependencies.eventSystem`, drive editor mutations programmatically, assert fan-out:

- `textDidChangeReachesEventSystem` — set `string`, assert system received `.textDidChange`.
- `selectionDidChangeReachesEventSystem` — set `selectedRange`, assert system received `.textSelectionDidChange`.
- `becomeFirstResponderReachesEventSystem` — wrap view in a window, call `makeFirstResponder`, assert `.didBecomeFirstResponder`.
- `resignFirstResponderReachesEventSystem` — symmetrical.

These guard against future regression of `publishEvent` vs `publishSync` mixups. macOS-only; iOS focus testing requires a `UIWindow` host that's out of scope for this pass.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Combine sink retains the coordinator → leak | Sink stored as `AnyCancellable` cleaned up in `detach()`; coordinator weakly captured in the closure. |
| `controller.completionEvents()` Task leaks past detach | Task token stored as `@ObservationIgnored`; cancelled in `detach()`. |
| Switching `publishSync` → `publishEvent` changes ordering semantics | Both go through the same `EditorEventPublisher.publishSync` path internally; only the fan-out to `runtime.dependencies.eventSystem` is added. No reordering of existing subscribers. |
| Focus overrides surprise consumers who already override `becomeFirstResponder` | `CodeEditorView` is the framework's own subclass; downstream consumers can't currently override it (no subclass surface). If they did, super-call semantics preserve behavior. |
| 200-entry ring forces redraws on every keystroke under load | `List` virtualization; `snapshot.entries` is a value type with `Hashable` IDs so SwiftUI diffs cheaply. If profile shows hot, raise capacity floor or batch publishes (out of scope v1). |
| iOS placement (a row in Inspectors) feels cramped | Layout-agnostic panel; if user testing flags it, future spec converts the row to a sheet without touching the coordinator. |

## Surface area summary

| File | Status | Lines (est) |
|---|---|---|
| `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift` | Modified | 2-line diff (×2 sites) |
| `Sources/CodeEditorPlugin/Core/CodeEditorView+ConfigurationExtensions.swift` | Modified | 2-line diff |
| `Sources/CodeEditorPlugin/Core/CodeEditorView+Responder.swift` | New | ~40 |
| `Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift` | New | ~180 |
| `Sources/CodeEditorSample/Sidebars/EventLogPanel.swift` | New | ~220 |
| `Sources/CodeEditorSample/App/AppState.swift` | Modified | ~5-line diff |
| `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift` | Modified | ~15-line diff |
| `Sources/CodeEditorSample/iOS/IOSRootView.swift` | Modified | ~10-line diff |
| `Sources/CodeEditorSample/App/WindowBody.swift` | Modified | 1-line diff |
| `Tests/CodeEditorSampleTests/EventLog/EventLogSampleCoordinatorTests.swift` | New | ~140 |
| `Tests/CodeEditorSampleTests/EventLog/EventLogPanelSnapshotTests.swift` | New | ~80 + 5 snapshot PNGs |
| `Tests/CodeEditorPluginTests/Core/PublishEventFanOutTests.swift` | New | ~120 |

## Out of scope (followups)

- **Annotation event emission** — `annotationHovered`/`annotationClicked` cases need call sites in `AnnotationsHub` or the hit-test path. Adds an `.annotation` filter pill to this panel.
- **Error event emission** — `error(SendableError)` from highlighting failures, LSP comms, etc. Requires `IssueReporting` policy decision.
- **Performance warning emission** — `performanceWarning(message:)` from `PerformanceObservation` thresholds. Bridges adaptive-perf-mode transitions.
- **Event detail drill-in** — tap a row to see full payload (full text for `textDidChange`, full `CompletionContext` for completion). Modal sheet or expandable row.
- **Export to clipboard / file** — useful for filing bug reports against the framework.
- **Per-row search and time-range filter** — beyond category pills.
- **iOS placement as a sheet rather than a row** — pending user feedback on v1.
- **Promote coordinator/panel to `CodeEditorUI`** — if consumers ask for a reusable component.

## References

- `NEXT.md` § A.1, § A.3 #7.
- `Sources/CodeEditorPlugin/Core/UnifiedEventSystem.swift` — `UnifiedEventSystem`, `CodeEditorView.publishEvent(_:)`.
- `Sources/CodeEditorPlugin/Core/EditorEvent.swift` — `EditorEvent` enum, `SendableError`.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift:576` — `.eventSystem(_:)` modifier.
- `Sources/CodeEditorSample/App/Completion/CompletionSampleCoordinator.swift` — closest existing pattern (subscribes to controller's AsyncSequence, ring buffer, observable snapshot).
- `Sources/CodeEditorSample/Sidebars/CompletionInspectorPanel.swift` — closest existing panel (stateless, snapshot-driven, time + monospaced row format).
