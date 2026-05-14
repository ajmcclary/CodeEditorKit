# `EditorController.onAttach` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `EditorController.onAttach(_:)` so SwiftUI hosts can run setup code after the controller becomes attached to a `CodeEditorView`, and migrate the sample's `AppState.init` to use it (closing the latent silent-no-op bug where `setAnnotationsDataSource(hub)` is called on an unattached controller).

**Architecture:** Strictly additive on the framework. Single new `@MainActor` public method that registers a `@MainActor` handler closure, stored as `[(UUID, Closure)]` to preserve registration order. The existing internal `attach(to:)` method fires handlers only on a real view transition (the de-dup gate `view !== previousView`) so SwiftUI re-renders that re-call attach with the same view don't fire handlers on every keystroke. Cancellation returns an `AnyCancellable` (already imported in the file) whose cancel closure hops to `MainActor` for handler removal.

**Tech Stack:** Swift 6.3 (StrictConcurrency), SwiftUI, Combine (`AnyCancellable`), XCTest. Spec at `docs/superpowers/specs/2026-05-14-editor-controller-onattach-design.md` (commit `7a44e41`).

---

## File Structure

**Framework — 1 modified:**
- `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift` — new method, internal `attachHandlers` storage, de-dup gate inside `attach(to:)`, one doc paragraph on `setAnnotationsDataSource(_:)`.

**Sample — 1 modified:**
- `Sources/CodeEditorSample/App/AppState.swift` — replace line 102 (silent-no-op `setAnnotationsDataSource(hub)`) with an `onAttach` registration; add `private var attachToken: AnyCancellable?` stored property.

**Tests — 2 added:**
- `Tests/CodeEditorPluginTests/SwiftUI/EditorControllerOnAttachTests.swift` (new, XCTest) — six unit tests covering registration, first-attach firing, redundant-attach de-dup, view-change re-fire, no-fire-on-detach, cancellation.
- `Tests/CodeEditorSampleTests/AnnotationsHubInstallTests.swift` (new, XCTest) — regression test that the sample's `AnnotationsHub` is installed as the view's data source after attach (closes the latent bug).

---

## Task 1: Bootstrap test file with the first failing test

**Files:**
- Create: `Tests/CodeEditorPluginTests/SwiftUI/EditorControllerOnAttachTests.swift`

This task lays down the test scaffolding plus the simplest test — registering a handler does NOT fire it. Because `onAttach` does not exist yet, the test will fail to compile, confirming the test references the right symbol once we add it.

- [ ] **Step 1: Create the test file with the first test**

Create `Tests/CodeEditorPluginTests/SwiftUI/EditorControllerOnAttachTests.swift`:

```swift
import Combine
import XCTest

@testable import CodeEditorPlugin

/// Unit tests for `EditorController.onAttach(_:)`.
///
/// Verifies the lifecycle hook fires only on real view transitions
/// (first attach, attach to a different view, re-attach after detach)
/// and never on redundant re-attaches with the same view, on detach,
/// or after the host cancels the returned `AnyCancellable`.
///
/// Related: docs/superpowers/specs/2026-05-14-editor-controller-onattach-design.md
@available(macOS 13.0, iOS 16.0, *)
@MainActor
final class EditorControllerOnAttachTests: XCTestCase {
    func testHandlerNotFiredAtRegistration() {
        let controller = EditorController()
        var fireCount = 0

        let token = controller.onAttach { _ in fireCount += 1 }

        XCTAssertEqual(fireCount, 0, "Handler must not run before any attach.")
        _ = token // suppress unused warning; token retains the registration
    }
}
```

- [ ] **Step 2: Run the test, expect a compile failure**

Run:
```bash
swift test --filter EditorControllerOnAttachTests/testHandlerNotFiredAtRegistration
```

Expected: compile failure with an error pointing at `controller.onAttach` (no such member).

**Do not commit yet** — the codebase currently compiles cleanly. A failing-to-compile test must not land in `main`. Move directly to Task 2.

---

## Task 2: Add the minimal `onAttach` stub returning a no-op `AnyCancellable`

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`

The stub method has the final public signature but does nothing internally. This is the smallest change that turns the test from a compile failure into a passing test (because the no-op stub trivially does not fire anything).

- [ ] **Step 1: Add the stub `onAttach` method**

Open `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift` and find the `// MARK: - Attach hook (called by the SwiftUI representable)` section (around line 107). Immediately above that MARK, add a new MARK section with the stub method:

