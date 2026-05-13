# Sample App Performance Inspector — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a live Performance Inspector panel to `CodeEditorSample`'s inspector sidebar that mirrors the `LSPInspectorPanel` pattern and surfaces real (not placeholder) FPS, memory, syntax-highlight times, and adaptive-mode state.

**Architecture:** A sample-side `@MainActor @Observable PerformanceSampleCoordinator` polls real framework monitors at 1Hz and exposes a single observable surface for a stateless `PerformanceInspectorPanel` view rendered in a 2-column tile grid. Six targeted framework changes (new `FrameRateMonitor`, two `PerformanceInsights` placeholder fixes, one `MemoryMonitor.resetPeak()`, one `EditorConfiguration.Performance` field, one `EditorController` accessor, one `AsyncSyntaxHighlighter` instrumentation site) make the metrics real. macOS-only via `#if canImport(AppKit)`.

**Tech Stack:** Swift 6.3 (StrictConcurrency), SwiftUI, Swift Testing (`@Suite`/`@Test`), CADisplayLink, `swift-snapshot-testing`. macOS 26.3+ / iOS 26.3+ already declared in `Package.swift`.

**Spec:** `docs/superpowers/specs/2026-05-13-sample-app-performance-inspector-design.md` (commit `85c23cd`).

---

## Working agreements

- After **every** task, run the project quality gate: `swift build && swiftlint --fix && swiftlint && swift test --parallel`. If anything fails, fix it in the same task before committing.
- Never use `print()` — use `CrossPlatformLogger.logger()` if logging is needed (none planned).
- Never use force unwraps. SwiftLint `force_unwrapping` rule + strict mode will catch these.
- Platform guards use `#if canImport(AppKit)`, not `#if os(macOS)`.
- All new commits end with `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.
- Conform to the `pfw-testing` / `pfw-snapshot-testing` conventions for new tests.

---

## Phase 1 — Framework foundations

### Task 1: Add `FrameRateMonitor` (new public type)

**Files:**
- Create: `Sources/CodeEditorPlugin/Performance/FrameRateMonitor.swift`
- Create: `Tests/CodeEditorPluginTests/Performance/FrameRateMonitorTests.swift`

- [ ] **Step 1.1: Write the failing test file**

Create `Tests/CodeEditorPluginTests/Performance/FrameRateMonitorTests.swift`:

```swift
import Testing
@testable import CodeEditorPlugin

@Suite("FrameRateMonitor")
@MainActor
struct FrameRateMonitorTests {
    @Test func startsAtZero() {
        let monitor = FrameRateMonitor()
        #expect(monitor.currentFPS == 0)
        #expect(monitor.averageFPS == 0)
    }

    @Test func computeFPSEmptyWindow() {
        let result = FrameRateMonitor.computeFPS(timestamps: [], window: 1.0, now: 100)
        #expect(result.current == 0)
        #expect(result.average == 0)
    }

    @Test func computeFPSSingleSampleInWindow() {
        let result = FrameRateMonitor.computeFPS(timestamps: [99.9], window: 1.0, now: 100)
        #expect(result.current == 1)
        #expect(result.average == 1.0)
    }

    @Test func computeFPSSixtyFramesIn1s() {
        let stamps = (0..<60).map { 99.0 + Double($0) / 60.0 }   // 60 frames spread over last 1s
        let result = FrameRateMonitor.computeFPS(timestamps: stamps, window: 1.0, now: 100)
        #expect(result.current == 60)
        #expect(abs(result.average - 60.0) < 0.5)
    }

    @Test func computeFPSDropsSamplesOlderThanWindow() {
        let stamps = [50.0, 90.0, 99.5]   // first two outside the 1s window
        let result = FrameRateMonitor.computeFPS(timestamps: stamps, window: 1.0, now: 100)
        #expect(result.current == 1)
    }

    @Test func stopMonitoringResetsFPS() {
        let monitor = FrameRateMonitor()
        monitor.startMonitoring()
        monitor.stopMonitoring()
        #expect(monitor.currentFPS == 0)
        #expect(monitor.averageFPS == 0)
    }
}
```

- [ ] **Step 1.2: Run tests, verify they fail to compile**

```bash
swift test --filter FrameRateMonitorTests
```

Expected: compile error — `cannot find 'FrameRateMonitor' in scope`.

- [ ] **Step 1.3: Create the implementation**

Create `Sources/CodeEditorPlugin/Performance/FrameRateMonitor.swift`:

```swift
import Foundation
#if canImport(QuartzCore)
import QuartzCore
#endif

/// Real-time frame-rate measurement using a `CADisplayLink` ticker.
///
/// Maintains a 1-second sliding window of frame timestamps and exposes the
/// frame count in that window as both an integer (`currentFPS`) and a decimal
/// average (`averageFPS`). Off by default; call `startMonitoring()` to begin.
@MainActor
@Observable
public final class FrameRateMonitor {

    public private(set) var currentFPS: Int = 0
    public private(set) var averageFPS: Double = 0

    @ObservationIgnored private var timestamps: [TimeInterval] = []
    @ObservationIgnored private var displayLink: CADisplayLink?

    public init() {}

    public func startMonitoring() {
        guard displayLink == nil else { return }
        #if canImport(QuartzCore)
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        self.displayLink = link
        #endif
    }

    public func stopMonitoring() {
        #if canImport(QuartzCore)
        displayLink?.invalidate()
        displayLink = nil
        #endif
        timestamps.removeAll(keepingCapacity: true)
        currentFPS = 0
        averageFPS = 0
    }

    /// Pure function over a window of timestamps so tests don't need a real display link.
    public static func computeFPS(
        timestamps: [TimeInterval],
        window: TimeInterval,
        now: TimeInterval
    ) -> (current: Int, average: Double) {
        let cutoff = now - window
        let recent = timestamps.filter { $0 >= cutoff }
        let count = recent.count
        return (current: count, average: Double(count))
    }

    #if canImport(QuartzCore)
    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        timestamps.append(now)
        let result = Self.computeFPS(timestamps: timestamps, window: 1.0, now: now)
        // Trim history we no longer need (memory bound).
        if let first = timestamps.first, now - first > 2.0 {
            timestamps.removeAll { $0 < now - 1.0 }
        }
        currentFPS = result.current
        averageFPS = result.average
    }
    #endif
}
```

- [ ] **Step 1.4: Run tests, verify they pass**

```bash
swift test --filter FrameRateMonitorTests
```

Expected: 6 tests pass.

- [ ] **Step 1.5: Run full quality gate**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Expected: clean.

- [ ] **Step 1.6: Commit**

```bash
git add Sources/CodeEditorPlugin/Performance/FrameRateMonitor.swift Tests/CodeEditorPluginTests/Performance/FrameRateMonitorTests.swift
git commit -m "$(cat <<'EOF'
Add FrameRateMonitor with CADisplayLink-based FPS measurement

New public @MainActor @Observable type maintaining a 1-second sliding
window of CADisplayLink timestamps; exposes currentFPS (Int) and
averageFPS (Double). Pure computeFPS(timestamps:window:now:) helper is
extracted so unit tests don't need a real display link.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Add `MemoryMonitor.resetPeak()`

**Files:**
- Modify: `Sources/CodeEditorPlugin/Performance/MemoryMonitor.swift`
- Modify (or create): `Tests/CodeEditorPluginTests/Performance/MemoryMonitorTests.swift`

- [ ] **Step 2.1: Locate `MemoryMonitor` public method block and confirm peak access**

Read `Sources/CodeEditorPlugin/Performance/MemoryMonitor.swift` around lines 380–450 (the existing `startMonitoring` / `stopMonitoring` / `resetStatistics` public methods) and confirm:
- `memoryStats: MemoryStatistics` is the `@Published` property declared at line 209.
- `peakUsageMB` is on `MemoryStatistics` (line 596 of the same file).
- `usageHistory: [Double]` is on `MemoryStatistics`.
- `resetStatistics()` already exists at line 440 — review its shape so the new method is in style.

- [ ] **Step 2.2: Write the failing test**

Open `Tests/CodeEditorPluginTests/Performance/MemoryMonitorTests.swift`. If it doesn't exist, create it with this content. If it exists, append the new `@Test` cases inside the existing `@Suite`.

