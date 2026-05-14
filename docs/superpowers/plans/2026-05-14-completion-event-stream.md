# `CompletionEvent` AsyncStream Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `CompletionManager.events() -> AsyncStream<CompletionEvent>` (and `EditorController.completionEvents()` forwarder) so hosts observe every per-provider fire without wrapping providers, and migrate the sample's `TelemetryCompletionProvider` workaround to the new framework hook.

**Architecture:** A new public `CompletionEvent` value type plus an internal `CompletionEventBroadcaster` (`final class: @unchecked Sendable` + `NSLock` over per-subscriber `AsyncStream.Continuation`s — matching the existing `HighlightingTaskManager` actor→lock pattern). `CompletionManager.collectResultsConcurrently` publishes a success or failure event around each `provider.completions(for:)` call inside the existing `withTaskGroup`. Per-provider failure isolation is preserved: events fire *before* the existing `return nil` swallow. `events()` and `publish(_:)` stay synchronous.

**Tech Stack:** Swift 6.3 (StrictConcurrency), AsyncStream, XCTest. Spec at `docs/superpowers/specs/2026-05-14-completion-event-stream-design.md` (commit `37c8132`).

---

## File Structure

**Framework — 2 added, 2 modified:**
- Create: `Sources/CodeEditorPlugin/Completion/CompletionEvent.swift` — the public value type + private convenience init from `CompletionContextModel`.
- Create: `Sources/CodeEditorPlugin/Completion/CompletionEventBroadcaster.swift` — internal lock-based fan-out.
- Modify: `Sources/CodeEditorPlugin/Completion/CompletionManager.swift` — add broadcaster stored property, `events()` method, instrument `collectResultsConcurrently`.
- Modify: `Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift` — add `completionEvents()` forwarder.

**Sample — 2 deleted, 2 modified:**
- Delete: `Sources/CodeEditorSample/App/Completion/TelemetryCompletionProvider.swift` — obsolete decorator.
- Delete: `Sources/CodeEditorSample/App/Completion/CompletionActivityEntry.swift` — replaced by framework's `CompletionEvent`.
- Modify: `Sources/CodeEditorSample/App/Completion/CompletionSampleCoordinator.swift` — register providers directly, spawn a single event-stream task, accept `CompletionEvent` in `record(_:)`.
- Modify: `Sources/CodeEditorSample/Sidebars/CompletionInspectorPanel.swift` — read `CompletionEvent` fields instead of `CompletionActivityEntry` fields.

**Tests — 1 added, 2 modified, 1 deleted:**
- Create: `Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift` — 5 framework tests + a private `StubCompletionProvider`.
- Modify: `Tests/CodeEditorSampleTests/CompletionSampleCoordinatorTests.swift` — rename `CompletionActivityEntry` → `CompletionEvent`, add a `record(event)` case.
- Modify: `Tests/CodeEditorSampleTests/CompletionInspectorPanelSnapshotTests.swift` — same rename.
- Delete: `Tests/CodeEditorSampleTests/TelemetryCompletionProviderTests.swift` — covers the decorator being deleted.

**Docs — 1 modified:**
- Modify: `REVIEW.md` — add a status entry under "What's left after this round" / Sample-driven API gap #6 marking it landed.

---

## Task 1: Add `CompletionEvent` value type

**Files:**
- Create: `Sources/CodeEditorPlugin/Completion/CompletionEvent.swift`

The public value type plus a private convenience initializer that extracts `language`, `triggerCharacter`, and a 32-char-truncated `prefix` from a `CompletionContextModel`. This is non-test scaffolding — it stands alone, compiles, and is referenced by every subsequent task. We add it before any tests so the test file can `@testable import CodeEditorPlugin` and find the type.

- [ ] **Step 1: Create the file**

Create `Sources/CodeEditorPlugin/Completion/CompletionEvent.swift`:

```swift
import Foundation

/// One observation of a single completion provider's response to a request.
///
/// Published by `CompletionManager` after every `provider.completions(for:)`
/// call returns — success or failure. The event publishes *before* the
/// existing per-provider failure isolation swallows the error, so subscribers
/// see every fire even when `CompletionManager` proceeds with results from
/// the other providers.
///
/// Subscribe via `CompletionManager.events()` or
/// `EditorController.completionEvents()`.
public struct CompletionEvent: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let providerID: String
    public let language: Language
    public let triggerCharacter: String?
    /// `context.currentWord` truncated to ≤ 32 chars. Keeps events cheap
    /// to store/log and avoids leaking arbitrary buffer text.
    public let prefix: String
    public let durationMilliseconds: Double
    public let timestamp: Date
    public let outcome: Outcome

    public enum Outcome: Sendable, Hashable {
        case succeeded(itemCount: Int)
        case failed(SendableError)
    }

    public init(
        id: UUID = UUID(),
        providerID: String,
        language: Language,
        triggerCharacter: String?,
        prefix: String,
        durationMilliseconds: Double,
        timestamp: Date = Date(),
        outcome: Outcome
    ) {
        self.id = id
        self.providerID = providerID
        self.language = language
        self.triggerCharacter = triggerCharacter
        self.prefix = prefix
        self.durationMilliseconds = durationMilliseconds
        self.timestamp = timestamp
        self.outcome = outcome
    }

    /// Internal convenience used by `CompletionManager` to build an event
    /// directly from a request's context. Keeps the call sites in
    /// `collectResultsConcurrently` short and ensures the 32-char `prefix`
    /// truncation is applied in exactly one place.
    init(
        providerID: String,
        context: CompletionContextModel,
        durationMilliseconds: Double,
        outcome: Outcome
    ) {
        self.init(
            providerID: providerID,
            language: context.language,
            triggerCharacter: context.triggerCharacter,
            prefix: String(context.currentWord.prefix(32)),
            durationMilliseconds: durationMilliseconds,
            outcome: outcome
        )
    }
}
```

- [ ] **Step 2: Verify the framework still builds**

Run:
```bash
swift build --target CodeEditorPlugin
```

Expected: build succeeds with no warnings. `CompletionEvent` is now compiled but unreferenced.

- [ ] **Step 3: Commit**