```swift
    // MARK: - Attach lifecycle hooks

    /// Register a handler that runs every time this controller becomes
    /// attached to a `CodeEditorView`. Use this to perform setup that
    /// requires a live view (installing a data source, scrolling to a
    /// caret position, applying initial decorations).
    ///
    /// Handlers fire on the main actor when the underlying view is
    /// first created and again every time SwiftUI re-creates it
    /// (e.g. parent identity change, sheet remount). Handlers MUST
    /// therefore be idempotent.
    ///
    /// Handlers are NOT invoked retroactively. If `onAttach` is called
    /// after the controller is already attached, the handler runs on
    /// the next attach. Hosts that want immediate-then-on-reattach
    /// semantics branch on `isAttached`:
    ///
    /// ```swift
    /// let token = controller.onAttach { ctrl in install(ctrl) }
    /// if controller.isAttached { install(controller) }
    /// ```
    ///
    /// - Parameter handler: Closure invoked on the main actor whenever
    ///   the controller becomes attached. The closure receives the
    ///   controller itself, so weak-self captures are unnecessary.
    /// - Returns: An `AnyCancellable` token. Drop or `cancel()` it to
    ///   remove the handler. Store it in `Set<AnyCancellable>` or as a
    ///   property to keep the subscription active.
    public func onAttach(
        _ handler: @MainActor @escaping (EditorController) -> Void
    ) -> AnyCancellable {
        AnyCancellable {}
    }
```

- [ ] **Step 2: Run the test, expect a pass**

Run:
```bash
swift test --filter EditorControllerOnAttachTests/testHandlerNotFiredAtRegistration
```

Expected: 1 test passes, 0 failures.

- [ ] **Step 3: Verify the build is clean**

Run:
```bash
swift build && swiftlint --fix && swiftlint
```

Expected: build succeeds; SwiftLint reports 0 violations.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/EditorController.swift \
        Tests/CodeEditorPluginTests/SwiftUI/EditorControllerOnAttachTests.swift
git commit -m "$(cat <<'EOF'
Add EditorController.onAttach stub

Public signature only — body returns a no-op AnyCancellable. Next
commits add storage, firing on attach, the de-dup gate, and
cancellation. Test confirms registration-time non-firing.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Implement basic firing on real attach (and confirm no-fire on detach)

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`
- Modify: `Tests/CodeEditorPluginTests/SwiftUI/EditorControllerOnAttachTests.swift`

Add two tests in one batch: (a) handler fires on first attach, (b) handler does NOT fire on detach. The first will fail (no firing yet); the second passes vacuously (still no firing path). Then add the storage + unconditional firing inside the `attach(to: nonNil)` branch, and both tests pass.

- [ ] **Step 1: Add the two new tests**

Append to `Tests/CodeEditorPluginTests/SwiftUI/EditorControllerOnAttachTests.swift`, inside the class body:

```swift
    func testHandlerFiredOnFirstAttach() {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        var fireCount = 0
        var receivedController: EditorController?

        let token = controller.onAttach { ctrl in
            fireCount += 1
            receivedController = ctrl
        }

        controller.attach(to: view)

        XCTAssertEqual(fireCount, 1, "Handler must fire exactly once on the first attach.")
        XCTAssertTrue(receivedController === controller,
                      "Handler must receive the controller it was registered on.")
        _ = token
    }

    func testHandlerNotFiredOnDetach() {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        var fireCount = 0

        let token = controller.onAttach { _ in fireCount += 1 }
        controller.attach(to: view)
        controller.attach(to: nil)

        XCTAssertEqual(fireCount, 1, "Detach must not fire onAttach handlers.")
        _ = token
    }
```

- [ ] **Step 2: Run the new tests, expect one failure**

Run:
```bash
swift test --filter EditorControllerOnAttachTests
```

Expected: 3 tests run, 1 fails (`testHandlerFiredOnFirstAttach` — fireCount is 0 instead of 1). The other two pass.

- [ ] **Step 3: Add internal storage and unconditional firing on attach**

In `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`:

**3a.** Find the `// MARK: - Internal wiring` block (around line 47). After the existing `@ObservationIgnored weak var codeEditorView: CodeEditorView?` and the symbol-navigator properties, add the new attach-handlers storage. Place it AFTER the existing `#if canImport(AppKit)` block that ends at line 87. The new field is platform-agnostic:

