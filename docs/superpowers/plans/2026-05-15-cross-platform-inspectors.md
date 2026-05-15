# Cross-Platform Inspector Panels + iPad 3-Column NavigationSplitView — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the combined NEXT.md A.3 #7 (iOS feature parity, inspector slice) + A.3 #9 (shared scene, content-fragment shape) deliverable. Extract `InspectorPanelStack` as a cross-platform view both platforms host; drop AppKit gates on the four inspector panel views, the two sample coordinators (`Performance`/`Completion`), the `EditorSidebarShell`, and the relevant `AppState` properties; promote iPad to a 3-column `NavigationSplitView` with a toolbar-toggleable inspector column. iOS LSP panel renders a disabled toggle + footnote until B.1 lands.

**Architecture:** No framework changes. One UI-package gate removal (`EditorSidebarShell`) plus a series of sample-side edits: new `InspectorPanelStack.swift`, new `Pasteboard.swift` helper, gate drops on six existing sample files, property rearrangement in `AppState`, three-column `NavigationSplitView` reshape in `IOSRootView`.

**Tech Stack:** Swift 6.3 (`StrictConcurrency`), SwiftUI, AppKit (macOS), UIKit (iOS), Swift Testing, XCTest, swift-snapshot-testing.

**Spec:** `docs/superpowers/specs/2026-05-15-cross-platform-inspectors-design.md`

---

## File structure

| Path | Status | Responsibility |
|---|---|---|
| `Sources/CodeEditorSample/Extensions/Pasteboard.swift` | Create | Cross-platform `Pasteboard.writeString(_:)` (`NSPasteboard` on macOS, `UIPasteboard` on iOS). |
| `Sources/CodeEditorSample/Sidebars/InspectorPanelStack.swift` | Create | Cross-platform ScrollView composing LSP / Performance / Completion / Annotations / EventLog / Config panels + Copy button. Hosted by macOS `InspectorSidebar` and `IOSRootView`. |
| `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift` | Rewrite | Shrink to thin `EditorSidebarShell { InspectorPanelStack(...) }` wrapper; macOS-only. |
| `Sources/CodeEditorSample/Sidebars/LSPInspectorPanel.swift` | Modify | Drop `#if canImport(AppKit)` top-level gate. |
| `Sources/CodeEditorSample/Sidebars/PerformanceInspectorPanel.swift` | Modify | Drop `#if canImport(AppKit)` top-level gate. |
| `Sources/CodeEditorSample/Sidebars/CompletionInspectorPanel.swift` | Modify | Drop `#if canImport(AppKit)` top-level gate. |
| `Sources/CodeEditorSample/Sidebars/AnnotationsInspectorPanel.swift` | Modify | Drop `#if canImport(AppKit)` top-level gate. |
| `Sources/CodeEditorUI/Sidebar/EditorSidebarShell.swift` | Modify | Drop `#if canImport(AppKit)`; rewrite docstring. |
| `Sources/CodeEditorSample/App/Performance/PerformanceSampleCoordinator.swift` | Modify | Drop `#if canImport(AppKit)` + `import AppKit`; replace `NSScreen.main…` with `Self.screenMaxFPS()` platform helper. |
| `Sources/CodeEditorSample/App/Completion/CompletionSampleCoordinator.swift` | Modify | Drop `#if canImport(AppKit)` + `import AppKit` (no AppKit symbols used). |
| `Sources/CodeEditorSample/App/AppState.swift` | Modify | Move `memoryMonitor`, `performanceObservation`, `performance`, `completion` out of the `#if canImport(AppKit)` block; keep `lsp` gated. |
| `Sources/CodeEditorSample/iOS/IOSRootView.swift` | Rewrite | 3-column `NavigationSplitView`; toolbar inspector toggle (gated on `hSizeClass != .compact`); `.inspectors` destination renders `InspectorPanelStack`; delete `inspectorsUnavailable`; restore `.performanceObserver(_:)` on the editor pane. |
| `Tests/CodeEditorSampleTests/PasteboardTests.swift` | Create | Round-trip smoke test for `Pasteboard.writeString`. |
| `Tests/CodeEditorSampleTests/PerformanceSampleCoordinatorTests.swift` | Modify | Drop top-level `#if canImport(AppKit)` and `import AppKit` so the existing suite runs on both platforms (cross-platform smoke). |
| `Tests/CodeEditorSampleTests/CompletionSampleCoordinatorTests.swift` | Modify | Drop top-level `#if canImport(AppKit)` and `import AppKit`. |
| `Tests/CodeEditorSampleTests/InspectorPanelStackSnapshotTests.swift` | Create | Snapshot tests for the new view on macOS (with a fixture `AppState`). |
| `NEXT.md` | Modify | Mark the inspector slice of A.3 #7 done; record A.3 #9 outcome (content-fragment sharing, no `EditorWorkspaceScene` wrapper). |

---

## Task 1: `Pasteboard.writeString(_:)` helper (TDD)

The only AppKit-hard call in the sample inspector path. Land the helper + test first so later tasks can route through it.

**Files:**
- Create: `Sources/CodeEditorSample/Extensions/Pasteboard.swift`
- Test: `Tests/CodeEditorSampleTests/PasteboardTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/CodeEditorSampleTests/PasteboardTests.swift`:

```swift
@testable import CodeEditorSample
import Testing

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
@Suite("Pasteboard helper")
struct PasteboardTests {
    @Test("writeString round-trips through the platform pasteboard")
    func writeRoundTrips() {
        let sentinel = "round-trip-\(UUID().uuidString)"
        Pasteboard.writeString(sentinel)

        #if canImport(AppKit)
        let read = NSPasteboard.general.string(forType: .string)
        #elseif canImport(UIKit)
        let read = UIPasteboard.general.string
        #else
        let read: String? = nil
        #endif

        #expect(read == sentinel)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PasteboardTests`