```swift
import Testing
@testable import CodeEditorPlugin

@Suite("MemoryMonitor resetPeak")
@MainActor
struct MemoryMonitorResetPeakTests {

    @Test func resetPeakSetsPeakToCurrent() {
        let monitor = MemoryMonitor.mock(memoryUsage: 75.0)
        // Drive peak above current by mutating stats directly:
        monitor.memoryStats.peakUsageMB = 250.0
        monitor.memoryStats.currentUsageMB = 75.0
        monitor.resetPeak()
        #expect(monitor.memoryStats.peakUsageMB == 75.0)
    }

    @Test func resetPeakClearsUsageHistory() {
        let monitor = MemoryMonitor.mock(memoryUsage: 50.0)
        monitor.memoryStats.usageHistory = [10, 20, 30, 50]
        monitor.resetPeak()
        #expect(monitor.memoryStats.usageHistory.isEmpty)
    }
}
```

- [ ] **Step 2.3: Run tests, verify they fail**

```bash
swift test --filter MemoryMonitorResetPeakTests
```

Expected: compile error — `value of type 'MemoryMonitor' has no member 'resetPeak'`.

- [ ] **Step 2.4: Add the implementation**

In `Sources/CodeEditorPlugin/Performance/MemoryMonitor.swift`, immediately after the existing `resetStatistics()` method (around line 440), add:

```swift
    /// Sets peak memory back to current usage and clears the usage history.
    /// Triggers `@Published` notification for `memoryStats` observers.
    public func resetPeak() {
        memoryStats.peakUsageMB = memoryStats.currentUsageMB
        memoryStats.usageHistory.removeAll(keepingCapacity: true)
    }
```

- [ ] **Step 2.5: Run tests, verify they pass**

```bash
swift test --filter MemoryMonitorResetPeakTests
```

Expected: 2 tests pass.

- [ ] **Step 2.6: Full quality gate, then commit**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
git add Sources/CodeEditorPlugin/Performance/MemoryMonitor.swift Tests/CodeEditorPluginTests/Performance/MemoryMonitorTests.swift
git commit -m "$(cat <<'EOF'
Add MemoryMonitor.resetPeak() for HUD reset-peak control

Public method zeros peakUsageMB back to currentUsageMB and clears
usageHistory; triggers @Published notification. Used by the new
Performance Inspector panel's reset-peak button.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Extend `MemoryMonitor.mock(...)` factory

**Files:**
- Modify: `Sources/CodeEditorPlugin/Performance/MemoryMonitor.swift`

- [ ] **Step 3.1: Read the existing mock factory**

Open `Sources/CodeEditorPlugin/Performance/MemoryMonitor.swift` lines 615–624 to confirm the existing signature:

```swift
public static func mock(
    memoryUsage: Double = 100.0,
    memoryPressure: MemoryPressure = .normal
) -> MemoryMonitor
```

- [ ] **Step 3.2: Add a new overload below the existing one**

In the same `MemoryMonitor` file, immediately after the closing brace of the existing `mock(...)` (around line 624), add:

```swift
    /// Test helper: returns a `MemoryMonitor` with the given fixed memoryStats values.
    /// Use for snapshot tests and coordinator tests that need specific peak/current values.
    public static func mock(
        currentUsageMB: Double,
        peakUsageMB: Double,
        averageUsageMB: Double = 0,
        usageHistory: [Double] = [],
        isUnderPressure: Bool = false
    ) -> MemoryMonitor {
        let monitor = MemoryMonitor.mock(
            memoryUsage: currentUsageMB,
            memoryPressure: isUnderPressure ? .critical : .normal
        )
        monitor.memoryStats.currentUsageMB = currentUsageMB
        monitor.memoryStats.peakUsageMB = peakUsageMB
        monitor.memoryStats.averageUsageMB = averageUsageMB == 0 ? currentUsageMB : averageUsageMB
        monitor.memoryStats.usageHistory = usageHistory
        return monitor
    }
```

- [ ] **Step 3.3: Write a sanity-check test**

Append to `Tests/CodeEditorPluginTests/Performance/MemoryMonitorTests.swift`:

```swift
@Suite("MemoryMonitor.mock factory")
@MainActor
struct MemoryMonitorMockFactoryTests {

    @Test func mockWithFixedValues() {
        let monitor = MemoryMonitor.mock(
            currentUsageMB: 145,
            peakUsageMB: 210,
            averageUsageMB: 132,
            usageHistory: [100, 120, 145],
            isUnderPressure: false
        )
        #expect(monitor.memoryStats.currentUsageMB == 145)
        #expect(monitor.memoryStats.peakUsageMB == 210)
        #expect(monitor.memoryStats.averageUsageMB == 132)
        #expect(monitor.memoryStats.usageHistory == [100, 120, 145])
    }
}
```

- [ ] **Step 3.4: Run the full quality gate, then commit**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
git add Sources/CodeEditorPlugin/Performance/MemoryMonitor.swift Tests/CodeEditorPluginTests/Performance/MemoryMonitorTests.swift
git commit -m "$(cat <<'EOF'
Add fixed-value overload to MemoryMonitor.mock factory

New static mock(currentUsageMB:peakUsageMB:averageUsageMB:usageHistory:
isUnderPressure:) for tests that need specific memoryStats values
(snapshot tests, coordinator state tests). Existing pressure/usage
overload is unchanged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Add non-throwing `UnifiedPerformanceSystem.track` overload

The existing `track<T>(_:operation:) async throws -> T` requires the operation to be throwing; the syntax highlighter's body is `async` but not `throws`. Wrapping it would force a `try?` discard. A non-throwing overload is one method addition that keeps the call site clean.

**Files:**
- Modify: `Sources/CodeEditorPlugin/Performance/UnifiedPerformanceSystem.swift`

- [ ] **Step 4.1: Read the existing `track` method**

Open `Sources/CodeEditorPlugin/Performance/UnifiedPerformanceSystem.swift` and find the existing `public func track<T>(_ metricType: PerformanceMetricType, operation: () async throws -> T) async throws -> T`. Note its body (timing wrapper around the operation, recording the metric on success/failure).

- [ ] **Step 4.2: Add the non-throwing overload immediately below the throwing one**

```swift
    /// Non-throwing overload. Use when the tracked operation does not throw.
    /// Records duration on success identically to the throwing variant.
    @MainActor
    public func track<T>(
        _ metricType: PerformanceMetricType,
        operation: () async -> T
    ) async -> T {
        let start = ContinuousClock.now
        let result = await operation()
        let duration = start.duration(to: ContinuousClock.now)
        recordMetric(
            type: metricType,
            duration: TimeInterval(duration.components.seconds) + TimeInterval(duration.components.attoseconds) / 1e18,
            success: true,
            error: nil
        )
        return result
    }
```

If `recordMetric(type:duration:success:error:)` is private in the existing type, this overload should mirror the throwing version's internals exactly — copy its private-method calls. (The throwing version's body is the canonical reference; the only difference is removing the `try`/`throws`/`do-catch`.)

- [ ] **Step 4.3: Write a sanity-check test**

Create or append to `Tests/CodeEditorPluginTests/Performance/UnifiedPerformanceSystemTests.swift`:

```swift
import Testing
@testable import CodeEditorPlugin

@Suite("UnifiedPerformanceSystem non-throwing track")
@MainActor
struct UnifiedPerformanceSystemNonThrowingTrackTests {

    @Test func trackNonThrowingRecordsOneMetric() async {
        let ups = UnifiedPerformanceSystem()
        let value = await ups.track(.syntaxHighlighting) {
            return 42
        }
        #expect(value == 42)
        let insights = ups.generateInsights()
        let analysis = insights.metricAnalyses[.syntaxHighlighting]
        #expect(analysis?.count == 1)
    }
}
```

- [ ] **Step 4.4: Run quality gate, commit**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
git add Sources/CodeEditorPlugin/Performance/UnifiedPerformanceSystem.swift Tests/CodeEditorPluginTests/Performance/UnifiedPerformanceSystemTests.swift
git commit -m "$(cat <<'EOF'
Add non-throwing track overload to UnifiedPerformanceSystem

New track<T>(_:operation:) async -> T mirrors the throwing variant but
accepts a non-throwing async closure. Lets non-throwing call sites (the
syntax highlighter) instrument without a try? discard at the call site.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 2 — Framework wiring

### Task 5: Replace `PerformanceInsights.currentFPS` placeholder

**Files:**
- Modify: `Sources/CodeEditorPlugin/Performance/PerformanceInsights.swift`

This task changes the public init signature of `PerformanceInsights` by adding a required `frameRateMonitor:` parameter. Any existing callers must be updated.

