# EventLog Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a cross-platform EventLog inspector panel to `CodeEditorSample` that surfaces `UnifiedEventSystem` events (text, selection, focus) layered with `CompletionEvent`s from `controller.completionEvents()`. While here, make the framework's `.eventSystem(_:)` modifier honest: convert the three existing `eventPublisher.publishSync(...)` call sites to use the fan-out `CodeEditorView.publishEvent(_:)`, and add `publishEvent(.didBecomeFirstResponder)` / `publishEvent(.didResignFirstResponder)` in responder hook overrides.

**Architecture:** Mirrors the existing three-coordinator pattern (LSP/Completion/Performance). A `@MainActor @Observable` `EventLogSampleCoordinator` owns a 200-entry ring of `LoggedEvent` values, subscribes to `UnifiedEventSystem.events` (Combine sink) and `controller.completionEvents()` (AsyncSequence task), exposes a flat `Snapshot` for SwiftUI. A stateless `EventLogPanel` view takes snapshot fields, renders header pills (Text/Selection/Focus/Completion) + Pause + Clear + a virtualized `List` of timestamped rows. The shared `UnifiedEventSystem` is owned by `AppState` and wired into both macOS (`WindowBody`) and iOS (`IOSRootView`) via `.eventSystem(_:)`. Framework wiring is four edits: three publishSync→publishEvent flips and a new `CodeEditorView+Responder.swift` with focus-event overrides.

**Tech Stack:** Swift 6.3 (`StrictConcurrency`), SwiftPM, AppKit + UIKit, Combine, `@Observable` (Swift Observation), `swift-snapshot-testing` (existing fork), `swift-custom-dump`. Tests use both Swift Testing (`@Suite` / `@Test`) and XCTest.

**Spec:** `docs/superpowers/specs/2026-05-14-event-log-panel-design.md`

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift` | Modify | Two-line flip: replace `eventPublisher.publishSync(.textDidChange(...))` with `publishEvent(.textDidChange(...))` in both AppKit and UIKit branches. |
| `Sources/CodeEditorPlugin/Core/CodeEditorView+ConfigurationExtensions.swift` | Modify | One-line flip: replace `eventPublisher.publishSync(.textSelectionDidChange(...))` with `publishEvent(.textSelectionDidChange(...))`. |
| `Sources/CodeEditorPlugin/Core/CodeEditorView+Responder.swift` | Create | New file with `becomeFirstResponder()` / `resignFirstResponder()` overrides that emit focus events via `publishEvent`. Platform-gated `#if canImport(AppKit)` / `#elseif canImport(UIKit)` because `super` resolves to a different base class under each. |
| `Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift` | Create | `@MainActor @Observable` coordinator. Owns the 200-entry ring, mute set, pause flag, both subscriptions. Cross-platform (no AppKit gate). |
| `Sources/CodeEditorSample/Sidebars/EventLogPanel.swift` | Create | Stateless SwiftUI view. Header pills + Pause + Clear + virtualized `List` of rows. Cross-platform. |
| `Sources/CodeEditorSample/App/AppState.swift` | Modify | Add ungated `let eventSystem = UnifiedEventSystem()` and `let eventLog = EventLogSampleCoordinator()`; call `eventLog.attach(...)` in `init()`. |
| `Sources/CodeEditorSample/App/WindowBody.swift` | Modify | Apply `.eventSystem(appState.eventSystem)` in `editorPane` modifier chain. |
| `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift` | Modify | Add `EventLogPanel` between `AnnotationsInspectorPanel(...)` and the config render block. |
| `Sources/CodeEditorSample/iOS/IOSRootView.swift` | Modify | Replace `inspectorsUnavailable` body with a stack that shows `EventLogPanel` above the existing "macOS-only" copy; apply `.eventSystem(appState.eventSystem)` to the iOS editor view. |
| `Tests/CodeEditorPluginTests/Core/PublishEventFanOutTests.swift` | Create | XCTest. Confirms `.eventSystem(_:)`-wired `UnifiedEventSystem` receives `textDidChange`, `textSelectionDidChange`, `didBecomeFirstResponder`, `didResignFirstResponder`. macOS-only (window host). |
| `Tests/CodeEditorSampleTests/EventLogSampleCoordinatorTests.swift` | Create | Swift Testing suite for ring, totals, mute, pause, clear. Pure logic; no SwiftUI. |
| `Tests/CodeEditorSampleTests/EventLogPanelSnapshotTests.swift` | Create | XCTest + swift-snapshot-testing. Five baselines: default, withTextMuted, paused, empty, withFailedCompletion. macOS-only. |
| `Tests/CodeEditorSampleTests/__Snapshots__/EventLogPanelSnapshotTests/*.png` | Create (record) | Snapshot baselines committed alongside the test. |
| `NEXT.md` | Modify | Mark § A.1 "Event stream invisible" done; cross-reference partial A.3 #7 (iOS Inspectors detail now has one cross-platform inspector). |

(`Package.swift` does NOT need editing — `Tests/CodeEditorSampleTests/__Snapshots__` is already in the excludes list, and the new snapshot tests live directly under that directory.)

---

## Task 1: Framework integration test for `.eventSystem(_:)` fan-out — text & selection

**Files:**
- Create: `Tests/CodeEditorPluginTests/Core/PublishEventFanOutTests.swift`

This task only writes the test. The flips that make it pass happen in Task 2.

- [ ] **Step 1.1: Write the failing fan-out test (text + selection)**

```swift
// Tests/CodeEditorPluginTests/Core/PublishEventFanOutTests.swift
#if canImport(AppKit)
import AppKit
import Combine
import XCTest
@testable import CodeEditorPlugin

/// Verifies that `CodeEditorView` events fan out through `publishEvent(_:)`
/// into a customer-supplied `UnifiedEventSystem`. This guards the
/// `.eventSystem(_:)` SwiftUI modifier contract — without these tests the
/// modifier silently delivers nothing.
@MainActor
final class PublishEventFanOutTests: XCTestCase {

    /// Make a hosted `CodeEditorView` with a `UnifiedEventSystem` wired
    /// through the framework runtime so `publishEvent(_:)` fans out.
    private func makeHostedView(
        text: String = ""
    ) throws -> (CodeEditorView, UnifiedEventSystem, NSWindow) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let container = CodeEditorContainerView(frame: window.contentLayoutRect)
        container.textView.string = text
        window.contentView = container
        window.makeKeyAndOrderFront(nil)

        let eventSystem = UnifiedEventSystem()
        container.textView.runtime.update(eventSystem: eventSystem)

        return (container.textView, eventSystem, window)
    }

    func testTextDidChangeFansOutToEventSystem() throws {
        let (view, eventSystem, window) = try makeHostedView(text: "alpha")
        defer { window.close() }

        var received: [String] = []
        var cancellables: Set<AnyCancellable> = []
        eventSystem.events
            .sink { event in
                if case .textDidChange(let text) = event { received.append(text) }
            }
            .store(in: &cancellables)

        view.string = "alpha\nbeta"

        // textDidChange is dispatched on the main queue via DispatchQueue.main.async
        // from textStorageDidProcessEditing; let the runloop drain so the event lands.
        let expectation = expectation(description: "textDidChange delivered")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(received.last, "alpha\nbeta",
                       "Setting `string` should fan out a textDidChange event into the customer-supplied UnifiedEventSystem.")
    }

    func testSelectionDidChangeFansOutToEventSystem() throws {
        let (view, eventSystem, window) = try makeHostedView(text: "hello world")
        defer { window.close() }

        var received: [NSRange] = []
        var cancellables: Set<AnyCancellable> = []
        eventSystem.events
            .sink { event in
                if case .textSelectionDidChange(let r) = event { received.append(r) }
            }
            .store(in: &cancellables)

        view.setSelectedRange(NSRange(location: 0, length: 5))

        let expectation = expectation(description: "selectionDidChange delivered")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(received.contains(NSRange(location: 0, length: 5)),
                      "Setting selection should fan out a textSelectionDidChange event into the customer-supplied UnifiedEventSystem.")
    }
}
#endif
```