Expected: **FAIL** with "cannot find 'Pasteboard' in scope".

- [ ] **Step 3: Implement `Pasteboard.writeString`**

Create `Sources/CodeEditorSample/Extensions/Pasteboard.swift`:

```swift
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Cross-platform string pasteboard write. Used by the sample's
/// inspector Copy button. Sample-side helper — the framework does not
/// need a pasteboard surface today.
enum Pasteboard {
    @MainActor
    static func writeString(_ string: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = string
        #endif
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter PasteboardTests`
Expected: **PASS**.

- [ ] **Step 5: Lint and commit**

```bash
swiftlint --fix Sources/CodeEditorSample/Extensions/Pasteboard.swift Tests/CodeEditorSampleTests/PasteboardTests.swift
swiftlint Sources/CodeEditorSample/Extensions/Pasteboard.swift Tests/CodeEditorSampleTests/PasteboardTests.swift
git add Sources/CodeEditorSample/Extensions/Pasteboard.swift Tests/CodeEditorSampleTests/PasteboardTests.swift
git commit -m "Sample: Pasteboard.writeString cross-platform helper"
```

---

## Task 2: Drop `CompletionSampleCoordinator` AppKit gate

The coordinator body has no AppKit symbols; the gate is defensive only. Drop it so the type is available on iOS.

**Files:**
- Modify: `Sources/CodeEditorSample/App/Completion/CompletionSampleCoordinator.swift`
- Modify: `Tests/CodeEditorSampleTests/CompletionSampleCoordinatorTests.swift`

- [ ] **Step 1: Run existing tests on macOS to establish a green baseline**

Run: `swift test --filter CompletionSampleCoordinator`
Expected: **PASS** (existing suite already runs on macOS).

- [ ] **Step 2: Drop the top-level gate + `import AppKit` from the coordinator**

In `Sources/CodeEditorSample/App/Completion/CompletionSampleCoordinator.swift`, replace the first two lines:

```swift
#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
```

with:

```swift
import CodeEditorPlugin
```

And remove the trailing `#endif` at the bottom of the file.

- [ ] **Step 3: Drop the test file gate + `import AppKit`**

In `Tests/CodeEditorSampleTests/CompletionSampleCoordinatorTests.swift`, replace:

```swift
#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing
```

with:

```swift
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing
```

And remove the trailing `#endif`.

- [ ] **Step 4: Build for both platforms (macOS triple plus iOS-simulator triple)**

Run on macOS:
```bash
swift build --target CodeEditorSample
swift test --filter CompletionSampleCoordinator
```
Expected: **PASS**.

Manual iOS-build check (covered again in Task 11; if Xcode is available locally, surface failures earlier):
```bash
xcrun xcodebuild -scheme CodeEditorSample -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```
Expected: **PASS** (no `'CompletionSampleCoordinator' is unavailable on this platform`).

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorSample/App/Completion/CompletionSampleCoordinator.swift Tests/CodeEditorSampleTests/CompletionSampleCoordinatorTests.swift
git commit -m "Sample: drop AppKit gate on CompletionSampleCoordinator"
```

---

## Task 3: `PerformanceSampleCoordinator` cross-platform + `screenMaxFPS()`

Drop the AppKit gate and replace the one `NSScreen.main` access with a platform-branching helper.

**Files:**
- Modify: `Sources/CodeEditorSample/App/Performance/PerformanceSampleCoordinator.swift`
- Modify: `Tests/CodeEditorSampleTests/PerformanceSampleCoordinatorTests.swift`

- [ ] **Step 1: Run existing tests to establish baseline**

Run: `swift test --filter PerformanceSampleCoordinator`
Expected: **PASS**.

- [ ] **Step 2: Modify the coordinator header**

In `Sources/CodeEditorSample/App/Performance/PerformanceSampleCoordinator.swift`, replace the first four lines:

```swift
#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
import Foundation
```

with:

```swift
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import CodeEditorPlugin
import Foundation
```

And remove the trailing `#endif` at end of file.

- [ ] **Step 3: Add the `screenMaxFPS()` helper and use it**

Find this line (currently around line 66):

```swift
        self.targetFPS = NSScreen.main?.maximumFramesPerSecond ?? 60
```

Replace with:

```swift
        self.targetFPS = Self.screenMaxFPS()
```

Add the helper as a private static method on the type (place it just above `init`):

```swift
    /// Platform's max screen refresh rate, with a 60 fallback. Used as
    /// the `targetFPS` baseline for the performance inspector.
    private static func screenMaxFPS() -> Int {
        #if canImport(AppKit)
        return NSScreen.main?.maximumFramesPerSecond ?? 60
        #elseif canImport(UIKit)
        return UIScreen.main.maximumFramesPerSecond
        #else
        return 60
        #endif
    }
```

- [ ] **Step 4: Drop the test file gate**

In `Tests/CodeEditorSampleTests/PerformanceSampleCoordinatorTests.swift`, replace:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
import Testing
```

with:

```swift
import CodeEditorPlugin
@testable import CodeEditorSample
import Testing
```

And remove the trailing `#endif`.

- [ ] **Step 5: Verify macOS build + tests still green**

