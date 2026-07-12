# Runtime Correctness and API Truth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate runtime state loss, make SwiftUI runtime-only updates effective, remove ambient test detection, and retire every placeholder production API identified by A4, A5, A7, and P2.

**Architecture:** Preserve `EditorRuntime.featureDependencies` across infrastructure updates, express memory cleanup behavior as injected policy, and rebind monitors without replacing feature owners. Remove identity text processors and simulated rendering optimization; replace fixed performance values with injected optional metrics.

**Tech Stack:** Swift 6.3, Swift Testing, XCTest, SwiftUI representables, TextKit 2, Point-Free Dependencies.

## Global Constraints

- Preserve stable editor-facing APIs except explicitly placeholder APIs.
- All runtime mutation occurs on `@MainActor`.
- No feature manager may be replaced solely because `MemoryMonitor` changes.
- Runtime-only SwiftUI changes apply even when text, language, and configuration are equal.
- Tests must observe state identity or behavior, not only absence of a throw.

---

### Task 1: Preserve Feature Dependencies Across Runtime Updates

**Files:**
- Create: `Tests/CodeEditorPluginTests/Core/EditorRuntimeStatePreservationTests.swift`
- Modify: `Sources/CodeEditorView/EditorRuntime.swift:94-123`

**Interfaces:**
- Consumes: `EditorRuntime`, `EditorRuntimeDependencies`, `EditorFeatureRuntimeDependencies`.
- Produces: `EditorRuntime.update(dependencies:)` that never replaces `featureDependencies`; explicit `replace(featureDependencies:)` for intentional replacement.

- [ ] **Step 1: Write the failing identity test**

```swift
import CodeEditorDiagnostics
@testable import CodeEditorView
import Testing

@MainActor
@Suite("EditorRuntime state preservation")
struct EditorRuntimeStatePreservationTests {
    @Test("infrastructure update preserves feature dependency identity")
    func preservesFeatureDependencies() {
        let features = EditorFeatureRuntimeDependencies()
        let runtime = EditorRuntime()
        runtime.replace(featureDependencies: features)

        runtime.update(dependencies: EditorRuntimeDependencies(memoryMonitor: MemoryMonitor()))

        #expect(runtime.featureDependencies === features)
    }
}
```

- [ ] **Step 2: Run the test and verify RED**

Run: `swift test --filter EditorRuntimeStatePreservationTests`

Expected: compilation fails because `replace(featureDependencies:)` does not exist, or the identity assertion fails if the test temporarily calls the current `update(featureDependencies:)` API.

- [ ] **Step 3: Separate replacement from infrastructure update**

```swift
public func update(dependencies: EditorRuntimeDependencies) {
    self.dependencies = dependencies
}

public func replace(featureDependencies: EditorFeatureRuntimeDependencies) {
    self.featureDependencies = featureDependencies
}

@available(*, deprecated, renamed: "replace(featureDependencies:)")
public func update(featureDependencies: EditorFeatureRuntimeDependencies) {
    replace(featureDependencies: featureDependencies)
}
```

Update in-tree intentional replacement call sites to `replace(featureDependencies:)`.

- [ ] **Step 4: Run focused and runtime tests**

Run:

```bash
swift test --filter EditorRuntimeStatePreservationTests
swift test --filter MemoryMonitorDITests
```