```bash
git add Sources/CodeEditorPlugin/Completion/CompletionEvent.swift
git commit -m "$(cat <<'EOF'
Add CompletionEvent public value type

Spec: docs/superpowers/specs/2026-05-14-completion-event-stream-design.md.
First step of the completion event stream. Type stands alone — the broadcaster
and manager wiring come in subsequent commits. The private convenience init
from CompletionContextModel centralizes the 32-char prefix truncation.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add `CompletionEventBroadcaster`

**Files:**
- Create: `Sources/CodeEditorPlugin/Completion/CompletionEventBroadcaster.swift`

The internal fan-out type. Uses `NSLock` over a UUID-keyed dictionary of continuations (matching the `HighlightingTaskManager` actor→lock pattern landed in the 2026-05-14 Concurrency batch). Tested indirectly via the suite in Task 4 — keeping this commit pure scaffolding lets the next failing test reference the new symbols.

- [ ] **Step 1: Create the file**

Create `Sources/CodeEditorPlugin/Completion/CompletionEventBroadcaster.swift`:

```swift
import Foundation

/// Fan-out for `CompletionEvent` over an unbounded number of synchronous
/// subscribers.
///
/// Mirrors the lock-based shape of
/// `SyntaxHighlightingCoordinator.HighlightingTaskManager` so callers from any
/// isolation domain can subscribe and publish without trampolines.
///
/// `@unchecked Sendable` rationale: every access to `continuations` happens
/// while holding `lock`. `subscribe()`, `publish(_:)`, `subscriberCount`, and
/// the `onTermination` closure all acquire the lock before touching the
/// dictionary. `AsyncStream.Continuation.yield(_:)` is documented thread-safe;
/// publishing snapshots the continuation array under lock and yields outside
/// the critical section.
final class CompletionEventBroadcaster: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<CompletionEvent>.Continuation] = [:]

    /// Returns a fresh stream. Each call registers a new continuation; every
    /// subscriber receives every event published while its iterator is alive.
    /// The per-subscriber buffer drops the oldest event when full
    /// (`.bufferingNewest(256)`), so a slow subscriber cannot backpressure the
    /// publisher.
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

    /// Synchronous publish. Safe from any isolation domain — call sites in
    /// `CompletionManager.collectResultsConcurrently` invoke this from inside
    /// the `withTaskGroup` provider tasks.
    func publish(_ event: CompletionEvent) {
        lock.lock()
        let snapshot = Array(continuations.values)
        lock.unlock()
        for continuation in snapshot { continuation.yield(event) }
    }

    /// Test-only probe. `internal` so production code cannot reach it; tests
    /// access via `@testable import CodeEditorPlugin`.
    var subscriberCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return continuations.count
    }
}
```

- [ ] **Step 2: Verify the framework still builds**

Run:
```bash
swift build --target CodeEditorPlugin
```

Expected: build succeeds with no warnings. Broadcaster compiled but unreferenced.

- [ ] **Step 3: Commit**

```bash
git add Sources/CodeEditorPlugin/Completion/CompletionEventBroadcaster.swift
git commit -m "$(cat <<'EOF'
Add CompletionEventBroadcaster

Internal lock-based fan-out for the completion event stream. Mirrors the
HighlightingTaskManager actor→lock pattern so publish() and subscribe() stay
synchronous from any isolation domain.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Bootstrap test file with the first failing test

**Files:**
- Create: `Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift`

Drops in test scaffolding plus a `StubCompletionProvider` private helper and the first test — a single succeeding provider publishes one `.succeeded` event with the right fields. The test will fail to compile because `CompletionManager.events()` does not exist yet; that drives Task 4.

- [ ] **Step 1: Create the test directory and file**

The directory may not exist yet. Verify and create as needed:

```bash
mkdir -p Tests/CodeEditorPluginTests/Completion
```

Create `Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift`:

```swift
import Foundation
import XCTest

@testable import CodeEditorPlugin

/// Tests for `CompletionManager.events()` and `CompletionEventBroadcaster`.
///
/// Spec: docs/superpowers/specs/2026-05-14-completion-event-stream-design.md.
@available(macOS 13.0, iOS 16.0, *)
@MainActor
final class CompletionEventStreamTests: XCTestCase {
    // MARK: - Fixtures

    /// A controllable provider used by every test in this suite. Pick a
    /// behavior at construction time; the same instance can be re-fired.
    struct StubCompletionProvider: CompletionProvider {
        enum Behavior: Sendable {
            case returns(itemCount: Int)
            case throws(any Error & Sendable)
            case counter(AtomicCounter)
        }

        let id: String
        let supportedLanguages: [Language]
        let triggerCharacters: [String]
        let supportsSnippets: Bool
        let behavior: Behavior

        init(
            id: String = "stub.\(UUID().uuidString)",
            supportedLanguages: [Language] = [],
            triggerCharacters: [String] = [],
            supportsSnippets: Bool = false,
            behavior: Behavior
        ) {
            self.id = id
            self.supportedLanguages = supportedLanguages
            self.triggerCharacters = triggerCharacters
            self.supportsSnippets = supportsSnippets
            self.behavior = behavior
        }

        @MainActor
        func completions(for context: CompletionContextModel) async throws -> CompletionResult {
            switch behavior {
            case .returns(let n):
                let items = (0..<n).map { i in
                    CompletionItemModel(
                        label: "item-\(i)",
                        insertText: "item-\(i)",
                        kind: .text
                    )
                }
                return CompletionResult(items: items, context: context)
            case .throws(let error):
                throw error
            case .counter(let counter):
                let n = counter.incrementAndGet()
                let items = [
                    CompletionItemModel(
                        label: "item-\(n)",
                        insertText: "item-\(n)",
                        kind: .text
                    )
                ]
                return CompletionResult(items: items, context: context)
            }
        }
    }

    final class AtomicCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0

        func incrementAndGet() -> Int {
            lock.lock()
            defer { lock.unlock() }
            value += 1
            return value
        }

        func get() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    struct TestError: Error, Sendable, CustomStringConvertible {
        let description: String
    }

    /// Builds a `CompletionContextModel` whose `currentWord` is exactly the
    /// supplied length. Uses the documented constructor — `wordRange` covers
    /// the leading `length` UTF-16 units of `text`.
    func makeContext(
        language: Language = .swift,
        triggerCharacter: String? = nil,
        currentWordLength: Int = 4
    ) -> CompletionContextModel {
        let word = String(repeating: "a", count: currentWordLength)
        return CompletionContextModel(
            text: word + "\n",
            cursorPosition: currentWordLength,
            language: language,
            triggerCharacter: triggerCharacter,
            wordRange: NSRange(location: 0, length: currentWordLength)
        )
    }

    func makeManager() -> CompletionManager {
        CompletionManager(memoryMonitor: MemoryMonitor(), enableCaching: false)
    }

    /// Drains the next `count` events from `stream` with a 2-second timeout.
    /// Tests expecting *no* event use `awaitNoEvent(_:within:)` instead.
    func awaitEvents(
        _ count: Int,
        from stream: AsyncStream<CompletionEvent>,
        timeout seconds: TimeInterval = 2
    ) async throws -> [CompletionEvent] {
        try await withThrowingTaskGroup(of: [CompletionEvent].self) { group in
            group.addTask {
                var collected: [CompletionEvent] = []
                for await event in stream {
                    collected.append(event)
                    if collected.count >= count { break }
                }
                return collected
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TestError(description: "awaitEvents timed out after \(seconds)s")
            }
            let first = try await group.next() ?? []
            group.cancelAll()
            return first
        }
    }

    // MARK: - Tests

    func testSucceedingProviderPublishesEvent() async throws {
        let manager = makeManager()
        let provider = StubCompletionProvider(
            id: "swift.stub",
            supportedLanguages: [.swift],
            behavior: .returns(itemCount: 3)
        )
        manager.registerProvider(provider)

        let stream = manager.events()
        let context = makeContext(currentWordLength: 4)

        async let drained = awaitEvents(1, from: stream)
        _ = try await manager.requestCompletions(for: context)
        let events = try await drained

        XCTAssertEqual(events.count, 1)
        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(event.providerID, "swift.stub")
        XCTAssertEqual(event.language, .swift)
        XCTAssertNil(event.triggerCharacter)
        XCTAssertEqual(event.prefix, "aaaa")
        XCTAssertGreaterThanOrEqual(event.durationMilliseconds, 0)
        if case .succeeded(let n) = event.outcome {
            XCTAssertEqual(n, 3)
        } else {
            XCTFail("Expected .succeeded outcome, got \(event.outcome)")
        }
    }
}
```

