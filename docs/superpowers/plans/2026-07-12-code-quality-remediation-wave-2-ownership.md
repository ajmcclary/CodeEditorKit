# Ownership Boundaries and Events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move feature lifecycle out of `CodeEditorView`, split SwiftUI synchronization, decompose completion/LSP internals, and establish one ordered event bus for A1–A3 and P3.

**Architecture:** A package-internal `EditorSession` coordinates focused feature controllers. Stable completion and LSP façades delegate to registry/request/cache/transport/document components. The SwiftUI coordinator delegates value synchronization to four collaborators, and all event compatibility APIs subscribe to one main-actor bus.

**Tech Stack:** Swift 6.3, Swift Testing, XCTest, TextKit 2, SwiftUI, AsyncStream, Combine, AppKit/UIKit.

## Global Constraints

- Keep `CodeEditorView`, `CompletionManager`, and `LSPClient` public façades.
- Feature controllers own their tasks, observers, cleanup registrations, and state.
- `attach` and `detach` are idempotent.
- Event publication occurs once and preserves one sequence across every adapter.
- No new target dependency cycle is allowed.

---

### Task 1: Establish the `EditorSession` Lifecycle

**Files:**
- Create: `Sources/CodeEditorView/EditorSession.swift`
- Create: `Sources/CodeEditorView/EditorFeatureController.swift`
- Create: `Tests/CodeEditorPluginTests/Core/EditorSessionTests.swift`

**Interfaces:**
- Produces: `EditorFeatureController`, `EditorSessionLifecycle`, `EditorSession.attach(to:)`, `EditorSession.detach()`.

- [ ] **Step 1: Write failing idempotence tests**

```swift
@MainActor
private final class RecordingFeatureController: EditorFeatureController {
    var attachCount = 0
    var detachCount = 0
    func attach(to _: CodeEditorView) { attachCount += 1 }
    func detach() { detachCount += 1 }
}

@MainActor
@Test("session attaches and detaches each feature once")
func lifecycleIsIdempotent() {
    let feature = RecordingFeatureController()
    let session = EditorSession(features: [feature])
    let view = CodeEditorView(frame: .zero)
    session.attach(to: view)
    session.attach(to: view)
    session.detach()
    session.detach()
    #expect(feature.attachCount == 1)
    #expect(feature.detachCount == 1)
}
```

- [ ] **Step 2: Run RED**

Run: `swift test --filter EditorSessionTests`

Expected: compilation fails because the session interfaces do not exist.

- [ ] **Step 3: Implement lifecycle-only composition**

```swift
@MainActor
package protocol EditorFeatureController: AnyObject {
    func attach(to view: CodeEditorView)
    func detach()
}

@MainActor
package protocol EditorSessionLifecycle: AnyObject {
    func attach(to view: CodeEditorView)
    func detach()
}

@MainActor
package final class EditorSession: EditorSessionLifecycle {
    private let features: [any EditorFeatureController]
    private weak var attachedView: CodeEditorView?

    package init(features: [any EditorFeatureController]) { self.features = features }

    package func attach(to view: CodeEditorView) {
        guard attachedView !== view else { return }
        detach()
        attachedView = view
        features.forEach { $0.attach(to: view) }
    }

    package func detach() {
        guard attachedView != nil else { return }
        features.reversed().forEach { $0.detach() }
        attachedView = nil
    }
}
```

- [ ] **Step 4: Run GREEN and commit**

```bash
swift test --filter EditorSessionTests
git add Sources/CodeEditorView/EditorSession.swift Sources/CodeEditorView/EditorFeatureController.swift Tests/CodeEditorPluginTests/Core/EditorSessionTests.swift
git commit -m "refactor(view): introduce editor session lifecycle"
```

### Task 2: Move Highlighting Lifecycle Into a Controller

**Files:**
- Create: `Sources/CodeEditorView/SyntaxHighlighting/HighlightingController.swift`
- Create: `Tests/CodeEditorPluginTests/SyntaxHighlighting/HighlightingControllerTests.swift`
- Modify: `Sources/CodeEditorView/CodeEditorView+SyntaxHighlightingExtensions.swift`
- Modify: `Sources/CodeEditorView/CodeEditorView.swift`