- [ ] **Step 1.2: Run the new tests; both should fail**

Run:

```
swift test --filter PublishEventFanOutTests
```

Expected: both tests FAIL — `received` is empty because the existing call sites use `eventPublisher.publishSync(...)`, which only hits the local publisher, not the runtime's `eventSystem`.

- [ ] **Step 1.3: Commit the failing tests**

```
git add Tests/CodeEditorPluginTests/Core/PublishEventFanOutTests.swift
git commit -m "Test: .eventSystem(_:) fan-out for textDidChange + textSelectionDidChange (failing)"
```

---

## Task 2: Flip three `publishSync` sites to `publishEvent`

**Files:**
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift:112,114`
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+ConfigurationExtensions.swift:121`

- [ ] **Step 2.1: Replace the AppKit `textDidChange` publish**

In `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift`, change line 112 from:

```swift
self.eventPublisher.publishSync(.textDidChange(self.string))
```

to:

```swift
self.publishEvent(.textDidChange(self.string))
```

- [ ] **Step 2.2: Replace the UIKit `textDidChange` publish**

In the same file, change line 114 from:

```swift
self.eventPublisher.publishSync(.textDidChange(self.text ?? ""))
```

to:

```swift
self.publishEvent(.textDidChange(self.text ?? ""))
```

- [ ] **Step 2.3: Replace the selection publish**

In `Sources/CodeEditorPlugin/Core/CodeEditorView+ConfigurationExtensions.swift`, change line 121 from:

```swift
self.eventPublisher.publishSync(.textSelectionDidChange(currentSelection))
```

to:

```swift
self.publishEvent(.textSelectionDidChange(currentSelection))
```

- [ ] **Step 2.4: Run the Task 1 tests**

Run:

```
swift test --filter PublishEventFanOutTests
```

Expected: both `testTextDidChangeFansOutToEventSystem` and `testSelectionDidChangeFansOutToEventSystem` PASS. `publishEvent(_:)` is the existing fan-out helper that calls both the local publisher and `runtime.dependencies.eventSystem?.publish`.

- [ ] **Step 2.5: Run the full Plugin test suite to confirm no regression**

Run:

```
swift build && swift test --parallel 2>&1 | tail -20
```

Expected: existing tests still pass. The fan-out helper internally calls `publishSync` (same as before) plus the new fan-out — no ordering or filtering change.

- [ ] **Step 2.6: Commit**

```
git add Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift Sources/CodeEditorPlugin/Core/CodeEditorView+ConfigurationExtensions.swift
git commit -m "CodeEditorView: route text/selection events through publishEvent fan-out"
```

---

## Task 3: Add focus-event responder overrides + tests

**Files:**
- Modify: `Tests/CodeEditorPluginTests/Core/PublishEventFanOutTests.swift` (add two tests)
- Create: `Sources/CodeEditorPlugin/Core/CodeEditorView+Responder.swift`

- [ ] **Step 3.1: Append failing responder tests to `PublishEventFanOutTests`**

In `Tests/CodeEditorPluginTests/Core/PublishEventFanOutTests.swift`, before the closing `}` of the class, add:

```swift
    func testBecomeFirstResponderFansOutFocusEvent() throws {
        let (view, eventSystem, window) = try makeHostedView()
        defer { window.close() }

        var becameCount = 0
        var cancellables: Set<AnyCancellable> = []
        eventSystem.events
            .sink { event in
                if case .didBecomeFirstResponder = event { becameCount += 1 }
            }
            .store(in: &cancellables)

        let became = window.makeFirstResponder(view)
        XCTAssertTrue(became, "Window must be able to make the editor view first responder for this test to be meaningful.")

        XCTAssertEqual(becameCount, 1, "becomeFirstResponder() should fan out exactly one didBecomeFirstResponder event.")
    }

    func testResignFirstResponderFansOutFocusEvent() throws {
        let (view, eventSystem, window) = try makeHostedView()
        defer { window.close() }

        var resignedCount = 0
        var cancellables: Set<AnyCancellable> = []
        eventSystem.events
            .sink { event in
                if case .didResignFirstResponder = event { resignedCount += 1 }
            }
            .store(in: &cancellables)

        _ = window.makeFirstResponder(view)
        // Move focus off — back to the window's contentView, then nil.
        _ = window.makeFirstResponder(window.contentView)

        XCTAssertEqual(resignedCount, 1, "Losing first-responder status should fan out exactly one didResignFirstResponder event.")
    }
```

- [ ] **Step 3.2: Run the new tests; both should fail**

Run:

```
swift test --filter PublishEventFanOutTests
```

Expected: the two new tests FAIL — `becameCount` and `resignedCount` are both 0 because `CodeEditorView` has no focus-event overrides yet.

- [ ] **Step 3.3: Create `CodeEditorView+Responder.swift`**

Create `Sources/CodeEditorPlugin/Core/CodeEditorView+Responder.swift`:

```swift
#if canImport(AppKit)
import AppKit

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
import UIKit

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

The branches share an identical body shape but are platform-gated because `super` resolves to a different base class (`NSTextView` vs `UITextView`) under each compile path.

- [ ] **Step 3.4: Run the responder tests**

Run:

```
swift test --filter PublishEventFanOutTests
```

Expected: all four `PublishEventFanOutTests` cases PASS.

- [ ] **Step 3.5: Run full Plugin suite (responder change touches both platforms)**

Run:

```
swift build && swift test --parallel 2>&1 | tail -20
```

Expected: no regressions. If a pre-existing macOS test asserts on first-responder state, this is purely additive — the overrides call `super` and propagate its return value.

- [ ] **Step 3.6: Commit**

```
git add Tests/CodeEditorPluginTests/Core/PublishEventFanOutTests.swift Sources/CodeEditorPlugin/Core/CodeEditorView+Responder.swift
git commit -m "CodeEditorView: publishEvent on first-responder transitions"
```

---

## Task 4: `EventLogSampleCoordinator` — value types and skeleton (no subscriptions yet)

**Files:**
- Create: `Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift`
- Create: `Tests/CodeEditorSampleTests/EventLogSampleCoordinatorTests.swift`

This task lands the data shape and one inert behavior (`append`) so subsequent tasks have a target to attach the two real subscriptions to.

- [ ] **Step 4.1: Write the failing initial test**

Create `Tests/CodeEditorSampleTests/EventLogSampleCoordinatorTests.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing

@Suite("EventLogSampleCoordinator")
@MainActor
struct EventLogSampleCoordinatorTests {

    @Test("initial snapshot is empty")
    func emptyAtBirth() {
        let coordinator = EventLogSampleCoordinator()
        #expect(coordinator.snapshot.entries.isEmpty)
        #expect(coordinator.snapshot.ringCount == 0)
        #expect(coordinator.mutedCategories.isEmpty)
        #expect(coordinator.paused == false)
    }

    @Test("appending a LoggedEvent shows up in the snapshot newest-first")
    func appendsNewestFirst() {
        let coordinator = EventLogSampleCoordinator()
        coordinator.append(.text(summary: "first", timestamp: Date(timeIntervalSince1970: 1)))
        coordinator.append(.text(summary: "second", timestamp: Date(timeIntervalSince1970: 2)))

        #expect(coordinator.snapshot.entries.count == 2)
        #expect(coordinator.snapshot.entries.first?.summary == "second")
        #expect(coordinator.snapshot.entries.last?.summary == "first")
        #expect(coordinator.snapshot.ringCount == 2)
        #expect(coordinator.snapshot.totals[.text] == 2)
    }
}
#endif
```

(The `.text(summary:timestamp:)` factory is added in the next step. The macOS gate matches the project test conventions; we'll widen later if iOS test scaffolding lands.)

- [ ] **Step 4.2: Run the new tests; both should fail**

Run:

```
swift test --filter EventLogSampleCoordinatorTests
```

Expected: build failure — `EventLogSampleCoordinator` doesn't exist yet.

- [ ] **Step 4.3: Create the coordinator skeleton**

Create `Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift`:

```swift
import CodeEditorPlugin
import Foundation
import Observation

/// Owns the sample's EventLog inspector lifecycle. Subscribes to a shared
/// `UnifiedEventSystem` and to `controller.completionEvents()`, appends each
/// incoming event to a bounded ring, and exposes the result through a single
/// `@Observable` snapshot for `EventLogPanel` to render.
///
/// Cross-platform: ungated by intent. The framework's `UnifiedEventSystem`
/// API is itself cross-platform, and the sample wires the same coordinator
/// into both `WindowBody` (macOS) and `IOSRootView` (iOS).
@MainActor
@Observable
final class EventLogSampleCoordinator {

    /// Source of an entry. Drives the filter pills in `EventLogPanel`.
    enum EventCategory: String, CaseIterable, Sendable, Hashable {
        case text
        case selection
        case focus
        case completion
    }

    /// One row in the panel. Pre-rendered summary so the view is trivial.
    struct LoggedEvent: Identifiable, Sendable, Hashable {
        let id: UUID
        let timestamp: Date
        let category: EventCategory
        let summary: String
        let detail: String?

        init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            category: EventCategory,
            summary: String,
            detail: String? = nil
        ) {
            self.id = id
            self.timestamp = timestamp
            self.category = category
            self.summary = summary
            self.detail = detail
        }

        /// Convenience factories used by the coordinator's translators and by tests.
        static func text(summary: String, timestamp: Date = Date()) -> LoggedEvent {
            LoggedEvent(timestamp: timestamp, category: .text, summary: summary)
        }
        static func selection(summary: String, timestamp: Date = Date()) -> LoggedEvent {
            LoggedEvent(timestamp: timestamp, category: .selection, summary: summary)
        }
        static func focus(summary: String, timestamp: Date = Date()) -> LoggedEvent {
            LoggedEvent(timestamp: timestamp, category: .focus, summary: summary)
        }
        static func completion(
            summary: String,
            detail: String? = nil,
            timestamp: Date = Date()
        ) -> LoggedEvent {
            LoggedEvent(timestamp: timestamp, category: .completion, summary: summary, detail: detail)
        }
    }

    /// Flat observable surface for `EventLogPanel`. All filtering is post-hoc;
    /// `ringCount` reflects the pre-filter ring size, `entries` reflects the
    /// post-filter newest-first view.
    struct Snapshot: Sendable {
        var entries: [LoggedEvent]
        var totals: [EventCategory: Int]
        var ringCount: Int

        static let empty = Snapshot(entries: [], totals: [:], ringCount: 0)
    }

    private static let ringCapacity = 200

    // MARK: - Observable surface

    private(set) var snapshot: Snapshot = .empty
    private(set) var paused: Bool = false
    private(set) var mutedCategories: Set<EventCategory> = []

    // MARK: - Internals

    @ObservationIgnored
    private var ring: [LoggedEvent] = []

    @ObservationIgnored
    private var totals: [EventCategory: Int] = [:]

    // MARK: - Append (test-visible)

    /// Append a pre-translated `LoggedEvent`. Honors `paused` (drops on the
    /// floor) and the ring capacity (drops oldest). `internal` so tests can
    /// drive the coordinator without spinning up live subscriptions.
    func append(_ entry: LoggedEvent) {
        guard !paused else { return }
        ring.append(entry)
        if ring.count > Self.ringCapacity {
            ring.removeFirst(ring.count - Self.ringCapacity)
        }
        totals[entry.category, default: 0] += 1
        publishSnapshot()
    }

    // MARK: - Snapshot publishing

    private func publishSnapshot() {
        let filtered = ring
            .reversed()
            .filter { !mutedCategories.contains($0.category) }
        snapshot = Snapshot(entries: Array(filtered), totals: totals, ringCount: ring.count)
    }
}
```

- [ ] **Step 4.4: Run the tests**

Run:

```
swift test --filter EventLogSampleCoordinatorTests
```

Expected: both tests PASS.

- [ ] **Step 4.5: Lint and commit**

```
swiftlint --fix && swiftlint
git add Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift Tests/CodeEditorSampleTests/EventLogSampleCoordinatorTests.swift
git commit -m "EventLogSampleCoordinator: value types + append skeleton"
```

---

## Task 5: Ring cap + clear + mute + pause behaviors (TDD'd)

**Files:**
- Modify: `Tests/CodeEditorSampleTests/EventLogSampleCoordinatorTests.swift`
- Modify: `Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift`

These four behaviors are simple enough to TDD as one task — each gets one test, one implementation, then a single commit at the end.

- [ ] **Step 5.1: Append four failing tests**

After the existing `appendsNewestFirst` test, add inside the same struct:

```swift
    @Test("ring caps at 200 entries, oldest dropped")
    func ringCapsAt200() {
        let coordinator = EventLogSampleCoordinator()
        for i in 0..<250 {
            coordinator.append(.text(summary: "e\(i)", timestamp: Date(timeIntervalSince1970: TimeInterval(i))))
        }
        #expect(coordinator.snapshot.ringCount == 200)
        // Newest-first: first visible entry should be the very last one we appended.
        #expect(coordinator.snapshot.entries.first?.summary == "e249")
        // Oldest 50 should have been dropped.
        #expect(coordinator.snapshot.entries.contains { $0.summary == "e49" } == false)
    }

    @Test("muted category hidden from snapshot but totals still update")
    func mutedHiddenButTotalsUpdate() {
        let coordinator = EventLogSampleCoordinator()
        for i in 0..<5 {
            coordinator.append(.text(summary: "t\(i)"))
        }
        coordinator.setMuted(.text, true)
        #expect(coordinator.snapshot.entries.isEmpty)
        #expect(coordinator.snapshot.totals[.text] == 5)
        #expect(coordinator.snapshot.ringCount == 5,
                "Muting must not drop events from the ring — totals and ring count survive.")
    }

    @Test("paused drops events; unpausing accepts new events")
    func pausedDrops() {
        let coordinator = EventLogSampleCoordinator()
        coordinator.setPaused(true)
        for i in 0..<10 {
            coordinator.append(.text(summary: "p\(i)"))
        }
        #expect(coordinator.snapshot.ringCount == 0)

        coordinator.setPaused(false)
        coordinator.append(.text(summary: "after-resume"))
        #expect(coordinator.snapshot.ringCount == 1)
        #expect(coordinator.snapshot.entries.first?.summary == "after-resume")
    }

    @Test("clear empties ring and totals")
    func clearEmptiesEverything() {
        let coordinator = EventLogSampleCoordinator()
        coordinator.append(.text(summary: "t"))
        coordinator.append(.selection(summary: "s"))
        coordinator.clear()
        #expect(coordinator.snapshot.entries.isEmpty)
        #expect(coordinator.snapshot.totals.isEmpty)
        #expect(coordinator.snapshot.ringCount == 0)
    }