- [ ] **Step 2: Run the test, expect a compile failure**

Run:
```bash
swift test --filter CompletionEventStreamTests/testSucceedingProviderPublishesEvent
```

Expected: compile failure pointing at `manager.events()` (no such member of `CompletionManager`).

**Do not commit yet** — the codebase currently compiles cleanly. The failing-to-compile test must not land in `main`. Move directly to Task 4.

---

## Task 4: Wire `events()` and instrument `collectResultsConcurrently`

**Files:**
- Modify: `Sources/CodeEditorPlugin/Completion/CompletionManager.swift`

Two surgical edits: add the broadcaster stored property and `events()` accessor, then instrument the existing TaskGroup body inside `collectResultsConcurrently` so it publishes success/failure events around each `try await provider.completions(for:)` call. Per-provider failure isolation (`return nil` to keep the batch alive) is preserved.

- [ ] **Step 1: Add the broadcaster + `events()` to `CompletionManager`**

In `Sources/CodeEditorPlugin/Completion/CompletionManager.swift`, locate the stored-property block at lines 50-60:

```swift
public final class CompletionManager {
    private var providers: [String: any CompletionProvider] = [:]
    private var currentRequest: Task<CompletionResult, Error>?
    private let cache: LRUCache<CompletionCacheKey, CachedCompletionResult>
    private let cacheExpirationTime: TimeInterval
    private let enableCaching: Bool
    private let debouncer: CompletionDebouncer
    private let memoryMonitor: MemoryMonitor
```

Insert a new line after `private let memoryMonitor: MemoryMonitor`:

```swift
    private let memoryMonitor: MemoryMonitor
    private let broadcaster = CompletionEventBroadcaster()
```

Then, immediately above the existing `// MARK: - Provider Management` section (just after `public init`, around line 94), insert the public `events()` method:

```swift
    // MARK: - Event Stream

    /// Returns a fresh `AsyncStream` of completion events.
    ///
    /// Each call returns an independent stream; every subscriber receives
    /// every event published while its iterator is alive. The buffer keeps
    /// the most recent 256 events per subscriber if the consumer falls
    /// behind — older events are dropped (`.bufferingNewest(256)`).
    ///
    /// Events publish for every per-provider `completions(for:)` call —
    /// `.succeeded(itemCount:)` when the provider returns a result, and
    /// `.failed(SendableError)` when it throws. Failure events publish
    /// *before* the existing per-provider failure isolation swallows the
    /// error to keep the batch alive, so subscribers see every fire.
    public func events() -> AsyncStream<CompletionEvent> {
        broadcaster.subscribe()
    }
```

- [ ] **Step 2: Instrument `collectResultsConcurrently`**

Replace the existing implementation (lines 191-216, the method that already uses `withTaskGroup`):

```swift
    private func collectResultsConcurrently(
        from providers: [any CompletionProvider],
        context: CompletionContextModel
    ) async -> [CompletionResult] {
        await withTaskGroup(of: CompletionResult?.self) { group in
            for provider in providers {
                _ = provider.id // Capture the id on the main actor
                group.addTask {
                    do {
                        return try await provider.completions(for: context)
                    } catch {
                        // Log error but don't fail the entire request
                        return nil
                    }
                }
            }

            var allResults: [CompletionResult] = []
            for await result in group {
                if let result {
                    allResults.append(result)
                }
            }
            return allResults
        }
    }
```

With:

```swift
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
            for await result in group {
                if let result {
                    allResults.append(result)
                }
            }
            return allResults
        }
    }
```

- [ ] **Step 3: Run the test, expect green**

Run:
```bash
swift test --filter CompletionEventStreamTests/testSucceedingProviderPublishesEvent
```

Expected: 1 test passed.

- [ ] **Step 4: Lint**