- [ ] **Step 5.1: Find existing call sites of `PerformanceInsights(memoryMonitor:...)`**

```bash
grep -rn "PerformanceInsights(" Sources Tests
```

Note every match — each will need an extra `frameRateMonitor:` argument in step 5.5.

- [ ] **Step 5.2: Update the init signature**

In `Sources/CodeEditorPlugin/Performance/PerformanceInsights.swift`, find the existing init at lines 55–63:

```swift
public init(
    memoryMonitor: MemoryMonitor,
    performanceMonitor: PerformanceMonitor? = nil,
    capabilities: PlatformCapabilities? = nil
) {
```

Replace with:

```swift
public init(
    memoryMonitor: MemoryMonitor,
    frameRateMonitor: FrameRateMonitor,
    performanceMonitor: PerformanceMonitor? = nil,
    capabilities: PlatformCapabilities? = nil
) {
```

Add a stored property near the other injected dependencies (top of the class body):

```swift
    @ObservationIgnored private let frameRateMonitor: FrameRateMonitor
```

In the init body, assign it after `self.memoryMonitor = memoryMonitor`:

```swift
    self.frameRateMonitor = frameRateMonitor
```

- [ ] **Step 5.3: Replace the FPS placeholder**

Find line 174:

```swift
metrics.currentFPS = 60 // Placeholder - would measure actual frame rate
```

Replace with:

```swift
metrics.currentFPS = frameRateMonitor.currentFPS
```

- [ ] **Step 5.4: Add a test that confirms FPS reflects the injected monitor**

Open `Tests/CodeEditorPluginTests/Performance/PerformanceInsightsTests.swift` (create if missing) and add:

```swift
import Testing
@testable import CodeEditorPlugin

@Suite("PerformanceInsights real FPS")
@MainActor
struct PerformanceInsightsRealFPSTests {

    @Test func currentFPSReflectsInjectedMonitor() async {
        let memory = MemoryMonitor.mock(memoryUsage: 100)
        let frames = FrameRateMonitor()
        let insights = PerformanceInsights(
            memoryMonitor: memory,
            frameRateMonitor: frames
        )
        // The monitor's currentFPS starts at 0; insights should reflect that.
        insights.startMonitoring()
        // updateMetrics() runs on its own timer; nudge by calling the internal once if exposed,
        // otherwise wait one tick interval.
        try? await Task.sleep(for: .milliseconds(1100))
        #expect(insights.metrics.currentFPS == 0)
        insights.stopMonitoring()
    }
}
```

If `PerformanceInsights` exposes `updateMetrics()` internally (line 142), the test can call it directly with `@testable import` access; replace the `Task.sleep` with a synchronous call. Confirm by reading the file's `internal`/`private` markers.

- [ ] **Step 5.5: Update all existing `PerformanceInsights(...)` call sites**

For each match from Step 5.1 (in non-test code), add `frameRateMonitor: FrameRateMonitor()` (or a shared instance if one is in scope). For test call sites, do the same.

- [ ] **Step 5.6: Run quality gate, commit**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
git add Sources/CodeEditorPlugin/Performance/PerformanceInsights.swift Tests/CodeEditorPluginTests/Performance/PerformanceInsightsTests.swift
# Also include any files modified in Step 5.5
git commit -m "$(cat <<'EOF'
Wire real FPS into PerformanceInsights via FrameRateMonitor

PerformanceInsights.init now requires a FrameRateMonitor; metrics.currentFPS
reads from it instead of the previous hardcoded 60. Updates all existing
call sites.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Replace `PerformanceInsights.cpuUsage` placeholder

**Files:**
- Modify: `Sources/CodeEditorPlugin/Performance/PerformanceInsights.swift`

- [ ] **Step 6.1: Add the private CPU-sampling helper**

In `Sources/CodeEditorPlugin/Performance/PerformanceInsights.swift`, at the bottom of the class body (before the closing brace), add:

```swift
    /// Reads the current process's CPU usage as a percentage in [0, 100].
    /// Returns 0 on any mach call failure (and reports the issue once).
    @MainActor private static var didReportCPUFailure = false

    @MainActor
    private static func sampleCPUUsage() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        let kerr = withUnsafeMutablePointer(to: &threadList) {
            $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadCount)
            }
        }
        guard kerr == KERN_SUCCESS, let threadList else {
            if !didReportCPUFailure {
                IssueReporting.reportIssue("PerformanceInsights: task_threads failed (\(kerr))")
                didReportCPUFailure = true
            }
            return 0
        }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: threadList)),
                vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
            )
        }
        var totalCPU: Double = 0
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var infoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                    thread_info(threadList[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &infoCount)
                }
            }
            if result == KERN_SUCCESS && (info.flags & TH_FLAGS_IDLE) == 0 {
                totalCPU += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }
        return min(max(totalCPU, 0), 100)
    }
```

At the top of the file (with the other imports), add:

```swift
import Darwin
import IssueReporting
```

(If `IssueReporting` isn't yet imported in this file, this adds it. Check the project's dependency on `xctest-dynamic-overlay`/`IssueReporting` per `Package.swift` and `CLAUDE.md`.)

- [ ] **Step 6.2: Replace the random placeholder**

Find line 167:

```swift
metrics.cpuUsage = Double.random(in: 10...90) // Placeholder
```

Replace with:

```swift
metrics.cpuUsage = Self.sampleCPUUsage()
```

- [ ] **Step 6.3: Write a test confirming `cpuUsage` is in range and not random**

Append to `Tests/CodeEditorPluginTests/Performance/PerformanceInsightsTests.swift`:

```swift
@Suite("PerformanceInsights real CPU")
@MainActor
struct PerformanceInsightsRealCPUTests {

    @Test func cpuUsageIsInRange() async {
        let memory = MemoryMonitor.mock(memoryUsage: 100)
        let frames = FrameRateMonitor()
        let insights = PerformanceInsights(memoryMonitor: memory, frameRateMonitor: frames)
        insights.startMonitoring()
        try? await Task.sleep(for: .milliseconds(1100))
        let cpu = insights.metrics.cpuUsage
        #expect(cpu >= 0)
        #expect(cpu <= 100)
        insights.stopMonitoring()
    }

    @Test func cpuUsageIsStableAcrossTicks() async {
        // Smoke test that consecutive reads are not random (Double.random would give
        // very different values across short intervals; real CPU usage is steady).
        let memory = MemoryMonitor.mock(memoryUsage: 100)
        let frames = FrameRateMonitor()
        let insights = PerformanceInsights(memoryMonitor: memory, frameRateMonitor: frames)
        insights.startMonitoring()
        try? await Task.sleep(for: .milliseconds(1100))
        let first = insights.metrics.cpuUsage
        try? await Task.sleep(for: .milliseconds(1100))
        let second = insights.metrics.cpuUsage
        // Two samples taken from an idle test process should differ by <30 percentage points;
        // Double.random(10...90) would frequently exceed that.
        #expect(abs(first - second) < 30)
        insights.stopMonitoring()
    }
}
```

- [ ] **Step 6.4: Run quality gate, commit**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
git add Sources/CodeEditorPlugin/Performance/PerformanceInsights.swift Tests/CodeEditorPluginTests/Performance/PerformanceInsightsTests.swift
git commit -m "$(cat <<'EOF'
Replace PerformanceInsights cpuUsage random placeholder with real reading

Adds private sampleCPUUsage() using mach task_threads / thread_info to
compute the process's actual CPU percentage, clamped to [0, 100]. Failure
falls back to 0 with a one-shot reportIssue. Tests cover range and stability
(non-random) properties.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Add `unifiedPerformanceSystem` to `EditorConfiguration.Performance`

**Files:**
- Modify: `Sources/CodeEditorPlugin/Configuration/EditorConfiguration+PerformanceExtensions.swift`

- [ ] **Step 7.1: Read the file's structure**

Open `Sources/CodeEditorPlugin/Configuration/EditorConfiguration+PerformanceExtensions.swift` and orient on:
- The `Performance` struct declaration at line 11
- The end of the struct body (around line 116)
- The custom `Codable` block (lines 120–182)
- The custom `Equatable` block (lines 185–202)

Identify the property declaration block (likely lines 12–80 with the existing knobs like `maxSyntaxHighlightingLength`).

- [ ] **Step 7.2: Add the new property**