**Interfaces:**
- Produces: `HighlightingController` owning async/legacy/range-based highlighting attachment and cancellation.

- [ ] **Step 1: Add failing detach test**

```swift
@MainActor
private final class HighlightingCancellationSpy: HighlightingCancelling {
    private(set) var cancelCount = 0

    func cancelAll() {
        cancelCount += 1
    }
}

@MainActor
@Test("detaching highlighting cancels work and clears range controller")
func detachCancelsHighlighting() {
    let spy = HighlightingCancellationSpy()
    let controller = HighlightingController(cancellation: spy)
    controller.attach(to: CodeEditorView(frame: .zero))
    controller.detach()
    #expect(spy.cancelCount == 1)
    #expect(controller.isAttached == false)
}
```

- [ ] **Step 2: Run RED**

Run: `swift test --filter HighlightingControllerTests`

Expected: compilation fails because the controller and cancellation port do not exist.

- [ ] **Step 3: Implement the controller and forwarding view methods**

Define the lifecycle port explicitly:

```swift
@MainActor
package protocol HighlightingCancelling: AnyObject {
    func cancelAll()
}
```

Make existing highlighters conform, and move task/range-controller teardown into
`HighlightingController.detach()`. `CodeEditorView.applySyntaxHighlighting()`
forwards to `session.highlighting.apply(language:text:)`.

- [ ] **Step 4: Run and commit**

```bash
swift test --filter HighlightingControllerTests
swift test --filter SyntaxHighlightingTests
git add Sources/CodeEditorView Tests/CodeEditorPluginTests/SyntaxHighlighting
git commit -m "refactor(highlighting): own lifecycle in feature controller"
```

### Task 3: Move Completion, Folding, and LSP View Lifecycle Into Controllers

**Files:**
- Create: `Sources/CodeEditorView/Completion/EditorCompletionController.swift`
- Create: `Sources/CodeEditorView/Folding/EditorFoldingController.swift`
- Create: `Sources/CodeEditorView/LSP/LSPDocumentController.swift`
- Create: `Tests/CodeEditorPluginTests/Core/EditorFeatureControllerTests.swift`
- Modify: `Sources/CodeEditorView/CodeEditorView.swift:299-497,624-675`
- Modify: `Sources/CodeEditorView/MemoryManagementCoordinator.swift`

**Interfaces:**
- Produces: controllers exposed from `EditorSession`; `CodeEditorView.removeFromSuperview()` calls only `session.detach()` plus platform-super cleanup.

- [ ] **Step 1: Add failing ownership tests**

```swift
@MainActor
@Test("view teardown delegates feature cleanup to its session")
func viewTeardownUsesSession() {
    final class RecordingEditorSession: EditorSessionLifecycle {
        var detachCount = 0
        func attach(to _: CodeEditorView) {}
        func detach() { detachCount += 1 }
    }
    let session = RecordingEditorSession()
    let view = CodeEditorView(frame: .zero, session: session)
    view.removeFromSuperview()
    #expect(session.detachCount == 1)
}
```

Add controller tests proving completion cancels its request/popover, folding detaches its engine, and LSP detaches the content coordinator without destroying the injected `LSPManager`.

- [ ] **Step 2: Run RED**

Run: `swift test --filter EditorFeatureControllerTests`

Expected: compilation fails because session injection and controllers do not exist.

- [ ] **Step 3: Implement controllers and reduce view ownership**

Move completion UI flags/controllers into `EditorCompletionController`, fold engine registration into `EditorFoldingController`, and LSP document/semantic provider state into `LSPDocumentController`. Preserve package forwarding properties needed by existing extensions during migration.

- [ ] **Step 4: Run view integration tests and commit**

```bash
swift test --filter EditorFeatureControllerTests
swift test --filter CodeEditorViewTests
swift test --filter LSPIntegrationTests
git add Sources/CodeEditorView Tests/CodeEditorPluginTests
git commit -m "refactor(view): move feature lifecycle into editor session"
```

### Task 4: Extract Text Binding Synchronization