Expected: both commands pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorView/EditorRuntime.swift Tests/CodeEditorPluginTests/Core/EditorRuntimeStatePreservationTests.swift Sources Tests
git commit -m "fix(runtime): preserve feature dependencies during updates"
```

### Task 2: Reconcile Runtime-Only SwiftUI Changes

**Files:**
- Create: `Sources/CodeEditorSwiftUI/EditorRuntimeSnapshot.swift`
- Modify: `Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift:107-129,460-495`
- Modify: `Tests/CodeEditorPluginTests/SwiftUICoordinatorTests.swift`

**Interfaces:**
- Consumes: `EditorRuntimeDependencies`, `CodeEditorBaseCoordinator.updateContainer`.
- Produces: `EditorRuntimeSnapshot`, `CodeEditorBaseCoordinator.shouldApply(runtimeDependencies:)`.

- [ ] **Step 1: Add a failing runtime-only update test**

```swift
@MainActor
func testRuntimeOnlyUpdateReplacesEventSystem() throws {
    let coordinator = CodeEditorCoordinator(
        text: .constant("let value = 1"),
        onTextChange: nil,
        onSelectionChange: nil
    )
    let container = CodeEditorContainerView(frame: .zero)
    let first = UnifiedEventSystem()
    let second = UnifiedEventSystem()
    let configuration = EditorConfiguration.default

    coordinator.setupContainer(
        container,
        text: "let value = 1",
        language: .swift,
        theme: .default,
        configuration: configuration,
        runtimeDependencies: .live(eventSystem: first)
    )
    coordinator.updateContainer(
        container,
        text: "let value = 1",
        language: .swift,
        theme: .default,
        configuration: configuration,
        runtimeDependencies: .live(eventSystem: second)
    )

    XCTAssertTrue(container.textView.runtime.dependencies.eventSystem === second)
}
```

- [ ] **Step 2: Run and verify RED**

Run: `swift test --filter SwiftUICoordinatorTests/testRuntimeOnlyUpdateReplacesEventSystem`

Expected: assertion fails because the value-state guard returns before applying the second runtime bag.

- [ ] **Step 3: Add identity snapshots and independent reconciliation**

```swift
@MainActor
struct EditorRuntimeSnapshot: Equatable {
    let memoryMonitor: ObjectIdentifier
    let actorCoordinator: ObjectIdentifier
    let platformCapabilities: ObjectIdentifier
    let unifiedPerformanceSystem: ObjectIdentifier
    let paragraphStyleCache: ObjectIdentifier
    let languageMetadataRegistry: ObjectIdentifier
    let platformServiceLayer: ObjectIdentifier
    let platformDeviceService: ObjectIdentifier
    let eventSystem: ObjectIdentifier?
    let workspaceRoot: URL?

    init(_ dependencies: EditorRuntimeDependencies) {
        memoryMonitor = ObjectIdentifier(dependencies.memoryMonitor)
        actorCoordinator = ObjectIdentifier(dependencies.actorCoordinator)
        platformCapabilities = ObjectIdentifier(dependencies.platformCapabilities)
        unifiedPerformanceSystem = ObjectIdentifier(dependencies.unifiedPerformanceSystem)
        paragraphStyleCache = ObjectIdentifier(dependencies.paragraphStyleCache)
        languageMetadataRegistry = ObjectIdentifier(dependencies.languageMetadataRegistry)
        platformServiceLayer = ObjectIdentifier(dependencies.platformServiceLayer)
        platformDeviceService = ObjectIdentifier(dependencies.platformDeviceService)
        eventSystem = dependencies.eventSystem.map(ObjectIdentifier.init)
        workspaceRoot = dependencies.workspaceRoot
    }
}
```

Store `lastRuntimeSnapshot` on the coordinator. In `updateContainer`, compute and apply runtime changes before the value-state early return, then update the stored snapshot.

- [ ] **Step 4: Run coordinator suites**

Run:

```bash
swift test --filter SwiftUICoordinatorTests
swift test --filter MemoryMonitorDITests
swift test --filter SwiftUIClosureLifecycleTests
```

Expected: all commands pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorSwiftUI Tests/CodeEditorPluginTests/SwiftUICoordinatorTests.swift
git commit -m "fix(swiftui): reconcile runtime-only editor updates"
```

### Task 3: Replace Ambient Test Detection With Memory Policy

**Files:**
- Create: `Sources/CodeEditorView/MemoryManagementPolicy.swift`
- Create: `Tests/CodeEditorPluginTests/Core/MemoryManagementPolicyTests.swift`
- Modify: `Sources/CodeEditorView/EditorRuntime.swift:16-75`
- Modify: `Sources/CodeEditorView/MemoryManagementCoordinator.swift:46-149`
- Delete: `Sources/CodeEditorCommon/Utilities/TestEnvironmentDetector.swift`

**Interfaces:**
- Consumes: `EditorRuntimeDependencies`, `MemoryManagementCoordinator`.
- Produces: `MemoryManagementPolicy(registersCleanupHandlers: Bool)` and policy-driven registration.

- [ ] **Step 1: Add failing policy tests**