```swift
    /// Handlers registered via `onAttach(_:)`. Stored as an array (rather
    /// than a dictionary) so registration order is preserved and
    /// iteration is deterministic. Typical sizes are 1–3 entries.
    @ObservationIgnored
    private var attachHandlers: [(id: UUID, closure: @MainActor (EditorController) -> Void)] = []
```

**3b.** Replace the stub body of `onAttach(_:)` with the real implementation. Update the method body to:

```swift
    public func onAttach(
        _ handler: @MainActor @escaping (EditorController) -> Void
    ) -> AnyCancellable {
        let id = UUID()
        attachHandlers.append((id, handler))
        return AnyCancellable { [weak self] in
            // `AnyCancellable`'s cancel closure is not @MainActor-isolated
            // (Combine predates strict concurrency). Hop back to
            // MainActor to mutate `attachHandlers` safely.
            Task { @MainActor in
                self?.attachHandlers.removeAll { $0.id == id }
            }
        }
    }
```

**3c.** Find the `func attach(to view: CodeEditorView?)` method (around line 111). Modify it to fire handlers inside the `if let view` branch, AFTER the existing `isAttached = true` and AppKit-only event-bus installer block. The full method becomes:

```swift
    func attach(to view: CodeEditorView?) {
        codeEditorView = view
        if let view {
            symbolNavigator.attach(to: view)
            // Mirror the navigator's symbol list into our @Observable
            // property so hosts can bind through the controller without
            // also retaining the navigator.
            symbolSubscription = symbolNavigator.$symbols.sink { [weak self] newSymbols in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.symbols = newSymbols
                }
            }
            isAttached = true
            #if canImport(AppKit)
            // Install hover/⌘-click monitoring on the wrapped text view.
            eventBusInstaller?.uninstall()
            let installer = EditorEventBusInstaller(bus: editorEventBus, textView: view)
            installer.install()
            eventBusInstaller = installer
            #endif

            // Fire registered onAttach handlers. Snapshot first so a
            // handler that calls onAttach again doesn't mutate the
            // in-flight iteration.
            let snapshot = attachHandlers
            for (_, handler) in snapshot {
                handler(self)
            }
        } else {
            symbolSubscription?.cancel()
            symbolSubscription = nil
            symbols = []
            matchCount = 0
            currentMatchIndex = -1
            isAttached = false
            #if canImport(AppKit)
            eventBusInstaller?.uninstall()
            eventBusInstaller = nil
            #endif
        }
    }
```

Note: this version fires unconditionally on `attach(to: nonNil)` — the de-dup gate is added in Task 4. The two tests added in this task will both pass with the unconditional firing.

- [ ] **Step 4: Run all three tests, expect all to pass**

Run:
```bash
swift test --filter EditorControllerOnAttachTests
```

Expected: 3 tests run, 3 pass, 0 fail.

- [ ] **Step 5: Verify the build is clean**

Run:
```bash
swift build && swiftlint --fix && swiftlint
```

Expected: build succeeds; SwiftLint reports 0 violations.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/EditorController.swift \
        Tests/CodeEditorPluginTests/SwiftUI/EditorControllerOnAttachTests.swift
git commit -m "$(cat <<'EOF'
EditorController.onAttach: fire on attach, never on detach

Internal storage as ordered array of (UUID, closure). Snapshot
before iterating so handlers can register new ones safely. No
de-dup gate yet — redundant re-attaches still fire handlers; next
commit adds the gate.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Add the de-duplication gate (skip same-view re-attaches)

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`
- Modify: `Tests/CodeEditorPluginTests/SwiftUI/EditorControllerOnAttachTests.swift`

`CodeEditorRepresentableHelper.updateContainer` calls `controller.attach(to: container.textView)` on every SwiftUI update (including every keystroke). Without the gate, every keystroke would re-fire all `onAttach` handlers. The gate fires only when `view !== previousView`.

- [ ] **Step 1: Add the two new tests**

Append to `Tests/CodeEditorPluginTests/SwiftUI/EditorControllerOnAttachTests.swift`, inside the class body:

```swift
    func testHandlerNotFiredOnRedundantAttach() {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        var fireCount = 0

        let token = controller.onAttach { _ in fireCount += 1 }
        controller.attach(to: view)
        controller.attach(to: view) // same view — must not re-fire
        controller.attach(to: view) // again — still must not re-fire

        XCTAssertEqual(fireCount, 1,
                       "Attaching the same view repeatedly must fire onAttach handlers exactly once.")
        _ = token
    }

    func testHandlerFiredOnDifferentView() {
        let controller = EditorController()
        let viewA = CodeEditorView(frame: .zero)
        let viewB = CodeEditorView(frame: .zero)
        var fireCount = 0

        let token = controller.onAttach { _ in fireCount += 1 }
        controller.attach(to: viewA)
        controller.attach(to: viewB)

        XCTAssertEqual(fireCount, 2,
                       "Switching to a different view must re-fire onAttach handlers.")
        _ = token
    }