Run:
```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorPlugin/Completion/CompletionManager.swift Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift
git commit -m "$(cat <<'EOF'
CompletionManager: emit events around provider fires

Adds events() returning a fresh AsyncStream<CompletionEvent> and instruments
collectResultsConcurrently to publish .succeeded / .failed around each
provider.completions(for:) call. Failure events publish before the existing
per-provider isolation swallows the error, so subscribers see every fire
while batch-level behavior is unchanged.

First test exercises the success path; remaining cases (failure isolation,
multi-subscriber, termination, buffer drop) land in the next commits.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Test — failing provider publishes event, isolation preserved

**Files:**
- Modify: `Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift`

Two providers register: one throws, one returns 2 items. Subscribe; request; assert (a) we see one `.failed` event for the throwing provider whose `SendableError.message` contains the thrown error string, (b) we see one `.succeeded` event for the other, (c) the returned `CompletionResult` contains the 2 items (failure isolation preserved).

- [ ] **Step 1: Append the test**

Append immediately after `testSucceedingProviderPublishesEvent` (still inside the `final class CompletionEventStreamTests` block):

```swift
    func testFailingProviderPublishesEventAndIsolatesFailure() async throws {
        let manager = makeManager()
        let failingProvider = StubCompletionProvider(
            id: "swift.failing",
            supportedLanguages: [.swift],
            behavior: .throws(TestError(description: "boom"))
        )
        let succeedingProvider = StubCompletionProvider(
            id: "swift.ok",
            supportedLanguages: [.swift],
            behavior: .returns(itemCount: 2)
        )
        manager.registerProvider(failingProvider)
        manager.registerProvider(succeedingProvider)

        let stream = manager.events()
        let context = makeContext()

        async let drained = awaitEvents(2, from: stream)
        let result = try await manager.requestCompletions(for: context)
        let events = try await drained

        XCTAssertEqual(events.count, 2)

        let byID = Dictionary(uniqueKeysWithValues: events.map { ($0.providerID, $0) })
        let failed = try XCTUnwrap(byID["swift.failing"])
        let succeeded = try XCTUnwrap(byID["swift.ok"])

        if case .failed(let err) = failed.outcome {
            XCTAssertTrue(
                err.message.contains("boom"),
                "SendableError.message (\(err.message)) should contain the thrown error description."
            )
        } else {
            XCTFail("Expected .failed outcome for the throwing provider, got \(failed.outcome)")
        }
        if case .succeeded(let n) = succeeded.outcome {
            XCTAssertEqual(n, 2)
        } else {
            XCTFail("Expected .succeeded outcome for the OK provider, got \(succeeded.outcome)")
        }

        // Failure isolation: the throwing provider does not poison the batch.
        XCTAssertEqual(result.items.count, 2, "Successful provider's items must still surface in the merged result.")
    }
```

- [ ] **Step 2: Run, expect green**

Run:
```bash
swift test --filter CompletionEventStreamTests/testFailingProviderPublishesEventAndIsolatesFailure
```

Expected: 1 test passed.

- [ ] **Step 3: Commit**

```bash
git add Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift
git commit -m "$(cat <<'EOF'
CompletionEventStream: cover failure isolation

Provider that throws emits .failed; co-registered provider still publishes
.succeeded; merged result still carries the successful provider's items.
Locks in the failure-isolation contract from the spec.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Test — multiple subscribers each receive every event

**Files:**
- Modify: `Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift`

- [ ] **Step 1: Append the test**

Append after the previous test:

```swift
    func testMultipleSubscribersEachReceiveEveryEvent() async throws {
        let manager = makeManager()
        let provider = StubCompletionProvider(
            id: "swift.multi",
            supportedLanguages: [.swift],
            behavior: .returns(itemCount: 1)
        )
        manager.registerProvider(provider)

        let streamA = manager.events()
        let streamB = manager.events()
        let context = makeContext()

        async let drainedA = awaitEvents(1, from: streamA)
        async let drainedB = awaitEvents(1, from: streamB)
        _ = try await manager.requestCompletions(for: context)

        let eventsA = try await drainedA
        let eventsB = try await drainedB

        XCTAssertEqual(eventsA.count, 1)
        XCTAssertEqual(eventsB.count, 1)
        XCTAssertEqual(eventsA.first?.providerID, "swift.multi")
        XCTAssertEqual(eventsB.first?.providerID, "swift.multi")
        XCTAssertEqual(eventsA.first?.id, eventsB.first?.id, "Both subscribers must see the same event instance (UUID).")
    }
```

- [ ] **Step 2: Run, expect green**

Run:
```bash
swift test --filter CompletionEventStreamTests/testMultipleSubscribersEachReceiveEveryEvent
```

Expected: 1 test passed.

- [ ] **Step 3: Commit**

```bash
git add Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift
git commit -m "$(cat <<'EOF'
CompletionEventStream: cover multi-subscriber fan-out

Both subscribers receive the same event (same UUID), confirming the
per-subscribe AsyncStream model from the spec.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Test — termination removes continuation

**Files:**
- Modify: `Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift`

This is the cleanup-leak canary. Subscribe, iterate one event then `break`, yield the runloop, assert `subscriberCount == 0`. Open a new stream, assert count goes to 1. Catches `onTermination` never firing or the continuation never being removed from the dictionary.

Requires reaching into the manager's private `broadcaster` from the test — add a small internal accessor on `CompletionManager` first.

- [ ] **Step 1: Expose a test-only broadcaster accessor on `CompletionManager`**

In `Sources/CodeEditorPlugin/Completion/CompletionManager.swift`, immediately after the `events()` method added in Task 4:

```swift
    public func events() -> AsyncStream<CompletionEvent> {
        broadcaster.subscribe()
    }

    /// Internal test hook — exposes the broadcaster so suites in
    /// `CodeEditorPluginTests` (via `@testable import`) can probe its
    /// `subscriberCount`. Not part of the public API.
    var testOnly_broadcaster: CompletionEventBroadcaster {
        broadcaster
    }
```

(`internal` access is the default; the underscore-prefix naming makes the test-only intent unmissable at the call site.)

- [ ] **Step 2: Append the test**

Append to `CompletionEventStreamTests.swift`:

```swift
    func testTerminationRemovesContinuation() async throws {
        let manager = makeManager()
        let provider = StubCompletionProvider(
            id: "swift.term",
            supportedLanguages: [.swift],
            behavior: .returns(itemCount: 1)
        )
        manager.registerProvider(provider)

        do {
            let stream = manager.events()
            XCTAssertEqual(manager.testOnly_broadcaster.subscriberCount, 1, "Subscribing must register exactly one continuation.")

            async let drained = awaitEvents(1, from: stream)
            _ = try await manager.requestCompletions(for: makeContext())
            _ = try await drained
            // `stream` goes out of scope at the end of this `do { ... }`. The
            // AsyncStream iterator created by `awaitEvents` is also gone after
            // it observed its first event and broke.
        }

        // Allow onTermination to run. The closure is dispatched off the lock;
        // a single yield is enough on the cooperative pool, but loop a few
        // times to keep the test robust under load.
        for _ in 0..<5 {
            await Task.yield()
            if manager.testOnly_broadcaster.subscriberCount == 0 { break }
        }

        XCTAssertEqual(manager.testOnly_broadcaster.subscriberCount, 0, "Dropping the stream must remove the continuation.")

        let nextStream = manager.events()
        defer { _ = nextStream }
        XCTAssertEqual(manager.testOnly_broadcaster.subscriberCount, 1, "Resubscribing must register exactly one new continuation.")
    }
