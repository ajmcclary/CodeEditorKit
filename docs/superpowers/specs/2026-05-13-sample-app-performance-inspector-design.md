# Sample App Performance Inspector — Design Spec

**Date:** 2026-05-13
**Status:** Design — ready for implementation plan
**Related:** `NEXT.md` "Performance HUD missing"; precedent: `docs/superpowers/specs/2026-05-13-sample-app-lsp-integration-design.md`

## Context

`CodeEditorSample` already wires up `sourcekit-lsp` end-to-end and surfaces it through `LSPInspectorPanel`. The framework also ships `PerformanceMonitor`, `MemoryMonitor`, `UnifiedPerformanceSystem`, `PerformanceInsights`, and `AdaptivePerformanceMode` — but none of them have a live view in the sample. The runtime behavior `NEXT.md` calls a "major selling point of the framework" is invisible to anyone reading the demo.

Exploration also surfaced a real bug behind the placeholder problem: `PerformanceInsights.currentFPS` is hardcoded to `60` and `cpuUsage` is `Double.random(in: 10...90)`. A Performance Inspector that "just surfaces what's there" would surface those placeholders verbatim, which is worse than not shipping the panel.

This spec covers the new sample-side panel **plus** the targeted framework changes needed for the metrics it displays to be real.

## Goals

1. Add a `PerformanceInspectorPanel` to the macOS sample's inspector sidebar, immediately below `LSPInspectorPanel`, demonstrating live framework runtime behavior.
2. Replace the two placeholder reads in `PerformanceInsights` (FPS and CPU) with real measurements.
3. Add a public `FrameRateMonitor` so any framework consumer — not just this sample — can read real FPS.
4. Instrument the syntax highlighter to feed `UnifiedPerformanceSystem` so the panel's `Last highlight` and `Highlight p95` numbers come from real measurements.
5. Mirror the established `LSPSampleCoordinator` ⇄ `LSPInspectorPanel` pattern so the next pass at NEXT.md (Event Log panel) has a second precedent to follow.

## Non-goals

- iOS feature parity. Whole feature is macOS-only via `#if canImport(AppKit)`, mirroring LSP. NEXT.md item 7 (iOS parity) remains a separate refactor.
- Splitting `AppState` into per-feature observable models. NEXT.md item 1 is a deferred refactor; the LSP work explicitly left `AppState` as a god object and this work follows that precedent. The coordinator is owned at the AppState level like LSP's.
- A user-facing on/off toggle. The `.onAppear` / `.onDisappear` lifecycle starts and stops monitoring; there is no in-panel switch (unlike LSP, where spawning a server is expensive).
- A manual adaptive-mode override picker. Considered and explicitly deferred — could be a follow-on demo if `AdaptivePerformanceMode` gains a public `setOverride(_:)`.
- Backward compatibility with macOS <26 / iOS <26. Targeting macOS 26+ / iOS 26+ only; no CVDisplayLink fallback path; no optional/default for the new `frameRateMonitor:` parameter on `PerformanceInsights`.

## Architecture

```
Sources/CodeEditorSample/
  App/
    AppState.swift                                   ← edit
    Performance/
      PerformanceSampleCoordinator.swift             ← new
  Sidebars/
    InspectorSidebar.swift                           ← edit
    PerformanceInspectorPanel.swift                  ← new

Sources/CodeEditorPlugin/
  Performance/
    FrameRateMonitor.swift                           ← new (public)
    PerformanceInsights.swift                        ← edit (placeholders → real)
    MemoryMonitor.swift                              ← edit (add resetPeak)
  Configuration/
    …PerformanceConfiguration…                       ← edit (add unifiedPerformanceSystem)
  Core/
    EditorController.swift                           ← edit (expose adaptivePerformanceMode)
  SyntaxHighlighting/
    <highlighter entry point>                        ← edit (wrap in ups.track)
```

### Ownership