Inside the `Performance` struct (after the last existing property, before the struct's closing brace), add:

```swift
    /// Optional `UnifiedPerformanceSystem` for tracking editor performance metrics.
    /// When non-nil, the syntax highlighter records `.syntaxHighlighting` metrics here.
    /// Excluded from `Codable` and `Equatable` (reference identity is not configuration).
    public var unifiedPerformanceSystem: UnifiedPerformanceSystem?
```

- [ ] **Step 7.3: Update `Codable` to ignore the new field**

In the same file, find the `Performance`'s `CodingKeys` enum (within the Codable block at lines 120–182). Leave the enum alone — do NOT add a case for `unifiedPerformanceSystem`.

Then find the `init(from decoder:)` implementation. At the END of the init body, add:

```swift
        self.unifiedPerformanceSystem = nil
```

(This satisfies Swift's requirement that every stored property be initialized.)

The `encode(to encoder:)` method requires no change — it never encodes the new field.

- [ ] **Step 7.4: Update `Equatable`**

Find the `static func == (lhs: Performance, rhs: Performance) -> Bool` at lines 185–202. Confirm it's a manual `&&` chain of property comparisons. Do NOT add the new field to the comparison — two `Performance` values are equal regardless of whether they reference the same `UnifiedPerformanceSystem`.

If the existing `==` uses synthesized `Equatable` (no manual body), you'll need to make it manual now — but the explore confirmed it's already manual.

- [ ] **Step 7.5: Sanity-check tests**

Find or create `Tests/CodeEditorPluginTests/Configuration/EditorConfigurationPerformanceTests.swift` and add:

```swift
import Testing
@testable import CodeEditorPlugin

@Suite("EditorConfiguration.Performance unifiedPerformanceSystem")
@MainActor
struct EditorConfigPerformanceUnifiedSystemTests {

    @Test func defaultsToNil() {
        let perf = EditorConfiguration.Performance()
        #expect(perf.unifiedPerformanceSystem == nil)
    }

    @Test func canBeSet() {
        var perf = EditorConfiguration.Performance()
        let ups = UnifiedPerformanceSystem()
        perf.unifiedPerformanceSystem = ups
        #expect(perf.unifiedPerformanceSystem === ups)
    }

    @Test func equatableIgnoresUnifiedPerformanceSystem() {
        var a = EditorConfiguration.Performance()
        var b = EditorConfiguration.Performance()
        a.unifiedPerformanceSystem = UnifiedPerformanceSystem()
        b.unifiedPerformanceSystem = nil
        #expect(a == b)
    }

    @Test func codableRoundTripIgnoresUnifiedPerformanceSystem() throws {
        var perf = EditorConfiguration.Performance()
        perf.unifiedPerformanceSystem = UnifiedPerformanceSystem()
        let data = try JSONEncoder().encode(perf)
        let decoded = try JSONDecoder().decode(EditorConfiguration.Performance.self, from: data)
        #expect(decoded.unifiedPerformanceSystem == nil)
    }
}
```

- [ ] **Step 7.6: Run quality gate, commit**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
git add Sources/CodeEditorPlugin/Configuration/EditorConfiguration+PerformanceExtensions.swift Tests/CodeEditorPluginTests/Configuration/EditorConfigurationPerformanceTests.swift
git commit -m "$(cat <<'EOF'
Add unifiedPerformanceSystem field to EditorConfiguration.Performance

Optional UnifiedPerformanceSystem? property; nil means no tracking. Excluded
from Codable (reference identity is not configuration) and Equatable
(comparisons should ignore the injected instance). Tests cover default,
set, Equatable-ignores, and Codable-ignores behaviors.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Expose `AdaptivePerformanceMode` on `EditorController`

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`

- [ ] **Step 8.1: Read the controller's existing accessors**

Open `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`. Confirm:
- Line 52: `@ObservationIgnored weak var codeEditorView: CodeEditorView?`
- Existing public computed properties (like `currentLineNumber` near line 300) that follow the pattern `codeEditorView?.someProperty`.

- [ ] **Step 8.2: Add the new accessor in style**

Below an existing accessor (e.g., near `currentLineNumber`), add:

```swift
    /// The editor's adaptive performance mode controller.
    ///
    /// Exposes the underlying `CodeEditorView`'s instance so observers see the same state the
    /// editor itself uses (file-size and memory-pressure driven transitions). Returns `nil`
    /// before the controller is attached to a view.
    public var adaptivePerformanceMode: AdaptivePerformanceMode? {
        codeEditorView?.adaptivePerformanceMode
    }
```

- [ ] **Step 8.3: Make `CodeEditorView.adaptivePerformanceMode` accessible from the SwiftUI module**

The exploration shows it's `internal lazy var adaptivePerformanceMode` at line 243 of `CodeEditorView.swift`. Since `EditorController` lives in the same target (`CodeEditorPlugin`), `internal` access is already sufficient — no change needed. **Confirm both files are members of the same target by reading the top of each file** (no module separation), and skip any change to `CodeEditorView`.

- [ ] **Step 8.4: Sanity-check test**

Append to (or create) `Tests/CodeEditorPluginTests/SwiftUI/EditorControllerTests.swift`:

```swift
import Testing
@testable import CodeEditorPlugin

@Suite("EditorController.adaptivePerformanceMode")
@MainActor
struct EditorControllerAdaptiveModeTests {

    @Test func returnsNilBeforeAttach() {
        let controller = EditorController()
        #expect(controller.adaptivePerformanceMode == nil)
    }
}
```

(A full "returns the view's instance after attach" test requires constructing a `CodeEditorView` which is heavier — defer to coordinator integration tests.)

- [ ] **Step 8.5: Run quality gate, commit**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
git add Sources/CodeEditorPlugin/SwiftUI/EditorController.swift Tests/CodeEditorPluginTests/SwiftUI/EditorControllerTests.swift
git commit -m "$(cat <<'EOF'
Expose AdaptivePerformanceMode on EditorController

New public read-only accessor returns the underlying CodeEditorView's
adaptivePerformanceMode instance (nil before attach). Lets external
observers (the sample's PerformanceSampleCoordinator) see the same
mode-transition state the editor uses internally, rather than creating
a duplicate instance that would drift.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Instrument `AsyncSyntaxHighlighter`

**Files:**
- Modify: `Sources/CodeEditorPlugin/SyntaxHighlighting/AsyncSyntaxHighlighter.swift`

- [ ] **Step 9.1: Read `performHighlighting` (lines 167–298)**

Confirm: the method signature is `private func performHighlighting(for textView: CodeEditorView, language: Language, visibleRange: NSRange? = nil) async`, configuration is reachable via `textView.configuration.performance`, and the bulk of the work starts after the size check around line 213 and continues through to the method's end.

- [ ] **Step 9.2: Add the instrumentation wrap**

Replace the method body. The pattern: pull the optional `unifiedPerformanceSystem` once, then branch on it. The simplest mechanical edit is to extract the existing body into a nested closure:

```swift
private func performHighlighting(
    for textView: CodeEditorView,
    language: Language,
    visibleRange: NSRange? = nil
) async {
    let body: () async -> Void = { [weak self] in
        // EXISTING BODY OF performHighlighting GOES HERE, UNCHANGED,
        // referencing `self?` for the previous `self` references.
    }

    if let ups = textView.configuration.performance.unifiedPerformanceSystem {
        await ups.track(.syntaxHighlighting) {
            await body()
        }
    } else {
        await body()
    }
}
```

If the existing body uses `self` directly (not `self?`), preserve that by capturing strongly via `[self]` inside the closure — but match the existing capture semantics; `weak` is the standard for long-running tasks in this class.

**Validation hint:** before editing, search for any `Task { [weak self] in` (line 238 in the existing body) — make sure the inner Task captures use the *renamed* outer self correctly after wrapping.

- [ ] **Step 9.3: Add an instrumentation test**

Create `Tests/CodeEditorPluginTests/SyntaxHighlighting/AsyncSyntaxHighlighterInstrumentationTests.swift`:

```swift
import Testing
@testable import CodeEditorPlugin

@Suite("AsyncSyntaxHighlighter UnifiedPerformanceSystem instrumentation")
@MainActor
struct AsyncSyntaxHighlighterInstrumentationTests {

    @Test func recordsSyntaxHighlightingMetricWhenSystemInjected() async {
        let ups = UnifiedPerformanceSystem()
        var config = EditorConfiguration()
        config.performance.unifiedPerformanceSystem = ups

        // Drive one highlight pass via the public entry point. The exact API call here
        // depends on how AsyncSyntaxHighlighter is constructed in this codebase — see
        // existing AsyncSyntaxHighlighter tests for the pattern; mirror the smallest
        // one that performs a single pass on a tiny string.
        // (Plan placeholder: see existing AsyncSyntaxHighlighter tests, mirror one.)

        let insights = ups.generateInsights()
        let analysis = insights.metricAnalyses[.syntaxHighlighting]
        #expect(analysis != nil)
        #expect((analysis?.count ?? 0) >= 1)
    }

    @Test func recordsNothingWhenSystemIsNil() async {
        let ups = UnifiedPerformanceSystem()
        var config = EditorConfiguration()
        config.performance.unifiedPerformanceSystem = nil
        // Run one highlight pass (mirroring the test above's setup).
        let insights = ups.generateInsights()
        let analysis = insights.metricAnalyses[.syntaxHighlighting]
        #expect(analysis == nil || analysis?.count == 0)
    }
}
```

**Note for implementer:** read one existing `AsyncSyntaxHighlighter` test file in `Tests/CodeEditorPluginTests/SyntaxHighlighting/` to discover the established pattern for driving a single highlight pass. Mirror that exactly in the "Plan placeholder" comment above. If no such test exists, the smallest reproducer is: construct an `AsyncSyntaxHighlighter`, call `highlightImmediately(for:language:visibleRange:)` against a minimal `CodeEditorView` whose `configuration` has the injected `ups`.

- [ ] **Step 9.4: Run quality gate, commit**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
git add Sources/CodeEditorPlugin/SyntaxHighlighting/AsyncSyntaxHighlighter.swift Tests/CodeEditorPluginTests/SyntaxHighlighting/AsyncSyntaxHighlighterInstrumentationTests.swift
git commit -m "$(cat <<'EOF'
Instrument AsyncSyntaxHighlighter with UnifiedPerformanceSystem

performHighlighting now wraps its body in
configuration.performance.unifiedPerformanceSystem.track(.syntaxHighlighting)
when one is present. Zero behavior change when nil. Lets the new
Performance Inspector panel surface real "Last highlight" and
"Highlight p95" numbers via UnifiedPerformanceSystem.generateInsights().

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 3 — Sample coordinator & panel

### Task 10: `PerformanceSampleCoordinator` (sample-side observable model)

**Files:**
- Create: `Sources/CodeEditorSample/App/Performance/PerformanceSampleCoordinator.swift`
- Create: `Tests/CodeEditorSampleTests/PerformanceSampleCoordinatorTests.swift`

- [ ] **Step 10.1: Create the coordinator file (skeleton)**

Create `Sources/CodeEditorSample/App/Performance/PerformanceSampleCoordinator.swift`:

```swift
#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
import Combine
import Foundation
import SwiftUI

@MainActor
@Observable
public final class PerformanceSampleCoordinator {

    public enum State: Sendable {
        case stopped
        case live
    }

    // MARK: Observable surface

    public private(set) var state: State = .stopped
    public private(set) var fps: Int = 0
    public private(set) var memoryStats: MemoryStatistics
    public private(set) var pressure: MemoryPressure = .normal
    public private(set) var adaptiveMode: PerformanceMode = .balanced
    public private(set) var lastHighlightMs: Double?
    public private(set) var highlightP95Ms: Double?
    public private(set) var healthScore: Double = 100
    public private(set) var issuesCount: Int = 0
    public private(set) var recommendationsCount: Int = 0
    public private(set) var memorySparkline: [Double] = []
    public let targetFPS: Int

    // MARK: Non-observable internals

    @ObservationIgnored private let memoryMonitor: MemoryMonitor
    @ObservationIgnored private let frameRateMonitor: FrameRateMonitor
    @ObservationIgnored private let unifiedPerformanceSystem: UnifiedPerformanceSystem
    @ObservationIgnored private let performanceInsights: PerformanceInsights
    @ObservationIgnored private weak var adaptivePerformanceMode: AdaptivePerformanceMode?
    @ObservationIgnored private var refreshTimer: Timer?

    public init(
        memoryMonitor: MemoryMonitor,
        unifiedPerformanceSystem: UnifiedPerformanceSystem
    ) {
        self.memoryMonitor = memoryMonitor
        self.frameRateMonitor = FrameRateMonitor()
        self.unifiedPerformanceSystem = unifiedPerformanceSystem
        self.performanceInsights = PerformanceInsights(
            memoryMonitor: memoryMonitor,
            frameRateMonitor: frameRateMonitor
        )
        self.memoryStats = memoryMonitor.memoryStats
        self.targetFPS = NSScreen.main?.maximumFramesPerSecond ?? 60
    }

    public func attach(controller: EditorController) {
        self.adaptivePerformanceMode = controller.adaptivePerformanceMode
    }

    public func start() {
        guard state == .stopped else { return }
        memoryMonitor.startMonitoring()
        frameRateMonitor.startMonitoring()
        performanceInsights.startMonitoring()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        self.refreshTimer = timer
        state = .live
    }

    public func stop() {
        guard state == .live else { return }
        memoryMonitor.stopMonitoring()
        frameRateMonitor.stopMonitoring()
        performanceInsights.stopMonitoring()
        refreshTimer?.invalidate()
        refreshTimer = nil
        state = .stopped
    }

    public func resetPeak() {
        memoryMonitor.resetPeak()
        refresh()
    }

    /// Called by the refresh timer (1Hz); exposed `internal` so tests can drive it deterministically.
    @MainActor
    func refresh() {
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
}
#endif
```

**Note for implementer:** Verify the exact types referenced (`MemoryStatistics`, `MemoryPressure`, `PerformanceMode`) match what the framework exposes (the explore agent confirmed all of these exist publicly). If `MemoryMonitor.getMemoryPressure()` has a different signature, adjust the `pressure` line.

- [ ] **Step 10.2: Write the coordinator's test suite**

Create `Tests/CodeEditorSampleTests/PerformanceSampleCoordinatorTests.swift`:

```swift
#if canImport(AppKit)
import Testing
@testable import CodeEditorPlugin
@testable import CodeEditorSample

@Suite("PerformanceSampleCoordinator")
@MainActor
struct PerformanceSampleCoordinatorTests {

    @Test func initialStateIsStopped() {
        let coordinator = PerformanceSampleCoordinator(
            memoryMonitor: MemoryMonitor.mock(memoryUsage: 100),
            unifiedPerformanceSystem: UnifiedPerformanceSystem()
        )
        #expect(coordinator.state == .stopped)
        #expect(coordinator.fps == 0)
        #expect(coordinator.adaptiveMode == .balanced)
    }

    @Test func startTransitionsToLive() {
        let coordinator = PerformanceSampleCoordinator(
            memoryMonitor: MemoryMonitor.mock(memoryUsage: 100),
            unifiedPerformanceSystem: UnifiedPerformanceSystem()
        )
        coordinator.start()
        #expect(coordinator.state == .live)
        coordinator.stop()
    }

    @Test func startIsIdempotent() {
        let coordinator = PerformanceSampleCoordinator(
            memoryMonitor: MemoryMonitor.mock(memoryUsage: 100),
            unifiedPerformanceSystem: UnifiedPerformanceSystem()
        )
        coordinator.start()
        coordinator.start()
        #expect(coordinator.state == .live)
        coordinator.stop()
    }

    @Test func stopTransitionsToStopped() {
        let coordinator = PerformanceSampleCoordinator(
            memoryMonitor: MemoryMonitor.mock(memoryUsage: 100),
            unifiedPerformanceSystem: UnifiedPerformanceSystem()
        )
        coordinator.start()
        coordinator.stop()
        #expect(coordinator.state == .stopped)
    }

    @Test func resetPeakClearsPeakAndUsageHistory() {
        let memory = MemoryMonitor.mock(
            currentUsageMB: 145,
            peakUsageMB: 210,
            usageHistory: [100, 145, 210]
        )
        let coordinator = PerformanceSampleCoordinator(
            memoryMonitor: memory,
            unifiedPerformanceSystem: UnifiedPerformanceSystem()
        )
        coordinator.resetPeak()
        #expect(memory.memoryStats.peakUsageMB == 145)
        #expect(memory.memoryStats.usageHistory.isEmpty)
    }

    @Test func refreshPopulatesFromInjectedMonitors() {
        let memory = MemoryMonitor.mock(
            currentUsageMB: 145,
            peakUsageMB: 210,
            averageUsageMB: 132,
            usageHistory: [100, 120, 145]
        )
        let coordinator = PerformanceSampleCoordinator(
            memoryMonitor: memory,
            unifiedPerformanceSystem: UnifiedPerformanceSystem()
        )
        coordinator.refresh()
        #expect(coordinator.memoryStats.currentUsageMB == 145)
        #expect(coordinator.memoryStats.peakUsageMB == 210)
        #expect(coordinator.memorySparkline == [100, 120, 145])
    }

    @Test func targetFPSReadsFromMainScreen() {
        let coordinator = PerformanceSampleCoordinator(
            memoryMonitor: MemoryMonitor.mock(memoryUsage: 100),
            unifiedPerformanceSystem: UnifiedPerformanceSystem()
        )
        // Expect either real screen rate or 60 fallback.
        #expect(coordinator.targetFPS >= 60)
    }
}
#endif
```

- [ ] **Step 10.3: Run quality gate, verify all tests pass, commit**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
git add Sources/CodeEditorSample/App/Performance/PerformanceSampleCoordinator.swift Tests/CodeEditorSampleTests/PerformanceSampleCoordinatorTests.swift
git commit -m "$(cat <<'EOF'
Add PerformanceSampleCoordinator

Sample-side @MainActor @Observable polling adapter. Wraps MemoryMonitor,
FrameRateMonitor, UnifiedPerformanceSystem, and (weakly) the editor's
AdaptivePerformanceMode behind a single observable surface for the new
inspector panel. 1Hz refresh; idempotent start/stop; resetPeak passthrough.
macOS-only via canImport(AppKit). Tests cover state machine, idempotence,
reset behavior, and field population from injected mocks.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: `PerformanceInspectorPanel` view + thresholds

**Files:**
- Create: `Sources/CodeEditorSample/Sidebars/PerformanceInspectorPanel.swift`

- [ ] **Step 11.1: Create the panel file**

Create `Sources/CodeEditorSample/Sidebars/PerformanceInspectorPanel.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import SwiftUI

struct PerformanceInspectorPanel: View {

    struct Thresholds: Sendable {
        var fpsTarget: Int
        var fpsGreenRatio: Double = 0.92
        var fpsAmberRatio: Double = 0.50
        var healthGreen: Double = 80
        var healthAmber: Double = 50
        var highlightGreenMs: Double = 16
        var highlightAmberMs: Double = 100

        static func `default`(fpsTarget: Int) -> Thresholds {
            Thresholds(fpsTarget: fpsTarget)
        }
    }

    let state: PerformanceSampleCoordinator.State
    let fps: Int
    let memoryStats: MemoryStatistics
    let pressure: MemoryPressure
    let adaptiveMode: PerformanceMode
    let lastHighlightMs: Double?
    let highlightP95Ms: Double?
    let healthScore: Double
    let issuesCount: Int
    let recommendationsCount: Int
    let memorySparkline: [Double]
    let thresholds: Thresholds
    let onResetPeak: () -> Void
    let onShowReport: () -> Void
    let onAppear: () -> Void
    let onDisappear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            adaptiveModeRow
            tileGrid
            pressureRow
            sparkline
            footer
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
    }

    // MARK: - Sub-views

    private var header: some View {
        HStack {
            Text("Performance").font(.headline)
            Spacer()
            statePill
        }
        Divider()
    }

    private var statePill: some View {
        let isLive = state == .live
        return Text(isLive ? "● LIVE" : "STOPPED")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(isLive ? Color.green : Color.gray)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private var adaptiveModeRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles").foregroundStyle(adaptiveModeColor)
            Text("Adaptive: ").foregroundStyle(.secondary)
            Text(adaptiveModeLabel).fontWeight(.semibold).foregroundStyle(adaptiveModeColor)
            Spacer()
        }
        .padding(8)
        .background(adaptiveModeColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var tileGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            MetricTile(
                label: "FPS",
                primary: "\(fps)",
                primaryColor: fpsColor
            )
            MetricTile(
                label: "Health",
                primary: "\(Int(healthScore))",
                primaryColor: healthColor
            )
            MetricTile(
                label: "Memory",
                primary: String(format: "%.0f", memoryStats.currentUsageMB),
                primaryUnit: "MB",
                secondary: "peak \(Int(memoryStats.peakUsageMB)) · avg \(Int(memoryStats.averageUsageMB))",
                trailingIcon: "arrow.counterclockwise",
                trailingAction: onResetPeak
            )
            MetricTile(
                label: "Highlight",
                primary: lastHighlightMs.map { String(format: "%.1f", $0) } ?? "—",
                primaryUnit: lastHighlightMs == nil ? nil : "ms",
                secondary: highlightP95Ms.map { String(format: "p95 %.1f ms", $0) },
                primaryColor: highlightColor
            )
        }
    }

    private var pressureRow: some View {
        HStack {
            Text("Memory pressure").foregroundStyle(.secondary)
            Spacer()
            Circle().fill(pressureColor).frame(width: 8, height: 8)
            Text(pressureLabel).fontWeight(.medium).foregroundStyle(pressureColor)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var sparkline: some View {
        if memorySparkline.count > 1 {
            VStack(alignment: .leading, spacing: 2) {
                Text("MEMORY · LAST \(memorySparkline.count) SAMPLES")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Canvas { context, size in
                    guard let maxValue = memorySparkline.max(), maxValue > 0 else { return }
                    let stepX = size.width / max(CGFloat(memorySparkline.count - 1), 1)
                    var path = Path()
                    for (index, value) in memorySparkline.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = size.height - (CGFloat(value / maxValue) * size.height)
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(path, with: .color(.accentColor), lineWidth: 1.5)
                }
                .frame(height: 32)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(issuesCount) issues · \(recommendationsCount) recs")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button(action: onShowReport) {
                Text("Report ›").font(.caption)
            }
            .buttonStyle(.link)
        }
        .padding(.top, 4)
    }

    // MARK: - Threshold-driven colors

    private var fpsColor: Color? {
        let target = Double(thresholds.fpsTarget)
        let ratio = Double(fps) / target
        if ratio >= thresholds.fpsGreenRatio { return nil }   // default text color
        if ratio >= thresholds.fpsAmberRatio { return .yellow }
        return .red
    }

    private var healthColor: Color? {
        if healthScore >= thresholds.healthGreen { return .green }
        if healthScore >= thresholds.healthAmber { return .yellow }
        return .red
    }

    private var highlightColor: Color? {
        guard let ms = lastHighlightMs else { return .secondary }
        if ms <= thresholds.highlightGreenMs { return nil }
        if ms <= thresholds.highlightAmberMs { return .yellow }
        return .red
    }

    private var adaptiveModeColor: Color {
        switch adaptiveMode {
        case .highQuality: return .blue
        case .balanced: return .orange
        case .performance: return .red
        }
    }

    private var adaptiveModeLabel: String {
        switch adaptiveMode {
        case .highQuality: return "High Quality"
        case .balanced: return "Balanced"
        case .performance: return "Performance"
        }
    }

    private var pressureColor: Color {
        switch pressure {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }

    private var pressureLabel: String {
        switch pressure {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}

private struct MetricTile: View {
    let label: String
    let primary: String
    var primaryUnit: String? = nil
    var secondary: String? = nil
    var primaryColor: Color? = nil
    var trailingIcon: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                if let icon = trailingIcon, let action = trailingAction {
                    Button(action: action) {
                        Image(systemName: icon).font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                }
            }
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(primary)
                    .font(.system(.title3, design: .monospaced).weight(.medium))
                    .foregroundStyle(primaryColor ?? .primary)
                if let unit = primaryUnit {
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            if let secondary {
                Text(secondary)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
#endif
```

**Note for implementer:** if `PerformanceMode` or `MemoryPressure` enum cases don't exactly match (`.highQuality` / `.balanced` / `.performance` / `.normal` / `.warning` / `.critical`), adjust the switches to use the real cases.

- [ ] **Step 11.2: Run quality gate, commit**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
git add Sources/CodeEditorSample/Sidebars/PerformanceInspectorPanel.swift
git commit -m "$(cat <<'EOF'
Add PerformanceInspectorPanel view

Stateless SwiftUI view rendering the Performance Inspector in a 2-column
tile grid: FPS + Health on top row, Memory + Highlight below, with a
memory-pressure row, memory sparkline, adaptive-mode badge, and footer
linking to DetailedPerformanceReportView. Threshold-driven colors live in
a nested Thresholds struct. macOS-only via canImport(AppKit).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Wire coordinator into `AppState`

**Files:**
- Modify: `Sources/CodeEditorSample/App/AppState.swift`

- [ ] **Step 12.1: Extract `MemoryMonitor` to a stored property**

Open `Sources/CodeEditorSample/App/AppState.swift`. Find lines 30–35 where `editorController` is declared:

```swift
let editorController = EditorController()
```

Immediately below `editorController` (still inside the AppState declaration block), add:

```swift
#if canImport(AppKit)
let memoryMonitor = MemoryMonitor()
let unifiedPerformanceSystem = UnifiedPerformanceSystem()
let performance: PerformanceSampleCoordinator
#endif
```

- [ ] **Step 12.2: Update `init()`'s LSP wiring to use the shared monitor**

Find line 77:

```swift
let coordinator = LSPSampleCoordinator(memoryMonitor: MemoryMonitor())
```

Replace with:

```swift
let coordinator = LSPSampleCoordinator(memoryMonitor: memoryMonitor)
```

- [ ] **Step 12.3: Wire the Performance coordinator and configuration**

Inside the same `init()`, immediately before `self.lsp = coordinator` (or wherever LSP is assigned to self at the end), add:

```swift
        configuration.performance.unifiedPerformanceSystem = unifiedPerformanceSystem
        let perfCoordinator = PerformanceSampleCoordinator(
            memoryMonitor: memoryMonitor,
            unifiedPerformanceSystem: unifiedPerformanceSystem
        )
        perfCoordinator.attach(controller: editorController)
        self.performance = perfCoordinator
```

The exact placement depends on the existing init structure — the goal is: `configuration.performance.unifiedPerformanceSystem` is set BEFORE the editor begins highlighting (which happens once a document is loaded), and the coordinator is created with the shared monitor.

- [ ] **Step 12.4: Run quality gate**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

If `AppState` compilation fails because `configuration` is declared with a non-mutable chain, you may need to read the existing `configuration` property's declaration. Confirm it's `var configuration: EditorConfiguration` (mutable) and that `EditorConfiguration.performance` is also `var`. If anything is `let`, change to `var` at the appropriate level.

- [ ] **Step 12.5: Commit**

```bash
git add Sources/CodeEditorSample/App/AppState.swift
git commit -m "$(cat <<'EOF'
Wire PerformanceSampleCoordinator into AppState

Extract MemoryMonitor to a stored property shared between the LSP and
Performance coordinators (was inline-constructed at AppState.swift:77).
Add a stored UnifiedPerformanceSystem, install it on
configuration.performance.unifiedPerformanceSystem so the highlighter
records into the same instance the coordinator polls, and instantiate
PerformanceSampleCoordinator with attach(controller:editorController).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: Mount the panel in `InspectorSidebar`

**Files:**
- Modify: `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift`

- [ ] **Step 13.1: Add the panel mount**

Open `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift`. Find the existing `LSPInspectorPanel(...)` mount (lines 19–27).

Add a `@State private var showingReport = false` near the top of the view's body or as a stored property of the view (mirroring however the file already handles local state).

Immediately AFTER the closing `)` of `LSPInspectorPanel(...)` and BEFORE the `AnnotationsInspectorPanel(...)` line, insert:

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
            thresholds: .default(fpsTarget: appState.performance.targetFPS),
            onResetPeak: { appState.performance.resetPeak() },
            onShowReport: { showingReport = true },
            onAppear: { appState.performance.start() },
            onDisappear: { appState.performance.stop() }
        )
        .sheet(isPresented: $showingReport) {
            DetailedPerformanceReportView(
                insights: appState.unifiedPerformanceSystem.generateInsights()
            )
        }
```

**Note:** `DetailedPerformanceReportView`'s init signature should be confirmed by reading `Sources/CodeEditorPlugin/Performance/PerformanceViews.swift` line 187. If it takes a different argument (e.g., a `PerformanceMonitor` or a report object), adjust the `.sheet` content.

- [ ] **Step 13.2: Build the sample app to confirm it runs**

```bash
swift build --target CodeEditorSample
swift run CodeEditorSample
```

Visually verify: open the inspector — the Performance panel appears between LSP and Annotations, showing live (non-zero) FPS within a second, real memory usage, and the adaptive-mode badge. Click the reset-peak arrow — peak resets to current. Click "Report ›" — the detailed report sheet opens.

Kill the app afterward (per CLAUDE.md memory: kill stale CodeEditorSample/lldb processes between runs).

- [ ] **Step 13.3: Run quality gate, commit**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
git add Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift
git commit -m "$(cat <<'EOF'
Mount PerformanceInspectorPanel in InspectorSidebar

Insert between LSPInspectorPanel and AnnotationsInspectorPanel.
.onAppear/.onDisappear drive the coordinator's start/stop. Report-link
opens DetailedPerformanceReportView in a sheet using the shared
UnifiedPerformanceSystem's insights snapshot.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 14: Snapshot tests for `PerformanceInspectorPanel`

**Files:**
- Create: `Tests/CodeEditorSampleTests/PerformanceInspectorPanelSnapshotTests.swift`

- [ ] **Step 14.1: Locate an existing snapshot test for reference**

```bash
find Tests -name "*Snapshot*.swift" -type f
```

Open one of the matches and confirm:
- It uses `import SnapshotTesting` (from `swift-snapshot-testing`).
- It uses `assertSnapshot(of: ..., as: .image)` or similar.
- Initial recording uses `isRecording: true`.
- Snapshots write to a `__Snapshots__/` subdirectory next to the test file.

Mirror that structure exactly.

- [ ] **Step 14.2: Create the snapshot test file**

Create `Tests/CodeEditorSampleTests/PerformanceInspectorPanelSnapshotTests.swift`:

```swift
#if canImport(AppKit)
import SnapshotTesting
import SwiftUI
import Testing
@testable import CodeEditorPlugin
@testable import CodeEditorSample

@Suite("PerformanceInspectorPanel snapshots")
@MainActor
struct PerformanceInspectorPanelSnapshotTests {

    private func panel(
        state: PerformanceSampleCoordinator.State = .live,
        fps: Int = 58,
        memoryStats: MemoryStatistics = .init(currentUsageMB: 145, peakUsageMB: 210, averageUsageMB: 132, usageHistory: [100, 120, 145]),
        pressure: MemoryPressure = .normal,
        adaptiveMode: PerformanceMode = .highQuality,
        lastHighlightMs: Double? = 2.4,
        highlightP95Ms: Double? = 5.8,
        healthScore: Double = 82,
        issuesCount: Int = 0,
        recommendationsCount: Int = 0,
        memorySparkline: [Double] = (0..<60).map { 100 + Double($0) }
    ) -> some View {
        PerformanceInspectorPanel(
            state: state,
            fps: fps,
            memoryStats: memoryStats,
            pressure: pressure,
            adaptiveMode: adaptiveMode,
            lastHighlightMs: lastHighlightMs,
            highlightP95Ms: highlightP95Ms,
            healthScore: healthScore,
            issuesCount: issuesCount,
            recommendationsCount: recommendationsCount,
            memorySparkline: memorySparkline,
            thresholds: .default(fpsTarget: 60),
            onResetPeak: {},
            onShowReport: {},
            onAppear: {},
            onDisappear: {}
        )
        .frame(width: 360)
    }

    @Test func stoppedState() {
        let view = panel(state: .stopped, fps: 0, lastHighlightMs: nil, highlightP95Ms: nil, memorySparkline: [])
        assertSnapshot(of: NSHostingView(rootView: view), as: .image, named: "stopped")
    }

    @Test func liveHighQualityGreen() {
        assertSnapshot(of: NSHostingView(rootView: panel()), as: .image, named: "live-highquality-green")
    }

    @Test func liveBalancedAmberMemory() {
        let stats = MemoryStatistics(currentUsageMB: 1200, peakUsageMB: 1400, averageUsageMB: 900, usageHistory: (0..<80).map { 800 + Double($0 * 5) })
        let view = panel(memoryStats: stats, pressure: .warning, adaptiveMode: .balanced, healthScore: 65)
        assertSnapshot(of: NSHostingView(rootView: view), as: .image, named: "live-balanced-amber")
    }

    @Test func livePerformanceRedHighlight() {
        let view = panel(adaptiveMode: .performance, lastHighlightMs: 240, highlightP95Ms: 450, healthScore: 35)
        assertSnapshot(of: NSHostingView(rootView: view), as: .image, named: "live-performance-red")
    }

    @Test func liveCriticalPressure() {
        let view = panel(pressure: .critical, healthScore: 25, issuesCount: 3, recommendationsCount: 1)
        assertSnapshot(of: NSHostingView(rootView: view), as: .image, named: "live-critical-pressure")
    }
}
#endif
```

- [ ] **Step 14.3: Record initial snapshots**

Toggle `isRecording = true` at the top of the file:

```swift
import SnapshotTesting

@Suite("PerformanceInspectorPanel snapshots")
@MainActor
struct PerformanceInspectorPanelSnapshotTests {
    init() {
        SnapshotTesting.isRecording = true
    }
    // ...
```

Run the tests:

```bash
swift test --filter PerformanceInspectorPanelSnapshotTests
```

Expected: tests "fail" with snapshot-recorded messages — five new image files appear under `Tests/CodeEditorSampleTests/__Snapshots__/PerformanceInspectorPanelSnapshotTests/`.

- [ ] **Step 14.4: Disable recording and re-run**

Remove `SnapshotTesting.isRecording = true` from the init. Re-run:

```bash
swift test --filter PerformanceInspectorPanelSnapshotTests
```

Expected: all 5 tests pass.

- [ ] **Step 14.5: Run full quality gate, commit**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
git add Tests/CodeEditorSampleTests/PerformanceInspectorPanelSnapshotTests.swift Tests/CodeEditorSampleTests/__Snapshots__/PerformanceInspectorPanelSnapshotTests
git commit -m "$(cat <<'EOF'
Add snapshot tests for PerformanceInspectorPanel

Five fixed-state renders at 360-pt width: Stopped, Live HighQuality green,
Live Balanced amber memory, Live Performance red highlight, Live critical
pressure. Generated images committed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 4 — Final verification

### Task 15: Full project quality pipeline + sample smoke

- [ ] **Step 15.1: Run the complete quality gate**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Expected: clean build, zero lint warnings under strict mode, all tests pass.

- [ ] **Step 15.2: Smoke-run the sample**

```bash
swift run CodeEditorSample
```

- Open a Swift file with the editor.
- Confirm the inspector sidebar shows the Performance panel between LSP and Annotations.
- Confirm FPS reads non-zero within ~1 second.
- Confirm Memory shows real MB values that match Activity Monitor's reading for the process (give or take a small delta).
- Confirm the adaptive mode badge shows "High Quality" for a small file; load a large (>100KB) file and confirm it transitions to "Balanced" or "Performance".
- Edit text; confirm "Last highlight" updates and is in the single-digit-ms range for short files.
- Click "Reset" arrow next to Peak — peak drops to current.
- Click "Report ›" — the detailed performance report sheet opens.
- Collapse the inspector — coordinator stops (verify by hovering near 1-2s and watching FPS readout in the briefly-visible panel before close).

- [ ] **Step 15.3: Kill the sample process cleanly**

Per the `feedback_process_hygiene` memory: ensure no stale `CodeEditorSample` or `lldb` processes remain.

```bash
pgrep -fl CodeEditorSample || echo "No stragglers"
```

If any are listed, `kill <pid>`.

- [ ] **Step 15.4: If anything in 15.2 failed, file it as a follow-up task and re-run the affected phase**

No commit in this task — Step 15.5's NEXT.md update is the closing commit.

- [ ] **Step 15.5: Update NEXT.md**

Open `NEXT.md` and find the "Performance HUD missing" bullet. Replace it with a "✅ complete" entry matching the LSP entry's style (`Performance HUD — ✅ complete (2026-05-13).` plus a brief summary linking to this spec and plan). Strike-through `PerformanceInspectorPanel` in the "What needs to be presented" table. Update the "Recommended next step" paragraph to point to the EventLog panel as the new next-up.

Commit:

```bash
git add NEXT.md
git commit -m "$(cat <<'EOF'
Mark Performance HUD gap as complete in NEXT.md

Performance Inspector panel + targeted framework changes (FrameRateMonitor,
PerformanceInsights placeholders fixed, MemoryMonitor.resetPeak,
EditorConfiguration.performance.unifiedPerformanceSystem,
EditorController.adaptivePerformanceMode, syntax-highlighter
instrumentation) all shipped. Next recommended gap is EventLog panel.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review (writing-plans checklist)

### Spec coverage

| Spec requirement | Plan task |
|---|---|
| `PerformanceSampleCoordinator` (Sec. Components) | Task 10 |
| `PerformanceInspectorPanel` view (Sec. Components) | Task 11 |
| `FrameRateMonitor` (4.1) | Task 1 |
| `PerformanceInsights` FPS placeholder fix (4.2) | Task 5 |
| `PerformanceInsights` CPU placeholder fix (4.2) | Task 6 |
| `EditorConfiguration.performance.unifiedPerformanceSystem` (4.3) | Task 7 |
| `EditorController.adaptivePerformanceMode` accessor (4.4) | Task 8 |
| Syntax highlighter instrumentation (4.5) | Tasks 4 (`track` overload) + 9 (wrap) |
| `MemoryMonitor.resetPeak()` (4.6) | Task 2 |
| Wiring in `AppState` (Sec. Wiring summary) | Task 12 |
| Mount in `InspectorSidebar` (Sec. Wiring summary) | Task 13 |
| Five panel snapshot states (Sec. Testing) | Task 14 |
| Coordinator unit tests (Sec. Testing) | Task 10 |
| Framework unit tests (Sec. Testing) | Tasks 1, 2, 4, 5, 6, 7, 8, 9 |
| Quality gate / NEXT.md update | Task 15 |

All spec requirements have a task. Step 14.2's `MemoryStatistics(...)` initializer assumes a public memberwise init — if the framework's `MemoryStatistics` is `public struct` with public fields it should synthesize one; if not, the test helpers build via `MemoryMonitor.mock(...)` and then mutate `memoryStats` directly. Implementer note: confirm before recording.

### Placeholder scan

The plan contains two **deliberate** implementer-note placeholders (not the kind the writing-plans skill forbids):

1. **Task 9 Step 9.3** — "Plan placeholder: see existing AsyncSyntaxHighlighter tests, mirror one." This is unavoidable without reading the AsyncSyntaxHighlighter test setup, which would balloon plan size. The implementer is given a precise navigation hint (`Tests/CodeEditorPluginTests/SyntaxHighlighting/`), the smallest fallback reproducer description, and the exact assertions to keep — that's complete enough.

2. **Task 7 Step 7.3** — "Find the `init(from decoder:)` ... at the END of the init body, add `self.unifiedPerformanceSystem = nil`." The exact lines aren't shown because the existing init body wasn't quoted. The implementer is given a single, mechanically-applicable instruction.

These are not "implement later" / "TBD" / "fill in details" — they are precise hand-offs of a small, well-scoped lookup. No vague verbiage like "add appropriate error handling".

### Type consistency

- `PerformanceSampleCoordinator.State` (cases `.stopped`, `.live`) is used identically in Task 10, Task 11, Task 14.
- `MemoryStatistics.currentUsageMB / peakUsageMB / averageUsageMB / usageHistory` referenced in Tasks 2, 3, 10, 11, 14 — all consistent.
- `PerformanceMode.highQuality / .balanced / .performance` referenced in Tasks 11, 14 — consistent.
- `MemoryPressure.normal / .warning / .critical` referenced in Tasks 10, 11, 14 — consistent.
- `Thresholds.default(fpsTarget:)` called identically in Task 11 (definition) and Task 13 (call site).
- `FrameRateMonitor.startMonitoring() / stopMonitoring() / currentFPS / averageFPS` — definitions in Task 1 match all consumers in Tasks 5, 6, 10.
- `PerformanceInsights.init(memoryMonitor:frameRateMonitor:performanceMonitor:capabilities:)` — added in Task 5, consumed in Tasks 6, 10.
- `MemoryMonitor.mock(currentUsageMB:peakUsageMB:averageUsageMB:usageHistory:isUnderPressure:)` — defined Task 3, consumed Tasks 10, 14.
- `UnifiedPerformanceSystem.track(_:operation:)` non-throwing overload — defined Task 4, used Task 9.
- `EditorController.adaptivePerformanceMode` — defined Task 8 (returns `AdaptivePerformanceMode?`), consumed Task 10 (`coordinator.attach(controller:)` captures it weakly).
- `EditorConfiguration.Performance.unifiedPerformanceSystem` — defined Task 7, set Task 12, read Task 9.

No drift detected.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-13-sample-app-performance-inspector.md`. Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