**Files:**
- Create: `Sources/CodeEditorSwiftUI/EditorBindingSynchronizer.swift`
- Create: `Tests/CodeEditorPluginTests/SwiftUI/EditorBindingSynchronizerTests.swift`
- Modify: `Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift:25-40,61-73,172-220`

**Interfaces:**
- Produces: `EditorBindingSynchronizer.bind(_:)`, `receiveEditorText(_:)`, `cancel()`.

- [ ] **Step 1: Add failing debounce/feedback tests**

```swift
@MainActor
@Test("editor text updates binding once after debounce")
func debouncedBindingUpdate() async {
    var writes: [String] = []
    let synchronizer = EditorBindingSynchronizer(
        debounce: .milliseconds(1),
        write: { writes.append($0) }
    )
    synchronizer.receiveEditorText("a")
    synchronizer.receiveEditorText("ab")
    try? await Task.sleep(for: .milliseconds(5))
    #expect(writes == ["ab"])
}
```

- [ ] **Step 2: Run RED**

Run: `swift test --filter EditorBindingSynchronizerTests`

Expected: compilation fails because the synchronizer does not exist.

- [ ] **Step 3: Implement and replace coordinator fields**

Use one cancellable `Task<Void, Never>`, immediate internal callback, delayed binding write, and explicit cancellation. Remove `textUpdateTask`, both debounce interval properties, duplicate text callbacks, and text feedback logic from the coordinator.

- [ ] **Step 4: Run and commit**

```bash
swift test --filter EditorBindingSynchronizerTests
swift test --filter SwiftUICoordinatorTests
git add Sources/CodeEditorSwiftUI Tests/CodeEditorPluginTests/SwiftUI
git commit -m "refactor(swiftui): extract text binding synchronization"
```

### Task 5: Extract Interaction-State Synchronization

**Files:**
- Create: `Sources/CodeEditorSwiftUI/EditorInteractionSynchronizer.swift`
- Create: `Tests/CodeEditorPluginTests/SwiftUI/EditorInteractionSynchronizerTests.swift`
- Modify: `Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift:41-59,87-92,223-296`

**Interfaces:**
- Produces: cursor restoration, dirty baseline, selection mirroring, and `markClean` in one owner.

- [ ] **Step 1: Add failing cursor/dirty tests**

```swift
@MainActor
@Test("host swap resets baseline and user edit marks dirty")
func dirtyStateLifecycle() {
    let state = EditorState()
    let synchronizer = EditorInteractionSynchronizer(hostState: state)
    synchronizer.installBaseline("one")
    synchronizer.receiveText("two", language: .swift)
    #expect(state.isDirty)
    synchronizer.markClean(currentText: "two")
    #expect(state.isDirty == false)
}
```

- [ ] **Step 2: Run RED**

Run: `swift test --filter EditorInteractionSynchronizerTests`

Expected: compilation fails because the synchronizer does not exist.

- [ ] **Step 3: Move state and conversion logic**

Move `DirtyTracker`, host state, interaction binding, selection derivation, UTF-16 cursor conversion, and baseline operations into the new type. The coordinator forwards delegate selection events and `markClean` only.

- [ ] **Step 4: Run and commit**

```bash
swift test --filter EditorInteractionSynchronizerTests
swift test --filter EditorStateDirtyMirrorTests
git add Sources/CodeEditorSwiftUI Tests/CodeEditorPluginTests
git commit -m "refactor(swiftui): extract interaction synchronization"
```

### Task 6: Extract Completion Modifier Registration

**Files:**
- Create: `Sources/CodeEditorSwiftUI/CompletionModifierRegistry.swift`
- Modify: `Tests/CodeEditorPluginTests/Completion/SwiftUIClosureLifecycleTests.swift`
- Modify: `Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift:80-85,672-702`

**Interfaces:**
- Produces: `CompletionModifierRegistry.reconcile(on:closure:)`.

- [ ] **Step 1: Rewrite lifecycle test against the new owner and run RED**

Use the existing four-state closure/adapter matrix, instantiate `CompletionModifierRegistry`, and assert stable adapter identity and manager registration count. Run `swift test --filter SwiftUIClosureLifecycleTests`; expect compilation failure for the missing type.