```

- [ ] **Step 2: Run the new tests, expect one failure**

Run:
```bash
swift test --filter EditorControllerOnAttachTests
```

Expected: 5 tests run, 1 fails (`testHandlerNotFiredOnRedundantAttach` — fireCount is 3 instead of 1 because every attach call currently fires). The other tests, including `testHandlerFiredOnDifferentView`, pass.

- [ ] **Step 3: Add the de-dup gate to `attach(to:)`**

In `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`, modify the `attach(to:)` method to record the previous view and gate handler firing on a real transition. The full method now reads:

```swift
    func attach(to view: CodeEditorView?) {
        let previousView = codeEditorView
        codeEditorView = view
        if let view {
            symbolNavigator.attach(to: view)
            // Mirror the navigator's symbol list into our @Observable
            // property so hosts can bind through the controller without
            // also retaining the navigator.
            symbolSubscription = symbolNavigator.$symbols.sink { [weak self] newSymbols in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.symbols = newSymbols
                }
            }
            isAttached = true
            #if canImport(AppKit)
            // Install hover/⌘-click monitoring on the wrapped text view.
            eventBusInstaller?.uninstall()
            let installer = EditorEventBusInstaller(bus: editorEventBus, textView: view)
            installer.install()
            eventBusInstaller = installer
            #endif

            // Fire registered onAttach handlers only on a real view
            // transition (nil → A, A → B, nil → A after detach). The
            // SwiftUI representable calls `attach(to: sameView)` on every
            // update, so skipping the same-view case keeps handlers from
            // firing on every keystroke.
            if view !== previousView {
                let snapshot = attachHandlers
                for (_, handler) in snapshot {
                    handler(self)
                }
            }
        } else {
            symbolSubscription?.cancel()
            symbolSubscription = nil
            symbols = []
            matchCount = 0
            currentMatchIndex = -1
            isAttached = false
            #if canImport(AppKit)
            eventBusInstaller?.uninstall()
            eventBusInstaller = nil
            #endif
        }
    }
```

- [ ] **Step 4: Run all five tests, expect all to pass**

Run:
```bash
swift test --filter EditorControllerOnAttachTests
```

Expected: 5 tests run, 5 pass, 0 fail.

- [ ] **Step 5: Verify the build is clean**

Run:
```bash
swift build && swiftlint --fix && swiftlint
```

Expected: build succeeds; SwiftLint reports 0 violations.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/EditorController.swift \
        Tests/CodeEditorPluginTests/SwiftUI/EditorControllerOnAttachTests.swift
git commit -m "$(cat <<'EOF'
EditorController.onAttach: gate firing on view-instance change

Prevents handlers from re-firing on every SwiftUI update — the
representable's updateContainer hits attach(to: sameView) on every
keystroke. The gate fires only on a real transition (nil → A,
A → B, nil → A after detach).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Implement cancellable removal

**Files:**
- Modify: `Tests/CodeEditorPluginTests/SwiftUI/EditorControllerOnAttachTests.swift`

The implementation of cancellation already landed in Task 3 (Step 3b's `AnyCancellable { [weak self] in Task { @MainActor in … } }` block). This task adds the test that asserts it works. Because `Task { @MainActor in … }` is asynchronous, the test awaits cancellation by yielding the runloop before re-attaching.

- [ ] **Step 1: Add the cancellation test**

Append to `Tests/CodeEditorPluginTests/SwiftUI/EditorControllerOnAttachTests.swift`, inside the class body:

```swift
    func testCancellableRemovesHandler() async {
        let controller = EditorController()
        let viewA = CodeEditorView(frame: .zero)
        let viewB = CodeEditorView(frame: .zero)
        var fireCount = 0

        var token: AnyCancellable? = controller.onAttach { _ in fireCount += 1 }

        // Initial attach fires the handler once.
        controller.attach(to: viewA)
        XCTAssertEqual(fireCount, 1, "Handler should fire on the first attach.")

        // Cancel the token. The cancel closure hops to MainActor via a
        // Task, so yield the runloop once to let it run.
        token?.cancel()
        token = nil
        await Task.yield()

        // After cancellation, a real view transition should NOT fire
        // the handler again.
        controller.attach(to: viewB)
        XCTAssertEqual(fireCount, 1,
                       "Cancelled handler must not run on subsequent attaches.")
    }
