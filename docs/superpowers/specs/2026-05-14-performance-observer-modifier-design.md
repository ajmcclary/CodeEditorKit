# `.performanceObserver(_:)` SwiftUI Modifier — Design

**Status.** Draft, 2026-05-14.
**Tracks.** REVIEW.md "Sample-driven API gaps", item #7 (`UnifiedPerformanceSystem` dual wiring).

## Problem

`UnifiedPerformanceSystem` is wired into a `CodeEditor` two ways today, and every host that wants a performance inspector has to do both:

1. Inject the system into `EditorConfiguration` so the framework's metric producers can record into it — `AsyncSyntaxHighlighter.swift:305` reads `textView.configuration.performance.unifiedPerformanceSystem` and calls `await ups.track(.syntaxHighlighting) { … }`.
2. Hold a separate reference to the same instance and poll `generateInsights()` on a timer to surface the snapshot to UI.

The sample does both:

- `Sources/CodeEditorSample/App/AppState.swift:135` — assigns to `configuration.performance.unifiedPerformanceSystem`.
- `Sources/CodeEditorSample/App/Performance/PerformanceSampleCoordinator.swift:111` — calls `generateInsights()` inside a 1 Hz `Timer.scheduledTimer` started in `start()`.

Two wirings, one shared instance, one purpose. Hosts that miss one half silently get half the feature (e.g., forget the config injection: the inspector renders empty metrics forever because no producer ever wrote to the system).

REVIEW.md's framing: "Add `.performanceObserver(_:)` modifier that does both."

## Goals & non-goals

**Goal.** Provide one SwiftUI modifier on `CodeEditor` that folds both wirings together. After this lands, a host writes one line and gets: the system injected into the editor's effective configuration, and a continuously-refreshed `@Observable` view of `generateInsights()` snapshots.

**Non-goals.**
- Adding new metric producers. `AsyncSyntaxHighlighter` remains the only in-tree producer; LSP / completion / FPS instrumentation are separate designs.
- Replacing `PerformanceInsights` (the aggregator over `MemoryMonitor` + `FrameRateMonitor` + UPS issues/recommendations) or `MemoryMonitor`. The sample's `PerformanceSampleCoordinator` keeps owning FPS / memory / sparkline / adaptive-mode aggregation — those are different signals from different monitors.
- Deprecating `EditorConfiguration.Performance.unifiedPerformanceSystem`. The field stays as an alternative injection path; a future cleanup pass can decide whether to gate it.

## Design overview

A new public `@MainActor @Observable` type `PerformanceObservation` wraps a `UnifiedPerformanceSystem` plus an internal `Task`-driven refresh loop. A new `.performanceObserver(_ observation: PerformanceObservation)` modifier on `CodeEditor` writes the observation into `CodeEditorEnvironment` so `CodeEditor.body` can inject `observation.system` into the effective `EditorConfiguration` it passes downstream. The host owns the observation's lifecycle (`start()` / `stop()`) and reads `observation.lastInsights` from SwiftUI bodies.

```
                ┌────────────────────────────────────────────┐
                │ Host (AppState / view)                     │
                │                                            │
   construct ──▶│ let obs = PerformanceObservation()         │
                │ obs.start()                                │
                │                                            │
                │ CodeEditor(text: $text)                    │
                │   .performanceObserver(obs)                │
                └───────────────┬────────────────────────────┘
                                │
                                ▼
        ┌───────────────────────────────────────────────────┐
        │ CodeEditor.body                                   │
        │   environment.performanceObservation = obs        │
        │   effectiveConfiguration = environment.configuration
        │   effectiveConfiguration.performance               │
        │     .unifiedPerformanceSystem = obs.system        │ ◀── injection
        │   → CodeEditorRepresentable(configuration: …)     │
        └───────────────────────────────────────────────────┘
                                │
                                ▼
        ┌───────────────────────────────────────────────────┐
        │ AsyncSyntaxHighlighter (sole producer)            │
        │   ups.track(.syntaxHighlighting) { … }            │ ◀── writes metrics
        └───────────────────────────────────────────────────┘
                                │
                                ▼
        ┌───────────────────────────────────────────────────┐
        │ PerformanceObservation (internal Task @1 Hz)      │
        │   lastInsights = system.generateInsights()        │ ◀── refresh
        └───────────────────────────────────────────────────┘
                                │
                                ▼
                          host SwiftUI body
                          reads obs.lastInsights
                          (observed via @Observable)
```