- [ ] **Step 2: Move the existing state machine unchanged**

```swift
@MainActor
final class CompletionModifierRegistry {
    typealias CompletionClosure = @Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem]
    private var adapter: SwiftUIClosureCompletionProvider?

    func reconcile(on manager: CompletionManager, closure: CompletionClosure?) {
        switch (closure, adapter) {
        case let (.some(new), .some(current)): current.closure = new
        case let (.some(new), .none):
            let current = SwiftUIClosureCompletionProvider()
            current.closure = new
            adapter = current
            manager.registerProvider(current)
        case (.none, .some):
            manager.unregisterProvider(withId: "swiftui-modifier")
            adapter = nil
        case (.none, .none): break
        }
    }
}
```

- [ ] **Step 3: Run GREEN and commit**

```bash
swift test --filter SwiftUIClosureLifecycleTests
git add Sources/CodeEditorSwiftUI Tests/CodeEditorPluginTests/Completion/SwiftUIClosureLifecycleTests.swift
git commit -m "refactor(swiftui): extract completion modifier registry"
```

### Task 7: Extract Render Reconciliation and Shrink the Coordinator

**Files:**
- Create: `Sources/CodeEditorSwiftUI/EditorRenderReconciler.swift`
- Create: `Tests/CodeEditorPluginTests/SwiftUI/EditorRenderReconcilerTests.swift`
- Modify: `Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift`

**Interfaces:**
- Consumes: Wave 1 `EditorRuntimeSnapshot`, Tasks 4–6 collaborators.
- Produces: `mount` and `update` ordering in a focused reconciler; coordinator retains only delegate/representable plumbing.

- [ ] **Step 1: Add failing operation-order test**

Record `runtime`, `text`, `language`, `configuration`, and `theme` operations through a test adapter. Assert runtime occurs before a value-state early return and initial order is deterministic.

- [ ] **Step 2: Run RED**

Run: `swift test --filter EditorRenderReconcilerTests`

Expected: compilation fails because the reconciler does not exist.

- [ ] **Step 3: Move setup/update orchestration**

Define `EditorRenderState: Equatable` and `EditorRenderReconciler.mount/update`. Inject platform operations behind the existing `CodeEditorPlatformAdapter`. Delete empty `cleanup`, empty macOS minimap setup, and empty iOS done-button methods.

- [ ] **Step 4: Run coordinator suites and commit**

```bash
swift test --filter EditorRenderReconcilerTests
swift test --filter SwiftUICoordinatorTests
swift test --filter SwiftUIIntegrationTests
git add Sources/CodeEditorSwiftUI Tests/CodeEditorPluginTests
git commit -m "refactor(swiftui): isolate render reconciliation"
```

### Task 8: Extract `CompletionProviderRegistry`

**Files:**
- Create: `Sources/CodeEditorCompletion/CompletionProviderRegistry.swift`
- Create: `Tests/CodeEditorPluginTests/Completion/CompletionProviderRegistryTests.swift`
- Modify: `Sources/CodeEditorCompletion/CompletionManager.swift:65,156-205`

**Interfaces:**
- Produces: registration, unregistration, language filtering, and built-in-provider reconciliation.

- [ ] **Step 1: Add failing collision/sweep tests**

Test host provider collision at `builtin.keywords.swift`, stale built-in removal on language change, and empty supported-language wildcard. Run `swift test --filter CompletionProviderRegistryTests`; expect missing-type failure.

- [ ] **Step 2: Implement registry and façade forwarding**

Move the provider dictionary and methods into `@MainActor final class CompletionProviderRegistry`. `CompletionManager.registeredProviders` and registration methods forward to it.

- [ ] **Step 3: Run and commit**

```bash
swift test --filter CompletionProviderRegistryTests
swift test --filter CompletionSystemTests
git add Sources/CodeEditorCompletion Tests/CodeEditorPluginTests/Completion
git commit -m "refactor(completion): extract provider registry"
```

### Task 9: Extract Completion Request Coordination