```

- [ ] **Step 2: Run all six tests, expect all to pass**

Run:
```bash
swift test --filter EditorControllerOnAttachTests
```

Expected: 6 tests run, 6 pass, 0 fail.

- [ ] **Step 3: Verify the build is clean**

Run:
```bash
swift build && swiftlint --fix && swiftlint
```

Expected: build succeeds; SwiftLint reports 0 violations.

- [ ] **Step 4: Commit**

```bash
git add Tests/CodeEditorPluginTests/SwiftUI/EditorControllerOnAttachTests.swift
git commit -m "$(cat <<'EOF'
EditorController.onAttach: cover cancellation behavior

Adds the sixth unit test asserting that cancelling the returned
AnyCancellable removes the handler. Test yields the runloop after
cancel() to let the MainActor hop inside the cancel closure run.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Document the unattached no-op contract on `setAnnotationsDataSource`

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`

Doc-only change. Point readers at `onAttach` for the "install this from my init" case so the next host doesn't hit the silent no-op.

- [ ] **Step 1: Update the doc comment on `setAnnotationsDataSource(_:)`**

Find the method declaration in `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift` (around line 267-273). Replace its existing doc comment with:

```swift
    /// Install a data source on the underlying `CodeEditorView` and
    /// trigger an annotation reload. The view holds the source weakly,
    /// so callers must keep their own strong reference.
    ///
    /// - Important: This method is a no-op when the controller is
    ///   unattached (`isAttached == false`). To install a data source
    ///   from a host's `init` — before the SwiftUI representable has
    ///   created the underlying view — use `onAttach(_:)`:
    ///
    ///   ```swift
    ///   attachToken = controller.onAttach { [weak hub] ctrl in
    ///       guard let hub else { return }
    ///       ctrl.setAnnotationsDataSource(hub)
    ///   }
    ///   ```
    public func setAnnotationsDataSource(_ source: any AnnotationsDataSource) {
        codeEditorView?.annotationsDataSource = source
        codeEditorView?.reloadAnnotations()
    }
```

- [ ] **Step 2: Verify the build is clean**

Run:
```bash
swift build && swiftlint --fix && swiftlint
```

Expected: build succeeds; SwiftLint reports 0 violations.

- [ ] **Step 3: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/EditorController.swift
git commit -m "$(cat <<'EOF'
EditorController: document onAttach pattern on setAnnotationsDataSource

Doc-only change. Points readers at onAttach(_:) so the next host
doesn't repeat the latent silent-no-op bug the sample's AppState
just had.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Migrate the sample's `AppState.init` to `onAttach`

**Files:**
- Modify: `Sources/CodeEditorSample/App/AppState.swift`

Replace the silent no-op call with an `onAttach` registration. Adds one stored property (`attachToken: AnyCancellable?`) so the registration outlives `init`.

- [ ] **Step 1: Add the `Combine` import and the `attachToken` property**

Open `Sources/CodeEditorSample/App/AppState.swift`. At the top of the file, the existing imports are:

```swift
import CodeEditorPlugin
import Foundation
import Observation
```

Add `Combine`:

```swift
import Combine
import CodeEditorPlugin
import Foundation
import Observation
```

Then in the class body, immediately after the existing `let editorController = EditorController()` line (around line 34), add the new stored property:

```swift
    /// Retains the `editorController.onAttach` subscription that wires
    /// the annotations data source after the SwiftUI representable
    /// attaches the underlying view. Dropping this would cancel the
    /// registration; we keep it for the lifetime of `AppState`.
    @ObservationIgnored
    private var attachToken: AnyCancellable?
```

- [ ] **Step 2: Replace the silent-no-op call in `init()`**

In `AppState.init()`, locate the three lines starting at line 99-102:

```swift
        let hub = AnnotationsHub()
        self.annotationsHub = hub
        hub.controller = editorController
        editorController.setAnnotationsDataSource(hub)