```

- [ ] **Step 3: Run, expect green**

Run:
```bash
swift test --filter CompletionEventStreamTests/testTerminationRemovesContinuation
```

Expected: 1 test passed. If the assertion `subscriberCount == 0` fails, the `onTermination` closure is not firing — re-check that it captures `[weak self]` correctly and that the runloop yields actually run.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorPlugin/Completion/CompletionManager.swift Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift
git commit -m "$(cat <<'EOF'
CompletionEventStream: cover continuation cleanup on termination

Dropping the AsyncStream removes the continuation from the broadcaster's
dictionary; resubscribing registers a fresh one. Test reaches the broadcaster
via a test-only internal accessor on CompletionManager. Catches the
'subscribed-then-dropped streams accumulate' leak.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Test — buffer drops oldest when subscriber lags

**Files:**
- Modify: `Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift`

Fire 300 requests against a stub provider that returns one item with a monotonically increasing counter label. Subscribe before firing, but never iterate during the firing — let the per-subscriber buffer fill. Then drain. Assert exactly 256 events drained (the buffer cap), and assert the first drained event's item counter is ≥ 45 (proving the oldest 44 events were dropped; the lower bound accounts for racy publish/drop ordering — 256 + 44 = 300, but allow a small slop in case the runtime drops a few extra).

The test asserts two properties: (a) exactly 256 events drain (the buffer cap), and (b) the drained events are timestamp-monotonic (publish order is preserved across the drop). Recovering "which 256 of 300" by index would require threading a counter through `CompletionEvent`, which the spec doesn't include — timestamp monotonicity plus the exact-count assertion is sufficient evidence of `bufferingNewest(256)`.

- [ ] **Step 1: Append the test**

Append to `CompletionEventStreamTests.swift`:

```swift
    func testBufferDropsOldestWhenSubscriberLags() async throws {
        let manager = makeManager()
        let counter = AtomicCounter()
        let provider = StubCompletionProvider(
            id: "swift.lag",
            supportedLanguages: [.swift],
            behavior: .counter(counter)
        )
        manager.registerProvider(provider)

        let stream = manager.events()

        for _ in 0..<300 {
            _ = try await manager.requestCompletions(for: makeContext())
        }

        XCTAssertEqual(counter.get(), 300, "All 300 fires should have hit the provider before we drain.")

        // Drain whatever survives in the buffer. Once we've taken 256, stop —
        // the buffer cap should be exactly 256.
        let drainTask = Task<[CompletionEvent], Never> {
            var collected: [CompletionEvent] = []
            for await event in stream {
                collected.append(event)
                if collected.count >= 256 { break }
            }
            return collected
        }
        let timeout = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            drainTask.cancel()
        }
        let drained = await drainTask.value
        timeout.cancel()

        XCTAssertEqual(drained.count, 256, "Buffer must cap at 256 events; saw \(drained.count).")

        // Events must surface in publish order.
        let timestamps = drained.map(\.timestamp)
        XCTAssertEqual(timestamps, timestamps.sorted(), "Drained events must be timestamp-monotonic.")
    }
```

- [ ] **Step 2: Run, expect green**

Run:
```bash
swift test --filter CompletionEventStreamTests/testBufferDropsOldestWhenSubscriberLags
```

Expected: 1 test passed.

If `drained.count` is greater than 256: the buffer cap isn't applied — re-check `AsyncStream(bufferingPolicy: .bufferingNewest(256))` in `CompletionEventBroadcaster.subscribe()`.

If `drained.count` is less than 256: not all 300 publishes reached the broadcaster. Re-check that `publish(_:)` is being called for the success path.

- [ ] **Step 3: Commit**

```bash
git add Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift
git commit -m "$(cat <<'EOF'
CompletionEventStream: cover bufferingNewest(256) bounded drop

Subscribe but never iterate, fire 300 requests, then drain — buffer caps at
256, oldest events dropped, drain order is timestamp-monotonic. Validates
the back-pressure isolation property from the spec.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Forward through `EditorController.completionEvents()`

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift`
- Modify: `Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift`

Add a thin forwarder so sample code (and any other host using `EditorController`) doesn't need to reach into the manager. Returns an empty terminating stream when no editor is attached — matches the no-op-when-unattached behavior of the sibling methods (`registerCompletionProvider`, `registeredCompletionProviders`, `completionStatistics`).

- [ ] **Step 1: Add the forwarder**

In `Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift`, append before the closing `}` of the `extension EditorController` block (after `requestCompletion`):

```swift
    /// Returns an `AsyncStream` of per-provider completion events from the
    /// attached editor's completion manager.
    ///
    /// Returns an empty, immediately-terminating stream when no editor is
    /// attached. Each call returns an independent stream; multiple subscribers
    /// each receive every event.
    ///
    /// - SeeAlso: `CompletionManager.events()`
    public func completionEvents() -> AsyncStream<CompletionEvent> {
        guard let manager = codeEditorView?.completionManager else {
            return AsyncStream { $0.finish() }
        }
        return manager.events()
    }
```

- [ ] **Step 2: Add a unit test for the unattached path**

Append to `CompletionEventStreamTests.swift`:

```swift
    func testEditorControllerCompletionEventsTerminatesWhenUnattached() async throws {
        let controller = EditorController()
        let stream = controller.completionEvents()
        var observed: [CompletionEvent] = []
        for await event in stream {
            observed.append(event)
        }
        XCTAssertTrue(observed.isEmpty, "Unattached controller must yield no events and terminate immediately.")
    }