**Files:**
- Create: `Sources/CodeEditorCompletion/CompletionRequestCoordinator.swift`
- Create: `Tests/CodeEditorPluginTests/Completion/CompletionRequestCoordinatorTests.swift`
- Modify: `Sources/CodeEditorCompletion/CompletionManager.swift:207-388`

**Interfaces:**
- Produces: cancellation, concurrent fan-out, provider failure isolation, and event emission.

- [ ] **Step 1: Add failing cancellation/fan-out tests**

Use two real test providers and an async gate. Assert the second request cancels the first, both applicable providers run concurrently, and one provider failure does not erase the successful result.

- [ ] **Step 2: Run RED**

Run: `swift test --filter CompletionRequestCoordinatorTests`

Expected: missing-type failure.

- [ ] **Step 3: Implement coordinator and delegate from façade**

The coordinator accepts `[any CompletionProvider]`, `CompletionEventSink`, and a result processor closure. It owns `currentRequest` and `CompletionDebouncer`; `CompletionManager` no longer owns request tasks.

- [ ] **Step 4: Run and commit**

```bash
swift test --filter CompletionRequestCoordinatorTests
swift test --filter CompletionSystemTests
git add Sources/CodeEditorCompletion Tests/CodeEditorPluginTests/Completion
git commit -m "refactor(completion): extract request coordination"
```

### Task 10: Extract Completion Cache, Learning, and Ranking

**Files:**
- Create: `Sources/CodeEditorCompletion/CompletionResponseCache.swift`
- Create: `Sources/CodeEditorCompletion/CompletionLearningStore.swift`
- Create: `Sources/CodeEditorCompletion/CompletionRanker.swift`
- Create: `Tests/CodeEditorPluginTests/Completion/CompletionComponentTests.swift`
- Modify: `Sources/CodeEditorCompletion/CompletionManager.swift:395-583`

**Interfaces:**
- Produces: pure `CompletionRanker.rank(_:context:learning:maxCount:)`; state-specific cache/learning owners.

- [ ] **Step 1: Add failing pure ranking and isolation tests**

Move existing six-tier ranking expectations to `CompletionRanker`. Add a test proving `clearLearnedPatterns` does not clear response cache and `clearCache` does not clear learning.

- [ ] **Step 2: Run RED**

Run: `swift test --filter CompletionComponentTests`

Expected: missing-type failure.

- [ ] **Step 3: Extract components and preserve façade API**

Move `FrequencyEntry` and `lastContext` into learning, cache key/expiration into response cache, and ranking/dedup sorting into the pure ranker. Keep public manager methods as forwards.

- [ ] **Step 4: Run and commit**

```bash
swift test --filter CompletionComponentTests
swift test --filter CompletionRanking
git add Sources/CodeEditorCompletion Tests/CodeEditorPluginTests/Completion
git commit -m "refactor(completion): isolate cache learning and ranking"
```

### Task 11: Reduce `CompletionManager` to a Façade

**Files:**
- Modify: `Sources/CodeEditorCompletion/CompletionManager.swift`
- Create: `Tests/CodeEditorPluginTests/Completion/CompletionFacadeIntegrationTests.swift`

**Interfaces:**
- Consumes: Tasks 8–10 components.
- Produces: source-compatible `CompletionManager` with component injection initializer for tests.

- [ ] **Step 1: Add failing façade integration test**

Inject recording registry/request/cache/learning/ranker components, call public manager APIs, and assert each delegates to the correct owner once.

- [ ] **Step 2: Run RED, complete façade, and run GREEN**

Run `swift test --filter CompletionFacadeIntegrationTests`; expect initializer failure. Add a package initializer accepting components, remove duplicated state from the façade, then rerun the test and `CompletionSystemTests`.

- [ ] **Step 3: Commit**

```bash
git add Sources/CodeEditorCompletion Tests/CodeEditorPluginTests/Completion
git commit -m "refactor(completion): reduce manager to orchestration facade"
```

### Task 12: Extract `JSONRPCSession`

**Files:**
- Create: `Sources/CodeEditorLSP/JSONRPCSession.swift`
- Create: `Tests/CodeEditorPluginTests/LSP/JSONRPCSessionTests.swift`
- Modify: `Sources/CodeEditorLSP/LSPClient.swift:103-146,555-659`

