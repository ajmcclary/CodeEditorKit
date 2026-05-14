# `EditorController.onAttach` — Design Spec

**Date:** 2026-05-14
**Closes:** Sample-driven API gap #5 from [`REVIEW.md`](../../../REVIEW.md) ("Three-way `EditorController` wiring is hidden in `AppState.init`").
**Status:** Draft for user review.

## Problem

`EditorController` is created eagerly by the host (typically in an app-state model) and only attached to the underlying `CodeEditorView` later, when the SwiftUI representable runs `make…`. Some controller methods need a live view to do anything useful — installing an annotations data source is the canonical case — but the framework offers no lifecycle hook for "run this once the controller is attached." Hosts either guess at timing or, more often, call the setup methods eagerly and silently lose the call.

The sample demonstrates the bug. `Sources/CodeEditorSample/App/AppState.swift:102` runs:

```swift
editorController.setAnnotationsDataSource(hub)
```

at a point where `editorController.codeEditorView` is `nil`. The current implementation of `setAnnotationsDataSource(_:)` is:

```swift
public func setAnnotationsDataSource(_ source: any AnnotationsDataSource) {
    codeEditorView?.annotationsDataSource = source
    codeEditorView?.reloadAnnotations()
}
```

Both lines are optional-chained no-ops while `codeEditorView` is `nil`. Worse, `attach(to:)` does not replay queued setup — when the controller later becomes attached, the previously-attempted data-source install is lost. The annotations data source is never installed at all.

The same shape — call-and-pray on an unattached controller — applies to any future controller method whose effect must persist past the call (decoration installs, initial scroll positions, custom-attribute decorations). `REVIEW.md` flags this collectively as the "three-way wiring in `AppState.init`" problem and suggests a lifecycle hook.

## Goals

- Provide a public, idiomatic hook hosts can use to run setup code once the controller is attached to a live view.
- Handle SwiftUI re-attachment cleanly (parent identity change, navigation, sheet remount) without firing on every routine SwiftUI re-render.
- Close the latent silent-no-op bug in the sample by routing `setAnnotationsDataSource` through the new hook.
- Stay strictly additive on the public API. No existing call site changes shape; no other controller methods change.

## Non-goals

- Reorganizing the four sample coordinators (`LSPSampleCoordinator`, `PerformanceSampleCoordinator`, `CompletionSampleCoordinator`, `AnnotationsHub`) into a unified attach pipeline. Only `AnnotationsHub` needs the hook today; the other three want a long-lived weak controller reference, which their existing `attach(controller:)` methods already provide.
- Adding `onDetach` symmetry. No sample case currently needs detach-time cleanup beyond what the framework does internally. Can be added later if a host case appears.
- Replaying queued state. Methods like `setAnnotationsDataSource(_:)` continue to be no-ops when called unattached; callers wanting deferred install use `onAttach`. Queueing semantics would require weak storage of arbitrary state and add hidden lifecycle, which conflicts with the "minimal" scope.
- Making `setAnnotationsDataSource(_:)` issue a runtime warning when called unattached. Documented via the doc comment instead — `onAttach`'s availability makes the right pattern obvious.

## Design

### Public API

A single new method on `EditorController`:

```swift
@available(macOS 13.0, iOS 16.0, *)
@MainActor
extension EditorController {
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
    ) -> AnyCancellable
}
```

`AnyCancellable` is already used in `EditorController.swift` for `symbolSubscription`, so the return type pulls no new imports and composes with hosts' existing Combine stores.

### Internal storage

```swift
// New stored property on EditorController (alongside the existing
// @ObservationIgnored private fields):
@ObservationIgnored
private var attachHandlers: [(id: UUID, closure: @MainActor (EditorController) -> Void)] = []
```

Array, not dictionary — registration order is preserved deterministically. Typical handler counts are small (one or two per controller), so the O(n) removal cost on cancel is acceptable.

### Implementation

```swift
public func onAttach(
    _ handler: @MainActor @escaping (EditorController) -> Void
) -> AnyCancellable {
    let id = UUID()
    attachHandlers.append((id, handler))
    return AnyCancellable { [weak self] in
        // MainActor isolation: AnyCancellable's cancel closure may run
        // off-main when the host drops the token from a background
        // context. Hop back to MainActor for the mutation.
        Task { @MainActor in
            self?.attachHandlers.removeAll { $0.id == id }
        }
    }
}
```

### De-duplication gate (load-bearing)

`attach(to:)` is currently called unconditionally by `CodeEditorRepresentableHelper.updateContainer` on every SwiftUI re-render (see `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift:113-118`). Today that's a silent no-op because `attach(to: sameView)` overwrites the weak ref with itself and re-runs the symbol-navigator wiring. With `onAttach` handlers attached, naive firing would invoke them on every keystroke. The fix lives inside `attach(to:)`:

```swift
func attach(to view: CodeEditorView?) {
    let previousView = codeEditorView
    codeEditorView = view
    if let view {
        // ... existing setup ...
        isAttached = true
        #if canImport(AppKit)
        // ... existing event-bus installer wiring ...
        #endif

        // Fire onAttach handlers only on a real transition
        // (nil → A, A → B, nil → A after detach). Skip when the
        // attached view is the same instance as before.
        if view !== previousView {
            let snapshot = attachHandlers
            for (_, handler) in snapshot {
                handler(self)
            }
        }
    } else {
        // ... existing teardown (no handler firing on detach) ...
    }
}
```