```swift
@MainActor
@Suite("Memory management policy")
struct MemoryManagementPolicyTests {
    @Test("disabled policy does not register coordinator cleanup")
    func disabledRegistration() {
        let monitor = MemoryMonitor()
        let view = CodeEditorView(frame: .zero)
        let coordinator = MemoryManagementCoordinator(
            memoryMonitor: monitor,
            policy: .disabled,
            editorView: view
        )

        #expect(coordinator.hasRegisteredCleanupHandler == false)
    }
}
```

- [ ] **Step 2: Run and verify RED**

Run: `swift test --filter MemoryManagementPolicyTests`

Expected: compilation fails because the policy initializer and inspection seam do not exist.

- [ ] **Step 3: Implement explicit policy**

```swift
public struct MemoryManagementPolicy: Sendable, Equatable {
    public var registersCleanupHandlers: Bool

    public init(registersCleanupHandlers: Bool = true) {
        self.registersCleanupHandlers = registersCleanupHandlers
    }

    public static let live = Self(registersCleanupHandlers: true)
    public static let disabled = Self(registersCleanupHandlers: false)
}
```

Add the policy to `EditorRuntimeDependencies`, pass it to `MemoryManagementCoordinator`, and replace the `TestEnvironmentDetector` branch with `guard policy.registersCleanupHandlers else { return }`. Expose `package var hasRegisteredCleanupHandler: Bool { cleanupIdentifier != nil }`.

- [ ] **Step 4: Delete detector and verify no production reference**

Run:

```bash
rg -n "TestEnvironmentDetector" Sources Tests
swift test --filter MemoryManagementPolicyTests
```

Expected: `rg` returns no matches; the test passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorView Sources/CodeEditorCommon Tests/CodeEditorPluginTests/Core/MemoryManagementPolicyTests.swift
git commit -m "refactor(memory): inject cleanup registration policy"
```

### Task 4: Rebind Memory Monitors Without Replacing Feature Owners

**Files:**
- Create: `Sources/CodeEditorDiagnostics/MemoryMonitorUsing.swift`
- Modify: `Sources/CodeEditorCompletion/CompletionManager.swift`
- Modify: `Sources/CodeEditorLSP/LSPManager.swift`
- Modify: `Sources/CodeEditorView/SyntaxHighlighting/AsyncSyntaxHighlighter.swift`
- Modify: `Sources/CodeEditorView/MemoryManagementCoordinator.swift:103-183`
- Modify: `Tests/CodeEditorPluginTests/MemoryMonitorDITests.swift`

**Interfaces:**
- Produces: `setMemoryMonitor(_:)` on live feature owners, preserving object identity and feature state.

- [ ] **Step 1: Add failing identity/state tests**

```swift
@MainActor
func testMonitorSwapPreservesCompletionManagerAndProviders() {
    let editor = CodeEditorView(frame: .zero)
    let manager = editor.completionManager
    let provider = LanguageKeywordCompletionProvider(language: .swift)
    manager.registerProvider(provider)

    editor.memoryMonitor = MemoryMonitor()

    XCTAssertTrue(editor.completionManager === manager)
    XCTAssertTrue(editor.completionManager.registeredProviders.contains { $0.id == provider.id })
}
```

Add the macOS equivalent for `lspManager` identity and workspace root.

- [ ] **Step 2: Run and verify RED**

Run: `swift test --filter MemoryMonitorDITests`

Expected: the new identity assertions fail because the coordinator recreates managers.

- [ ] **Step 3: Implement monitor rebinding**

```swift
@MainActor
public protocol MemoryMonitorUsing: AnyObject {
    func setMemoryMonitor(_ monitor: MemoryMonitor)
}
```

Keep this protocol in `CodeEditorDiagnostics`, beside `MemoryMonitor`; placing it in
`CodeEditorCommon` would create a `CodeEditorCommon -> CodeEditorDiagnostics ->
CodeEditorCommon` target cycle.

For each conformer, make the monitor mutable, unregister its stored cleanup identifier from the old monitor, assign the new monitor, and register the same cleanup closure on the new monitor. Store cleanup identifiers explicitly.

Replace `updateComponentsMemoryMonitor()` recreation with:

```swift
components.asyncHighlighter?.setMemoryMonitor(memoryMonitor)
components.completionManager?.setMemoryMonitor(memoryMonitor)
#if canImport(AppKit)
components.lspManager?.setMemoryMonitor(memoryMonitor)
#endif
```

- [ ] **Step 4: Run memory and completion/LSP tests**

Run:

```bash
swift test --filter MemoryMonitorDITests
swift test --filter CompletionSystemTests
swift test --filter LSPIntegrationTests
```

Expected: all commands pass and identities are preserved.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorCommon Sources/CodeEditorCompletion Sources/CodeEditorLSP Sources/CodeEditorView Tests/CodeEditorPluginTests/MemoryMonitorDITests.swift
git commit -m "fix(memory): rebind monitors without state loss"
```