```

- [ ] **Step 5.2: Run them; all four should fail**

Run:

```
swift test --filter EventLogSampleCoordinatorTests
```

Expected: build failure — `setMuted(_:_:)`, `setPaused(_:)`, `clear()` don't exist yet. (`ringCapsAt200` would compile but would fail because the previous test already had append behavior — leaving that test compiling is fine.)

- [ ] **Step 5.3: Add `setMuted`, `setPaused`, `clear` to the coordinator**

In `Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift`, after the `publishSnapshot()` method, add:

```swift
    // MARK: - Actions

    /// Toggle whether `category` is hidden from the snapshot. Does NOT drop
    /// events from the underlying ring — pills only filter the view.
    func setMuted(_ category: EventCategory, _ muted: Bool) {
        if muted {
            mutedCategories.insert(category)
        } else {
            mutedCategories.remove(category)
        }
        publishSnapshot()
    }

    /// Pause receiving new events. Existing events stay in the ring.
    func setPaused(_ paused: Bool) {
        self.paused = paused
    }

    /// Empty the ring and reset all counts. Does NOT change `mutedCategories`
    /// or `paused`.
    func clear() {
        ring.removeAll()
        totals.removeAll()
        publishSnapshot()
    }
```

- [ ] **Step 5.4: Run the tests**

Run:

```
swift test --filter EventLogSampleCoordinatorTests
```

Expected: all six tests in the suite PASS.

- [ ] **Step 5.5: Lint and commit**

```
swiftlint --fix && swiftlint
git add Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift Tests/CodeEditorSampleTests/EventLogSampleCoordinatorTests.swift
git commit -m "EventLogSampleCoordinator: ring cap + mute + pause + clear"
```

---

## Task 6: Wire `UnifiedEventSystem` subscription

**Files:**
- Modify: `Tests/CodeEditorSampleTests/EventLogSampleCoordinatorTests.swift`
- Modify: `Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift`

- [ ] **Step 6.1: Append a failing subscription test**

Add inside `EventLogSampleCoordinatorTests`:

```swift
    @Test("textDidChange from UnifiedEventSystem lands in the .text category")
    func attachReceivesTextDidChange() {
        let coordinator = EventLogSampleCoordinator()
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        controller.attach(to: view)
        let eventSystem = UnifiedEventSystem()
        coordinator.attach(controller: controller, eventSystem: eventSystem)
        defer { coordinator.detach() }

        eventSystem.publish(.textDidChange("hello"))

        #expect(coordinator.snapshot.entries.count == 1)
        let entry = coordinator.snapshot.entries.first
        #expect(entry?.category == .text)
        #expect(entry?.summary == "textDidChange (len=5)")
    }

    @Test("selection and focus events land in their categories")
    func attachReceivesSelectionAndFocus() {
        let coordinator = EventLogSampleCoordinator()
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        controller.attach(to: view)
        let eventSystem = UnifiedEventSystem()
        coordinator.attach(controller: controller, eventSystem: eventSystem)
        defer { coordinator.detach() }

        eventSystem.publish(.textSelectionDidChange(NSRange(location: 3, length: 2)))
        eventSystem.publish(.didBecomeFirstResponder)

        // Two events; newest-first means focus is at .first.
        #expect(coordinator.snapshot.entries.count == 2)
        #expect(coordinator.snapshot.entries.first?.category == .focus)
        #expect(coordinator.snapshot.entries.first?.summary == "didBecomeFirstResponder")
        #expect(coordinator.snapshot.entries.last?.category == .selection)
        #expect(coordinator.snapshot.entries.last?.summary == "selection=[loc=3, len=2]")
    }
```

- [ ] **Step 6.2: Run them; both should fail**

Run:

```
swift test --filter EventLogSampleCoordinatorTests
```

Expected: build failure — `attach(controller:eventSystem:)` and `detach()` don't exist yet.

- [ ] **Step 6.3: Add the subscription**

In `Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift`, add a `Combine` import at the top:

```swift
import Combine
```

After `@ObservationIgnored private var totals: [EventCategory: Int] = [:]`, add:

```swift
    @ObservationIgnored
    private var eventSystemCancellable: AnyCancellable?
```

Add a new section before `// MARK: - Append (test-visible)`:

```swift
    // MARK: - Lifecycle

    /// Subscribe to the shared `UnifiedEventSystem` for first-class editor
    /// events and to `controller.completionEvents()` for completion activity.
    /// Idempotent — calling `attach` again replaces both subscriptions.
    func attach(controller: EditorController, eventSystem: UnifiedEventSystem) {
        detach()
        eventSystemCancellable = eventSystem.events
            .sink { [weak self] event in
                guard let self else { return }
                if let entry = Self.translate(editorEvent: event) {
                    self.append(entry)
                }
            }
        // Completion subscription is wired in Task 7.
    }

    /// Tear down all subscriptions. Safe to call multiple times.
    func detach() {
        eventSystemCancellable?.cancel()
        eventSystemCancellable = nil
    }

    // MARK: - Translators

    private static func translate(editorEvent event: EditorEvent) -> LoggedEvent? {
        switch event {
        case .textDidChange(let text):
            return .text(summary: "textDidChange (len=\(text.utf16.count))")
        case .textSelectionDidChange(let range):
            return .selection(summary: "selection=[loc=\(range.location), len=\(range.length)]")
        case .didBecomeFirstResponder:
            return .focus(summary: "didBecomeFirstResponder")
        case .didResignFirstResponder:
            return .focus(summary: "didResignFirstResponder")
        // Annotation, completion, error, performanceWarning are intentionally
        // unhandled at v1 — none are emitted by the framework today, and
        // completion events arrive through the dedicated AsyncSequence.
        case .completionRequested, .completionItemSelected,
             .annotationHovered, .annotationClicked,
             .performanceWarning, .error,
             .textWillChange:
            return nil
        }
    }
```