- `AppState` owns one `MemoryMonitor` instance and passes the same instance to both `LSPSampleCoordinator` and `PerformanceSampleCoordinator`.
- `AppState` owns one `UnifiedPerformanceSystem` instance and installs it on `appState.configuration.performance.unifiedPerformanceSystem` so the framework's highlighter feeds the same instance the coordinator polls.
- `PerformanceSampleCoordinator` owns its `FrameRateMonitor` and `PerformanceInsights` instances; the latter is constructed with both monitors injected so its `currentFPS` and `cpuUsage` fields read real data.
- The editor's `AdaptivePerformanceMode` instance is owned by the framework's `CodeEditorView`; the coordinator captures a weak reference via `EditorController.adaptivePerformanceMode`.

## Components

### `PerformanceSampleCoordinator`

Sample-side `@MainActor @Observable final class`. Polling adapter: a 1Hz `Timer` snapshots each underlying monitor into an `@Observable` mirror so the SwiftUI panel binds to one consistent surface.

```swift
@MainActor
@Observable
public final class PerformanceSampleCoordinator {
    public enum State: Sendable { case stopped, live }

    // Observable surface
    public private(set) var state: State = .stopped
    public private(set) var fps: Int = 0
    public private(set) var memoryStats: MemoryStatistics
    public private(set) var pressure: MemoryPressureLevel = .normal
    public private(set) var adaptiveMode: PerformanceMode = .balanced
    public private(set) var lastHighlightMs: Double?
    public private(set) var highlightP95Ms: Double?
    public private(set) var healthScore: Double = 100
    public private(set) var issuesCount: Int = 0
    public private(set) var recommendationsCount: Int = 0
    public private(set) var memorySparkline: [Double] = []
    public let targetFPS: Int    // NSScreen.main?.maximumFramesPerSecond ?? 60, captured at init

    // Non-observable internals
    @ObservationIgnored private let memoryMonitor: MemoryMonitor
    @ObservationIgnored private let frameRateMonitor: FrameRateMonitor
    @ObservationIgnored private let unifiedPerformanceSystem: UnifiedPerformanceSystem
    @ObservationIgnored private let performanceInsights: PerformanceInsights
    @ObservationIgnored private weak var adaptivePerformanceMode: AdaptivePerformanceMode?
    @ObservationIgnored private var refreshTimer: Timer?

    public init(
        memoryMonitor: MemoryMonitor,
        unifiedPerformanceSystem: UnifiedPerformanceSystem
    )
    public func attach(controller: EditorController)
    public func start()         // idempotent
    public func stop()          // idempotent
    public func resetPeak()
}
```

Polling tick (1Hz):

```swift
private func refresh() {
    fps = frameRateMonitor.currentFPS
    memoryStats = memoryMonitor.memoryStats
    pressure = memoryMonitor.getMemoryPressure()
    if let adaptive = adaptivePerformanceMode { adaptiveMode = adaptive.currentMode }
    issuesCount = performanceInsights.issues.count
    recommendationsCount = performanceInsights.recommendations.count
    let insights = unifiedPerformanceSystem.generateInsights()
    if let h = insights.metricAnalyses[.syntaxHighlighting] {
        lastHighlightMs = h.averageDuration * 1000
        highlightP95Ms = h.p95Duration * 1000
    }
    healthScore = insights.overallHealth
    memorySparkline = Array(memoryStats.usageHistory.suffix(100))
}
```

Polling rather than per-monitor Combine subscriptions because the underlying monitors are a mix of `ObservableObject` and `@Observable`; one timer simplifies the bridging at a sub-second staleness cost that's invisible to the user.

### `PerformanceInspectorPanel`

Stateless SwiftUI view. Values come in via init params; no `@State` for data. Driven by the coordinator's observable mirror.

Layout (2-column tile grid, chosen during brainstorming):

```
┌────────────────────────────────────────────┐
│ Performance                       ● LIVE   │
├────────────────────────────────────────────┤
│ ✦ Adaptive: High Quality                   │
├────────────────────────────────────────────┤
│ ┌──────────┐  ┌──────────┐                 │
│ │ FPS      │  │ HEALTH   │                 │
│ │ 58       │  │ 82       │                 │
│ └──────────┘  └──────────┘                 │
│ ┌──────────┐  ┌──────────┐                 │
│ │ MEMORY   │  │ HIGHLIGHT│                 │
│ │ 145 MB ⟲│  │ 2.4 ms   │                 │
│ │ peak 210 │  │ p95 5.8  │                 │
│ │ avg 132  │  │          │                 │
│ └──────────┘  └──────────┘                 │
├────────────────────────────────────────────┤
│ Memory pressure              ● Normal      │
├────────────────────────────────────────────┤
│ Memory · last 100 samples                  │
│ [sparkline]                                │
├────────────────────────────────────────────┤
│ 0 issues · 0 recs              Report ›    │
└────────────────────────────────────────────┘
```