### Task 5: Remove Identity Text Processing APIs

**Files:**
- Create: `Tests/CodeEditorPluginTests/Architecture/PlaceholderAPIRemovalTests.swift`
- Modify: `Sources/CodeEditorView/ActorCoordinator.swift`
- Delete: `Sources/CodeEditorView/Actors/TextProcessingActor.swift`
- Delete: `Tests/CodeEditorPluginTests/Core/Actors/TextProcessingActorCancellationTests.swift`
- Modify: `docs/README.md`

**Interfaces:**
- Removes: `TextProcessingActor`, `ActorCoordinator.textProcessor`, `ActorCoordinator.processText`, `CodeEditorView.processText`.
- Preserves: real smart-editing entry points in `CodeEditorSmartEditing`.

- [ ] **Step 1: Add a failing structural test**

```swift
import Foundation
import Testing

@Suite("Placeholder API removal")
struct PlaceholderAPIRemovalTests {
    @Test("production sources contain no identity text processor")
    func noIdentityTextProcessor() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = root.appending(path: "Sources/CodeEditorView/Actors/TextProcessingActor.swift")
        #expect(FileManager.default.fileExists(atPath: source.path) == false)
    }
}
```

- [ ] **Step 2: Run and verify RED**

Run: `swift test --filter PlaceholderAPIRemovalTests/noIdentityTextProcessor`

Expected: assertion fails because the source file exists.

- [ ] **Step 3: Remove the placeholder surface**

Delete the actor source and its cancellation-only tests. Remove its properties and forwarding methods from `ActorCoordinator` and `CodeEditorView`. Update public docs to direct formatting/indentation behavior to `CodeEditorSmartEditing` attachment APIs.

- [ ] **Step 4: Verify removal and affected builds**

Run:

```bash
rg -n "TextProcessingActor|processText\(" Sources Tests docs --glob '!docs/archive/**'
swift test --filter PlaceholderAPIRemovalTests
swift build --target CodeEditorView
```

Expected: search returns no live references; tests and build pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorView Tests/CodeEditorPluginTests docs/README.md
git commit -m "refactor(view): remove placeholder text processing API"
```

### Task 6: Remove Simulated Rendering Optimization

**Files:**
- Create: `Sources/CodeEditorView/Text/TextKit2RenderingMetrics.swift`
- Create: `Tests/CodeEditorPluginTests/TextKit2RenderingMetricsTests.swift`
- Delete: `Sources/CodeEditorView/Text/TextKit2RenderingOptimizer.swift`
- Modify: `Sources/CodeEditorView/CodeEditorView.swift:290-298`
- Modify: `Sources/CodeEditorView/MemoryManagementCoordinator.swift`
- Modify: `Tests/CodeEditorPluginTests/TextKit2OptimizationTests.swift`

**Interfaces:**
- Removes: simulated fragment cache/recycling/prefetch API.
- Produces: metrics-only `TextKit2RenderingMetrics` with counters updated only by real layout call sites.

- [ ] **Step 1: Add failing real-counter tests**

```swift
@MainActor
@Suite("TextKit2 rendering metrics")
struct TextKit2RenderingMetricsTests {
    @Test("records only observed layout work")
    func observedLayout() {
        let metrics = TextKit2RenderingMetrics()
        #expect(metrics.layoutPassCount == 0)
        metrics.recordLayoutPass(duration: .milliseconds(3), visibleFragmentCount: 8)
        #expect(metrics.layoutPassCount == 1)
        #expect(metrics.visibleFragmentCount == 8)
    }
}
```

- [ ] **Step 2: Run and verify RED**

Run: `swift test --filter TextKit2RenderingMetricsTests`

Expected: compilation fails because `TextKit2RenderingMetrics` does not exist.

- [ ] **Step 3: Implement truthful metrics and remove optimizer**

```swift
@MainActor
public final class TextKit2RenderingMetrics: ObservableObject {
    @Published public private(set) var layoutPassCount = 0
    @Published public private(set) var visibleFragmentCount = 0
    @Published public private(set) var latestLayoutDuration = Duration.zero