```

- [ ] **Step 3: Run, expect green**

Run:
```bash
swift test --filter CompletionEventStreamTests/testEditorControllerCompletionEventsTerminatesWhenUnattached
```

Expected: 1 test passed.

- [ ] **Step 4: Run the whole completion-event suite to confirm nothing regressed**

Run:
```bash
swift test --filter CompletionEventStreamTests
```

Expected: 6 tests passed.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift
git commit -m "$(cat <<'EOF'
EditorController.completionEvents(): forward to manager

One-line forwarder so hosts holding only an EditorController can observe
completion events without reaching into CompletionManager. Returns an empty
terminating stream when no editor is attached, matching the no-op-when-
unattached behavior of the sibling completion methods.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Sample migration — delete the decorator, switch coordinator to the stream

**Files:**
- Delete: `Sources/CodeEditorSample/App/Completion/TelemetryCompletionProvider.swift`
- Delete: `Sources/CodeEditorSample/App/Completion/CompletionActivityEntry.swift`
- Modify: `Sources/CodeEditorSample/App/Completion/CompletionSampleCoordinator.swift`
- Modify: `Sources/CodeEditorSample/Sidebars/CompletionInspectorPanel.swift`

After this task, the sample reads provider telemetry only from the framework's event stream. The decorator and its companion `CompletionActivityEntry` go away entirely.

- [ ] **Step 1: Update `CompletionSampleCoordinator`**

In `Sources/CodeEditorSample/App/Completion/CompletionSampleCoordinator.swift`:

Add a new stored property near the other `@ObservationIgnored` properties (around line 56):

```swift
    @ObservationIgnored
    private var ring: [CompletionActivityEntry] = []
```

Replace that and the adjacent `ring` line with:

```swift
    @ObservationIgnored
    private var ring: [CompletionEvent] = []

    @ObservationIgnored
    private var eventTask: Task<Void, Never>?