Snapshotting the array before iterating means a handler that calls `onAttach` again doesn't mutate the in-flight loop.

### Doc-comment update on `setAnnotationsDataSource`

`Sources/CodeEditorPlugin/SwiftUI/EditorController.swift:267-273` gets one paragraph noting that the method is a no-op when called unattached and pointing at `onAttach` for the "install from my init" case. No behavior change.

### Sample migration

`Sources/CodeEditorSample/App/AppState.swift` line 102 is the only place that hits the latent bug:

```swift
// Before:
editorController.setAnnotationsDataSource(hub)

// After:
attachToken = editorController.onAttach { [weak hub] ctrl in
    guard let hub else { return }
    ctrl.setAnnotationsDataSource(hub)
}
```

`AppState` grows one new stored property:

```swift
private var attachToken: AnyCancellable?
```

The other three sample coordinators (`LSPSampleCoordinator`, `PerformanceSampleCoordinator`, `CompletionSampleCoordinator`) and `AnnotationsHub.controller = editorController` assignment are unchanged.

## Lifecycle semantics

| Event | Handler fires? |
|---|---|
| `onAttach(...)` called while unattached | No (registered for next attach) |
| `onAttach(...)` called while attached | No (no retroactive replay) |
| `attach(to: view)` — first attach | Yes |
| `attach(to: view)` — re-render with same view | No (de-dup gate) |
| `attach(to: view2)` — different view | Yes |
| `attach(to: nil)` — detach | No |
| `attach(to: view)` after detach (re-attach) | Yes |
| `AnyCancellable.cancel()` called | Handler removed; no further fires |
| Controller `deinit` | Handlers dropped with the controller |

## Threading

- All public surface (`onAttach`, the handler closure) is `@MainActor`-isolated, matching the existing `EditorController` class isolation.
- `AnyCancellable`'s cancel closure is not statically `@MainActor`-isolated (Combine's API is pre-strict-concurrency). The implementation hops to `MainActor` via `Task { @MainActor in … }` to make handler removal main-thread-safe regardless of where the cancellable is dropped from.

## Public API impact

Strictly additive:

- New `EditorController.onAttach(_:)` method.
- One paragraph added to `EditorController.setAnnotationsDataSource(_:)`'s doc comment.
- No signature changes on existing methods.
- No new imports in any framework file (`Combine` is already imported in `EditorController.swift`).

Source-breaking inside the sample only: one line of `AppState.init` becomes three (the `onAttach` block plus the `attachToken` property). No external consumers exist.

## Test plan

New test file: `Tests/CodeEditorPluginTests/SwiftUI/EditorControllerOnAttachTests.swift` (XCTest, matching the convention of neighboring `SwiftUICoordinatorTests.swift`).

Six unit tests, each builds a `CodeEditorView(frame: .zero)` and a fresh `EditorController()`:

1. `testHandlerNotFiredAtRegistration` — register a handler; assert it has not run before any `attach(to:)`.
2. `testHandlerFiredOnFirstAttach` — register, then `attach(to: view)`; assert the handler ran exactly once and received the controller.
3. `testHandlerNotFiredOnRedundantAttach` — register, `attach(to: view)`, then `attach(to: view)` again with the same view; assert the handler ran exactly once total. **Covers the de-dup gate**.
4. `testHandlerFiredOnDifferentView` — register, `attach(to: viewA)`, `attach(to: viewB)`; assert exactly two firings.
5. `testHandlerNotFiredOnDetach` — register, `attach(to: view)`, `attach(to: nil)`; assert exactly one firing (the initial attach, none on detach).
6. `testCancellableRemovesHandler` — register and store the cancellable, `cancel()` it, `attach(to: view)`; assert the handler never ran.

Plus one regression test in `Tests/CodeEditorSampleTests/`:

7. `testAnnotationsDataSourceInstalledAfterAttach` — build the sample's `AppState`-style wiring, attach the controller, assert `view.annotationsDataSource === hub`. Closes the latent bug.

## Risks & open questions

- **AnyCancellable cancellation timing.** When the host stores the token in a property that's released during teardown, `cancel()` runs from whatever isolation deallocates the property. The `Task { @MainActor in … }` hop is the safe play but means cancellation is asynchronous — a handler that was about to fire and a `cancel()` arriving simultaneously could race. Acceptable: the handler is idempotent by contract, and the worst case is one extra invocation, not a crash.
- **Late de-dup ordering.** If the host calls `onAttach(...)` after a real attach has already happened, the handler registers but doesn't fire until the *next* attach transition. That's the chosen semantic (Section "Lifecycle semantics" table). Hosts wanting immediate-fire can branch on `isAttached` and call setup directly (idempotent by contract).
- **Future `onDetach`.** Deliberately deferred. If a future host needs cleanup on detach (e.g. tearing down a debounced timer scoped to view lifetime), we add a symmetric `onDetach(_:)` then. No call sites change.

## Files touched (expected)

Framework — 1 modified:
- `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift` (new method, internal storage field, de-dup gate in `attach(to:)`, doc paragraph on `setAnnotationsDataSource`).

Sample — 1 modified:
- `Sources/CodeEditorSample/App/AppState.swift` (line 102 migration + `attachToken` property).

Tests — 1 added, 0 modified:
- `Tests/CodeEditorPluginTests/SwiftUI/EditorControllerOnAttachTests.swift` (6 unit tests).
- Optionally a sample-side regression test in `Tests/CodeEditorSampleTests/` (one test).

No public-API breakage outside the strictly-additive method. No new dependencies.