    public func recordLayoutPass(duration: Duration, visibleFragmentCount: Int) {
        layoutPassCount += 1
        self.visibleFragmentCount = visibleFragmentCount
        latestLayoutDuration = duration
    }
}
```

Delete simulated fragment types and optimizer tests. Retain genuine `TextKit2PerformanceHelper` tests, moving any `RenderingStatistics` behavior that reflects real observations into the new metrics test. Remove optimizer construction/recreation from the view and memory coordinator.

- [ ] **Step 4: Verify no simulated behavior remains**

Run:

```bash
rg -n "TextKit2RenderingOptimizer|createOrRecycleFragment|prefetchLayoutAsync|CachedFragment" Sources Tests
swift test --filter TextKit2RenderingMetricsTests
swift test --filter TextKit2OptimizationTests
```

Expected: search returns no matches; remaining metrics/performance tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorView Tests/CodeEditorPluginTests
git commit -m "refactor(textkit): replace simulated optimizer with real metrics"
```

### Task 7: Inject Real Performance Insight Sources

**Files:**
- Create: `Sources/CodeEditorDiagnostics/PerformanceMetricProviders.swift`
- Modify: `Sources/CodeEditorDiagnostics/PerformanceInsights.swift`
- Modify: `Sources/CodeEditorSample/App/Performance/PerformanceSampleCoordinator.swift`
- Modify: `Tests/CodeEditorPluginTests/PerformanceInsightsRealMetricsTests.swift`

**Interfaces:**
- Produces: `DocumentMetricsProviding`, `TextLayoutMetricsProviding`, optional metric semantics in `PerformanceInsights`.

- [ ] **Step 1: Add failing provider-driven tests**

```swift
private struct TestDocumentMetrics: DocumentMetricsProviding {
    let fileSizeBytes: Int?
}

private struct TestLayoutMetrics: TextLayoutMetricsProviding {
    let averageLayoutTime: TimeInterval?
    let cacheHitRate: Double?
}

@MainActor
@Test("recommendations use injected document size")
func documentSizeRecommendation() {
    let insights = PerformanceInsights(
        memoryMonitor: MemoryMonitor(),
        frameRateMonitor: FrameRateMonitor(),
        documentMetrics: TestDocumentMetrics(fileSizeBytes: 20_000_000),
        textLayoutMetrics: TestLayoutMetrics(averageLayoutTime: nil, cacheHitRate: nil)
    )
    insights.refresh()
    #expect(insights.recommendations.contains { recommendation in
        if case .splitLargeFile = recommendation { return true }
        return false
    })
}
```

- [ ] **Step 2: Run and verify RED**

Run: `swift test --filter PerformanceInsightsRealMetricsTests`

Expected: compilation fails because provider protocols and initializer parameters do not exist.

- [ ] **Step 3: Implement optional metric providers**

```swift
public protocol DocumentMetricsProviding: Sendable {
    var fileSizeBytes: Int? { get }
}

public protocol TextLayoutMetricsProviding: Sendable {
    var averageLayoutTime: TimeInterval? { get }
    var cacheHitRate: Double? { get }
}
```

Replace `InsightsTextKit2Monitor` and `getCurrentFileSize()` with injected providers. Only create slow-layout, low-cache, or split-file findings when the corresponding metric is non-nil. Update `DetailedPerformanceReport.textKitMetrics` to an optional or an availability-bearing value and update the sample view accordingly.

- [ ] **Step 4: Run diagnostics and sample tests**

Run:

```bash
swift test --filter PerformanceInsightsRealMetricsTests
swift test --filter CodeEditorSampleTests
swift build --target CodeEditorSample
```

Expected: all commands pass; no fixed `0.01`, `0.85`, or hard-coded total operation count remains in `PerformanceInsights.swift`.

- [ ] **Step 5: Commit and run Wave 1 gate**

```bash
git add Sources/CodeEditorDiagnostics Sources/CodeEditorSample Tests
git commit -m "fix(diagnostics): source performance insights from real metrics"
swift build
swiftlint --fix
swiftlint
swift test --parallel
```

Expected: commit succeeds and the full Wave 1 gate passes.