Run:
```bash
swift build --target CodeEditorSample
swift test --filter PerformanceSampleCoordinator
```
Expected: **PASS**.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorSample/App/Performance/PerformanceSampleCoordinator.swift Tests/CodeEditorSampleTests/PerformanceSampleCoordinatorTests.swift
git commit -m "Sample: drop AppKit gate on PerformanceSampleCoordinator + screenMaxFPS"
```

---

## Task 4: Drop AppKit gates on the four inspector panel views

`LSPInspectorPanel`, `PerformanceInspectorPanel`, `CompletionInspectorPanel`, `AnnotationsInspectorPanel` are pure SwiftUI inside. The gates were transitive (they used to live inside the macOS-only `EditorSidebarShell`).

**Files:**
- Modify: `Sources/CodeEditorSample/Sidebars/LSPInspectorPanel.swift`
- Modify: `Sources/CodeEditorSample/Sidebars/PerformanceInspectorPanel.swift`
- Modify: `Sources/CodeEditorSample/Sidebars/CompletionInspectorPanel.swift`
- Modify: `Sources/CodeEditorSample/Sidebars/AnnotationsInspectorPanel.swift`

- [ ] **Step 1: Drop gate from `LSPInspectorPanel.swift`**

Replace the first lines:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import SwiftUI
```

with:

```swift
import CodeEditorPlugin
import SwiftUI
```

And remove the trailing `#endif`.

- [ ] **Step 2: Drop gate from `PerformanceInspectorPanel.swift`**

Same pattern. Replace the top `#if canImport(AppKit)` and the bottom `#endif`.

- [ ] **Step 3: Drop gate from `CompletionInspectorPanel.swift`**

Same pattern.

- [ ] **Step 4: Drop gate from `AnnotationsInspectorPanel.swift`**

Same pattern. Verify the file still compiles — it uses `CodeEditorDesignTokens`, `CodeEditorPlugin`, and `SwiftUI`, none of which are AppKit-gated.

- [ ] **Step 5: Verify build still passes**

Run:
```bash
swift build --target CodeEditorSample
```
Expected: **PASS** on macOS.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorSample/Sidebars/LSPInspectorPanel.swift Sources/CodeEditorSample/Sidebars/PerformanceInspectorPanel.swift Sources/CodeEditorSample/Sidebars/CompletionInspectorPanel.swift Sources/CodeEditorSample/Sidebars/AnnotationsInspectorPanel.swift
git commit -m "Sample: drop AppKit gates on inspector panel views"
```

---

## Task 5: Drop AppKit gate on `EditorSidebarShell` + docstring rewrite

The shell's only platform-specific call is `.platformGlassSurface(.panel)`, which is itself fully cross-platform.

**Files:**
- Modify: `Sources/CodeEditorUI/Sidebar/EditorSidebarShell.swift`

- [ ] **Step 1: Drop the top-level gate**

Replace the first line `#if canImport(AppKit)` (and matching trailing `#endif`) with nothing — the file becomes ungated.

- [ ] **Step 2: Rewrite the docstring**

Find the docstring on `EditorSidebarShell` (around line 17-19):

```swift
/// Available on macOS. Absent on iOS — sidebars on
/// iPad have a different navigation idiom and aren't covered by this
/// component.
```

Replace with:

```swift
/// Used by both platforms. Renders a glass-backed panel with optional
/// section/prominent header, content slot, and footer slot. Pure
/// SwiftUI — `.platformGlassSurface(.panel)` provides the chrome.
```

- [ ] **Step 3: Verify build still passes**

Run:
```bash
swift build --target CodeEditorUI
swift build --target CodeEditorSample
```
Expected: **PASS**.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorUI/Sidebar/EditorSidebarShell.swift
git commit -m "CodeEditorUI: drop AppKit gate on EditorSidebarShell"
```

---

## Task 6: Move `AppState` coordinator properties out of the `#if` block

