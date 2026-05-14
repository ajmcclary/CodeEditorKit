# `CompletionEvent` AsyncStream — Design

**Status.** Draft, 2026-05-14.
**Tracks.** REVIEW.md "Sample-driven API gaps", item #6 (`CompletionEvent` AsyncStream on `CompletionManager`).

## Problem

The framework gives `CompletionManager` no telemetry hook on provider fires. The sample needs one — its Completion Inspector renders every per-provider call with its duration, item count, language, trigger, and outcome — so it ships a workaround: `Sources/CodeEditorSample/App/Completion/TelemetryCompletionProvider.swift`, a decorator wrapping every registered provider. Every host that wants a completion inspector has to rediscover this pattern.

Concretely, today's sample wiring is:

```swift
// Sources/CodeEditorSample/App/Completion/CompletionSampleCoordinator.swift:65-79
for provider in BuiltInLanguageProviders.all() {
    controller.registerCompletionProvider(
        TelemetryCompletionProvider(wrapping: provider) { [weak self] entry in
            Task { @MainActor [weak self] in self?.record(entry) }
        }
    )
}
controller.registerCompletionProvider(
    TelemetryCompletionProvider(wrapping: DemoCompletionProvider()) { [weak self] entry in
        Task { @MainActor [weak self] in self?.record(entry) }
    }
)
```

Each provider has to be wrapped before it's registered. The decorator captures `(providerId, language, triggerCharacter, prefix, itemCount, durationMs, timestamp, error?)` into a `CompletionActivityEntry` and pushes it through a `@Sendable` recorder closure. The wrapped provider's throw is re-thrown so `CompletionManager`'s existing per-provider failure isolation behavior is preserved.

REVIEW.md's framing (line 415): "Expose `AsyncStream<CompletionEvent>` on `CompletionManager`."

## Goals & non-goals

**Goal.** Hosts subscribe to one stream and see every provider fire — success or failure — without wrapping providers. After this lands, the sample deletes `TelemetryCompletionProvider` and `CompletionActivityEntry` entirely and replaces them with a single `for await event in controller.completionEvents() { … }` loop.

**Non-goals.**
- Cache-hit, aggregated-result, or manager-level events. Brainstorm settled scope to per-provider fires only; adding the wider surface is a separate follow-up if a future host needs it.
- UI-lifecycle events (popover shown / item committed / dismissed). Those live in `CompletionViewController` today; surfacing them would require new cross-layer plumbing back to `CompletionManager` and was explicitly out of scope.
- A `.providerStarted` event. Cancellations surface as `.providerFailed` carrying `CancellationError`, which is sufficient for the inspector. Adding `.started` would double event volume for no current consumer benefit.
- Replacing `CompletionStatistics`. Aggregate counters (`totalRequests`, `cacheHitRate`, `averageProcessingTime`) keep their existing surface; the stream is per-fire telemetry, not an aggregator.
- Reusing `EditorEventPublisher`. Its `EditorEvent` enum is tied to text-edit semantics; mixing completion telemetry into it would blur the domain boundary.

## Design overview

`CompletionManager` gains one new public method (`events() -> AsyncStream<CompletionEvent>`) backed by a small private `CompletionEventBroadcaster` (a `final class: @unchecked Sendable` wrapping an `NSLock` over a dictionary of per-subscriber `AsyncStream.Continuation`s). The hook fires inside `collectResultsConcurrently` — the single call site of `provider.completions(for:)` — so instrumentation is centralized and every provider is observed without any per-provider responsibility. `EditorController` forwards the method for hosts that don't reach into the manager directly.

The actor→lock shape matches the framework's existing precedent: `SyntaxHighlightingCoordinator`'s internal `HighlightingTaskManager` was converted from an actor to a `final class: @unchecked Sendable` + `NSLock` during the 2026-05-14 Concurrency batch precisely so callers from any isolation domain could subscribe/publish synchronously without trampolines. Using the same pattern keeps `events()` synchronous (clean from SwiftUI bodies and AppKit handlers) and keeps `publish(_:)` synchronous on the request hot path.