```

Replace them with:

```swift
        let hub = AnnotationsHub()
        self.annotationsHub = hub
        hub.controller = editorController
        // The controller is freshly constructed at line 34 — its
        // codeEditorView is nil, so a direct call to
        // setAnnotationsDataSource here would be a silent no-op.
        // Defer the install until the SwiftUI representable attaches
        // the underlying view.
        attachToken = editorController.onAttach { [weak hub] ctrl in
            guard let hub else { return }
            ctrl.setAnnotationsDataSource(hub)
        }
```

- [ ] **Step 3: Build and run targeted sample tests**

Run:
```bash
swift build --target CodeEditorSample
swift test --filter AnnotationsHub
```

Expected: sample target builds; existing `AnnotationsHubDiagnosticsTests` continue to pass.

- [ ] **Step 4: Verify SwiftLint is clean**

Run:
```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorSample/App/AppState.swift
git commit -m "$(cat <<'EOF'
Sample: migrate AnnotationsHub install to EditorController.onAttach

Closes the silent-no-op bug at AppState.swift:102 — the previous
direct setAnnotationsDataSource(hub) call hit an unattached
controller and was lost. onAttach defers the install until the
SwiftUI representable wires up the underlying view.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Add sample-side regression test

**Files:**
- Create: `Tests/CodeEditorSampleTests/AnnotationsHubInstallTests.swift`

Asserts that the `AnnotationsHub` actually becomes the view's data source after attach. This is the test that would have caught the original bug.

- [ ] **Step 1: Create the test file**

Create `Tests/CodeEditorSampleTests/AnnotationsHubInstallTests.swift`:

```swift
#if canImport(AppKit)
import Combine
import CodeEditorPlugin
@testable import CodeEditorSample
import XCTest

/// Regression test for the silent-no-op bug at AppState.swift:102
/// (before the onAttach migration): calling
/// `editorController.setAnnotationsDataSource(hub)` on an unattached
/// controller did nothing. After the migration the install is deferred
/// until the SwiftUI representable's attach hook fires; this test
/// reproduces that flow and asserts the data source is wired.
///
/// Related: docs/superpowers/specs/2026-05-14-editor-controller-onattach-design.md
@MainActor
final class AnnotationsHubInstallTests: XCTestCase {
    func testHubInstalledAsDataSourceAfterAttach() {
        // Construct AppState the way the app does — eager
        // editorController, AnnotationsHub, onAttach registration.
        let appState = AppState()

        // Pre-attach, the controller's underlying view is nil, so the
        // hub is NOT yet installed as a data source anywhere. The
        // attachToken inside AppState is now alive and waiting.
        XCTAssertFalse(appState.editorController.isAttached,
                       "Freshly-constructed controller should be unattached.")

        // Simulate what the SwiftUI representable does: build a
        // CodeEditorView and run attach(to:).
        let view = CodeEditorView(frame: .zero)
        appState.editorController.attach(to: view)

        XCTAssertTrue(appState.editorController.isAttached,
                      "Controller should be attached after attach(to:).")

        // The annotations data source should now be the hub.
        XCTAssertTrue(view.annotationsDataSource === appState.annotationsHub,
                      "AnnotationsHub must be installed as the view's data source after attach.")
    }
}
#endif
```

- [ ] **Step 2: Run the new test**

Run:
```bash
swift test --filter AnnotationsHubInstallTests
```

Expected: 1 test runs, 1 passes.

- [ ] **Step 3: Verify build + lint**

Run:
```bash
swift build && swiftlint --fix && swiftlint
```

Expected: build succeeds; SwiftLint reports 0 violations.

- [ ] **Step 4: Commit**