After Tasks 2/3, `PerformanceSampleCoordinator` and `CompletionSampleCoordinator` (and the framework's `MemoryMonitor` / `PerformanceObservation`, which were already cross-platform) compile on iOS. Move their properties + init wiring out of the `#if canImport(AppKit)` block.

**Files:**
- Modify: `Sources/CodeEditorSample/App/AppState.swift`

- [ ] **Step 1: Move property declarations**

Locate the `#if canImport(AppKit)` block around lines 85–109 (the one starting `let memoryMonitor = MemoryMonitor()`). Split it into two blocks:

Replace:
```swift
    #if canImport(AppKit)
    /// Shared `MemoryMonitor` instance fed into both `lsp` and
    /// `performance` coordinators so the panel readouts and LSP
    /// coordination agree on a single source of memory truth.
    let memoryMonitor = MemoryMonitor()

    /// Shared `PerformanceObservation` instance. Installed onto the
    /// editor view via `.performanceObserver(_:)`.
    let performanceObservation = PerformanceObservation(refreshInterval: .seconds(1))

    /// Sample-side LSP coordinator. Owns the `LSPManager`, document
    /// mirroring, and the diagnostics bridge. macOS-only. IUO for the
    /// same reason as `documents` — coordinator wiring closures must
    /// `[weak self]` capture, which the DI analyzer rejects during
    /// `let` field initialization. Set once in `init()`.
    private(set) var lsp: LSPSampleCoordinator! // swiftlint:disable:this implicitly_unwrapped_optional

    /// Sample-side Performance Inspector coordinator. macOS-only.
    /// IUO; see `lsp` above.
    private(set) var performance: PerformanceSampleCoordinator! // swiftlint:disable:this implicitly_unwrapped_optional

    /// Sample-side Completion Inspector coordinator. macOS-only.
    /// IUO; see `lsp` above.
    private(set) var completion: CompletionSampleCoordinator! // swiftlint:disable:this implicitly_unwrapped_optional
    #endif
```

with:
```swift
    /// Shared `MemoryMonitor` instance fed into the `performance`
    /// coordinator (and into `lsp` on macOS) so memory readouts agree
    /// on a single source of truth.
    let memoryMonitor = MemoryMonitor()

    /// Shared `PerformanceObservation` instance. Installed onto the
    /// editor view via `.performanceObserver(_:)`.
    let performanceObservation = PerformanceObservation(refreshInterval: .seconds(1))

    /// Sample-side Performance Inspector coordinator. Cross-platform.
    /// IUO; see `documents` rationale.
    private(set) var performance: PerformanceSampleCoordinator! // swiftlint:disable:this implicitly_unwrapped_optional

    /// Sample-side Completion Inspector coordinator. Cross-platform.
    /// IUO; see `documents` rationale.
    private(set) var completion: CompletionSampleCoordinator! // swiftlint:disable:this implicitly_unwrapped_optional

    #if canImport(AppKit)
    /// Sample-side LSP coordinator. Owns the `LSPManager`, document
    /// mirroring, and the diagnostics bridge. macOS-only because
    /// `LSPManager` itself is AppKit-gated until B.1 iOS coverage lands.
    /// IUO; see `documents` rationale.
    private(set) var lsp: LSPSampleCoordinator! // swiftlint:disable:this implicitly_unwrapped_optional
    #endif
```

- [ ] **Step 2: Move init wiring**

Locate the `#if canImport(AppKit)` block inside `init()` around lines 126–159 (starting `let coordinator = LSPSampleCoordinator(...)`).

Inside it, the `// Performance Inspector wiring.` block and the `CompletionSampleCoordinator` block need to move OUT of the `#if` so they run on both platforms. The `LSPSampleCoordinator` block stays gated.

Replace the existing block with:

```swift
        #if canImport(AppKit)
        let coordinator = LSPSampleCoordinator(memoryMonitor: memoryMonitor)
        self.lsp = coordinator
        let storeRef = documents.store
        let editorControllerRef = documents.editorController
        coordinator.attach(
            controller: editorControllerRef,
            hub: hub
        ) { [weak coordinator, weak storeRef] in
            guard let coordinator,
                  let store = storeRef,
                  let activeID = store.activeID,
                  let url = coordinator.mirrorURL(for: activeID) else { return nil }
            return "file://" + url.path
        }
        coordinator.onRequestOpen = { [weak storeRef] url in
            storeRef?.openFile(url: url)
        }
        coordinator.onRequestScroll = { [weak editorControllerRef] line in
            editorControllerRef?.gotoLine(line)
        }
        #endif

        // Performance Inspector wiring. Cross-platform.
        let perfCoordinator = PerformanceSampleCoordinator(
            memoryMonitor: memoryMonitor,
            performanceObservation: performanceObservation
        )
        perfCoordinator.attach(controller: documents.editorController)
        self.performance = perfCoordinator

        // Completion Inspector wiring. Cross-platform.
        let completionCoordinator = CompletionSampleCoordinator()
        self.completion = completionCoordinator
        completionCoordinator.attach(controller: documents.editorController)
```

- [ ] **Step 3: Verify build**

Run:
```bash
swift build --target CodeEditorSample
swift test --filter AppState
swift test --filter PerformanceSampleCoordinator
swift test --filter CompletionSampleCoordinator
```
Expected: **PASS**.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/App/AppState.swift
git commit -m "Sample: move Performance/Completion coordinators out of AppKit #if"
```

---

## Task 7: Create `InspectorPanelStack`

The cross-platform composition view. Lifted out of `InspectorSidebar` so both `InspectorSidebar` (macOS chrome wrapper) and `IOSRootView` can host it.

**Files:**
- Create: `Sources/CodeEditorSample/Sidebars/InspectorPanelStack.swift`

- [ ] **Step 1: Create the file**

```swift
import CodeEditorPlugin
import SwiftUI

/// Cross-platform composition of the six inspector panels. Reads
/// everything off `AppState`; owns no state itself except the
/// performance-report sheet `Binding`, which the host passes in so
/// the sheet survives column-visibility toggles on iPad.
///
/// Hosted by:
/// - macOS `InspectorSidebar` (wrapped in `EditorSidebarShell`).
/// - `IOSRootView`'s 3-column `NavigationSplitView` detail column.
/// - `IOSRootView`'s `.inspectors` sidebar destination (rendered raw
///   in the content column).
///
/// On iOS the LSP panel renders with hardcoded `.off` inputs and a
/// footnote naming the constraint; real iOS LSP data lands with the
/// B.1 LSP iOS coverage rollout.
struct InspectorPanelStack: View {
    @Environment(\.codeEditorTheme) private var theme
    @Bindable var appState: AppState
    @Binding var showingPerformanceReport: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                lspPanel
                performancePanel
                completionPanel
                AnnotationsInspectorPanel(
                    hub: appState.annotationsHub,
                    controller: appState.documents.editorController
                )
                eventLogPanel
                configurationCard
            }
        }
        .sheet(isPresented: $showingPerformanceReport) {
            VStack(spacing: 16) {
                PerformanceInsightsPanel(insights: appState.performance.performanceInsights)
                    .padding([.horizontal, .top])
                DetailedPerformanceReportView(insights: appState.performance.performanceInsights)
            }
            .frame(minWidth: 520, minHeight: 540)
        }
    }

    // MARK: - LSP panel (platform-branched)

    @ViewBuilder
    private var lspPanel: some View {
        #if canImport(AppKit)
        LSPInspectorPanel(
            state: appState.lsp.state,
            counts: appState.lsp.diagnosticCounts,
            serverPath: appState.lsp.resolvedServerPath,
            lastError: appState.lsp.lastError,
            isSwiftActive: appState.documents.store.active?.language == .swift,
            onToggle: { handleLSPToggle() }
        )
        #else
        LSPInspectorPanel(
            state: .off,
            counts: .empty,
            serverPath: nil,
            lastError: nil,
            isSwiftActive: false,
            onToggle: {}
        )
        Text("iOS: remote-server support arrives with the LSP iOS coverage rollout.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        #endif
    }

    #if canImport(AppKit)
    private func handleLSPToggle() {
        Task {
            switch appState.lsp.state {
            case .off, .failed:
                await appState.lsp.start(workspaceRoot: appState.workspaceRoot)
                if case .running = appState.lsp.state {
                    for doc in appState.documents.store.documents where doc.language == .swift {
                        await appState.lsp.openTab(id: doc.id, text: doc.text, language: .swift)
                    }
                }
            case .running:
                await appState.lsp.stop()
            default:
                break
            }
        }
    }
    #endif

    // MARK: - Performance panel

    private var performancePanel: some View {
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
            onShowReport: { showingPerformanceReport = true },
            onAppear: {
                appState.performance.start()
                appState.performanceObservation.start()
            },
            onDisappear: {
                appState.performance.stop()
                appState.performanceObservation.stop()
            }
        )
    }

    // MARK: - Completion panel

    private var completionPanel: some View {
        CompletionInspectorPanel(
            registeredProviders: appState.completion.snapshot.registeredProviders,
            recentActivity: appState.completion.snapshot.recentActivity,
            lastActivity: appState.completion.snapshot.lastActivity,
            requests: appState.completion.snapshot.requests,
            cacheHitRate: appState.completion.snapshot.cacheHitRate,
            avgProcessingMs: appState.completion.snapshot.avgProcessingMs,
            onFireAtCursor: { appState.completion.fireAtCursor() },
            onClear: { appState.completion.resetActivity() },
            onAppear: { appState.completion.start() },
            onDisappear: { appState.completion.stop() }
        )
    }

    // MARK: - Event log panel

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

    // MARK: - Configuration card (text + Copy)

    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ConfigurationCodeFormatter.render(appState.configuration.current))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color(tokens: theme.style.text.base))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            HStack {
                Spacer()
                Button("Copy") {
                    Pasteboard.writeString(
                        ConfigurationCodeFormatter.render(appState.configuration.current)
                    )
                }
                .controlSize(.small)
            }
        }
        .padding(12)
    }
}
```

Notes for the implementer:
- `LSPInspectorPanel.counts` accepts a `DiagnosticsBridge.Counts`; the `.empty` static lives next to the type. If `DiagnosticsBridge.Counts.empty` is gated to AppKit (it's in the LSP folder), drop that gate too OR inline the zero-initialised counts at the iOS call site — verify which during implementation.
- `PerformanceInsightsPanel` and `DetailedPerformanceReportView` are framework types from `CodeEditorPlugin` — cross-platform.
- `appState.completion.fireAtCursor()` / `resetActivity()` / `start()` / `stop()` must exist on the cross-platform coordinator after Task 2.

- [ ] **Step 2: Build to surface any cross-platform gaps**

Run:
```bash
swift build --target CodeEditorSample
```

If `DiagnosticsBridge.Counts.empty` or related LSP-side types are AppKit-gated and used in the iOS branch, drop their gates too OR replace with inline `DiagnosticsBridge.Counts(errors: 0, warnings: 0, infos: 0, hints: 0)` (verify field names at the source file).

- [ ] **Step 3: Lint**

Run:
```bash
swiftlint --fix Sources/CodeEditorSample/Sidebars/InspectorPanelStack.swift
swiftlint Sources/CodeEditorSample/Sidebars/InspectorPanelStack.swift
```
Expected: clean.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/Sidebars/InspectorPanelStack.swift
git commit -m "Sample: introduce InspectorPanelStack (cross-platform inspector composition)"
```