## Public API

### `PerformanceObservation`

```swift
// Sources/CodeEditorPlugin/Performance/PerformanceObservation.swift

@MainActor
@Observable
public final class PerformanceObservation {
    public let system: UnifiedPerformanceSystem
    public private(set) var lastInsights: UnifiedPerformanceInsights
    public var refreshInterval: Duration

    public init(
        system: UnifiedPerformanceSystem = UnifiedPerformanceSystem(),
        refreshInterval: Duration = .seconds(1)
    )

    public func start()
    public func stop()
    public func refresh()

    deinit
}
```

Semantics:

- `system` is `let` and `public` so hosts can call `system.track(...)` directly for custom producers if they choose. No reason to hide it; the observation does not own private state on the system.
- `lastInsights` initial value is `UnifiedPerformanceInsights()` (the type's zero state — empty `metricAnalyses`, empty `issues`/`recommendations`, `overallHealth = 100`). Hosts can read it before `start()` without an Optional ceremony.
- `refreshInterval` is `var`. Mutating it after `start()` takes effect on the next sleep boundary — the in-flight `Task.sleep(for:)` finishes first, then the loop reads the new value. Acceptable for a knob hosts may tweak at most once.
- `start()` spawns the internal refresh `Task`. Idempotent — calling it while running is a no-op.
- `stop()` cancels the refresh `Task` and nils its reference. Idempotent.
- `refresh()` is a synchronous one-shot snapshot: reads `system.generateInsights()` and writes to `lastInsights`. Safe to call from outside the refresh loop (e.g., from tests, or from a host that wants to drive ticks itself).
- `deinit` cancels the refresh `Task` via the `nonisolated(unsafe)` pattern `MemoryMonitor` already uses (`Performance/MemoryMonitor.swift:259-285`).

No convenience flat fields (`lastHighlightMs`, `healthScore`, etc.). Hosts compute from `lastInsights.metricAnalyses[.syntaxHighlighting]` / `.overallHealth` / `.issues.count` at the call site, the same arithmetic the sample uses today. Adding flat fields can be a follow-up once multiple hosts converge on the same set.

### `.performanceObserver(_:)`

```swift
// Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift

extension CodeEditor {
    public func performanceObserver(_ observation: PerformanceObservation) -> some View
}
```

The modifier writes the observation into the editor's `CodeEditorEnvironment`. It does NOT call `start()` — lifecycle stays with the host.

## Wiring

### `CodeEditorEnvironment`

Add a new field to `CodeEditorEnvironment` plus the standard builder pair:

```swift
public struct CodeEditorEnvironment {
    // ... existing fields ...
    public var performanceObservation: PerformanceObservation?

    public func with(performanceObservation: PerformanceObservation?) -> Self { ... }
}
```

Plus a legacy env-key forwarder, matching the existing pattern at `Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift:144-153`:

```swift
public var codeEditorPerformanceObservation: PerformanceObservation? {
    get { codeEditorEnvironment.performanceObservation }
    set { codeEditorEnvironment = codeEditorEnvironment.with(performanceObservation: newValue) }
}
```

### `CodeEditor.body`

After the existing runtime-deps overlay block (`Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift:287-304`), call a new static helper to compute the effective configuration:

```swift
extension CodeEditor {
    static func makeEffectiveConfiguration(
        from environment: CodeEditorEnvironment
    ) -> EditorConfiguration {
        var config = environment.configuration
        if let observation = environment.performanceObservation {
            config.performance.unifiedPerformanceSystem = observation.system
        }
        return config
    }
}

// in body:
let effectiveConfiguration = Self.makeEffectiveConfiguration(from: environment)
```

…then pass `effectiveConfiguration` (instead of `environment.configuration`) into the `CodeEditorRepresentable(...)` initializer and into the `.environment(\.codeEditorConfiguration, _)` modifier. `EditorConfiguration` is a `struct`, so `effectiveConfiguration` is a local copy; nothing leaks back to the caller's binding.

The static helper is extracted specifically so it's unit-testable without rendering the view (see Testing section).

`AsyncSyntaxHighlighter` is unchanged — it keeps reading `textView.configuration.performance.unifiedPerformanceSystem`, which is now the value placed there by the modifier.

### `EditorRuntimeDependencies`

No change. The observation is not part of runtime deps; the system reference it owns reaches the framework through `configuration.performance.unifiedPerformanceSystem` exactly as the legacy path did.

## Lifecycle

The host owns the observation and decides when to start/stop. Typical wiring:

```swift
@MainActor
@Observable
final class AppState {
    let performanceObservation = PerformanceObservation(refreshInterval: .seconds(1))

    init() {
        performanceObservation.start()
    }
}

struct EditorPane: View {
    let appState: AppState

    var body: some View {
        CodeEditor(text: $text)
            .performanceObserver(appState.performanceObservation)
    }
}
```

`start()` must be called explicitly. The modifier does not auto-start because:

- The host may want to construct the observation before any editor is on screen.
- Multiple editors may share one observation; auto-starting from `body` would re-trigger every render.
- The framework already uses host-driven lifecycle for `MemoryMonitor` (`startMonitoring()` / `stopMonitoring()`).

`deinit` cancels the refresh task as a safety net for hosts that forget `stop()`.

## Sample migration

`Sources/CodeEditorSample/App/Performance/PerformanceSampleCoordinator.swift` keeps its broader role (FPS / memory / pressure / adaptive mode / sparkline / health aggregation). The UPS-specific surface gets refactored:

- `init(memoryMonitor:unifiedPerformanceSystem:)` becomes `init(memoryMonitor:performanceObservation:)`.
- The `unifiedPerformanceSystem: UnifiedPerformanceSystem` stored property becomes `performanceObservation: PerformanceObservation`.
- The `let insights = unifiedPerformanceSystem.generateInsights()` line (`PerformanceSampleCoordinator.swift:111`) becomes `let insights = performanceObservation.lastInsights` — no double-tick.
- The coordinator keeps its own `Timer.scheduledTimer` for FPS / memory / sparkline (those signals aren't on UPS). The observation's internal `Task` ticks UPS independently. Both run at 1 Hz; they're not synchronised, but the coordinator's read of `performanceObservation.lastInsights` is cheap and lock-free (an `@Observable` property read on the same actor).

`Sources/CodeEditorSample/App/AppState.swift`:

- Replace `let unifiedPerformanceSystem = UnifiedPerformanceSystem()` (line 70) with `let performanceObservation = PerformanceObservation(refreshInterval: .seconds(1))`.
- Pass `performanceObservation` to `PerformanceSampleCoordinator(...)` (line 124-127) instead of the bare system.
- Delete `self.configuration.performance.unifiedPerformanceSystem = unifiedPerformanceSystem` (line 135). The modifier owns that injection now.
- Wherever the sample's start/stop hooks already fire (`PerformanceSampleCoordinator.start()` / `.stop()`), also call `performanceObservation.start()` / `.stop()`. One place, two extra lines.

Editor construction site (`Sources/CodeEditorSample/App/WindowBody.swift`, the editor pane): add `.performanceObserver(appState.performanceObservation)` after the existing modifiers.

## Testing

Two new test files; no changes to existing tests. The pattern follows `Tests/CodeEditorPluginTests/SwiftUIEnvironmentTests.swift` — exercise the `CodeEditorEnvironment` struct and env-key forwarder directly, plus the new `makeEffectiveConfiguration` helper. We don't introspect `CodeEditor.body`; the helper extraction is what makes the body-side logic testable in isolation.

`Tests/CodeEditorPluginTests/Performance/PerformanceObservationTests.swift` (Swift Testing). Cases:

- `startIsIdempotent` — call `start()` twice; track invocations via a private `refreshCount` counter incremented in `refresh()`; after two `start()` calls and one `Task.sleep`, assert the counter incremented at the single-loop rate (i.e., the second `start()` didn't spawn a parallel loop).
- `refreshUpdatesLastInsights` — `try await system.track(.syntaxHighlighting) { /* no-op */ }`; call `observation.refresh()`; assert `observation.lastInsights.metricAnalyses[.syntaxHighlighting]?.count == 1`.
- `stopCancelsRefreshTask` — start; sleep past one tick; capture `refreshCount`; stop; sleep past two more tick intervals; assert `refreshCount` unchanged.
- `restartAfterStopResumes` — start; stop; start; sleep; assert `refreshCount` advances.

`deinit` cancellation is not directly tested (probing through `weak` references is brittle under `@MainActor @Observable`); instead, `stopCancelsRefreshTask` covers the same code path explicitly, and the `deinit` implementation is a one-line `refreshTask?.cancel()` that's reviewable on its face.

Use `Duration.milliseconds(20)` for `refreshInterval` in tests so the internal task drives multiple ticks within a 100 ms window.

`Tests/CodeEditorPluginTests/SwiftUI/PerformanceObserverModifierTests.swift` (XCTest, matching `SwiftUIEnvironmentTests.swift`). Cases:

- `testEnvironmentWithMethodCarriesObservation` — round-trip the new `with(performanceObservation:)` builder on `CodeEditorEnvironment`; assert the field is set on the copy and unset on the original.
- `testCodeEditorPerformanceObservationEnvKey` — assign via `EnvironmentValues.codeEditorPerformanceObservation`; assert both the env-key getter and the underlying `codeEditorEnvironment.performanceObservation` reflect the value.
- `testMakeEffectiveConfigurationInjectsObservedSystem` — populate a `CodeEditorEnvironment` with `performanceObservation`; call `CodeEditor.makeEffectiveConfiguration(from:)`; assert `result.performance.unifiedPerformanceSystem === observation.system`.
- `testMakeEffectiveConfigurationNoObservationLeavesConfigUntouched` — populate the environment WITHOUT a `performanceObservation`; assert `result.performance.unifiedPerformanceSystem` equals whatever the env's configuration already had (`nil` for the default, or a host-set value if injected directly).
- `testMakeEffectiveConfigurationObservationWinsOverDirectConfigInjection` — pre-set `environment.configuration.performance.unifiedPerformanceSystem` to system A; set `environment.performanceObservation = PerformanceObservation(system: B)`; assert the result resolves to system B. Documents the "modifier wins" precedence noted under Risks.

## Risks & migration notes

- **Source-breaking change is sample-internal only.** No external host has `PerformanceObservation` today — adding it is strictly additive. The sample's `PerformanceSampleCoordinator.init` signature changes, but every caller is in-tree.
- **Two UPS injection paths persist post-merge.** Hosts can write `configuration.performance.unifiedPerformanceSystem = …` directly OR pass an observation through the modifier. We don't deprecate the field in this PR. If both are set, the modifier wins (it mutates `effectiveConfiguration` last). The follow-up cleanup pass can decide whether to gate the field.
- **Refresh-rate cost.** A `Task.sleep(for: .seconds(1))` loop adds zero load between ticks; the `generateInsights()` call itself walks the existing in-memory metric dictionaries and is O(n) in recorded metrics. Cheap.
- **`UnifiedPerformanceInsights` is not `Sendable` today.** The observation reads it on `@MainActor` and stores it on `@MainActor`; no cross-actor hops. If a future producer wants to call `refresh()` from a different isolation, marking `UnifiedPerformanceInsights` (and its members) `Sendable` is a separate small change.