**Interfaces:**
- Produces: request allocation, encoding, pending continuation ownership, response routing, and `failAllPending(with:)`.

- [ ] **Step 1: Add failing exactly-once tests**

Use a recording transport to cover response success, partial-send failure after response, disconnect with pending requests, and request-ID wrap. Assert each continuation completes once.

- [ ] **Step 2: Run RED**

Run: `swift test --filter JSONRPCSessionTests`

Expected: missing-type failure.

- [ ] **Step 3: Implement actor-isolated session**

`JSONRPCSession` owns `[RequestId: CheckedContinuation]`, removes before resume, and only resumes a send failure if removal returned a pending continuation. It accepts an async `send(Data)` closure.

- [ ] **Step 4: Run and commit**

```bash
swift test --filter JSONRPCSessionTests
swift test --filter LSPIntegrationTests
git add Sources/CodeEditorLSP Tests/CodeEditorPluginTests/LSP
git commit -m "refactor(lsp): isolate JSON-RPC session state"
```

### Task 13: Split LSP Connection, Document, and Feature Components

**Files:**
- Create: `Sources/CodeEditorLSP/LSPConnectionLifecycle.swift`
- Create: `Sources/CodeEditorLSP/LSPDocumentSession.swift`
- Create: `Sources/CodeEditorLSP/LSPLanguageFeatureClient.swift`
- Create: `Tests/CodeEditorPluginTests/LSP/LSPComponentTests.swift`
- Modify: `Sources/CodeEditorLSP/LSPClient.swift`

**Interfaces:**
- Consumes: `JSONRPCSession`.
- Produces: focused components and source-compatible `LSPClient` forwarding API.

- [ ] **Step 1: Add failing component tests**

Test idempotent connection teardown, document open/change/close messages, diagnostic removal on close, and one language-feature request/parse path per response shape.

- [ ] **Step 2: Run RED**

Run: `swift test --filter LSPComponentTests`

Expected: missing-type failure.

- [ ] **Step 3: Move behavior and project observable state**

Connection lifecycle owns transport/process teardown. Document session owns diagnostics and notification builders. Feature client owns request parameter/response parsing. `LSPClient` publishes component state and forwards existing public methods.

- [ ] **Step 4: Run and commit**

```bash
swift test --filter LSPComponentTests
swift test --filter LSPIntegrationTests
swift test --filter RemoteLSP
git add Sources/CodeEditorLSP Tests/CodeEditorPluginTests/LSP
git commit -m "refactor(lsp): split connection documents and features"
```

### Task 14: Implement the Canonical Ordered Event Bus

**Files:**
- Create: `Sources/CodeEditorView/EditorEventBus.swift`
- Create: `Tests/CodeEditorPluginTests/Core/EditorEventBusTests.swift`

**Interfaces:**
- Produces: `SequencedEditorEvent`, synchronous main-actor publication, independent buffered streams.

- [ ] **Step 1: Add failing ordering tests**

Publish three events, consume from two streams, and assert both observe sequence numbers `[1, 2, 3]` and identical payload order.

- [ ] **Step 2: Run RED**

Run: `swift test --filter EditorEventBusTests`

Expected: missing-type failure.

- [ ] **Step 3: Implement bus**

```swift
public struct SequencedEditorEvent: Sendable {
    public let sequence: UInt64
    public let event: EditorEvent
}

@MainActor
public final class EditorEventBus {
    private var nextSequence: UInt64 = 1
    private var continuations: [UUID: AsyncStream<SequencedEditorEvent>.Continuation] = [:]
    private var history: [SequencedEditorEvent] = []
    private let historyLimit: Int

    public init(historyLimit: Int = 100) {
        self.historyLimit = max(1, historyLimit)
    }

    public func publish(_ event: EditorEvent) {
        let value = SequencedEditorEvent(sequence: nextSequence, event: event)
        nextSequence &+= 1
        history.append(value)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
        continuations.values.forEach { $0.yield(value) }
    }

    public func stream(
        bufferingPolicy: AsyncStream<SequencedEditorEvent>.Continuation.BufferingPolicy = .bufferingNewest(100)
    ) -> AsyncStream<SequencedEditorEvent> {
        let identifier = UUID()
        return AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            continuations[identifier] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.continuations.removeValue(forKey: identifier)
                }
            }
        }
    }

    public func recentEvents(
        matching predicate: (EditorEvent) -> Bool = { _ in true }
    ) -> [SequencedEditorEvent] {
        history.filter { predicate($0.event) }
    }
}
```