---

## Task 8: Shrink `InspectorSidebar` to a thin shell wrapper

`InspectorSidebar` becomes a macOS-only chrome wrapper around `InspectorPanelStack`. The body shrinks from ~165 lines to ~15.

**Files:**
- Rewrite: `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift`

- [ ] **Step 1: Replace the file body**

Replace the entire contents of `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift` with:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Right-rail inspector chrome for macOS. Wraps `InspectorPanelStack`
/// in an `EditorSidebarShell` and pins a fixed 360-pt width. The
/// stack reads from `AppState` and owns the panel composition; this
/// view owns only the macOS-specific chrome and the performance-report
/// sheet binding.
struct InspectorSidebar: View {
    @Bindable var appState: AppState
    @State private var showingPerformanceReport = false

    var body: some View {
        EditorSidebarShell(
            sectionTitle: "Configuration",
            content: {
                InspectorPanelStack(
                    appState: appState,
                    showingPerformanceReport: $showingPerformanceReport
                )
            }
        )
        .frame(width: 360)
    }
}
#endif
```

- [ ] **Step 2: Verify macOS build + visual regression**

Run:
```bash
swift build --target CodeEditorSample
swift run CodeEditorSample
```

Click around: the inspector sidebar on the right should render LSP / Performance / Completion / Annotations / EventLog / Config + Copy button. Verify Copy still writes to the pasteboard.

Note one expected visual delta: the Copy button moves from the floating `EditorSidebarShell` footer into the bottom of the configuration card (inside the scroll). This is intentional — `InspectorPanelStack` carries Copy with the config text it copies. Everything else renders identically.

- [ ] **Step 3: Lint and commit**

```bash
swiftlint --fix Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift
swiftlint Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift
git add Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift
git commit -m "Sample: shrink InspectorSidebar to EditorSidebarShell + InspectorPanelStack"
```

---

## Task 9: `IOSRootView` 3-column NavigationSplitView + inspector rail

Reshape `IOSRootView` so iPad gets a 3-column layout with a user-toggleable inspector column; iPhone falls back to single-column behaviour automatically.

**Files:**
- Rewrite: `Sources/CodeEditorSample/iOS/IOSRootView.swift`

- [ ] **Step 1: Replace the file body**

Replace the entire `IOSRootView` body and helpers with:

```swift
#if !canImport(AppKit)
import CodeEditorPlugin
import SwiftUI