Sub-views: `header`, `adaptiveModeRow`, `tileGrid`, `pressureRow`, `sparkline`, `footer` — each a small `@ViewBuilder` computed property. A `MetricTile` helper view renders one cell with primary value, unit, secondary line, threshold-driven color, and optional trailing-icon action (the Memory tile's reset-peak `arrow.counterclockwise`).

Thresholds collected in one tunable struct:

```swift
public struct Thresholds: Sendable {
    public var fpsTarget: Int                       // coordinator passes its targetFPS
    public var fpsGreenRatio: Double = 0.92         // ≥55 @ 60Hz, ≥110 @ 120Hz
    public var fpsAmberRatio: Double = 0.50

    public var healthGreen: Double = 80
    public var healthAmber: Double = 50

    public var highlightGreenMs: Double = 16        // one 60Hz frame budget
    public var highlightAmberMs: Double = 100

    public static let `default` = Thresholds(fpsTarget: 60)
}
```

Report sheet: `onShowReport` opens the framework's existing public `DetailedPerformanceReportView` in a `.sheet`, passing a snapshot from `unifiedPerformanceSystem.generateInsights()` at open time. No new framework view.

### Framework changes

#### 1. `FrameRateMonitor.swift` — new public

```swift
@MainActor
@Observable
public final class FrameRateMonitor {
    public private(set) var currentFPS: Int = 0
    public private(set) var averageFPS: Double = 0

    public init() {}
    public func startMonitoring()
    public func stopMonitoring()
}
```

Single `CADisplayLink` path (macOS 26+ / iOS 26+). Maintains a 1-second sliding window of frame timestamps; `currentFPS = round(framesInLastSecond)`, `averageFPS = framesInLastSecond` (decimal). The FPS computation is extracted into a static testable function `Self.computeFPS(timestamps: [TimeInterval], window: TimeInterval) -> (current: Int, average: Double)` so unit tests don't need a real display link.

#### 2. `PerformanceInsights.swift` — placeholders → real

```swift
public init(
    memoryMonitor: MemoryMonitor,
    performanceMonitor: PerformanceMonitor? = nil,
    platformCapabilities: PlatformCapabilities = .current,
    frameRateMonitor: FrameRateMonitor       // NEW, required
)
```

Two replacements inside the 1Hz update loop:

- `metrics.currentFPS = 60` → `metrics.currentFPS = frameRateMonitor.currentFPS`
- `metrics.cpuUsage = Double.random(in: 10...90)` → `metrics.cpuUsage = Self.sampleCPUUsage()`

`sampleCPUUsage()` is a private static helper using `mach task_info(.taskBasicInfo)` plus `host_processor_info` to compute the process's CPU usage as a percentage, clamped to `[0, 100]`. On any mach failure: emit `reportIssue` once per session and return 0. Non-throwing — preserves the existing API surface.

#### 3. `EditorConfiguration` performance section

```swift
extension EditorConfiguration.PerformanceConfiguration {
    public var unifiedPerformanceSystem: UnifiedPerformanceSystem?  // default nil
}
```

`nil` means "no tracking" (the legitimate default for consumers who don't care). Mirrors the existing `memoryMonitor: MemoryMonitor?` DI pattern on the same struct.

#### 4. `EditorController.adaptivePerformanceMode`

Public read-only accessor exposing the existing internal `AdaptivePerformanceMode` instance on the underlying `CodeEditorView`. Returns the editor's instance — never a fresh one — so the coordinator and the editor observe the same state.

#### 5. Syntax highlighter instrumentation

The highlighter's main entry point (identified during planning) wraps its body in:

```swift
guard let ups = configuration.performance.unifiedPerformanceSystem else {
    return try await performHighlightPass(...)
}
return try await ups.track(.syntaxHighlighting) {
    try await performHighlightPass(...)
}
```

Zero behavior change when `unifiedPerformanceSystem` is `nil`. Tracking cost is per-pass, not per-line.

#### 6. `MemoryMonitor.resetPeak()`

```swift
public func resetPeak() {
    memoryStats.peakUsageMB = memoryStats.currentUsageMB
    memoryStats.usageHistory.removeAll(keepingCapacity: true)
}
```

Triggers `@Published`; the coordinator's next refresh picks it up.

## Data flow & lifecycle

```
[user opens inspector]
  ↓
InspectorSidebar mounts PerformanceInspectorPanel
  ↓
panel .onAppear → appState.performance.start()
  ↓
  ├─ memoryMonitor.startMonitoring()
  ├─ frameRateMonitor.startMonitoring()
  ├─ performanceInsights.startMonitoring()
  └─ refreshTimer (1Hz) → refresh() → coordinator's @Observable fields update
       ↓
       panel re-renders bound subviews

[user collapses inspector]
  ↓
panel .onDisappear → appState.performance.stop()
  ↓
  ├─ memoryMonitor.stopMonitoring()
  ├─ frameRateMonitor.stopMonitoring()
  ├─ performanceInsights.stopMonitoring()
  └─ refreshTimer invalidated
```

Independent of this: while the editor is doing work, the highlighter writes `.syntaxHighlighting` metrics into the shared `UnifiedPerformanceSystem` instance. Those land in `lastHighlightMs` / `highlightP95Ms` on the next refresh tick.

## Error handling

| Site | Failure mode | Response |
|---|---|---|
| `FrameRateMonitor.startMonitoring()` | `CADisplayLink` registration failure (vanishingly rare) | `reportIssue`; `currentFPS` stays 0 |
| `PerformanceInsights.sampleCPUUsage()` | mach call non-success | `reportIssue` once per session; return 0 |
| `MemoryMonitor.resetPeak()` | n/a — pure assignment | none |
| `ups.track(.syntaxHighlighting)` | re-throws the highlighter's own errors | pass through |
| `PerformanceSampleCoordinator.refresh()` | underlying calls are non-throwing | none |

No new `CodeEditorError` cases. No new throwing public API.

## Testing

### Framework tests — `Tests/CodeEditorPluginTests/Performance/`

| File | New/Edit | Cases |
|---|---|---|
| `FrameRateMonitorTests.swift` | new | starts at 0; `computeFPS(timestamps:window:)` correctness across edge cases (empty, single sample, exactly-window-boundary); `stopMonitoring` zeros and unregisters; `CI=1`-gated live test confirms a real `CADisplayLink` produces non-zero FPS within 2 s |
| `PerformanceInsightsTests.swift` | edit | `currentFPS` reflects injected `FrameRateMonitor`; `cpuUsage ∈ [0, 100]` and is not uniformly random; existing assertions about issues/recommendations still pass |
| `MemoryMonitorTests.swift` | edit | `resetPeak()` after a known peak → `peakUsageMB == currentUsageMB`; `usageHistory.isEmpty`; `@Published` notification fires once |
| `SyntaxHighlightingInstrumentationTests.swift` | new | With `config.performance.unifiedPerformanceSystem = ups`, one highlight pass produces exactly one `.syntaxHighlighting` metric in `ups.generateInsights()`. With `nil`, no metric is recorded. |

### Sample tests — `Tests/CodeEditorSampleTests/`

| File | New/Edit | Cases |
|---|---|---|
| `PerformanceSampleCoordinatorTests.swift` | new | initial state `.stopped`; `start()` transitions to `.live` and starts each injected monitor once; `start()` idempotent; `stop()` symmetric; `resetPeak()` calls through; `refresh()` populates all observable fields from injected mocks |
| `PerformanceInspectorPanelSnapshotTests.swift` | new, macOS-only | five distinct states via `pfw-snapshot-testing`: Stopped, Live·HighQuality·green, Live·Balanced·amberMemory, Live·Performance·redHighlight, Live·criticalPressure. 360-pt fixed width. `isRecording: true` for initial run; generated images committed. |

Mocks live in a small `PerformanceTestDoubles.swift`:

```swift
final class MockFrameRateMonitor: FrameRateMonitor { /* override currentFPS, never starts CADisplayLink */ }
extension MemoryMonitor {
    static func mock(currentUsageMB: Double, peakUsageMB: Double, isUnderPressure: Bool = false) -> MemoryMonitor
}
```

The `MemoryMonitor.mock(...)` factory is the established pattern per `CLAUDE.md` ("MemoryMonitor is final: tests should use `MemoryMonitor.mock(...)`"); we add overloads if the existing arity doesn't fit.

## SwiftLint / Swift 6 compliance

- Whole feature is `@MainActor`-isolated; no new `Sendable` violations expected.
- No `print()` (use `CrossPlatformLogger.logger()` if any logging is needed — none currently planned).
- No force unwraps.
- Platform guards via `#if canImport(AppKit)`, not `#if os(macOS)`.
- New extension files use `+Extensions` suffix where applicable.

## Wiring summary

`InspectorSidebar.swift` insert (between LSP and Annotations):

```swift
PerformanceInspectorPanel(
    state: appState.performance.state,
    fps: appState.performance.fps,
    memoryStats: appState.performance.memoryStats,
    pressure: appState.performance.pressure,
    adaptiveMode: appState.performance.adaptiveMode,
    lastHighlightMs: appState.performance.lastHighlightMs,
    highlightP95Ms: appState.performance.highlightP95Ms,
    healthScore: appState.performance.healthScore,
    issuesCount: appState.performance.issuesCount,
    recommendationsCount: appState.performance.recommendationsCount,
    memorySparkline: appState.performance.memorySparkline,
    thresholds: .init(fpsTarget: appState.performance.targetFPS),
    onResetPeak: { appState.performance.resetPeak() },
    onShowReport: { showingReport = true },
    onAppear: { appState.performance.start() },
    onDisappear: { appState.performance.stop() }
)
```

`AppState.init()` (macOS-only block). Today `MemoryMonitor()` is constructed inline as an argument to `LSPSampleCoordinator(memoryMonitor:)` at `AppState.swift:77`. This change lifts it out into a stored property so both coordinators share the same instance:

```swift
let memoryMonitor = MemoryMonitor()                         // was inline; now a stored let
let unifiedSystem = UnifiedPerformanceSystem()
configuration.performance.unifiedPerformanceSystem = unifiedSystem

let lspCoordinator = LSPSampleCoordinator(memoryMonitor: memoryMonitor)
let perfCoordinator = PerformanceSampleCoordinator(
    memoryMonitor: memoryMonitor,                           // same instance
    unifiedPerformanceSystem: unifiedSystem
)
perfCoordinator.attach(controller: editorController)

self.memoryMonitor = memoryMonitor
self.lsp = lspCoordinator
self.performance = perfCoordinator
```

## Out of scope (potential follow-ons)

- iOS inspector parity (NEXT.md item 7).
- Manual adaptive-mode override picker.
- Per-panel inspector toggles (today's all-or-nothing inspector remains).
- Splitting `AppState` into per-feature observable models (NEXT.md item 1).
- Issue/recommendation drilldown UI inside the panel (the existing footer link to `DetailedPerformanceReportView` covers this).
- An `EventLog` panel — the natural next step per NEXT.md; this spec is structured so the `LSPSampleCoordinator` ⇄ `PerformanceSampleCoordinator` pair forms a clear template for a third coordinator-and-panel.

## Reference

- Pattern precedent: `Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift`, `Sources/CodeEditorSample/Sidebars/LSPInspectorPanel.swift`
- Inspector mount point: `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift`
- Existing performance types: `Sources/CodeEditorPlugin/Performance/{PerformanceMonitor,MemoryMonitor,UnifiedPerformanceSystem,PerformanceInsights,AdaptivePerformanceMode}.swift`
- Existing reporting view to reuse: `Sources/CodeEditorPlugin/Performance/PerformanceViews.swift` (`DetailedPerformanceReportView`)
- Project conventions: `CLAUDE.md`
- Brainstorm session artifacts: `.superpowers/brainstorm/7946-1778698210/content/panel-layout.html`