- [ ] **Step 6.4: Run the tests**

Run:

```
swift test --filter EventLogSampleCoordinatorTests
```

Expected: all eight tests in the suite PASS.

- [ ] **Step 6.5: Lint and commit**

```
swiftlint --fix && swiftlint
git add Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift Tests/CodeEditorSampleTests/EventLogSampleCoordinatorTests.swift
git commit -m "EventLogSampleCoordinator: Combine sink on UnifiedEventSystem.events"
```

---

## Task 7: Wire `controller.completionEvents()` subscription

**Files:**
- Modify: `Tests/CodeEditorSampleTests/EventLogSampleCoordinatorTests.swift`
- Modify: `Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift`

`controller.completionEvents()` is an `AsyncSequence` consumed via a `for await` `Task`. Driving it deterministically in tests requires routing real `CompletionEvent`s through the controller — but the unit-of-behavior here is the translator and the append, which we can test via the existing `append` seam plus a translator function. We do the cheap test (translator) here; the live AsyncSequence is exercised end-to-end in the panel snapshot tests later (Task 9) and the live demo.

- [ ] **Step 7.1: Append a failing translator test**

Add inside `EventLogSampleCoordinatorTests`:

```swift
    @Test("translate(completionEvent:) renders succeeded outcomes")
    func translateCompletionSucceeded() {
        let event = CompletionEvent(
            providerID: "swift-universal",
            language: .swift,
            triggerCharacter: ".",
            prefix: "",
            durationMilliseconds: 4.25,
            outcome: .succeeded(itemCount: 12)
        )
        let entry = EventLogSampleCoordinator.translate(completionEvent: event)
        #expect(entry.category == .completion)
        #expect(entry.summary == "swift → 12 items · 4.3ms")
        #expect(entry.detail == "swift-universal · trigger=\".\"")
    }

    @Test("translate(completionEvent:) renders failed outcomes")
    func translateCompletionFailed() {
        let event = CompletionEvent(
            providerID: "swift-universal",
            language: .swift,
            triggerCharacter: nil,
            prefix: "",
            durationMilliseconds: 1.0,
            outcome: .failed(SendableError(message: "timed out", domain: "Completion"))
        )
        let entry = EventLogSampleCoordinator.translate(completionEvent: event)
        #expect(entry.category == .completion)
        #expect(entry.summary == "swift failed")
        #expect(entry.detail?.contains("timed out") == true)
    }
```