/// iOS / iPadOS root scene for the sample. On iPad: 3-column
/// `NavigationSplitView` with a toolbar-toggleable inspector column.
/// On iPhone: collapses to single-stack navigation automatically; the
/// inspector toolbar button is hidden in compact width classes.
struct IOSRootView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Bindable var appState: AppState

    @State private var sidebarSelection: IOSSidebarSection? = .editor
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var showingPerformanceReport = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } content: {
            detail(for: selectedSection)
                .navigationTitle(title(for: selectedSection))
                .toolbar { toolbar(documents: appState.documents.store) }
        } detail: {
            inspectorRail
        }
        .onChange(of: sidebarSelection) { _, newValue in
            if newValue != .editor {
                columnVisibility = .doubleColumn
            }
        }
        .codeTheme(appState.theme.current)
        .preferredColorScheme(appState.theme.current.appearance == .dark ? .dark : .light)
        .sheet(item: $appState.documents.pendingSaveAs) { state in
            ExportDocumentSheet(
                temporaryURL: state.temporaryURL,
                onPick: { url in
                    appState.documents.finalizeSaveAs(to: url)
                    appState.documents.pendingSaveAs = nil
                },
                onCancel: { appState.documents.pendingSaveAs = nil }
            )
        }
        .sheet(isPresented: $appState.documents.pendingOpenFile) {
            ImportDocumentSheet(
                onPick: { url in
                    appState.documents.store.openFile(url: url)
                    appState.documents.pendingOpenFile = false
                },
                onCancel: { appState.documents.pendingOpenFile = false }
            )
        }
    }

    private var sidebar: some View {
        List(selection: $sidebarSelection) {
            ForEach(IOSSidebarSection.allCases) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.icon)
                }
            }
        }
        .navigationTitle("CodeEditorSample")
    }

    private var selectedSection: IOSSidebarSection {
        sidebarSelection ?? .editor
    }

    @ViewBuilder
    private func detail(for section: IOSSidebarSection) -> some View {
        switch section {
        case .editor:
            editor
        case .settings:
            settingsPanel
        case .themes:
            themePanel
        case .languages:
            languagePanel
        case .inspectors:
            InspectorPanelStack(
                appState: appState,
                showingPerformanceReport: $showingPerformanceReport
            )
        }
    }

    private func title(for section: IOSSidebarSection) -> String {
        switch section {
        case .editor:
            return appState.documents.store.active?.name ?? "Editor"
        case .settings:
            return "Editor Settings"
        case .themes:
            return "Themes"
        case .languages:
            return "Languages"
        case .inspectors:
            return "Inspectors"
        }
    }

    @ViewBuilder
    private var inspectorRail: some View {
        if selectedSection == .editor {
            InspectorPanelStack(
                appState: appState,
                showingPerformanceReport: $showingPerformanceReport
            )
            .navigationTitle("Inspectors")
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var editor: some View {
        if appState.documents.store.active != nil {
            CodeEditor()
                .editorController(appState.documents.editorController)
                .activeDocument(in: appState.documents.store)
                .environment(\.codeEditorConfiguration, appState.configuration.current)
                .codeTheme(appState.theme.current)
                .codeWorkspaceRoot(appState.workspaceRoot)
                .becomeFirstResponder()
                .eventSystem(appState.eventSystem)
                .performanceObserver(appState.performanceObservation)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No tabs open",
                systemImage: "doc.text",
                description: Text("Tap + in the toolbar to start a new document.")
            )
        }
    }

    private var settingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                DisplayKnobsSection(configuration: appState.configuration, expansion: .always)
                LayoutKnobsSection(configuration: appState.configuration, expansion: .always)
                BehaviorKnobsSection(configuration: appState.configuration, expansion: .always)
                PerformanceKnobsSection(configuration: appState.configuration, expansion: .always)
                WorkspaceKnobsSection(workspaceRoot: $appState.workspaceRoot, expansion: .always)
                AnnotationsKnobsSection(appState: appState, expansion: .always)
            }
            .padding(.vertical, 12)
        }
    }

    private var themePanel: some View {
        List {
            ForEach(ThemeCatalog.all, id: \.name) { theme in
                Button {
                    appState.theme.current = ThemeCatalog.theme(named: theme.name)
                } label: {
                    Label(
                        theme.name,
                        systemImage: theme.name == appState.theme.current.name ? "checkmark.circle.fill" : "circle"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var languagePanel: some View {
        if let activeID = appState.documents.store.activeID {
            List {
                ForEach(LanguageCatalog.all, id: \.self) { language in
                    Button {
                        appState.documents.store.setLanguageRenaming(language, of: activeID)
                    } label: {
                        Label(
                            language.name,
                            systemImage: language == appState.documents.store.active?.language ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "No Active Tab",
                systemImage: "doc.text",
                description: Text("Create a tab before choosing a language.")
            )
        }
    }

    @ToolbarContentBuilder
    private func toolbar(documents: EditorDocuments) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Save", action: appState.documents.requestSave)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(appState.documents.store.active == nil)
                Button("Save As…", action: appState.documents.requestSaveAs)
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(appState.documents.store.active == nil)
                Divider()
                Button("New Tab") { documents.newTab() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Open File…", action: appState.documents.requestOpenFile)
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            } label: {
                Label("File", systemImage: "doc")
            }
        }

        if hSizeClass != .compact {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    columnVisibility = (columnVisibility == .all) ? .doubleColumn : .all
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .disabled(selectedSection != .editor)
            }
        }
    }
}

private enum IOSSidebarSection: String, Identifiable, CaseIterable {
    case editor
    case settings
    case themes
    case languages
    case inspectors

    var id: String { rawValue }

    var title: String {
        switch self {
        case .editor: "Editor"
        case .settings: "Editor Settings"
        case .themes: "Themes"
        case .languages: "Languages"
        case .inspectors: "Inspectors"
        }
    }

    var icon: String {
        switch self {
        case .editor: "doc.text"
        case .settings: "slider.horizontal.3"
        case .themes: "paintpalette"
        case .languages: "text.alignleft"
        case .inspectors: "magnifyingglass"
        }
    }
}
#endif
```

Differences from the previous version:
- Top-level gate flipped from `#if !canImport(AppKit)` (same as before — iOS-only file).
- `NavigationSplitView` is the 3-column form `init(columnVisibility:sidebar:content:detail:)`.
- `inspectorRail` replaces the old `.inspectors` detail — it renders `InspectorPanelStack` only on the `.editor` destination; otherwise `EmptyView`.
- `.inspectors` destination's `detail(for:)` branch now renders `InspectorPanelStack` (was `inspectorsUnavailable`).
- `inspectorsUnavailable` is **deleted**.
- Toolbar adds an inspector-toggle button, gated on `hSizeClass != .compact` and `selectedSection == .editor`.
- `editor` pane gains `.performanceObserver(appState.performanceObservation)` — wired now that `performanceObservation` is cross-platform on `AppState`.

- [ ] **Step 2: Build for macOS first**

The file is `#if !canImport(AppKit)` so macOS build skips it entirely. Verify:
```bash
swift build --target CodeEditorSample
```
Expected: **PASS** on macOS.

- [ ] **Step 3: Build for iOS simulator**

```bash
xcrun xcodebuild -scheme CodeEditorSample -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -30
```
Expected: **PASS**. Common failures to triage:
- "Cannot find 'InspectorPanelStack' in scope" → Task 7 didn't compile on iOS, re-verify cross-platform symbols.
- "Cannot find 'Pasteboard' in scope" → Task 1 didn't land for the sample target.
- "Cannot find 'DiagnosticsBridge.Counts' in scope" → confirm `DiagnosticsBridge` has a cross-platform `Counts.empty` or inline the literal.

- [ ] **Step 4: Lint and commit**

```bash
swiftlint --fix Sources/CodeEditorSample/iOS/IOSRootView.swift
swiftlint Sources/CodeEditorSample/iOS/IOSRootView.swift
git add Sources/CodeEditorSample/iOS/IOSRootView.swift
git commit -m "Sample: IOSRootView 3-column NavigationSplitView + inspector rail"
```

---

## Task 10: Snapshot tests for `InspectorPanelStack` (macOS)

Cover the composition's visual rendering. Implementation may need to construct a sample `AppState` fixture or refactor `InspectorPanelStack` to accept per-panel inputs — the spec leaves this open. Default path: construct an `AppState`.

**Files:**
- Create: `Tests/CodeEditorSampleTests/InspectorPanelStackSnapshotTests.swift`

- [ ] **Step 1: Create the test file (macOS branch)**

```swift
#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class InspectorPanelStackSnapshotTests: XCTestCase {
    func testEmptyStateLight() {
        let appState = AppState()
        let view = host(
            InspectorPanelStack(
                appState: appState,
                showingPerformanceReport: .constant(false)
            ),
            scheme: .light
        )
        assertSnapshot(of: view, as: .image(precision: 0.99), named: "empty-light")
    }

    func testEmptyStateDark() {
        let appState = AppState()
        let view = host(
            InspectorPanelStack(
                appState: appState,
                showingPerformanceReport: .constant(false)
            ),
            scheme: .dark
        )
        assertSnapshot(of: view, as: .image(precision: 0.99), named: "empty-dark")
    }

    // MARK: - Helpers

    private func host<Content: View>(_ view: Content, scheme: ColorScheme) -> some View {
        view
            .frame(width: 360, height: 1_200)
            .preferredColorScheme(scheme)
    }
}
#endif
```

- [ ] **Step 2: Record snapshots**

Add `.record(.all)` (or `isRecording = true` if using the older API — match the convention used by `CompletionInspectorPanelSnapshotTests`) at the top of the suite. Run:
```bash
swift test --filter InspectorPanelStackSnapshotTests
```
Expected: tests fail with "Recorded new snapshot" — verify the PNGs land in `Tests/CodeEditorSampleTests/__Snapshots__/InspectorPanelStackSnapshotTests/`.

- [ ] **Step 3: Visually verify**

Open the two PNGs. They should show LSP (off state) → Performance (stopped) → Completion (empty) → Annotations (empty) → EventLog (empty) → Config (rendered EditorConfiguration text + Copy button). Stack ~1100pt tall.

- [ ] **Step 4: Remove the recording flag**

Delete `.record(.all)` / `isRecording = true`. Re-run:
```bash
swift test --filter InspectorPanelStackSnapshotTests
```
Expected: **PASS**.

- [ ] **Step 5: Commit**

```bash
git add Tests/CodeEditorSampleTests/InspectorPanelStackSnapshotTests.swift Tests/CodeEditorSampleTests/__Snapshots__/InspectorPanelStackSnapshotTests/
git commit -m "Tests: InspectorPanelStack snapshot baselines (empty-light/empty-dark)"
```

---

## Task 11: Manual verification — iPad and iPhone simulators + macOS regression

The plan's only end-to-end gate. None of the prior tasks exercise the actual `NavigationSplitView` shape; this task pins the visual behaviour.

- [ ] **Step 1: macOS regression check**

```bash
swift run CodeEditorSample
```
Compare against memory of pre-refactor state: right inspector rail should render the same six panels in the same order with the same behaviour. One expected visual delta: the Copy button moved from the floating `EditorSidebarShell` footer into the bottom of the configuration card (inside the scroll). Open a Swift file, toggle LSP, watch diagnostics flow. Verify Copy still writes to the pasteboard. Close.

- [ ] **Step 2: iPad simulator — 3-column layout**

```bash
xcrun simctl boot 'iPad Pro 13-inch (M4)' || true
open -a Simulator
xcrun xcodebuild -scheme CodeEditorSample -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' run
```

Verify:
1. Sidebar shows 5 destinations (Editor / Settings / Themes / Languages / Inspectors).
2. `.editor` selected: middle column shows `CodeEditor`; right column initially collapsed.
3. Tap toolbar `sidebar.right` button: inspector column appears with LSP / Performance / Completion / Annotations / EventLog / Config panels.
4. LSP panel: "Attach sourcekit-lsp" toggle is disabled; footnote "iOS: remote-server support arrives with the LSP iOS coverage rollout." visible directly below.
5. Switch sidebar to `.settings`: inspector column collapses automatically (`.doubleColumn` enforced by `onChange`); inspector toolbar button becomes disabled.
6. Switch back to `.editor`: inspector column stays collapsed (sticky off); tap toolbar button to reopen.
7. `.inspectors` destination: middle column shows the same `InspectorPanelStack`; toolbar button is disabled.
8. Rotate to portrait: `NavigationSplitView` system-collapses the inspector column (the toolbar button still works to overlay it). Reflects automatic visibility.

- [ ] **Step 3: iPhone simulator — single-column fallback**

```bash
xcrun xcodebuild -scheme CodeEditorSample -destination 'platform=iOS Simulator,name=iPhone 16 Pro' run
```

Verify:
1. Single-column navigation stack; sidebar destinations push to detail.
2. Toolbar inspector toggle button is **hidden** (`hSizeClass == .compact`).
3. `.inspectors` destination pushes to a full-screen `InspectorPanelStack` (6 panels, no chrome wrapper, no toolbar inspector button). LSP panel shows the disabled toggle + footnote.

- [ ] **Step 4: Document any visual deltas**

If a step above did not match the expectation, file the issue in a new commit's body and fix before merging:

```bash
git commit --allow-empty -m "VERIFICATION: [describe issue + fix]"
```

(If everything passes, no commit needed for this task.)

---

## Task 12: Update NEXT.md

Record the slice's completion + note A.3 #9's outcome.

**Files:**
- Modify: `NEXT.md`

- [ ] **Step 1: Mark A.3 #7 inspector slice done**

Find the A.3 #7 entry (line ~59):

```markdown
7. **iOS feature parity.** `IOSRootView.swift` exposes Editor/Settings/Themes/Languages/Inspectors only — no presets, no annotations panel, no workspace knobs. Mirror the macOS knob sections through `NavigationSplitView`. (Partial progress: the Inspectors detail now hosts `EventLogPanel` cross-platform — the first cross-platform inspector — alongside the existing macOS-only explainer.)
```

Append to its end (preserving the existing prose):

```markdown
**Inspector slice landed (2026-05-15)**: iPad now renders a 3-column `NavigationSplitView` with a toolbar-toggleable inspector column hosting `InspectorPanelStack` (LSP / Performance / Completion / Annotations / EventLog / Config). iPhone keeps its 2-column shape; `.inspectors` destination renders the same `InspectorPanelStack` for compact width classes. iOS LSP panel shows a disabled toggle + footnote until B.1 iOS coverage lands. Spec: `docs/superpowers/specs/2026-05-15-cross-platform-inspectors-design.md`; plan: `docs/superpowers/plans/2026-05-15-cross-platform-inspectors.md`. **Still open in A.3 #7**: workspace surface on iOS (Files/Search), tab strip, find/replace overlay, command palette, presets switching surface.
```

- [ ] **Step 2: Update A.3 #9 with the realised outcome**

Find the A.3 #9 entry (line ~63):

```markdown
9. **`canImport(AppKit)` switching is fine, but `RootWindow.swift`/`WindowBody.swift`/`IOSRootView.swift` re-implement layout twice.** Extract a shared `EditorWorkspaceScene` view that composes sidebars + main editor and let each platform supply its own chrome.
```

Replace with:

```markdown
9. ~~**`canImport(AppKit)` switching is fine, but `RootWindow.swift`/`WindowBody.swift`/`IOSRootView.swift` re-implement layout twice.**~~ Partially closed. The inspector slice landed as `InspectorPanelStack` content sharing (a cross-platform view both `InspectorSidebar` and `IOSRootView` host) rather than an `EditorWorkspaceScene` layout wrapper. Layout-primitive divergence between platforms — macOS uses `HStack` with toggles + custom chrome (title bar, tab strip, status bar, command palette overlay); iPad uses `NavigationSplitView` — made a single shell wrapper a leaky abstraction. Content fragments are the honest sharing unit. Still re-implemented on each platform: workspace surface composition, tab strip, find/replace overlay, command palette. See `docs/superpowers/specs/2026-05-15-cross-platform-inspectors-design.md` for rationale.
```

- [ ] **Step 3: Commit**

```bash
git add NEXT.md
git commit -m "NEXT.md: inspector slice landed; A.3 #9 outcome (content fragments, not scene wrapper)"
```

---

## Final verification gate

After all tasks complete:

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Watch for known pre-existing flakes (NEXT.md D — not caused by this slice):
- `LineGeometryStoreBenchmarkTests.testFuzzIncrementalEditCorrectness` flakes under parallel load; passes in isolation.
- `EditorStatusBarSnapshots/*` SIGSEGV under `--parallel`; pass in isolation. If either fires, fall back to:
  ```bash
  swift test  # serial
  ```

All new tests added in this plan should pass under either runner.