```bash
git add Tests/CodeEditorSampleTests/AnnotationsHubInstallTests.swift
git commit -m "$(cat <<'EOF'
Sample: regression test for AnnotationsHub install after attach

Reproduces the AppState construction flow, attaches a fresh
CodeEditorView to the controller, and asserts the hub becomes
the view's data source. This is the test that would have caught
the original silent-no-op bug.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Final verification

**Files:** None modified.

Confirm the whole-package state: build, lint, and the targeted test suites are green. The full `swift test --parallel` is left to discretion — REVIEW.md memory note `feedback_test_confirmations` says to skip it after additive-only steps. The Status section in REVIEW.md documents pre-existing failures (`EditorStatusBarSnapshots`, `RegexRangeHighlightProviderTests.testParsePerformance10K/100KLines`, `ScrollPositionPreservationTests`, `LineGeometryStoreBenchmarkTests.testFuzzIncrementalEditCorrectness`, `PerformanceInsightsRealMetricsTests.currentFPSReflectsInjectedMonitor`); none should be affected by this work.

- [ ] **Step 1: Whole-package build and lint**

Run:
```bash
swift build && swiftlint --fix && swiftlint
```

Expected: build succeeds; SwiftLint reports 0 violations.

- [ ] **Step 2: Targeted test sweep across touched areas**

Run:
```bash
swift test --filter "EditorController|AnnotationsHub|Annotation"
```

Expected: all `EditorControllerOnAttachTests` (6 tests), `EditorControllerTests`, `EditorControllerCompletionTests`, `EditorControllerTemporaryAttributesTests`, `AnnotationsHubInstallTests`, `AnnotationsHubDiagnosticsTests`, and other annotation suites pass without new failures.

- [ ] **Step 3: Verify the working tree is clean**

Run:
```bash
git status
```

Expected: `On branch main`, `nothing to commit, working tree clean` (all commits from Tasks 2–8 have landed).

- [ ] **Step 4: Update REVIEW.md status**

Open `REVIEW.md`. Locate the "What's left after this round" section near the bottom. The current line reads:

```markdown
- **Sample-driven API gaps #5, #6** — `EditorController.onAttach`, `CompletionEvent` AsyncStream. (#3 `EditorDocument` recipe and #7 `.performanceObserver(_:)` modifier — landed.)
```

Edit it to:

```markdown
- **Sample-driven API gap #6** — `CompletionEvent` AsyncStream. (#3 `EditorDocument` recipe, #5 `EditorController.onAttach`, and #7 `.performanceObserver(_:)` modifier — landed.)
```

Also locate the "API gaps revealed by `CodeEditorSample`" section's item 5 (around line 414):

```markdown
5. **Three-way `EditorController` wiring is hidden in `AppState.init`** (`AppState.swift:93-118`): `.editorController(_:)` modifier + injection into `AnnotationsHub` + injection into `LSPSampleCoordinator`. Consider `EditorController.onAttach { ... }`.
```

Edit it to:

```markdown
5. ~~**Three-way `EditorController` wiring is hidden in `AppState.init`** (`AppState.swift:93-118`): `.editorController(_:)` modifier + injection into `AnnotationsHub` + injection into `LSPSampleCoordinator`. Consider `EditorController.onAttach { ... }`.~~ ✅ Done in the `EditorController.onAttach` batch on 2026-05-14. Closes the silent-no-op bug where `setAnnotationsDataSource(hub)` was called on an unattached controller. Spec at `docs/superpowers/specs/2026-05-14-editor-controller-onattach-design.md`; plan at `docs/superpowers/plans/2026-05-14-editor-controller-onattach.md`.
```

- [ ] **Step 5: Commit the REVIEW.md update**

```bash
git add REVIEW.md
git commit -m "$(cat <<'EOF'
Update REVIEW.md: EditorController.onAttach landed

Closes sample-driven API gap #5. Strikes through the entry in the
gap list and trims "What's left" to gap #6 only.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: Verify final state**

Run:
```bash
git log --oneline | head -10
git status
```

Expected: nine new commits since the spec commit (`7a44e41`), working tree clean.

---

## Spec Coverage Check

| Spec section | Plan task(s) |
|---|---|
| Public API surface (`onAttach` signature, doc) | Task 2 (stub), Task 3 (storage + firing) |
| Internal storage (`attachHandlers` array, UUID id) | Task 3 |
| Implementation (registration, snapshot iteration) | Task 3 |
| De-duplication gate (`view !== previousView`) | Task 4 |
| Doc-comment update on `setAnnotationsDataSource` | Task 6 |
| Sample migration (`AppState` line 102 → `onAttach`) | Task 7 |
| Threading (`Task { @MainActor in … }` in cancel closure) | Task 3 step 3b |
| Test plan — 6 unit tests on `EditorController` | Tasks 1, 3, 4, 5 |
| Test plan — sample regression test | Task 8 |
| Public API impact (strictly additive) | All — verified in Tasks 2, 4, 6 builds |

All spec sections accounted for. No placeholders. Type names, method signatures, and property names are consistent across tasks.