```
                   ┌─────────────────────────────────────────────────┐
                   │ Host (sample's CompletionSampleCoordinator)     │
                   │                                                 │
        attach ──▶ │ Task { for await event in                       │
                   │     controller.completionEvents() { record(event) } }
                   └─────────────────────┬───────────────────────────┘
                                         │
                                         ▼  (per-subscribe AsyncStream)
                   ┌─────────────────────────────────────────────────┐
                   │ EditorController.completionEvents()             │
                   │   → CompletionManager.events()                  │
                   │     → CompletionEventBroadcaster.subscribe()    │
                   └─────────────────────┬───────────────────────────┘
                                         │
                                         ▼  (registers continuation under lock)
                   ┌─────────────────────────────────────────────────┐
                   │ CompletionEventBroadcaster                      │
                   │   final class: @unchecked Sendable              │
                   │   NSLock + [UUID: Continuation]                 │
                   │   publish(_:) is synchronous                    │
                   └─────────────────────▲───────────────────────────┘
                                         │  publish()  (synchronous)
        ┌────────────────────────────────┴────────────────────────────┐
        │ CompletionManager.collectResultsConcurrently                │
        │   for provider in providers {                               │
        │     group.addTask {                                         │
        │       let start = Date()                                    │
        │       do { let result = try await provider.completions(…)   │
        │            broadcaster.publish(.succeeded(itemCount: …))    │
        │            return result }                                  │
        │       catch { broadcaster.publish(.failed(…)); return nil } │
        │     }                                                       │
        │   }                                                         │
        └─────────────────────────────────────────────────────────────┘
```

Two load-bearing properties:

- **Failure isolation is preserved.** Today's `collectResultsConcurrently` already swallows per-provider errors (`return nil`, batch continues with the other providers' results). The new `publish(.failed(…))` fires *before* the swallow, so subscribers see every fire while the batch-level behavior is unchanged.
- **Publish is synchronous and lock-bounded.** `publish(_:)` snapshots the continuations under lock, releases the lock, then yields to each. `AsyncStream.Continuation.yield(_:)` is thread-safe per Swift's documentation, and the snapshot is bounded by the active subscriber count (≤ a handful in practice). One slow subscriber's bounded buffer fills independently of every other; no consumer can backpressure the request hot path.

## Public surface

Strictly additive. No existing call sites compile differently.

### `CompletionEvent`

```swift
/// One observation of a single completion provider's response to a request.
///
/// Published by `CompletionManager` after every `provider.completions(for:)`
/// call returns — success or failure. The event publishes *before* the
/// existing per-provider failure isolation swallows the error, so subscribers
/// see every fire even when `CompletionManager` proceeds with results from
/// the other providers.
public struct CompletionEvent: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let providerID: String
    public let language: Language
    public let triggerCharacter: String?
    /// `context.currentWord` truncated to ≤ 32 chars, matching the cap the
    /// sample's `TelemetryCompletionProvider` already established. Keeps
    /// events cheap to store/log and avoids leaking arbitrary buffer text.
    public let prefix: String
    public let durationMilliseconds: Double
    public let timestamp: Date
    public let outcome: Outcome

    public enum Outcome: Sendable, Hashable {
        case succeeded(itemCount: Int)
        case failed(SendableError)
    }
}
```

Notes:

- One struct with an `Outcome` enum (vs. two top-level cases) reads better at call sites: `if case .succeeded(let n) = event.outcome { … }` and pattern-matching only the outcome leaves the common envelope fields directly accessible.
- `SendableError` already exists in the framework (introduced in REVIEW Critical #3) and is `Sendable + Hashable + CustomStringConvertible`. Reusing it keeps `CompletionEvent` `Hashable` without inventing an `Error`-wrapping conformance.
- A private convenience initializer `(providerID:context:durationMilliseconds:outcome:)` extracts `language`, `triggerCharacter`, and the 32-char-truncated `prefix` from a `CompletionContextModel` so the `collectResultsConcurrently` call sites stay tidy. The public initializer is the memberwise one.

### `CompletionManager.events()`

```swift
extension CompletionManager {
    /// Returns a fresh AsyncStream of completion events.
    ///
    /// Each call returns an independent stream; every subscriber receives
    /// every event published while its iterator is alive. The buffer keeps
    /// the most recent 256 events per subscriber if the consumer falls
    /// behind — older events are dropped (`.bufferingNewest(256)`).
    public func events() -> AsyncStream<CompletionEvent>
}
```

### `EditorController.completionEvents()`

```swift
extension EditorController {
    /// Forwards to the attached editor's `CompletionManager.events()`.
    /// Returns an empty, terminating stream when no editor is attached.
    public func completionEvents() -> AsyncStream<CompletionEvent>
}
```

Forwarding through the controller matches existing methods (`registerCompletionProvider`, `completionStatistics`) so hosts that already use the controller don't have to reach the manager.

## Internal broadcaster

```swift
// Sources/CodeEditorPlugin/Completion/CompletionEventBroadcaster.swift

/// Fan-out for `CompletionEvent` over an unbounded number of synchronous
/// subscribers. Mirrors the lock-based shape of
/// `SyntaxHighlightingCoordinator.HighlightingTaskManager` so callers from any
/// isolation domain can subscribe and publish without trampolines.
final class CompletionEventBroadcaster: @unchecked Sendable {
    // Invariant: every read or write to `continuations` happens while holding `lock`.
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<CompletionEvent>.Continuation] = [:]

    func subscribe() -> AsyncStream<CompletionEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(256)) { continuation in
            let token = UUID()
            lock.lock()
            continuations[token] = continuation
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                let removed = self.continuations.removeValue(forKey: token)
                self.lock.unlock()
                removed?.finish()
            }
        }
    }

    func publish(_ event: CompletionEvent) {
        lock.lock()
        let snapshot = Array(continuations.values)
        lock.unlock()
        // yield is documented thread-safe; snapshotting first avoids holding
        // the lock across the per-subscriber buffer write.
        for continuation in snapshot { continuation.yield(event) }
    }

    // Test-only probe; internal so production code can't reach it.
    var subscriberCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return continuations.count
    }
}
```

Design notes:

- **Per-subscriber buffer.** `AsyncStream(bufferingPolicy:)` owns the buffer for that one continuation. One slow subscriber's buffer fills independently; other subscribers don't see drops.
- **Termination lifecycle.** `onTermination` fires when the iterator drops or the stream completes, removing the continuation under the lock and then calling `.finish()` outside the critical section. A subscribed-then-dropped stream cannot accumulate in `continuations`.
- **No retain cycle.** `onTermination` captures the broadcaster `weak`. The broadcaster is owned by `CompletionManager`; if both go away while a stream is still iterating, the stream's continuation is dropped on the next yield and the iterator finishes.
- **`@unchecked Sendable` rationale comment** (matching the convention enforced across `Sources/`): every access to `continuations` is serialized via `lock`. The `subscriberCount` property is read under the same lock. The closure escaping into `onTermination` only captures `self` weakly and re-locks before mutating.
- **`subscriberCount` is test-only.** Internal access keeps it out of the public API; tests in the same module can reach it via `@testable import`.

## Wiring into `CompletionManager`

Two surgical changes — adding the broadcaster, and instrumenting the existing TaskGroup. Nothing else in `CompletionManager` moves.

```swift
public final class CompletionManager {
    // … existing stored properties …
    private let broadcaster = CompletionEventBroadcaster()

    // Public entry — forwards to broadcaster.subscribe(). Synchronous.
    public func events() -> AsyncStream<CompletionEvent> {
        broadcaster.subscribe()
    }

    private func collectResultsConcurrently(
        from providers: [any CompletionProvider],
        context: CompletionContextModel
    ) async -> [CompletionResult] {
        await withTaskGroup(of: CompletionResult?.self) { group in
            for provider in providers {
                let providerID = provider.id
                let broadcaster = self.broadcaster
                let capturedContext = context
                group.addTask {
                    let start = Date()
                    do {
                        let result = try await provider.completions(for: capturedContext)
                        broadcaster.publish(
                            CompletionEvent(
                                providerID: providerID,
                                context: capturedContext,
                                durationMilliseconds: Date().timeIntervalSince(start) * 1_000,
                                outcome: .succeeded(itemCount: result.items.count)
                            )
                        )
                        return result
                    } catch {
                        broadcaster.publish(
                            CompletionEvent(
                                providerID: providerID,
                                context: capturedContext,
                                durationMilliseconds: Date().timeIntervalSince(start) * 1_000,
                                outcome: .failed(SendableError(error, domain: "CompletionProvider"))
                            )
                        )
                        return nil   // existing per-provider failure isolation preserved
                    }
                }
            }
            var allResults: [CompletionResult] = []
            for await result in group { if let result { allResults.append(result) } }
            return allResults
        }
    }
}
```

Because the broadcaster is a `final class` (not an actor), `events()` is a one-liner forwarding to `subscribe()` — no trampoline, no semaphore, no async accessor. SwiftUI bodies and AppKit handlers grab a stream synchronously; the request hot path publishes synchronously inside the existing TaskGroup tasks. The actor→lock shape is the same pattern the framework already adopted for `HighlightingTaskManager` after REVIEW's Concurrency batch flagged the same trampoline class of problem.

## Sample migration

`Sources/CodeEditorSample/App/Completion/`:

- **Delete `TelemetryCompletionProvider.swift`.** No remaining consumers.
- **Delete `CompletionActivityEntry.swift`.** `CompletionEvent` covers every field (`providerID`, `language`, `triggerCharacter`, `prefix`, `durationMilliseconds`, `timestamp`, `outcome`).
- **Rewrite `CompletionSampleCoordinator.attach(controller:)`:**

  ```swift
  func attach(controller: EditorController) {
      self.controller = controller
      for provider in BuiltInLanguageProviders.all() {
          controller.registerCompletionProvider(provider)
      }
      controller.registerCompletionProvider(DemoCompletionProvider())

      eventTask = Task { @MainActor [weak self] in
          for await event in controller.completionEvents() {
              self?.record(event)
          }
      }
      refresh()
  }
  ```

  `eventTask: Task<Void, Never>?` is a new `@ObservationIgnored` property. `detach()` calls `eventTask?.cancel()`; `stop()` is unchanged. The closure-based `recorder` parameter is gone — providers are registered directly.

- **Update `record(_:)`** to take `CompletionEvent` instead of `CompletionActivityEntry`. The 20-entry ring stays exactly the same (display bound, separate from the framework's 256-event subscriber buffer); newest-first ordering, max 20, identical to today.

- **Update `CompletionInspectorPanel`** (`Sources/CodeEditorSample/Sidebars/`) row rendering: replace `CompletionActivityEntry` field reads with `CompletionEvent`. `error: String?` becomes `if case .failed(let err) = event.outcome { … }`; the truncated `prefix` field is unchanged.

After migration, the sample stops mediating per-provider telemetry — it observes a single stream owned by the framework.

## Testing

New file `Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift` (Swift Testing `@Suite`, matching existing tests under `Tests/CodeEditorPluginTests/Completion/`):

1. **`testSucceedingProviderPublishesEvent`** — register a stub provider returning 3 items; subscribe; request; assert one event with `.succeeded(itemCount: 3)`, the right `providerID`, `language`, `prefix` truncated at 32 chars (use a 64-char `currentWord` to exercise truncation), and `durationMilliseconds > 0`.
2. **`testFailingProviderPublishesEventAndIsolatesFailure`** — register two stub providers; one throws a test error, the other returns 2 items; subscribe; request. Assert (a) the failing provider's event is `.failed`, with `SendableError`'s string containing the thrown error's description, (b) the successful provider's event arrives, (c) the returned `CompletionResult` contains the 2 items (existing per-provider failure isolation preserved).
3. **`testMultipleSubscribersEachReceiveEveryEvent`** — open two streams via `events()`, register one provider, fire one request, assert both subscribers see the same single event. Catches a regression where a shared continuation gets reused.
4. **`testTerminationRemovesContinuation`** — open a stream, iterate one event then `break`, then yield the runloop once (`await Task.yield()`) to let `onTermination` fire, then assert `broadcaster.subscriberCount == 0`. Open a new stream and assert count goes to 1. Catches the "terminated-but-still-registered" leak.
5. **`testBufferDropsOldestWhenSubscriberLags`** — register a fast stub provider, subscribe but never iterate, fire 300 requests, then drain. Assert the drained count is exactly 256 and the events are the most recent 256 (provider-side counter monotonically increases, so checking the first drained event's counter ≥ 44 suffices). Validates `.bufferingNewest(256)`.

Test infrastructure:

- A small `StubCompletionProvider` in the test file: `init(id:, supportedLanguages:, behavior: Behavior)` where `Behavior` is `.returns([CompletionItemModel])` / `.throws(Error)` / `.counter(AtomicInt)` for test 5. Lives alongside the suite; not exposed.
- `subscriberCount` on the broadcaster is `internal` and accessible from tests via `@testable import`.

Sample-side: `Tests/CodeEditorSampleTests/CompletionSampleCoordinatorTests.swift` (if it exists; otherwise added) gets the `CompletionActivityEntry` → `CompletionEvent` rename, plus a new case verifying that `attach(controller:)` starts an event task and `detach()` cancels it.

## Public API impact

Strictly additive on the framework:

- New `CompletionEvent` value type.
- New `CompletionManager.events() -> AsyncStream<CompletionEvent>` method.
- New `EditorController.completionEvents() -> AsyncStream<CompletionEvent>` forwarding method.
- New internal `CompletionEventBroadcaster` type (not exposed).

No existing types or methods change signature or semantics. The only behavior change in existing code is that `collectResultsConcurrently` now also publishes events around its existing `try await provider.completions(for:)` call — the success / failure / isolation paths are otherwise unchanged.

Source-breaking inside the sample only: `TelemetryCompletionProvider` and `CompletionActivityEntry` are deleted. No external consumers exist (sample is in-tree).

## Open questions

None at this time. Scope, subscriber model, event payload, and instrumentation site were settled during brainstorming. If a future host wants cache-hit, aggregated-result, or UI-lifecycle events, that's a strictly additive follow-up: new `CompletionEvent.Outcome` cases (cache/aggregated) or a separate `CompletionUIEvent` stream (popover/commit/dismiss).