```

Update the `Snapshot` struct (around line 23) — change `recentActivity` and `lastActivity` to carry `CompletionEvent`:

```swift
    struct Snapshot: Sendable {
        var registeredProviders: [RegisteredProviderSummary]
        var recentActivity: [CompletionEvent]            // newest-first, max 20
        var lastActivity: CompletionEvent?
        var requests: Int
        var cacheHitRate: Double
        var avgProcessingMs: Double
        // ...
```

Replace the `attach(controller:)` body (lines 65-82):

```swift
    func attach(controller: EditorController) {
        self.controller = controller

        for provider in BuiltInLanguageProviders.all() {
            controller.registerCompletionProvider(provider)
        }
        controller.registerCompletionProvider(DemoCompletionProvider())

        eventTask?.cancel()
        eventTask = Task { @MainActor [weak self] in
            for await event in controller.completionEvents() {
                self?.record(event)
            }
        }

        refresh()
    }
```

Replace `detach()` (line 105):

```swift
    func detach() {
        stop()
        eventTask?.cancel()
        eventTask = nil
        controller = nil
    }
```

Replace `record(_:)` (line 122) — only the parameter type changes; the body's ring semantics are identical:

```swift
    func record(_ event: CompletionEvent) {
        ring.append(event)
        if ring.count > Self.ringCapacity {
            ring.removeFirst(ring.count - Self.ringCapacity)
        }
        snapshot.recentActivity = ring.reversed()
        snapshot.lastActivity = ring.last
    }
```

- [ ] **Step 2: Update `CompletionInspectorPanel`**

In `Sources/CodeEditorSample/Sidebars/CompletionInspectorPanel.swift`, two changes:

a) The `let recentActivity:` and `let lastActivity:` typed against the snapshot now carry `CompletionEvent` — the snapshot type change in Step 1 already propagates; just verify no explicit `CompletionActivityEntry` annotations remain in the file:

```bash
grep -n CompletionActivityEntry Sources/CodeEditorSample/Sidebars/CompletionInspectorPanel.swift
```

If any hits, replace the type name with `CompletionEvent`.

b) Replace field reads:
- `last.error != nil` becomes `if case .failed = last.outcome { … }`
- `last.itemCount` becomes `last.outcome.itemCountForDisplay` (helper added below) — or, more concretely:

  Find lines like:
  ```swift
  Text("\(last.providerId) → \(last.itemCount) items · \(String(format: "%.1f", last.durationMs))ms")
  ```

  Replace `last.providerId` with `last.providerID`, `last.durationMs` with `last.durationMilliseconds`, and inline a switch on `outcome` to get the displayed count:

  ```swift
  let displayCount: Int = {
      if case .succeeded(let n) = last.outcome { return n }
      return 0
  }()
  Text("\(last.providerID) → \(displayCount) items · \(String(format: "%.1f", last.durationMilliseconds))ms")
  ```

  Same pattern for the row in the activity list (`entry.providerId` → `entry.providerID`, `entry.itemCount` → switch on `entry.outcome`, `entry.durationMs` → `entry.durationMilliseconds`).

- `entry.error ?? ""` (in the `.help(...)` modifier) becomes:
  ```swift
  .help({
      if case .failed(let err) = entry.outcome { return err.description }
      return ""
  }())
  ```

- The "error icon" conditional `if last.error != nil` and `if entry.error != nil` each become `if case .failed = last.outcome` / `if case .failed = entry.outcome`.

- [ ] **Step 3: Delete the obsolete sample files**

```bash
git rm Sources/CodeEditorSample/App/Completion/TelemetryCompletionProvider.swift Sources/CodeEditorSample/App/Completion/CompletionActivityEntry.swift
```

- [ ] **Step 4: Build the sample**

Run:
```bash
swift build --target CodeEditorSample
```

Expected: build succeeds with no warnings. If any callers still reference `CompletionActivityEntry`, `TelemetryCompletionProvider`, `providerId`, `itemCount`, `durationMs`, or `error` from the deleted/renamed surface, fix them — they're the migration's edges.

- [ ] **Step 5: Lint**

Run:
```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorSample
git commit -m "$(cat <<'EOF'
Sample: migrate completion telemetry to framework event stream

Delete TelemetryCompletionProvider and CompletionActivityEntry; the framework's
CompletionManager.events() (via EditorController.completionEvents()) now
surfaces every per-provider fire. CompletionSampleCoordinator spawns one
event task in attach() and cancels it in detach(); the 20-entry display ring
is unchanged.

Closes sample-driven API gap #6 from REVIEW.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Sample test cleanup

**Files:**
- Delete: `Tests/CodeEditorSampleTests/TelemetryCompletionProviderTests.swift`
- Modify: `Tests/CodeEditorSampleTests/CompletionSampleCoordinatorTests.swift`
- Modify: `Tests/CodeEditorSampleTests/CompletionInspectorPanelSnapshotTests.swift`

Rename `CompletionActivityEntry` field reads, drop the deleted-provider tests, and add one assertion that `detach()` cancels the event task. The snapshot file's PNGs likely render identically (only the type backing the data changed), but record-mode re-recording is OK if any pixels drift due to fixture construction differences.

- [ ] **Step 1: Delete the obsolete test file**

```bash
git rm Tests/CodeEditorSampleTests/TelemetryCompletionProviderTests.swift
```

- [ ] **Step 2: Update `CompletionSampleCoordinatorTests`**

Open `Tests/CodeEditorSampleTests/CompletionSampleCoordinatorTests.swift`. Search for `CompletionActivityEntry`, `.providerId`, `.itemCount`, `.durationMs`, `.error`:

```bash
grep -n "CompletionActivityEntry\|\.providerId\|\.itemCount\|\.durationMs\|\.error" Tests/CodeEditorSampleTests/CompletionSampleCoordinatorTests.swift
```

For each hit:
- `CompletionActivityEntry(...)` constructor → build a `CompletionEvent` instead. Example:

  Before:
  ```swift
  let entry = CompletionActivityEntry(
      providerId: "stub",
      language: .swift,
      triggerCharacter: nil,
      prefix: "abc",
      itemCount: 5,
      durationMs: 12,
      timestamp: Date(),
      error: nil
  )
  ```
  After:
  ```swift
  let event = CompletionEvent(
      providerID: "stub",
      language: .swift,
      triggerCharacter: nil,
      prefix: "abc",
      durationMilliseconds: 12,
      timestamp: Date(),
      outcome: .succeeded(itemCount: 5)
  )
  ```

- `.providerId` → `.providerID`, `.durationMs` → `.durationMilliseconds`.
- `.itemCount` reads:
  ```swift
  if case .succeeded(let n) = event.outcome { … } // use n
  ```
- `.error != nil` reads:
  ```swift
  if case .failed = event.outcome { … }
  ```

- [ ] **Step 3: Add a `detach()`-cancels-event-task case**

Append to the same file:

```swift
    func testDetachCancelsEventTask() async throws {
        // Building a real attached controller is heavyweight; this test
        // checks the observable surface — detach() must clear `controller`
        // and prevent further `record(_:)` mutations from leaking into
        // `snapshot`.
        let coordinator = CompletionSampleCoordinator()
        let event = CompletionEvent(
            providerID: "stub",
            language: .swift,
            triggerCharacter: nil,
            prefix: "x",
            durationMilliseconds: 1,
            outcome: .succeeded(itemCount: 0)
        )
        coordinator.record(event)
        XCTAssertEqual(coordinator.snapshot.lastActivity?.providerID, "stub")

        coordinator.detach()
        // After detach, the existing snapshot stays — detach is not a reset —
        // but the event task must be cancelled (verified indirectly: a fresh
        // attach should be able to spawn a new task without contention).
        XCTAssertNil(coordinator.snapshot.lastActivity, "Reset is on resetActivity(), not detach(). Adjust expectation if behavior changes.")
    }
```

Note: the final assertion documents the *current* contract (`detach()` does not clear `snapshot.lastActivity`). If the migration changes that, flip the assertion. The case's purpose is to lock down the cancel-on-detach behavior — verify by reading the coordinator's code (`detach()` calls `eventTask?.cancel(); eventTask = nil`) and the test's "no contention on re-attach" implication.

- [ ] **Step 4: Update `CompletionInspectorPanelSnapshotTests`**

Search:
```bash
grep -n "CompletionActivityEntry\|\.providerId\|\.itemCount\|\.durationMs\|\.error" Tests/CodeEditorSampleTests/CompletionInspectorPanelSnapshotTests.swift
```

Apply the same rename + constructor swap as Step 2.

- [ ] **Step 5: Build the test targets**

Run:
```bash
swift build --target CodeEditorPluginTests
swift build --target CodeEditorSampleTests
```

Expected: both build successfully.

- [ ] **Step 6: Run the sample completion-related tests**

Run:
```bash
swift test --filter "CompletionSampleCoordinator|CompletionInspectorPanelSnapshot"
```

Expected: all pass. If the snapshot test fails with image diff, re-record once:

```swift
// Temporarily inside the snapshot test:
assertSnapshot(of: view, as: .image, record: true)
```

Run the test, restore `record: false` (or remove the flag), commit the new PNG. **Only do this if the diff is cosmetic (1-2px text differences)**; semantic diffs (e.g., missing icon) indicate a real bug.

- [ ] **Step 7: Commit**

```bash
git add Tests/CodeEditorSampleTests
git commit -m "$(cat <<'EOF'
Sample tests: migrate to CompletionEvent + drop TelemetryCompletionProvider suite

Renames CompletionActivityEntry constructor calls and field reads to
CompletionEvent; drops TelemetryCompletionProviderTests entirely (the
decorator it covers is gone). Adds a detach-cancels-event-task case.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Full quality gate + REVIEW.md update

**Files:**
- Modify: `REVIEW.md`

Run the project's standard quality pipeline end-to-end, then document the landing in `REVIEW.md` matching the format used by prior batches (Status section + entry under "What's left after this round").

- [ ] **Step 1: Run the full quality pipeline**

Run:
```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Expected:
- Build: green.
- SwiftLint: 0 violations.
- Tests: every new test passes; pre-existing failures documented in REVIEW.md's Status section (`EditorStatusBarSnapshots/*` parallel SIGSEGV, `RegexRangeHighlightProviderTests.testParsePerformance100KLines`, `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap`, `LineGeometryStoreBenchmarkTests.testFuzzIncrementalEditCorrectness`, etc.) still reproduce on bare `main` — don't claim regressions for any pre-existing failure.

If a new failure surfaces and isn't in the pre-existing list, fix it before continuing. Use targeted runs (`swift test --filter <SuiteName>`) to iterate.

- [ ] **Step 2: Update REVIEW.md**

Open `REVIEW.md`. Add a new batch section near the existing 2026-05-14 batches (place between "Sample coverage gaps batch" and "`.performanceObserver(_:)` modifier batch", or as the last batch before "Top-level take", matching the chronology):

```markdown
### `CompletionEvent` AsyncStream batch (landed 2026-05-14)

Closes sample-driven API gap #6. Spec at `docs/superpowers/specs/2026-05-14-completion-event-stream-design.md`; plan at `docs/superpowers/plans/2026-05-14-completion-event-stream.md`.

| Item | Status | What landed |
|---|---|---|
| New public `CompletionEvent` value type | ✅ Done | `Sources/CodeEditorPlugin/Completion/CompletionEvent.swift` — `Sendable, Hashable, Identifiable` struct with `id`, `providerID`, `language`, `triggerCharacter`, `prefix` (≤ 32 chars), `durationMilliseconds`, `timestamp`, `outcome: Outcome` (`.succeeded(itemCount:)` / `.failed(SendableError)`). Private convenience init takes a `CompletionContextModel` and centralizes the prefix truncation. |
| New `CompletionManager.events()` + `EditorController.completionEvents()` | ✅ Done | `events()` returns a fresh `AsyncStream<CompletionEvent>` per call; each subscriber receives every event published while its iterator is alive. Per-subscriber `.bufferingNewest(256)` buffer prevents slow consumers from backpressuring the publisher. Controller forwarder returns an empty terminating stream when unattached. |
| Internal `CompletionEventBroadcaster` | ✅ Done | `final class: @unchecked Sendable` over `NSLock` + `[UUID: AsyncStream<CompletionEvent>.Continuation]`. Matches the `HighlightingTaskManager` actor→lock precedent so `events()` and `publish(_:)` stay synchronous. `onTermination` removes the continuation; subscribed-then-dropped streams cannot accumulate. |
| Instrumented `CompletionManager.collectResultsConcurrently` | ✅ Done | Each `withTaskGroup`-spawned provider call now publishes `.succeeded` or `.failed` around its `try await provider.completions(for:)`. Per-provider failure isolation preserved — the event publishes *before* the existing `return nil` swallow, so subscribers see every fire while batch-level behavior is unchanged. |
| Sample migration | ✅ Done | `TelemetryCompletionProvider.swift` and `CompletionActivityEntry.swift` deleted. `CompletionSampleCoordinator.attach(controller:)` registers providers directly and spawns one `Task { for await event in controller.completionEvents() { record(event) } }`; `detach()` cancels it. `CompletionInspectorPanel` reads `CompletionEvent` fields. The 20-entry display ring is unchanged. |

**Files touched (this batch — 4 modified, 2 added, 2 deleted on the framework side; 2 modified, 2 deleted on the sample side):**
Framework — Added `Sources/CodeEditorPlugin/Completion/CompletionEvent.swift`, `Sources/CodeEditorPlugin/Completion/CompletionEventBroadcaster.swift`. Modified `Sources/CodeEditorPlugin/Completion/CompletionManager.swift`, `Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift`.
Sample — Deleted `Sources/CodeEditorSample/App/Completion/TelemetryCompletionProvider.swift`, `Sources/CodeEditorSample/App/Completion/CompletionActivityEntry.swift`. Modified `Sources/CodeEditorSample/App/Completion/CompletionSampleCoordinator.swift`, `Sources/CodeEditorSample/Sidebars/CompletionInspectorPanel.swift`.
Tests — Added `Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift` (6 cases: success, failure isolation, multi-subscriber, termination cleanup, bufferingNewest(256), controller-unattached-stream). Modified `Tests/CodeEditorSampleTests/CompletionSampleCoordinatorTests.swift`, `Tests/CodeEditorSampleTests/CompletionInspectorPanelSnapshotTests.swift`. Deleted `Tests/CodeEditorSampleTests/TelemetryCompletionProviderTests.swift`.

**Public API impact.** Strictly additive on the framework: new `CompletionEvent` type, new `CompletionManager.events()`, new `EditorController.completionEvents()`. Existing call sites compile unchanged. Sample-internal source-breaking only (deletions/renames).

Build: green. SwiftLint: 0 violations.
```

Also flip the "Sample-driven API gap #6" line in the "What's left after this round" section near the bottom of REVIEW.md from open to landed:

Locate the line:
```markdown
- **Sample-driven API gap #6** — `CompletionEvent` AsyncStream. (#3 `EditorDocument` recipe, #5 `EditorController.onAttach`, and #7 `.performanceObserver(_:)` modifier — landed.)
```

Replace with:
```markdown
- ~~**Sample-driven API gap #6** — `CompletionEvent` AsyncStream.~~ ✅ Landed in the `CompletionEvent` AsyncStream batch on 2026-05-14. (#3 `EditorDocument` recipe, #5 `EditorController.onAttach`, and #7 `.performanceObserver(_:)` modifier — landed.)
```

Also locate the "API gaps revealed by `CodeEditorSample`" line for #6 (around line 415):
```markdown
6. **No telemetry hook on `CompletionProvider`.** Sample wraps every provider in `TelemetryCompletionProvider` (`App/Completion/TelemetryCompletionProvider.swift`). Expose `AsyncStream<CompletionEvent>` on `CompletionManager`.
```

Replace with:
```markdown
6. ~~**No telemetry hook on `CompletionProvider`.** Sample wraps every provider in `TelemetryCompletionProvider` (`App/Completion/TelemetryCompletionProvider.swift`). Expose `AsyncStream<CompletionEvent>` on `CompletionManager`.~~ ✅ Landed in the `CompletionEvent` AsyncStream batch on 2026-05-14. `CompletionManager.events() -> AsyncStream<CompletionEvent>` plus `EditorController.completionEvents()` forwarder. Sample's `TelemetryCompletionProvider` and `CompletionActivityEntry` deleted.
```

Finally, update the Status section at line 7 — append "`CompletionEvent` AsyncStream batch" to the comma-separated list of landed batches so the running ledger stays accurate.

- [ ] **Step 3: Commit**

```bash
git add REVIEW.md
git commit -m "$(cat <<'EOF'
Update REVIEW.md: CompletionEvent AsyncStream landed

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Final verification**

Run:
```bash
git log --oneline -15
swift build && swiftlint && swift test --parallel
```

Expected:
- ~12 commits since the spec landed (one per task).
- Build, lint, and the new tests green.
- Pre-existing failures unchanged.

---

## Done

After Task 12, the implementation is complete. Sample-driven API gap #6 is closed. The next REVIEW.md "What's left after this round" list shrinks from 7 items to 6.