Add tests for the history limit, predicate filtering, independent buffering, and
continuation removal after cancellation before returning from this task.

- [ ] **Step 4: Run and commit**

```bash
swift test --filter EditorEventBusTests
git add Sources/CodeEditorView/EditorEventBus.swift Tests/CodeEditorPluginTests/Core/EditorEventBusTests.swift
git commit -m "feat(events): add canonical ordered editor event bus"
```

### Task 15: Adapt Existing Event APIs to the Bus

**Files:**
- Modify: `Sources/CodeEditorView/EditorEventPublisher.swift`
- Modify: `Sources/CodeEditorView/UnifiedEventSystem.swift`
- Create: `Sources/CodeEditorView/NotificationCenterEventAdapter.swift`
- Create: `Tests/CodeEditorPluginTests/Core/EditorEventAdapterTests.swift`

**Interfaces:**
- Consumes: `EditorEventBus` streams.
- Produces: weak-handler, Combine, unified history/filter, and notification compatibility without republishing.

- [ ] **Step 1: Add failing cross-adapter ordering/single-delivery test**

Attach all adapters to one bus, publish selection and text events, and assert each adapter receives the same sequence once. Assert notifications do not cause a second bus event.

- [ ] **Step 2: Run RED**

Run: `swift test --filter EditorEventAdapterTests`

Expected: adapters cannot be constructed from a shared bus.

- [ ] **Step 3: Convert adapters**

Remove independent event subjects/sources. Each adapter consumes the bus stream and projects its public surface. Deprecate direct adapter `publish` methods and forward them to the bus for source compatibility.

- [ ] **Step 4: Run and commit**

```bash
swift test --filter EditorEventAdapterTests
swift test --filter PublishEventFanOutTests
git add Sources/CodeEditorView Tests/CodeEditorPluginTests/Core
git commit -m "refactor(events): adapt legacy surfaces to canonical bus"
```

### Task 16: Publish Once From `CodeEditorView`

**Files:**
- Modify: `Sources/CodeEditorView/EditorRuntime.swift`
- Modify: `Sources/CodeEditorView/UnifiedEventSystem.swift:404-413`
- Modify: `Sources/CodeEditorView/CodeEditorView+ConfigurationExtensions.swift:131-141`
- Modify: `Sources/CodeEditorView/CodeEditorView+Responder.swift`
- Modify: `Sources/CodeEditorView/CodeEditorView+SyntaxHighlightingExtensions.swift`
- Modify: `Tests/CodeEditorPluginTests/Core/PublishEventFanOutTests.swift`

**Interfaces:**
- Produces: one `CodeEditorView.publishEvent` call into `EditorEventBus`; adapters fan out.

- [ ] **Step 1: Change fan-out test to require one source publication and run RED**

Instrument the bus publish count while subscribing through every legacy adapter. One editor event must produce publish count `1` and delivery count `1` per adapter.

- [ ] **Step 2: Replace direct notification/local/global fan-out**

`EditorRuntimeDependencies` owns one bus. `CodeEditorView.publishEvent` calls `runtime.dependencies.eventBus.publish(event)`. Selection no longer posts directly; the notification adapter owns notification translation.

- [ ] **Step 3: Run full event and Wave 2 gates**

```bash
swift test --filter PublishEventFanOutTests
swift test --filter EditorEvent
swift build
swiftlint --fix
swiftlint
swift test --parallel
```

Expected: all commands pass and event order/single-delivery tests are green.

- [ ] **Step 4: Commit**

```bash
git add Sources Tests
git commit -m "refactor(events): publish editor events through one bus"
```