(`CompletionEvent.Outcome.failed` is defined in `Sources/CodeEditorPlugin/Completion/CompletionEvent.swift:27` as `case failed(SendableError)`. The assertion uses `contains` so a future change to `SendableError.description` formatting won't immediately break the test.)

- [ ] **Step 7.2: Run; both should fail**

Run:

```
swift test --filter EventLogSampleCoordinatorTests
```

Expected: build failure — `translate(completionEvent:)` doesn't exist yet.

- [ ] **Step 7.3: Add the completion translator and the live subscription**

In `Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift`, add another `@ObservationIgnored` storage member alongside `eventSystemCancellable`:

```swift
    @ObservationIgnored
    private var completionTask: Task<Void, Never>?
```

Inside `attach(controller:eventSystem:)`, after the existing `eventSystemCancellable = ...` block, add:

```swift
        completionTask = Task { @MainActor [weak self] in
            for await event in controller.completionEvents() {
                guard let self else { return }
                self.append(Self.translate(completionEvent: event))
            }
        }
```

In `detach()`, before the closing `}`, add:

```swift
        completionTask?.cancel()
        completionTask = nil
```

Below the existing `translate(editorEvent:)` static, add:

```swift
    static func translate(completionEvent event: CompletionEvent) -> LoggedEvent {
        let language = event.language.rawValue
        switch event.outcome {
        case .succeeded(let itemCount):
            let ms = String(format: "%.1f", event.durationMilliseconds)
            let triggerSuffix: String
            if let trigger = event.triggerCharacter {
                triggerSuffix = "\(event.providerID) · trigger=\"\(trigger)\""
            } else {
                triggerSuffix = "\(event.providerID)"
            }
            return .completion(
                summary: "\(language) → \(itemCount) items · \(ms)ms",
                detail: triggerSuffix,
                timestamp: event.timestamp
            )
        case .failed(let failure):
            return .completion(
                summary: "\(language) failed",
                detail: String(describing: failure),
                timestamp: event.timestamp
            )
        }
    }
```

- [ ] **Step 7.4: Run the tests**

Run:

```
swift test --filter EventLogSampleCoordinatorTests
```

Expected: all ten tests in the suite PASS. (Two new translator tests + eight pre-existing.)

- [ ] **Step 7.5: Lint and commit**

```
swiftlint --fix && swiftlint
git add Sources/CodeEditorSample/App/EventLog/EventLogSampleCoordinator.swift Tests/CodeEditorSampleTests/EventLogSampleCoordinatorTests.swift
git commit -m "EventLogSampleCoordinator: completion event subscription + translator"
```

---

## Task 8: Stateless `EventLogPanel` SwiftUI view

**Files:**
- Create: `Sources/CodeEditorSample/Sidebars/EventLogPanel.swift`

No tests yet — the snapshot tests live in Task 9. The view is stateless, so the only way to validate behavior is rendering. We hand-verify by running the sample app at the end of Task 11.

- [ ] **Step 8.1: Create the panel**

Create `Sources/CodeEditorSample/Sidebars/EventLogPanel.swift`:

```swift
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// Stateless view backing the EventLog inspector. Takes the coordinator's
/// snapshot fields as parameters — no direct coordinator reference — so it
/// remains snapshot-testable.
struct EventLogPanel: View {
    typealias Category = EventLogSampleCoordinator.EventCategory
    typealias LoggedEvent = EventLogSampleCoordinator.LoggedEvent

    let entries: [LoggedEvent]
    let totals: [Category: Int]
    let mutedCategories: Set<Category>
    let paused: Bool

    var onToggleCategory: (Category) -> Void
    var onTogglePause: () -> Void
    var onClear: () -> Void
    var onAppear: () -> Void = {}
    var onDisappear: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            pillsRow
            Divider()
            entriesList
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Events").font(.headline)
            Spacer()
            Text("\(entries.count) shown · \(totals.values.reduce(0, +)) total")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Pills + controls

    private var pillsRow: some View {
        HStack(spacing: 6) {
            ForEach(Category.allCases, id: \.self) { category in
                CategoryPill(
                    category: category,
                    count: totals[category] ?? 0,
                    muted: mutedCategories.contains(category),
                    onToggle: { onToggleCategory(category) }
                )
            }
            Spacer()
            Button(action: onTogglePause) {
                Label(
                    paused ? "Resume" : "Pause",
                    systemImage: paused ? "play.fill" : "pause.fill"
                )
                .labelStyle(.iconOnly)
            }
            .controlSize(.small)
            .help(paused ? "Resume receiving events" : "Pause receiving events")

            Button("Clear", action: onClear)
                .controlSize(.small)
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Entries

    private var entriesList: some View {
        Group {
            if entries.isEmpty {
                emptyState
            } else {
                List(entries) { entry in
                    EventLogRow(entry: entry)
                        .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .frame(minHeight: 200, maxHeight: 360)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No events yet.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("Type to see textDidChange fire.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }
}

private struct CategoryPill: View {
    let category: EventLogSampleCoordinator.EventCategory
    let count: Int
    let muted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 4) {
                Circle()
                    .fill(EventLogPanel.color(for: category))
                    .frame(width: 6, height: 6)
                Text("\(category.rawValue.capitalized) · \(count)")
                    .font(.system(size: 11, design: .monospaced))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(muted ? Color.clear : EventLogPanel.color(for: category).opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(EventLogPanel.color(for: category).opacity(muted ? 0.6 : 0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EventLogRow: View {
    let entry: EventLogSampleCoordinator.LoggedEvent

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(Self.timeFormatter.string(from: entry.timestamp))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            HStack(spacing: 4) {
                Circle()
                    .fill(EventLogPanel.color(for: entry.category))
                    .frame(width: 6, height: 6)
                Text(entry.category.rawValue.capitalized)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 90, alignment: .leading)

            if entry.detail != nil, entry.category == .completion,
               entry.summary.hasSuffix("failed") {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.system(size: 10))
            }

            Text(entry.summary)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)

            Spacer()

            if let detail = entry.detail {
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .help(entry.detail ?? "")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

extension EventLogPanel {
    /// Per-category accent. The Text swatch comes from `Tokens.Palette.Accent.dark`
    /// so the panel exercises a `CodeEditorDesignTokens` swatch in passing —
    /// the rest are SwiftUI semantic colors. (The token is the package's own
    /// `Color(hex:)` type, bridged to SwiftUI via `Color(tokens:)` from
    /// `Theming/Bridges/Tokens.Color+SwiftUI.swift`.)
    static func color(for category: EventLogSampleCoordinator.EventCategory) -> Color {
        switch category {
        case .text:       return Color(tokens: Tokens.Palette.Accent.dark)
        case .selection:  return .blue
        case .focus:      return .purple
        case .completion: return .green
        }
    }
}
```

- [ ] **Step 8.2: Build to confirm compilation**

Run:

```
swift build --target CodeEditorSample
```

Expected: clean build. If `Color(tokens:)` is unavailable in the current import set, switch the line to `Color.accentColor` and note for a follow-up.

- [ ] **Step 8.3: Lint and commit**

```
swiftlint --fix && swiftlint
git add Sources/CodeEditorSample/Sidebars/EventLogPanel.swift
git commit -m "EventLogPanel: stateless SwiftUI view with pills + virtualized rows"
```

---

## Task 9: `EventLogPanel` snapshot tests

**Files:**
- Create: `Tests/CodeEditorSampleTests/EventLogPanelSnapshotTests.swift`
- Create (record): `Tests/CodeEditorSampleTests/__Snapshots__/EventLogPanelSnapshotTests/*.png`

- [ ] **Step 9.1: Write the snapshot test scaffolding**

Create `Tests/CodeEditorSampleTests/EventLogPanelSnapshotTests.swift`:

```swift
#if canImport(AppKit)
import AppKit
@testable import CodeEditorSample
import Foundation
import SnapshotTesting
import SwiftUI
import XCTest

final class EventLogPanelSnapshotTests: XCTestCase {

    private func sampleEntries(failedCompletion: Bool = false) -> [EventLogSampleCoordinator.LoggedEvent] {
        let base = Date(timeIntervalSince1970: 0)
        var entries: [EventLogSampleCoordinator.LoggedEvent] = [
            .text(summary: "textDidChange (len=42)", timestamp: base),
            .selection(summary: "selection=[loc=12, len=0]", timestamp: base.addingTimeInterval(1)),
            .focus(summary: "didBecomeFirstResponder", timestamp: base.addingTimeInterval(2))
        ]
        if failedCompletion {
            entries.append(EventLogSampleCoordinator.LoggedEvent(
                timestamp: base.addingTimeInterval(3),
                category: .completion,
                summary: "swift failed",
                detail: "timedOut"
            ))
        } else {
            entries.append(.completion(
                summary: "swift → 12 items · 4.3ms",
                detail: "swift-universal · trigger=\".\"",
                timestamp: base.addingTimeInterval(3)
            ))
        }
        return entries.reversed()
    }

    private func render(
        entries: [EventLogSampleCoordinator.LoggedEvent],
        totals: [EventLogSampleCoordinator.EventCategory: Int],
        mutedCategories: Set<EventLogSampleCoordinator.EventCategory> = [],
        paused: Bool = false
    ) -> some View {
        EventLogPanel(
            entries: entries,
            totals: totals,
            mutedCategories: mutedCategories,
            paused: paused,
            onToggleCategory: { _ in },
            onTogglePause: { },
            onClear: { }
        )
        .frame(width: 480, height: 320)
    }

    func testDefault() {
        let entries = sampleEntries()
        let totals: [EventLogSampleCoordinator.EventCategory: Int] = [.text: 1, .selection: 1, .focus: 1, .completion: 1]
        assertSnapshot(of: render(entries: entries, totals: totals), as: .image)
    }

    func testWithTextMuted() {
        let entries = sampleEntries().filter { $0.category != .text }
        let totals: [EventLogSampleCoordinator.EventCategory: Int] = [.text: 1, .selection: 1, .focus: 1, .completion: 1]
        assertSnapshot(
            of: render(entries: entries, totals: totals, mutedCategories: [.text]),
            as: .image
        )
    }

    func testPaused() {
        let entries = sampleEntries()
        let totals: [EventLogSampleCoordinator.EventCategory: Int] = [.text: 1, .selection: 1, .focus: 1, .completion: 1]
        assertSnapshot(of: render(entries: entries, totals: totals, paused: true), as: .image)
    }

    func testEmpty() {
        assertSnapshot(of: render(entries: [], totals: [:]), as: .image)
    }

    func testWithFailedCompletion() {
        let entries = sampleEntries(failedCompletion: true)
        let totals: [EventLogSampleCoordinator.EventCategory: Int] = [.text: 1, .selection: 1, .focus: 1, .completion: 1]
        assertSnapshot(of: render(entries: entries, totals: totals), as: .image)
    }
}
#endif
```

- [ ] **Step 9.2: Run with `isRecording: true` to capture baselines**

Temporarily edit the test file to add `isRecording = true` in `setUp`:

```swift
override func setUp() {
    super.setUp()
    isRecording = true
}
```

Run:

```
swift test --filter EventLogPanelSnapshotTests
```

Expected: all five tests "FAIL" with "Recorded new snapshot" — five PNGs land under `Tests/CodeEditorSampleTests/__Snapshots__/EventLogPanelSnapshotTests/`.

- [ ] **Step 9.3: Inspect the PNGs**

```
open Tests/CodeEditorSampleTests/__Snapshots__/EventLogPanelSnapshotTests/
```

Spot-check each: default shows all four rows, withTextMuted shows three rows and the Text pill outlined, paused has the play icon, empty shows the empty-state copy, withFailedCompletion has the orange warning glyph.

If any baseline looks wrong, edit the view or test inputs and re-run with `isRecording = true` until acceptable.

- [ ] **Step 9.4: Remove `isRecording = true`, re-run**

Delete the `override func setUp()` block (or set `isRecording = false`).

Run:

```
swift test --filter EventLogPanelSnapshotTests
```

Expected: all five tests PASS.

- [ ] **Step 9.5: Commit tests + snapshot baselines**

```
git add Tests/CodeEditorSampleTests/EventLogPanelSnapshotTests.swift Tests/CodeEditorSampleTests/__Snapshots__/EventLogPanelSnapshotTests/
git commit -m "Test: EventLogPanel snapshot baselines (default, muted, paused, empty, failed)"
```

---

## Task 10: Wire `AppState` + macOS sidebar

**Files:**
- Modify: `Sources/CodeEditorSample/App/AppState.swift`
- Modify: `Sources/CodeEditorSample/App/WindowBody.swift`
- Modify: `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift`

- [ ] **Step 10.1: Add `eventSystem` and `eventLog` to `AppState`**

In `Sources/CodeEditorSample/App/AppState.swift`, find the existing `let editorController = EditorController()` line. After the `annotationsHub` declaration (the existing block that defines `let annotationsHub: AnnotationsHub`), add two new properties OUTSIDE any `#if canImport(AppKit)` gate (`UnifiedEventSystem` and the coordinator are cross-platform):

```swift
    /// Shared `UnifiedEventSystem` for the sample. Wired into the editor view
    /// via `.eventSystem(_:)` in both `WindowBody` (macOS) and `IOSRootView`
    /// (iOS). The framework's `CodeEditorView.publishEvent(_:)` fans events
    /// into this instance.
    let eventSystem = UnifiedEventSystem()

    /// Cross-platform EventLog coordinator. Subscribes to `eventSystem` for
    /// framework-emitted EditorEvents and to `editorController.completionEvents()`
    /// for completion activity.
    let eventLog = EventLogSampleCoordinator()
```

Inside `init()`, after the existing AppKit-gated attachment block, add (UNGATED — coordinator is cross-platform):

```swift
        eventLog.attach(controller: editorController, eventSystem: eventSystem)
```

(Place this AFTER the AppKit-gated block so `editorController` is fully wired through other coordinators first — order matches the existing LSP / Performance / Completion attachment order.)

- [ ] **Step 10.2: Apply `.eventSystem(_:)` modifier in `WindowBody.editorPane`**

In `Sources/CodeEditorSample/App/WindowBody.swift`, find the `CodeEditor()` modifier chain in `editorPane` (around line 47). After `.performanceObserver(appState.performanceObservation)`, add:

```swift
                .eventSystem(appState.eventSystem)
```

- [ ] **Step 10.3: Add `EventLogPanel` to `InspectorSidebar`**

In `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift`, inside `scrollContent`, after the existing `AnnotationsInspectorPanel(...)` line and before the config `Text(rendered)` block, insert:

```swift
                eventLogPanel
```

And add a new computed property alongside the existing `completionPanel`:

```swift
    private var eventLogPanel: some View {
        EventLogPanel(
            entries: appState.eventLog.snapshot.entries,
            totals: appState.eventLog.snapshot.totals,
            mutedCategories: appState.eventLog.mutedCategories,
            paused: appState.eventLog.paused,
            onToggleCategory: { category in
                appState.eventLog.setMuted(category, !appState.eventLog.mutedCategories.contains(category))
            },
            onTogglePause: { appState.eventLog.setPaused(!appState.eventLog.paused) },
            onClear: { appState.eventLog.clear() }
        )
    }
```

- [ ] **Step 10.4: Build and run the sample app on macOS**

Run:

```
swift build --target CodeEditorSample && swift run CodeEditorSample
```

Verify by hand:
1. Open the right sidebar (it's already on by default for the sample).
2. Scroll past Performance / Completion / Annotations to find the new "Events" section.
3. Type into the editor — see `textDidChange (len=N)` rows appear in the Text category.
4. Click in the editor to move the cursor — see `selection=[loc=…, len=…]` rows in Selection.
5. Click out of the editor (e.g. into the sidebar) — see `didResignFirstResponder`. Click back in — see `didBecomeFirstResponder`.
6. Trigger a completion (⌃␣) — see a green Completion row.
7. Click the Text pill — text rows disappear, pill becomes outlined.
8. Click Pause — new events stop arriving; click Resume.
9. Click Clear — list empties, counts reset.

If any step misbehaves, fix the wiring before proceeding. (Examples: if Events never appear, suspect a missed `.eventSystem(appState.eventSystem)`; if completions never show, suspect a Combine retain cycle or a missed `completionTask` start.)

- [ ] **Step 10.5: Quit the sample, lint, and commit**

```
swiftlint --fix && swiftlint
git add Sources/CodeEditorSample/App/AppState.swift Sources/CodeEditorSample/App/WindowBody.swift Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift
git commit -m "Sample: wire EventLogPanel into macOS InspectorSidebar"
```

---

## Task 11: Surface the panel on iOS

**Files:**
- Modify: `Sources/CodeEditorSample/iOS/IOSRootView.swift`

- [ ] **Step 11.1: Replace `inspectorsUnavailable` with a layered view**

In `Sources/CodeEditorSample/iOS/IOSRootView.swift`, find the `inspectorsUnavailable` computed property (around line 87) and replace its entire body with:

```swift
    private var inspectorsUnavailable: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                EventLogPanel(
                    entries: appState.eventLog.snapshot.entries,
                    totals: appState.eventLog.snapshot.totals,
                    mutedCategories: appState.eventLog.mutedCategories,
                    paused: appState.eventLog.paused,
                    onToggleCategory: { category in
                        appState.eventLog.setMuted(category, !appState.eventLog.mutedCategories.contains(category))
                    },
                    onTogglePause: { appState.eventLog.setPaused(!appState.eventLog.paused) },
                    onClear: { appState.eventLog.clear() }
                )

                Divider()

                ContentUnavailableView {
                    Label("Other inspectors are macOS-only", systemImage: "macwindow.badge.plus")
                } description: {
                    Text(
                        """
                        The LSP, Completion, Performance, and Annotations inspectors \
                        live in `Sources/CodeEditorSample/Sidebars/` and are gated to \
                        AppKit. The underlying CodeEditorPlugin APIs (LSPManager, \
                        CompletionManager, PerformanceInsights, AnnotationsHub) work \
                        on iOS — only the sample's inspector chrome is desktop-only.

                        Remote LSP servers work on iOS: use \
                        `LanguageServerConfig.remote(url:)` with `LSPManager` to wire \
                        up a WebSocket-backed language server. Local servers require \
                        AppKit's `Process` API (macOS only) and throw an `LSPError` \
                        at start time on iOS.
                        """
                    )
                }
            }
            .padding(16)
        }
    }
```

The property name stays the same to minimize diff churn; rename to `inspectorsView` in a follow-up if desired.

- [ ] **Step 11.2: Apply `.eventSystem(_:)` to the iOS editor view**

In the same file, find the `editor` computed property (around line 110). Inside the `if appState.documents.active != nil` branch, after `.becomeFirstResponder()`, add:

```swift
                .eventSystem(appState.eventSystem)
```

- [ ] **Step 11.3: Build for iOS**

Run:

```
swift build --target CodeEditorSample
```

Then build for an iOS simulator destination if your local SDK has one available; otherwise rely on CI to validate the iOS path. The plan does not require a manual iOS smoke run — the underlying coordinator + panel are exercised by macOS tests and the Task 10 manual run.

- [ ] **Step 11.4: Lint and commit**

```
swiftlint --fix && swiftlint
git add Sources/CodeEditorSample/iOS/IOSRootView.swift
git commit -m "Sample iOS: surface EventLogPanel in Inspectors detail"
```

---

## Task 12: Final pass — full test suite, NEXT.md, summary commit

**Files:**
- Modify: `NEXT.md`

- [ ] **Step 12.1: Run lint + build + full test suite**

Run:

```
swift build && swiftlint --fix && swiftlint && swift test --parallel 2>&1 | tail -40
```

Expected: clean build, lint clean, all tests pass. If pre-existing flakes from NEXT.md § D surface, ignore — those are tracked separately. New flake or failure caused by this work should be diagnosed and fixed before continuing.

- [ ] **Step 12.2: Update `NEXT.md`**

In `NEXT.md`:

1. Find the line under "### A.1 Missing capabilities" that begins with `**Event stream invisible.**` and rewrite it to:

```
~~**Event stream invisible.**~~ — done. `EventLogSampleCoordinator` + `EventLogPanel` now surface `UnifiedEventSystem.events` (text / selection / focus) layered with `controller.completionEvents()` in the macOS `InspectorSidebar` and the iOS `IOSRootView` Inspectors detail. Framework wiring converted three `eventPublisher.publishSync(...)` sites to `publishEvent(...)` and added focus-event responder overrides in `CodeEditorView+Responder.swift`. Spec: `docs/superpowers/specs/2026-05-14-event-log-panel-design.md`; plan: `docs/superpowers/plans/2026-05-14-event-log-panel.md`.
```

2. In the A.2 "Concrete additions" table, strike through the `EventLogPanel` row:

```
| ~~`EventLogPanel`~~ | ~~Inspector sidebar~~ | done |
```

3. Add to A.3 #7 (iOS feature parity): a parenthetical note that the iOS Inspectors detail now has one cross-platform inspector (Events), partially closing the gap.

- [ ] **Step 12.3: Commit `NEXT.md`**

```
git add NEXT.md
git commit -m "NEXT.md: mark A.1 event stream gap done; note partial A.3 #7 progress"
```

- [ ] **Step 12.4: Verify branch state**

Run:

```
git log --oneline -15
```

Expected: 9 new commits since `8a56b7f NEXT.md: mark B.5 (NSRulerView TK1 island) done`, in this order (oldest first):

1. Spec: EventLog panel (already on `main` as `deb5e22`)
2. Test: .eventSystem(_:) fan-out for textDidChange + textSelectionDidChange (failing)
3. CodeEditorView: route text/selection events through publishEvent fan-out
4. CodeEditorView: publishEvent on first-responder transitions
5. EventLogSampleCoordinator: value types + append skeleton
6. EventLogSampleCoordinator: ring cap + mute + pause + clear
7. EventLogSampleCoordinator: Combine sink on UnifiedEventSystem.events
8. EventLogSampleCoordinator: completion event subscription + translator
9. EventLogPanel: stateless SwiftUI view with pills + virtualized rows
10. Test: EventLogPanel snapshot baselines (default, muted, paused, empty, failed)
11. Sample: wire EventLogPanel into macOS InspectorSidebar
12. Sample iOS: surface EventLogPanel in Inspectors detail
13. NEXT.md: mark A.1 event stream gap done; note partial A.3 #7 progress

(Numbering is informational — exact count depends on whether any task triggered extra commits for follow-ups.)

---

## Manual verification checklist

After Task 12, walk through this against `swift run CodeEditorSample` once more:

- [ ] Type "hello world" — see four `textDidChange` rows with growing `len=` values.
- [ ] Cursor home / end — see `selection=[loc=0, len=0]` and `selection=[loc=11, len=0]`.
- [ ] Click out of editor — `didResignFirstResponder`. Click back — `didBecomeFirstResponder`.
- [ ] Press ⌃␣ at end of `hello` — see Completion row, success path.
- [ ] Mute Text — only Selection / Focus / Completion rows visible; Text pill outlined; type more — Text count rises but no rows added.
- [ ] Unmute Text — old Text rows reappear up to ring cap (200).
- [ ] Pause — new events stop. Type — no rows appear. Resume — new events resume.
- [ ] Clear — list and pill counts all zero.
- [ ] Type rapidly to force ring cap — confirm oldest entries drop and no crash.

If anything fails, open an issue and fix before considering the plan complete.

---

## Notes for the implementing engineer

- **YAGNI on annotation / error events.** The `EditorEvent` cases `annotationHovered`, `annotationClicked`, `error`, `performanceWarning`, `textWillChange`, `completionRequested`, `completionItemSelected` are intentionally returned as `nil` from `translate(editorEvent:)`. Do not wire them. The spec defers them to a follow-up.
- **YAGNI on completion fan-out into UnifiedEventSystem.** `CompletionEventBroadcaster` stays separate from `UnifiedEventSystem`. The sample's coordinator unifies the two streams in the UI; the framework's separation stays.
- **DRY on the macOS/iOS panel binding.** The closure block that maps to coordinator actions is currently duplicated in `InspectorSidebar` and `IOSRootView`. If a third site appears, extract a helper. Two sites doesn't justify abstraction.
- **TDD discipline.** Each behavior (cap, mute, pause, clear, subscribe) gets a failing test FIRST. Do not skip ahead.
- **Frequent commits.** Every task ends in `git commit`. Do not batch multiple tasks into one commit — the commit log is the rollback granularity.
- **Color tokens.** `Color(tokens:)` is defined in `Sources/CodeEditorPlugin/Theming/Bridges/Tokens.Color+SwiftUI.swift` and `Tokens.Palette.Accent.dark` is in `Sources/CodeEditorDesignTokens/Palette.swift:13`. `CodeEditorSample` already depends on both targets via `Package.swift`. If a future refactor moves either, fall back to `Color.accentColor` for the Text pill and note the gap in NEXT.md A.1.
