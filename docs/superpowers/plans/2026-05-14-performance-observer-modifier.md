# `.performanceObserver(_:)` SwiftUI Modifier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `.performanceObserver(_:)` SwiftUI modifier on `CodeEditor` that folds the two existing wirings of `UnifiedPerformanceSystem` (config injection so `AsyncSyntaxHighlighter` can record metrics, and host-side polling of `generateInsights()`) into a single call. Hosts construct a `PerformanceObservation`, attach it once, and read `lastInsights` from SwiftUI bodies.

**Architecture:** New `@MainActor @Observable public final class PerformanceObservation` wraps a `UnifiedPerformanceSystem` plus an internal `Task`-driven refresh loop. A new field on `CodeEditorEnvironment` carries the observation; a new static helper `CodeEditor.makeEffectiveConfiguration(from:)` overlays `observation.system` onto `configuration.performance.unifiedPerformanceSystem` so the existing `AsyncSyntaxHighlighter` producer keeps working untouched. The modifier itself is `extension View -> some View` to match the `.memoryMonitor(_:)` / `.eventSystem(_:)` precedent in the same file.

**Tech Stack:** Swift 6.3 strict concurrency, SwiftUI, Observation framework, Swift Testing (`@Suite` / `@Test`) for the observation tests, XCTest for the environment tests (matching `SwiftUIEnvironmentTests.swift`'s style).

**Spec:** `docs/superpowers/specs/2026-05-14-performance-observer-modifier-design.md` (commit `3f55ee7`).

**Deviation from spec:** Spec showed `extension CodeEditor` for the modifier signature, but the closest precedents in the same file (`memoryMonitor`, `eventSystem`) are `extension View` returning `some View`. This plan uses `extension View` so the modifier composes with view-typed modifiers higher in the chain (e.g., `CodeEditor(text:).codeLanguage(.swift).performanceObserver(obs)` works either order). REVIEW.md already flags modifier-return-type consistency as an open design issue; staying with the local precedent is the right call here.

---

## File Structure

**New files (3):**

- `Sources/CodeEditorPlugin/Performance/PerformanceObservation.swift` — the `@MainActor @Observable` wrapper type.
- `Tests/CodeEditorPluginTests/Performance/PerformanceObservationTests.swift` — Swift Testing suite for the wrapper's lifecycle, idempotency, and refresh behaviour.
- `Tests/CodeEditorPluginTests/SwiftUI/PerformanceObserverModifierTests.swift` — XCTest for the env-struct builder, env-key forwarder, and `makeEffectiveConfiguration` overlay.

**Modified files (5):**

- `Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift` — add `performanceObservation` field on `CodeEditorEnvironment`, the `with(...)` parameter, the legacy `codeEditorPerformanceObservation` env-key forwarder, and an overload on the `View.codeEditorEnvironment(...)` convenience modifier.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift` — add the `.performanceObserver(_:)` view modifier.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift` — add `static func makeEffectiveConfiguration(from:)` helper; call it from `body` and route the result through the representable + environment.
- `Sources/CodeEditorSample/App/Performance/PerformanceSampleCoordinator.swift` — accept `PerformanceObservation` instead of `UnifiedPerformanceSystem`; read `performanceObservation.lastInsights` in `refresh()` instead of polling `generateInsights()` itself.
- `Sources/CodeEditorSample/App/AppState.swift` — construct `PerformanceObservation` instead of a bare `UnifiedPerformanceSystem`; delete the direct config-injection line; pass observation into coordinator.
- `Sources/CodeEditorSample/App/WindowBody.swift` — add `.performanceObserver(appState.performanceObservation)` in `editorPane`.
- `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift` — start/stop the observation alongside `performance.start()` / `performance.stop()`.

(Total: 3 new + 7 modified = 10 files touched.)

---

## Task 1: `PerformanceObservation` — failing tests

**Files:**
- Create: `Tests/CodeEditorPluginTests/Performance/PerformanceObservationTests.swift`

- [ ] **Step 1: Write the failing test file**

```swift
//
//  PerformanceObservationTests.swift
//  CodeEditorPluginTests
//

import Testing
@testable import CodeEditorPlugin

@available(macOS 13.0, iOS 16.0, *)
@Suite("PerformanceObservation")
@MainActor
struct PerformanceObservationTests {
    @Test("init sets initial lastInsights to a zero-state snapshot")
    func initStartsWithZeroSnapshot() {
        let observation = PerformanceObservation(refreshInterval: .seconds(1))
        #expect(observation.lastInsights.metricAnalyses.isEmpty)
        #expect(observation.lastInsights.issues.isEmpty)
        #expect(observation.lastInsights.recommendations.isEmpty)
        #expect(observation.lastInsights.overallHealth == 100.0)
        #expect(observation.refreshCount == 0)
    }

    @Test("refresh updates lastInsights from tracked operations")
    func refreshUpdatesLastInsights() async throws {
        let observation = PerformanceObservation(refreshInterval: .seconds(1))
        await observation.system.track(.syntaxHighlighting) { /* no-op */ }
        observation.refresh()
        #expect(observation.lastInsights.metricAnalyses[.syntaxHighlighting]?.count == 1)
        #expect(observation.refreshCount == 1)
    }

    @Test("start is idempotent — second start does not spawn a parallel loop")
    func startIsIdempotent() async throws {
        let observation = PerformanceObservation(refreshInterval: .milliseconds(20))
        observation.start()
        observation.start()
        try await Task.sleep(for: .milliseconds(80))
        observation.stop()
        // A single 20ms loop over 80ms yields ~4 ticks. A doubled loop would
        // yield ~8. Allow generous slack (≤ 6) for scheduler jitter.
        #expect(observation.refreshCount <= 6)
        #expect(observation.refreshCount >= 1)
    }

    @Test("stop cancels the refresh task")
    func stopCancelsRefreshTask() async throws {
        let observation = PerformanceObservation(refreshInterval: .milliseconds(20))
        observation.start()
        try await Task.sleep(for: .milliseconds(80))
        let snapshot = observation.refreshCount
        observation.stop()
        try await Task.sleep(for: .milliseconds(80))
        #expect(observation.refreshCount == snapshot)
    }

    @Test("restart after stop resumes refresh ticks")
    func restartAfterStopResumes() async throws {
        let observation = PerformanceObservation(refreshInterval: .milliseconds(20))
        observation.start()
        try await Task.sleep(for: .milliseconds(40))
        observation.stop()
        let stopSnapshot = observation.refreshCount
        observation.start()
        try await Task.sleep(for: .milliseconds(80))
        observation.stop()
        #expect(observation.refreshCount > stopSnapshot)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter PerformanceObservationTests
```

Expected: build failure with `cannot find 'PerformanceObservation' in scope` (the type doesn't exist yet).

---

## Task 2: `PerformanceObservation` — minimal implementation

**Files:**
- Create: `Sources/CodeEditorPlugin/Performance/PerformanceObservation.swift`

- [ ] **Step 1: Create the file**

```swift
//
//  PerformanceObservation.swift
//  CodeEditorPlugin
//
//  Host-facing observable wrapper around `UnifiedPerformanceSystem`. Owns
//  an internal Task-driven refresh loop that periodically snapshots
//  `system.generateInsights()` into `lastInsights`. Designed to be paired
//  with the `.performanceObserver(_:)` modifier, which injects
//  `observation.system` into the editor's effective `EditorConfiguration`
//  so framework producers (e.g. `AsyncSyntaxHighlighter`) record metrics
//  into the same system the host observes.
//

import Foundation
import Observation

@available(macOS 13.0, iOS 16.0, *)
@MainActor
@Observable
public final class PerformanceObservation {
    /// The underlying performance system. `let` so hosts can call
    /// `system.track(...)` directly for custom producers.
    public let system: UnifiedPerformanceSystem

    /// Most recent snapshot from `system.generateInsights()`. Updated by
    /// the internal refresh loop while `start()`ed, or by direct
    /// `refresh()` calls from outside the loop.
    public private(set) var lastInsights: UnifiedPerformanceInsights

    /// Interval between refreshes. Mutating after `start()` takes effect
    /// on the next sleep boundary (the in-flight `Task.sleep` finishes
    /// first, then the loop reads the new value).
    public var refreshInterval: Duration

    /// Test/debug probe: counts every successful `refresh()` invocation
    /// (whether driven by the internal loop or called externally).
    internal private(set) var refreshCount: Int = 0

    /// `nonisolated(unsafe)` so `deinit` (which runs in a nonisolated
    /// context) can cancel it. Writes happen only from `@MainActor`
    /// (`start` / `stop`); the deinit read happens-after the last
    /// `@MainActor` reference is released. Mirrors the pattern in
    /// `MemoryMonitor.monitoringTask`.
    nonisolated(unsafe) private var refreshTask: Task<Void, Never>?

    public init(
        system: UnifiedPerformanceSystem = UnifiedPerformanceSystem(),
        refreshInterval: Duration = .seconds(1)
    ) {
        self.system = system
        self.refreshInterval = refreshInterval
        self.lastInsights = UnifiedPerformanceInsights()
    }

    deinit {
        refreshTask?.cancel()
    }

    /// Starts the refresh loop. Idempotent — calling while running is a
    /// no-op. The loop runs at `refreshInterval` cadence; mutating
    /// `refreshInterval` takes effect on the next iteration.
    public func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let interval = await self?.refreshInterval else { return }
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }
                await self?.refresh()
            }
        }
    }

    /// Cancels the refresh loop. Idempotent.
    public func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// One-shot snapshot: reads `system.generateInsights()` and updates
    /// `lastInsights`. Safe to call from outside the refresh loop.
    public func refresh() {
        lastInsights = system.generateInsights()
        refreshCount += 1
    }
}
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
swift test --filter PerformanceObservationTests
```

Expected: all 5 tests pass.

- [ ] **Step 3: Run SwiftLint**

```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorPlugin/Performance/PerformanceObservation.swift \
        Tests/CodeEditorPluginTests/Performance/PerformanceObservationTests.swift
git commit -m "$(cat <<'EOF'
PerformanceObservation: @Observable wrapper around UnifiedPerformanceSystem

Refresh loop driven by an internal Task at configurable cadence; idempotent
start/stop; deinit cancels via the nonisolated(unsafe) pattern from
MemoryMonitor. Five Swift-Testing cases cover zero-state init, refresh
semantics, start idempotency, stop cancellation, and restart-after-stop.
EOF
)"
```

---

## Task 3: Extend `CodeEditorEnvironment` with `performanceObservation` — failing tests

**Files:**
- Modify: `Tests/CodeEditorPluginTests/SwiftUIEnvironmentTests.swift`

- [ ] **Step 1: Read the existing test file to find the insertion point**

```bash
grep -n "testCodeEditorEnvironmentDefaults\|testCodeEditorEnvironmentWithMethod\|testCodeEditorPerformanceObservation" Tests/CodeEditorPluginTests/SwiftUIEnvironmentTests.swift
```

Locate the existing `testCodeEditorEnvironmentDefaults` test (line ~10) and the convenience-modifier test (line ~180); add new tests immediately after `testCodeEditorEnvironmentWithMethod`.

- [ ] **Step 2: Add failing tests**

Append the following inside the existing `XCTestCase` class, immediately after the `testCodeEditorEnvironmentWithMethod` method:

```swift
    @MainActor
    func testCodeEditorEnvironmentCarriesPerformanceObservation() {
        let env = CodeEditorEnvironment()
        XCTAssertNil(env.performanceObservation)

        let observation = PerformanceObservation()
        let updated = env.with(performanceObservation: observation)

        XCTAssertIdentical(updated.performanceObservation, observation)
        // Original is unchanged.
        XCTAssertNil(env.performanceObservation)
    }

    @MainActor
    func testCodeEditorPerformanceObservationEnvKeyRoundTrips() {
        var values = EnvironmentValues()
        XCTAssertNil(values.codeEditorPerformanceObservation)

        let observation = PerformanceObservation()
        values.codeEditorPerformanceObservation = observation

        XCTAssertIdentical(values.codeEditorEnvironment.performanceObservation, observation)
        XCTAssertIdentical(values.codeEditorPerformanceObservation, observation)
    }
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
swift test --filter SwiftUIEnvironmentTests
```

Expected: build failure — `CodeEditorEnvironment` has no `performanceObservation` member; `EnvironmentValues` has no `codeEditorPerformanceObservation`; `with(performanceObservation:)` does not exist.

---

## Task 4: Extend `CodeEditorEnvironment` — implementation

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift`

- [ ] **Step 1: Add the `performanceObservation` field on `CodeEditorEnvironment`**

In `CodeEditorEnvironment+Extensions.swift`, add a new stored property immediately after the existing `runtimeDependencies` property (current line 48):

```swift
    /// Optional performance observation. When set, the editor's effective
    /// configuration receives `observation.system` as its
    /// `performance.unifiedPerformanceSystem`, so framework producers
    /// (e.g. AsyncSyntaxHighlighter) record metrics into the system the
    /// host observes. Paired with the `.performanceObserver(_:)` modifier.
    public var performanceObservation: PerformanceObservation?
```

- [ ] **Step 2: Add the init parameter**

Update the `public init(...)` (currently lines 51-69) to accept `performanceObservation`:

```swift
    public init(
        language: Language = .plainText,
        theme: Theme = .default,
        configuration: EditorConfiguration = EditorConfiguration(),
        becomeFirstResponder: Bool = false,
        workspaceRoot: URL? = nil,
        memoryMonitor: MemoryMonitor? = nil,
        eventSystem: UnifiedEventSystem? = nil,
        runtimeDependencies: EditorRuntimeDependencies? = nil,
        performanceObservation: PerformanceObservation? = nil
    ) {
        self.language = language
        self.theme = theme
        self.configuration = configuration
        self.becomeFirstResponder = becomeFirstResponder
        self.workspaceRoot = workspaceRoot
        self.memoryMonitor = memoryMonitor
        self.eventSystem = eventSystem
        self.runtimeDependencies = runtimeDependencies
        self.performanceObservation = performanceObservation
    }
```

- [ ] **Step 3: Add the `with(...)` parameter**

Update the `public func with(...)` builder (currently lines 75-95) to accept and propagate `performanceObservation`:

```swift
    public func with(
        language: Language? = nil,
        theme: Theme? = nil,
        configuration: EditorConfiguration? = nil,
        becomeFirstResponder: BecomeFirstResponderOption = .unchanged,
        workspaceRoot: URL? = nil,
        memoryMonitor: MemoryMonitor? = nil,
        eventSystem: UnifiedEventSystem? = nil,
        runtimeDependencies: EditorRuntimeDependencies? = nil,
        performanceObservation: PerformanceObservation? = nil
    ) -> Self {
        Self(
            language: language ?? self.language,
            theme: theme ?? self.theme,
            configuration: configuration ?? self.configuration,
            becomeFirstResponder: becomeFirstResponder == .unchanged ? self.becomeFirstResponder : (becomeFirstResponder == .yes),
            workspaceRoot: workspaceRoot ?? self.workspaceRoot,
            memoryMonitor: memoryMonitor ?? self.memoryMonitor,
            eventSystem: eventSystem ?? self.eventSystem,
            runtimeDependencies: runtimeDependencies ?? self.runtimeDependencies,
            performanceObservation: performanceObservation ?? self.performanceObservation
        )
    }
```

- [ ] **Step 4: Add the legacy env-key forwarder**

In the `extension EnvironmentValues` block (currently lines 109-166), add a new computed property immediately after `codeEditorEventSystem` (line 150-153):

```swift
    /// Legacy: Access the performance observation directly
    public var codeEditorPerformanceObservation: PerformanceObservation? {
        get { codeEditorEnvironment.performanceObservation }
        set { codeEditorEnvironment = codeEditorEnvironment.with(performanceObservation: newValue) }
    }
```

- [ ] **Step 5: Update the convenience `View.codeEditorEnvironment(...)` modifier**

Add `performanceObservation` to the parameter list and the inner `env.with(...)` call (currently lines 185-207):

```swift
    public func codeEditorEnvironment(
        language: Language? = nil,
        theme: Theme? = nil,
        configuration: EditorConfiguration? = nil,
        becomeFirstResponder: BecomeFirstResponderOption = .unchanged,
        workspaceRoot: URL? = nil,
        memoryMonitor: MemoryMonitor? = nil,
        eventSystem: UnifiedEventSystem? = nil,
        runtimeDependencies: EditorRuntimeDependencies? = nil,
        performanceObservation: PerformanceObservation? = nil
    ) -> some View {
        transformEnvironment(\.codeEditorEnvironment) { env in
            env = env.with(
                language: language,
                theme: theme,
                configuration: configuration,
                becomeFirstResponder: becomeFirstResponder,
                workspaceRoot: workspaceRoot,
                memoryMonitor: memoryMonitor,
                eventSystem: eventSystem,
                runtimeDependencies: runtimeDependencies,
                performanceObservation: performanceObservation
            )
        }
    }
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
swift test --filter SwiftUIEnvironmentTests
```

Expected: all `SwiftUIEnvironmentTests` pass, including the two new tests from Task 3.

- [ ] **Step 7: Run SwiftLint**

```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 8: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift \
        Tests/CodeEditorPluginTests/SwiftUIEnvironmentTests.swift
git commit -m "$(cat <<'EOF'
CodeEditorEnvironment: carry PerformanceObservation through env + env key

Adds `performanceObservation` to the env struct (field, init param,
`with(...)` builder), the legacy `codeEditorPerformanceObservation`
EnvironmentValues forwarder, and threads it through the bulk
`View.codeEditorEnvironment(...)` modifier. Two new env tests cover the
round-trip via the struct and via the env key.
EOF
)"
```

---

## Task 5: `makeEffectiveConfiguration` + `.performanceObserver` modifier — failing tests

**Files:**
- Create: `Tests/CodeEditorPluginTests/SwiftUI/PerformanceObserverModifierTests.swift`

- [ ] **Step 1: Create the failing test file**

```swift
//
//  PerformanceObserverModifierTests.swift
//  CodeEditorPluginTests
//

import XCTest
import SwiftUI
@testable import CodeEditorPlugin

@available(macOS 13.0, iOS 16.0, *)
final class PerformanceObserverModifierTests: XCTestCase {
    @MainActor
    func testMakeEffectiveConfigurationInjectsObservedSystem() {
        let observation = PerformanceObservation()
        let env = CodeEditorEnvironment(performanceObservation: observation)

        let effective = CodeEditor.makeEffectiveConfiguration(from: env)

        XCTAssertTrue(
            effective.performance.unifiedPerformanceSystem === observation.system,
            "Observation system should be injected into the effective configuration."
        )
    }

    @MainActor
    func testMakeEffectiveConfigurationNoObservationLeavesConfigUntouched() {
        let env = CodeEditorEnvironment()
        let effective = CodeEditor.makeEffectiveConfiguration(from: env)
        XCTAssertNil(effective.performance.unifiedPerformanceSystem)
    }

    @MainActor
    func testMakeEffectiveConfigurationObservationWinsOverDirectConfigInjection() {
        let systemA = UnifiedPerformanceSystem()
        var configuration = EditorConfiguration()
        configuration.performance.unifiedPerformanceSystem = systemA

        let observation = PerformanceObservation(system: UnifiedPerformanceSystem())
        let env = CodeEditorEnvironment(
            configuration: configuration,
            performanceObservation: observation
        )

        let effective = CodeEditor.makeEffectiveConfiguration(from: env)

        XCTAssertTrue(
            effective.performance.unifiedPerformanceSystem === observation.system,
            "Modifier-supplied observation should win over direct config injection."
        )
        XCTAssertFalse(
            effective.performance.unifiedPerformanceSystem === systemA,
            "Direct config injection should be overridden when an observation is present."
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter PerformanceObserverModifierTests
```

Expected: build failure — `CodeEditor` has no static method `makeEffectiveConfiguration(from:)`.

---

## Task 6: `makeEffectiveConfiguration` + `.performanceObserver` modifier — implementation

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift`
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift`

- [ ] **Step 1: Add the static helper to `CodeEditor`**

In `CodeEditor.swift`, immediately before the `// MARK: - Body` comment (current line 281), add:

```swift
    // MARK: - Configuration overlay

    /// Produces the configuration value `body` actually passes downstream,
    /// after overlaying environment-driven knobs that are wired through
    /// SwiftUI modifiers rather than the configuration struct directly.
    ///
    /// Currently overlays:
    /// - `performanceObservation.system` →
    ///   `performance.unifiedPerformanceSystem` (so framework producers
    ///   like `AsyncSyntaxHighlighter` record into the same system the
    ///   host observes via `.performanceObserver(_:)`).
    ///
    /// Extracted as a `static` helper so it's unit-testable without
    /// rendering the view.
    static func makeEffectiveConfiguration(
        from environment: CodeEditorEnvironment
    ) -> EditorConfiguration {
        var configuration = environment.configuration
        if let observation = environment.performanceObservation {
            configuration.performance.unifiedPerformanceSystem = observation.system
        }
        return configuration
    }
```

- [ ] **Step 2: Call the helper from `body`**

In `CodeEditor.swift`, in the `public var body: some View` block, replace the existing block (current lines 287-308):

```swift
        var effectiveRuntimeDependencies: EditorRuntimeDependencies
        if let provided = environment.runtimeDependencies {
            effectiveRuntimeDependencies = provided
            if let memoryMonitor = environment.memoryMonitor {
                effectiveRuntimeDependencies.memoryMonitor = memoryMonitor
            }
        } else {
            // Reuse cached components (MemoryMonitor, ActorCoordinator, etc.)
            // and overlay the per-render env knobs onto a local copy.
            effectiveRuntimeDependencies = fallbackRuntimeDependencies
            effectiveRuntimeDependencies.workspaceRoot = environment.workspaceRoot
            effectiveRuntimeDependencies.eventSystem = environment.eventSystem
            if let memoryMonitor = environment.memoryMonitor {
                effectiveRuntimeDependencies.memoryMonitor = memoryMonitor
            } else {
                effectiveRuntimeDependencies.memoryMonitor = defaultMemoryMonitor
            }
        }

        // Use configuration's debounce interval when no explicit override was passed.
        let effectiveDebounceInterval = textDebounceInterval
            ?? environment.configuration.performance.textChangeDebounceInterval
```

with:

```swift
        var effectiveRuntimeDependencies: EditorRuntimeDependencies
        if let provided = environment.runtimeDependencies {
            effectiveRuntimeDependencies = provided
            if let memoryMonitor = environment.memoryMonitor {
                effectiveRuntimeDependencies.memoryMonitor = memoryMonitor
            }
        } else {
            // Reuse cached components (MemoryMonitor, ActorCoordinator, etc.)
            // and overlay the per-render env knobs onto a local copy.
            effectiveRuntimeDependencies = fallbackRuntimeDependencies
            effectiveRuntimeDependencies.workspaceRoot = environment.workspaceRoot
            effectiveRuntimeDependencies.eventSystem = environment.eventSystem
            if let memoryMonitor = environment.memoryMonitor {
                effectiveRuntimeDependencies.memoryMonitor = memoryMonitor
            } else {
                effectiveRuntimeDependencies.memoryMonitor = defaultMemoryMonitor
            }
        }

        // Overlay env-driven knobs onto a local copy of configuration.
        // Currently: performanceObservation → performance.unifiedPerformanceSystem.
        let effectiveConfiguration = Self.makeEffectiveConfiguration(from: environment)

        // Use configuration's debounce interval when no explicit override was passed.
        let effectiveDebounceInterval = textDebounceInterval
            ?? effectiveConfiguration.performance.textChangeDebounceInterval
```

- [ ] **Step 3: Route `effectiveConfiguration` through the representable + environment**

In the same `body` block, replace `configuration: environment.configuration` in the `CodeEditorRepresentable(...)` initializer (current line 314) and `.environment(\.codeEditorConfiguration, environment.configuration)` (current line 330):

```swift
        return CodeEditorRepresentable(
            text: $text,  // Pass the binding directly
            language: effectiveLanguage,
            theme: effectiveTheme,
            configuration: effectiveConfiguration,
            runtimeDependencies: effectiveRuntimeDependencies,
            textDebounceInterval: effectiveDebounceInterval,
            interactionState: interactionState,
            editorController: editorController,
            hostEditorState: hostEditorState,
            onTextChange: handleTextChange,
            onSelectionChange: handleSelectionChange
        )
        // ... (existing comments)
        .environment(\.codeEditorLanguage, effectiveLanguage)
        .environment(\.codeEditorTheme, effectiveTheme)
        .environment(\.codeEditorConfiguration, effectiveConfiguration)
        .environment(\.editorEventBus, editorController?.editorEventBus)
        // ... (existing .onAppear / .onDisappear unchanged)
```

- [ ] **Step 4: Add the `.performanceObserver(_:)` modifier**

In `CodeEditor+ModifiersExtensions.swift`, immediately after the existing `eventSystem(_:)` modifier (current line 548-550), add:

```swift
    /// Wires a `PerformanceObservation` into the editor's effective
    /// configuration AND the SwiftUI environment in a single call.
    ///
    /// The observation's `UnifiedPerformanceSystem` is installed onto
    /// `configuration.performance.unifiedPerformanceSystem` so framework
    /// producers (e.g. `AsyncSyntaxHighlighter`) record metrics into it,
    /// and the observation's `lastInsights` property is the canonical
    /// place to read snapshots from a SwiftUI body.
    ///
    /// Lifecycle (`start()` / `stop()`) stays with the host — the
    /// modifier does not auto-start the refresh loop because the same
    /// observation may be shared across multiple editors and constructed
    /// before any editor is on screen.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @State private var observation = PerformanceObservation()
    ///
    /// var body: some View {
    ///     CodeEditor(text: $code)
    ///         .performanceObserver(observation)
    ///     Text("Health: \(observation.lastInsights.overallHealth, format: .number)")
    /// }
    /// ```
    ///
    /// - Parameter observation: The performance observation to wire.
    /// - Returns: A view with the observation installed in the editor environment.
    public func performanceObserver(_ observation: PerformanceObservation) -> some View {
        environment(\.codeEditorPerformanceObservation, observation)
    }
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
swift test --filter PerformanceObserverModifierTests
```

Expected: all 3 tests pass.

- [ ] **Step 6: Run the broader test suite for regressions in the SwiftUI surface**

```bash
swift test --filter "SwiftUI|CodeEditorView|Coordinator"
```

Expected: no new failures.

- [ ] **Step 7: Run SwiftLint**

```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 8: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift \
        Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift \
        Tests/CodeEditorPluginTests/SwiftUI/PerformanceObserverModifierTests.swift
git commit -m "$(cat <<'EOF'
CodeEditor: .performanceObserver(_:) modifier + effective-config overlay

Adds View.performanceObserver(_:) that writes a PerformanceObservation
into the editor environment. CodeEditor.body now overlays the
observation's UnifiedPerformanceSystem onto a local copy of the
configuration via a new static `makeEffectiveConfiguration(from:)`
helper, so the existing AsyncSyntaxHighlighter producer reads the
host-observed system unchanged. Modifier-supplied observation wins over
direct `configuration.performance.unifiedPerformanceSystem` writes,
documented in the test suite.
EOF
)"
```

---

## Task 7: Sample — `PerformanceSampleCoordinator` accepts `PerformanceObservation`

**Files:**
- Modify: `Sources/CodeEditorSample/App/Performance/PerformanceSampleCoordinator.swift`

- [ ] **Step 1: Change the init parameter type**

Replace the existing stored property (current line 41-42):

```swift
    @ObservationIgnored
    private let unifiedPerformanceSystem: UnifiedPerformanceSystem
```

with:

```swift
    @ObservationIgnored
    private let performanceObservation: PerformanceObservation
```

- [ ] **Step 2: Update the `init(...)` signature**

Replace the existing init (current line 53-67):

```swift
    init(
        memoryMonitor: MemoryMonitor,
        unifiedPerformanceSystem: UnifiedPerformanceSystem
    ) {
        let frames = FrameRateMonitor()
        self.memoryMonitor = memoryMonitor
        self.frameRateMonitor = frames
        self.unifiedPerformanceSystem = unifiedPerformanceSystem
        self.performanceInsights = PerformanceInsights(
            memoryMonitor: memoryMonitor,
            frameRateMonitor: frames
        )
        self.memoryStats = memoryMonitor.memoryStats
        self.targetFPS = NSScreen.main?.maximumFramesPerSecond ?? 60
    }
```

with:

```swift
    init(
        memoryMonitor: MemoryMonitor,
        performanceObservation: PerformanceObservation
    ) {
        let frames = FrameRateMonitor()
        self.memoryMonitor = memoryMonitor
        self.frameRateMonitor = frames
        self.performanceObservation = performanceObservation
        self.performanceInsights = PerformanceInsights(
            memoryMonitor: memoryMonitor,
            frameRateMonitor: frames
        )
        self.memoryStats = memoryMonitor.memoryStats
        self.targetFPS = NSScreen.main?.maximumFramesPerSecond ?? 60
    }
```

- [ ] **Step 3: Replace the `generateInsights()` call in `refresh()` with a `lastInsights` read**

In `refresh()` (current line 102-118), replace:

```swift
        let insights = unifiedPerformanceSystem.generateInsights()
        if let highlight = insights.metricAnalyses[.syntaxHighlighting] {
            lastHighlightMs = highlight.averageDuration * 1_000
            highlightP95Ms = highlight.p95Duration * 1_000
        }
        healthScore = insights.overallHealth
```

with:

```swift
        let insights = performanceObservation.lastInsights
        if let highlight = insights.metricAnalyses[.syntaxHighlighting] {
            lastHighlightMs = highlight.averageDuration * 1_000
            highlightP95Ms = highlight.p95Duration * 1_000
        }
        healthScore = insights.overallHealth
```

- [ ] **Step 4: Build the sample to verify the migration**

```bash
swift build --target CodeEditorSample
```

Expected: build failure in `AppState.swift` (caller passes a `UnifiedPerformanceSystem`, not a `PerformanceObservation` — that gets fixed in Task 8). Verify the failure is at the call site, not inside `PerformanceSampleCoordinator` itself.

---

## Task 8: Sample — `AppState` constructs `PerformanceObservation`

**Files:**
- Modify: `Sources/CodeEditorSample/App/AppState.swift`

- [ ] **Step 1: Replace the UPS stored property with a `PerformanceObservation`**

In `AppState.swift`, replace the existing block (current lines 66-70):

```swift
    /// Shared `UnifiedPerformanceSystem` instance: installed on
    /// `configuration.performance.unifiedPerformanceSystem` so the framework's
    /// syntax highlighter records into it, and polled by `performance` for
    /// the `Last highlight` / `Highlight p95` panel readouts.
    let unifiedPerformanceSystem = UnifiedPerformanceSystem()
```

with:

```swift
    /// Shared `PerformanceObservation` instance. Installed onto the
    /// editor view via `.performanceObserver(_:)` (which wires its
    /// underlying `UnifiedPerformanceSystem` into the framework's
    /// effective configuration AND surfaces refresh snapshots through
    /// `lastInsights`). The sample's `performance` coordinator reads
    /// snapshots from `performanceObservation.lastInsights` rather than
    /// polling `generateInsights()` directly.
    let performanceObservation = PerformanceObservation(refreshInterval: .seconds(1))
```

- [ ] **Step 2: Pass the observation into the coordinator**

In `init()`, replace the `PerformanceSampleCoordinator(...)` construction (current lines 122-125):

```swift
        let perfCoordinator = PerformanceSampleCoordinator(
            memoryMonitor: memoryMonitor,
            unifiedPerformanceSystem: unifiedPerformanceSystem
        )
```

with:

```swift
        let perfCoordinator = PerformanceSampleCoordinator(
            memoryMonitor: memoryMonitor,
            performanceObservation: performanceObservation
        )
```

- [ ] **Step 3: Delete the direct config-injection line**

Delete the line (current line 135):

```swift
        self.configuration.performance.unifiedPerformanceSystem = unifiedPerformanceSystem
```

The `.performanceObserver(_:)` modifier (added to `WindowBody.editorPane` in Task 9) now owns this injection.

- [ ] **Step 4: Build the sample**

```bash
swift build --target CodeEditorSample
```

Expected: build succeeds. The earlier `AppState`-level failure from Task 7 is resolved.

---

## Task 9: Sample — wire `.performanceObserver` in `WindowBody.editorPane`

**Files:**
- Modify: `Sources/CodeEditorSample/App/WindowBody.swift`

- [ ] **Step 1: Add the modifier to `editorPane`**

In `WindowBody.swift`, locate `editorPane` (line 45). Add `.performanceObserver(appState.performanceObservation)` immediately after `.becomeFirstResponder()` (current line 66) and before the macOS-only `.onTextHover` block (current line 67-82):

```swift
                .becomeFirstResponder()
                .performanceObserver(appState.performanceObservation)
                #if canImport(AppKit)
                .onTextHover { position in
```

- [ ] **Step 2: Build the sample**

```bash
swift build --target CodeEditorSample
```

Expected: success.

---

## Task 10: Sample — start/stop observation alongside `performance` coordinator

**Files:**
- Modify: `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift`

- [ ] **Step 1: Locate the `start` / `stop` hooks**

The existing call sites are at `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift:71-72`:

```swift
            onAppear: { appState.performance.start() },
            onDisappear: { appState.performance.stop() }
```

- [ ] **Step 2: Add observation start/stop alongside**

Replace those two lines with:

```swift
            onAppear: {
                appState.performance.start()
                appState.performanceObservation.start()
            },
            onDisappear: {
                appState.performance.stop()
                appState.performanceObservation.stop()
            }
```

This pairing ensures the framework-side refresh loop only runs while the inspector panel is visible — matching the existing sample's lifecycle model (FPS / memory monitors also bind to inspector visibility, not app lifetime).

- [ ] **Step 3: Build the sample**

```bash
swift build --target CodeEditorSample
```

Expected: success.

- [ ] **Step 4: Run the sample manually for a smoke test**

```bash
./Scripts/run-sample.sh debug
```

In the running app: open a Swift file (or any tab), open the Performance inspector, type into the editor for a few seconds. Confirm:

- `Last highlight` and `Highlight p95` rows show non-zero values (proves the modifier's config injection reached `AsyncSyntaxHighlighter`).
- The values update over time (proves the observation's refresh loop is running while the inspector is visible).
- Closing the inspector and re-opening it: values continue to update (proves `restart-after-stop`).

Kill any stale `CodeEditorSample` / `lldb` processes after the smoke test per the project's process-hygiene convention.

- [ ] **Step 5: Commit sample changes**

```bash
git add Sources/CodeEditorSample/App/Performance/PerformanceSampleCoordinator.swift \
        Sources/CodeEditorSample/App/AppState.swift \
        Sources/CodeEditorSample/App/WindowBody.swift \
        Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift
git commit -m "$(cat <<'EOF'
CodeEditorSample: migrate to .performanceObserver(_:)

PerformanceSampleCoordinator takes a PerformanceObservation instead of a
bare UnifiedPerformanceSystem and reads from observation.lastInsights
instead of polling generateInsights() itself. AppState constructs the
observation directly (no more direct configuration mutation in init).
WindowBody.editorPane attaches the observation via the new modifier;
InspectorSidebar's onAppear/onDisappear pair start/stop the framework
refresh loop alongside the sample coordinator's own lifecycle.
EOF
)"
```

---

## Task 11: Final verification

**Files:** None modified.

- [ ] **Step 1: Run the full project pipeline**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Expected:
- Build: green (both `CodeEditorPlugin` and `CodeEditorSample`).
- SwiftLint: 0 violations.
- Tests: no new failures. Pre-existing failures (`EditorStatusBarSnapshots` parallel SIGSEGV/SIGBUS, `AnnotationTests.testAnnotationTextKit2Integration` — already skipped in tree, `RegexRangeHighlightProviderTests.testParsePerformance10K/100KLines` flakiness, `PerformanceInsightsRealMetricsTests.currentFPSReflectsInjectedMonitor`, `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap`) reproduce on bare `main` per REVIEW.md status section and are out of scope.

- [ ] **Step 2: Update REVIEW.md**

Edit `REVIEW.md` to mark item #7 (`UnifiedPerformanceSystem` dual wiring) as ✅ Done, with a one-paragraph batch summary including:

- The new public type (`PerformanceObservation`) and modifier (`.performanceObserver(_:)`).
- The `makeEffectiveConfiguration(from:)` helper extraction (testability win).
- File touch count.
- "What's left after this round" section: cross off the bullet point referencing this item.

The exact prose pattern is established by the existing batch sections in REVIEW.md (e.g., "Editor lifecycle + EditorState mirror batch" or "SwiftUI hot path + env hygiene batch"). Match that template.

- [ ] **Step 3: Commit REVIEW.md update**

```bash
git add REVIEW.md
git commit -m "$(cat <<'EOF'
REVIEW.md: .performanceObserver(_:) modifier landed

Closes sample-driven API gap #7. The UnifiedPerformanceSystem dual
wiring is now folded into a single modifier backed by a new
@Observable PerformanceObservation type.
EOF
)"
```

---

## Notes

- **No new excludes in `Package.swift`.** Swift Package Manager auto-discovers files in test targets; the new `Tests/CodeEditorPluginTests/Performance/` subdirectory just works.
- **Deinit safety net.** `PerformanceObservation.deinit` cancels via the same `nonisolated(unsafe) private var refreshTask: Task<Void, Never>?` pattern `MemoryMonitor.monitoringTask` already uses (`Sources/CodeEditorPlugin/Performance/MemoryMonitor.swift:214-220, 260-266`). The invariant: writes happen only from `@MainActor` (`start()` / `stop()`); deinit reads only after all `@MainActor` references are released, so the read happens-after the last write.
- **Two UPS injection paths persist post-merge.** Hosts can still write `configuration.performance.unifiedPerformanceSystem = …` directly. If they also pass `.performanceObserver(...)`, the modifier wins (`makeEffectiveConfiguration` writes to a local copy after the host's mutation). This is covered by `testMakeEffectiveConfigurationObservationWinsOverDirectConfigInjection` (Task 5).
- **No changes to `AsyncSyntaxHighlighter`** — it keeps reading `textView.configuration.performance.unifiedPerformanceSystem` and now sees the modifier-supplied system when one is attached.
