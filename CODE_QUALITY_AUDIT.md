# CodeEditorPlugin Structural Code Quality Audit

**Audit date:** 2026-07-12

**Repository state:** `main` at `a958f96d`

**Primary focus:** abstraction quality, pattern consistency, duplication, reuse, and maintainability

## Executive Summary

CodeEditorPlugin has **moderate-to-good structural health**. The recent extraction of the former umbrella implementation into focused Swift Package Manager targets is directionally strong: configuration, theming, language metadata, text-model primitives, diagnostics, completion, LSP, layout, view integration, and SwiftUI hosting now have visible module boundaries. The codebase also enforces valuable low-level conventions—Swift 6 strict concurrency, `canImport` platform checks, dependency injection instead of custom singletons, a delegate multiplexer, and strict linting.

The main risk is that the package is **more modular in its directory and target structure than in its runtime ownership model**. `CodeEditorView` remains the composition root, state owner, feature façade, and platform view for most of the framework. It compiles with 38–40 type-level properties depending on platform and is extended across 29 files totaling approximately 5,618 lines. `CodeEditorBaseCoordinator`, `CompletionManager`, and `LSPClient` exhibit the same concentration at smaller scales. These types are not merely large; they combine lifecycle, caching, policy, state synchronization, transport, rendering, and diagnostics, which makes changes cross-cutting and increases regression risk.

Several abstractions also over-promise. Public actors and optimizers expose operations whose implementation is explicitly placeholder or simulated. A group of public protocols and helpers have no consumers or only their declaring concrete type as a conformer. Conversely, real cross-cutting policies—runtime dependency replacement, event delivery, cache behavior, logging identity, and platform state preservation—are implemented through multiple competing mechanisms.

Duplication is **noticeable but not systemic**. A conservative exact-clone scan found 141 maximal clone pairs in library sources, covering about 3.70% of non-comment, non-import significant lines. Much of that repetition is acceptable: Apple-platform shells, semantic theme value types, wire-format models, and declarative language descriptors should remain explicit when their concepts can evolve independently. The highest-value redundancy is concentrated in a few families: two linked-list LRU implementations, two nearly identical debounce implementations, repeated string-or-integer LSP codecs, identical JavaScript/TypeScript capture maps, duplicated platform cell state, and repeated scroll-position preservation logic.

### Overall assessment

| Dimension | Assessment | Rationale |
|---|---|---|
| Module decomposition | Good, incomplete | Focused targets exist, but `CodeEditorView` depends on 15 internal modules and optional UI imports the umbrella. |
| Abstraction quality | Mixed | Strong bridges and registries coexist with speculative protocols and placeholder public capabilities. |
| Pattern consistency | Mixed | Platform and lint conventions are strong; DI, events, logging, and test boundaries are fragmented. |
| Duplication/reuse | Moderate | 3.70% conservative clone coverage; a small number of reusable kernels would remove disproportionate debt. |
| Change scalability | At risk | Core changes frequently traverse the view, SwiftUI coordinator, container, runtime, and feature managers. |

### Highest-priority conclusions

1. Make runtime dependency updates state-preserving and observable by SwiftUI before further expanding dependency injection.
2. Remove, internalize, or fully implement placeholder public actors/optimizers so the API represents real behavior.
3. Decompose the largest coordinators by owned state and lifecycle, not merely by extension file.
4. Consolidate the duplicate LRU and debounce kernels.
5. Align package, test, lint, and import boundaries with the source-target architecture already in place.

## Scope and Methodology

The audit examined all Swift sources under `Sources/`, the SPM graph in `Package.swift`, lint policy, and representative tests. At this revision:

- Production sources contain **591 Swift files / 97,711 lines**, including the sample.
- Library sources excluding `CodeEditorSample` contain **524 Swift files / 89,809 lines**.
- `CodeEditorView` is the largest target at **120 files / 29,204 lines**.
- `CodeEditorPluginTests` contains **181 files / 31,881 lines** and depends on 19 internal modules/products.

The duplication scan used eight consecutive code lines after trimming whitespace and excluding blank lines, comments, imports, availability/actor annotations, and conditional-compilation directives. It reports maximal exact clones; it does not count renamed/parameterized near-clones, so the results are a conservative lower bound.

| Scope | Files | Significant lines | Maximal clone pairs | Files involved | Unique cloned-line coverage |
|---|---:|---:|---:|---:|---:|
| Library sources | 524 | 53,633 | 141 | 91 | 1,985 lines / 3.70% |
| All sources including sample | 591 | 59,491 | 144 | 96 | Not used for prioritization |

Severity labels in this report mean:

- **High:** likely to cause state loss, misleading behavior, architectural bottlenecks, or broad regression surfaces.
- **Medium:** sustained cognitive load, redundant maintenance, or erosion of intended boundaries.
- **Low:** localized inconsistency or cleanup with limited immediate risk.

## Abstraction Analysis

### A1. `CodeEditorView` is still a God object behind extension-file decomposition

**Severity:** High

**Evidence**

- The class owns the delegate multiplexer, event publisher, runtime, configuration, highlighters, performance monitor, LSP state, folding, search, geometry, TextKit bridge, annotations, completion UI, and memory coordinator in [Sources/CodeEditorView/CodeEditorView.swift](Sources/CodeEditorView/CodeEditorView.swift#L149-L497).
- The class has 38–40 type-level property declarations in a platform build (40 on macOS, 38 on iOS) and 29 extension-bearing files totaling approximately 5,618 lines.
- Its SPM target depends on 15 internal modules plus two external products in [Package.swift](Package.swift#L252-L273).
- Teardown directly coordinates highlighting, memory registration, layout, completion, folding, LSP, gutter, and delegate state in [Sources/CodeEditorView/CodeEditorView.swift](Sources/CodeEditorView/CodeEditorView.swift#L624-L675).

**Impact**

The extension files improve navigation but do not create ownership boundaries. Every feature can still mutate shared view state, and feature construction order is encoded through lazy properties and setup calls. This makes feature removal difficult, encourages package-wide imports, and turns the view into the integration test surface for otherwise independent services.

**Recommendation**

Keep `CodeEditorView` as the public platform view, but move feature state and lifecycle into an internal session composed of narrow controllers. Start with completion, highlighting, and LSP because each already has a recognizable lifecycle.

```swift
@MainActor
final class EditorSession {
    let highlighting: HighlightingController
    let completion: CompletionController
    let folding: FoldingController
    #if canImport(AppKit)
    let lsp: LSPDocumentController
    #endif

    func attach(to view: CodeEditorView) { /* attach feature ports */ }
    func detach() { /* idempotent feature teardown */ }
}

@MainActor
open class CodeEditorView: PlatformTextView {
    private let session: EditorSession

    override public func removeFromSuperview() {
        session.detach()
        super.removeFromSuperview()
    }
}
```

The key is state ownership, not another set of forwarding helpers. A controller should own its tasks, caches, observers, and cleanup registration end-to-end.

### A2. `CodeEditorBaseCoordinator` combines five independent SwiftUI bridge responsibilities

**Severity:** High

**Evidence**

- Binding state, callbacks, focus, debounce state, platform adaptation, completion-provider adaptation, and dirty tracking are co-located in [Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift](Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift#L20-L92).
- Text synchronization and debouncing are implemented in [Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift](Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift#L107-L220).
- Selection/cursor conversion and notification lifecycle occupy [Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift](Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift#L223-L327).
- Container creation/update orchestration spans [Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift](Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift#L354-L565), while provider reconciliation is appended at [Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift](Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift#L672-L702).
- The file is 703 lines and contains 25 methods/initializers.

**Impact**

Changes to SwiftUI identity, binding behavior, cursor restoration, completion modifiers, or platform mounting all touch one coordinator. The coordinator is difficult to test without a real container because its responsibilities depend on shared mutable fields rather than explicit inputs and outputs.

**Recommendation**

Extract value-driven reconciliation and lifecycle objects, leaving the coordinator as a thin adapter:

```swift
struct EditorRenderState: Equatable {
    var text: String
    var language: Language
    var configuration: EditorConfiguration
    var runtimeIdentity: ObjectIdentifier
}

@MainActor final class BindingSynchronizer { /* text + selection */ }
@MainActor final class InteractionStateSynchronizer { /* cursor + dirty */ }
@MainActor final class ModifierProviderRegistry { /* completion closure */ }

@MainActor
final class CodeEditorCoordinator: NSObject {
    let bindings: BindingSynchronizer
    let interaction: InteractionStateSynchronizer
    let modifiers: ModifierProviderRegistry
}
```

This also creates focused unit-test seams for feedback-loop prevention and cursor conversion.

### A3. `CompletionManager` and `LSPClient` are overburdened service façades

**Severity:** High

**Evidence**

- `CompletionManager` owns provider registration, request cancellation, two caches, debouncing, event broadcasting, usage learning, ranking, statistics, and memory-pressure cleanup in [Sources/CodeEditorCompletion/CompletionManager.swift](Sources/CodeEditorCompletion/CompletionManager.swift#L64-L128), [Sources/CodeEditorCompletion/CompletionManager.swift](Sources/CodeEditorCompletion/CompletionManager.swift#L156-L388), and [Sources/CodeEditorCompletion/CompletionManager.swift](Sources/CodeEditorCompletion/CompletionManager.swift#L395-L583).
- `LSPClient` owns public observable protocol state, message routing, two transport modes, process lifecycle, pending continuations, request IDs, and teardown state in [Sources/CodeEditorLSP/LSPClient.swift](Sources/CodeEditorLSP/LSPClient.swift#L90-L146).
- The same LSP type also exposes document synchronization and language features in [Sources/CodeEditorLSP/LSPClient.swift](Sources/CodeEditorLSP/LSPClient.swift#L355-L553), then implements JSON-RPC request/response routing and notification decoding in [Sources/CodeEditorLSP/LSPClient.swift](Sources/CodeEditorLSP/LSPClient.swift#L555-L687).

**Impact**

Both types have too many reasons to change. For completion, ranking and learning changes risk request orchestration and cache behavior. For LSP, adding a protocol feature touches the same object that owns connection teardown and continuations. This reduces independent testability and makes alternative transports or ranking strategies harder to introduce safely.

**Recommendation**

Use orchestration façades backed by independently owned components:

```swift
@MainActor
final class CompletionManager {
    private let providers: CompletionProviderRegistry
    private let requests: CompletionRequestCoordinator
    private let ranking: any CompletionRanking
    private let responseCache: CompletionResponseCache
    private let learning: CompletionLearningStore
}

@MainActor
final class LSPClient {
    private let rpc: JSONRPCSession
    private let connection: LSPConnectionLifecycle
    private let documents: LSPDocumentSession
    private let features: LSPLanguageFeatureClient
}
```

Preserve the current public façades so this can be delivered incrementally without an API break.

### A4. Runtime dependency replacement is not state-preserving

**Severity:** High

**Evidence**

- `EditorRuntime.update(dependencies:)` replaces runtime dependencies and unconditionally creates a new `EditorFeatureRuntimeDependencies` graph in [Sources/CodeEditorView/EditorRuntime.swift](Sources/CodeEditorView/EditorRuntime.swift#L94-L109). Custom feature services installed through `update(featureDependencies:)` are therefore lost after a runtime update.
- `CodeEditorView.apply(runtimeDependencies:)` calls that resetting method in [Sources/CodeEditorView/EditorRuntime.swift](Sources/CodeEditorView/EditorRuntime.swift#L134-L149).
- Replacing the memory monitor recreates the async highlighter, rendering optimizer, completion manager, and LSP manager in [Sources/CodeEditorView/MemoryManagementCoordinator.swift](Sources/CodeEditorView/MemoryManagementCoordinator.swift#L151-L183). This discards provider registrations, learned completion state, in-flight connection state, and other component-local data.
- The `memoryMonitor` API promises that dependent subsystems are “automatically updated” in [Sources/CodeEditorView/CodeEditorView.swift](Sources/CodeEditorView/CodeEditorView.swift#L363-L392), but the update is replacement rather than migration.

**Impact**

Dependency injection can change runtime behavior in surprising ways: a host swapping monitoring infrastructure may silently lose completion providers or LSP state, while applying a new runtime bag can erase explicitly injected feature services. This is a correctness risk created by an unclear abstraction boundary.

**Recommendation**

Make runtime updates explicit and state-preserving. Immutable dependencies should be replaced by rebuilding a whole session at a documented boundary; mutable infrastructure should support rebinding without replacing feature owners.

```swift
@MainActor
public final class EditorRuntime {
    public private(set) var dependencies: EditorRuntimeDependencies
    public let features: EditorFeatureRuntimeDependencies

    public func updateInfrastructure(_ update: (inout EditorRuntimeDependencies) -> Void) {
        update(&dependencies)
        features.rebind(to: dependencies)
    }
}

protocol MemoryMonitorUsing: AnyObject {
    func setMemoryMonitor(_ monitor: MemoryMonitor)
}
```

Add regression tests that register a completion provider and custom feature service, replace the monitor/runtime bag, and prove identity and state remain intact.

### A5. Public placeholder components advertise behavior they do not provide

**Severity:** High

**Evidence**

- Four of five `TextProcessingActor` operations return the input unchanged; its own comment calls them simplified placeholders in [Sources/CodeEditorView/Actors/TextProcessingActor.swift](Sources/CodeEditorView/Actors/TextProcessingActor.swift#L116-L149). `priority`, `textBuffers`, and actor-local recovery infrastructure are not used to perform the advertised work in [Sources/CodeEditorView/Actors/TextProcessingActor.swift](Sources/CodeEditorView/Actors/TextProcessingActor.swift#L11-L53).
- `ActorCoordinator` publicly exposes that actor as the editor’s text-processing system and routes `CodeEditorView.processText` through it in [Sources/CodeEditorView/ActorCoordinator.swift](Sources/CodeEditorView/ActorCoordinator.swift#L12-L57) and [Sources/CodeEditorView/ActorCoordinator.swift](Sources/CodeEditorView/ActorCoordinator.swift#L137-L167).
- `TextKit2RenderingOptimizer` explicitly states that optimization uses placeholder fragments and simulated work in [Sources/CodeEditorView/Text/TextKit2RenderingOptimizer.swift](Sources/CodeEditorView/Text/TextKit2RenderingOptimizer.swift#L10-L23). It creates empty `NSTextLayoutFragment` instances and records no-op optimization flags in [Sources/CodeEditorView/Text/TextKit2RenderingOptimizer.swift](Sources/CodeEditorView/Text/TextKit2RenderingOptimizer.swift#L277-L313), while prefetching only yields and records a duration in [Sources/CodeEditorView/Text/TextKit2RenderingOptimizer.swift](Sources/CodeEditorView/Text/TextKit2RenderingOptimizer.swift#L331-L341).
- `PerformanceInsights` bases TextKit recommendations on fixed placeholder values and can never obtain the current file size in [Sources/CodeEditorDiagnostics/PerformanceInsights.swift](Sources/CodeEditorDiagnostics/PerformanceInsights.swift#L204-L220), [Sources/CodeEditorDiagnostics/PerformanceInsights.swift](Sources/CodeEditorDiagnostics/PerformanceInsights.swift#L322-L325), and [Sources/CodeEditorDiagnostics/PerformanceInsights.swift](Sources/CodeEditorDiagnostics/PerformanceInsights.swift#L434-L451).

**Impact**

These APIs increase maintenance surface, create misleading tests that verify state transitions rather than real outcomes, and make it difficult for users to distinguish production features from experiments. Placeholder performance components are especially dangerous because they can report authoritative-looking metrics and recommendations.

**Recommendation**

Choose one of three statuses per component: implement, internalize behind an experimental namespace, or remove. Public production API should not expose identity operations as processors or simulated fragments as optimizers.

```swift
package enum ExperimentalEditorFeature {
    case textProcessing
    case fragmentPrefetching
}

@available(*, unavailable, message: "Text processing is not implemented")
public func processText(/* ... */) async throws { fatalError() }
```

For performance reporting, inject real sources (`DocumentMetricsProviding`, `TextLayoutMetricsProviding`) and omit a recommendation when its source is unavailable.

### A6. Speculative protocols and utilities add surface without substitutability

**Severity:** Medium

**Evidence**

- `ConfigurableUIComponent` and `ReusableUIComponent` have no in-tree conformers or consumers in [Sources/CodeEditorLayout/BaseUIComponents.swift](Sources/CodeEditorLayout/BaseUIComponents.swift#L14-L49).
- `UISpacing` and `UIMargins` are unused and duplicate the canonical token scale in [Sources/CodeEditorLayout/BaseUIComponents.swift](Sources/CodeEditorLayout/BaseUIComponents.swift#L51-L97) versus [Sources/CodeEditorDesignTokens/Spacing.swift](Sources/CodeEditorDesignTokens/Spacing.swift#L3-L33).
- `AnnotationViewProtocol`, `AnnotationsContentViewProtocol`, and `GutterViewProtocol` are each used only by their declaring concrete class; no API consumes the protocol existential in [Sources/CodeEditorAnnotations/AnnotationView.swift](Sources/CodeEditorAnnotations/AnnotationView.swift#L15-L30), [Sources/CodeEditorAnnotations/AnnotationsContentView.swift](Sources/CodeEditorAnnotations/AnnotationsContentView.swift#L15-L29), and [Sources/CodeEditorView/Layout/GutterView.swift](Sources/CodeEditorView/Layout/GutterView.swift#L69-L83).
- `CompletionCellComponentProvider` has platform-specific conformers but no generic consumer, and `CompletionCellFactory` has no in-tree call site in [Sources/CodeEditorLayout/CompletionCellComponents.swift](Sources/CodeEditorLayout/CompletionCellComponents.swift#L92-L123) and [Sources/CodeEditorLayout/CompletionCellComponents.swift](Sources/CodeEditorLayout/CompletionCellComponents.swift#L490-L510).

**Impact**

Unused abstractions make the public API harder to understand, imply extension points that are not integrated anywhere, and force maintainers to preserve contracts without receiving polymorphism or reuse in return.

**Recommendation**

Apply a “consumer before abstraction” rule. Remove protocols with zero consumers; keep concrete APIs until a second implementation or an injection point exists. Replace UI spacing helpers with `CGFloat(Tokens.Spacing.*)` or a single platform conversion extension.

```swift
extension Tokens.Spacing {
    static var platformDefault: CGFloat {
        #if canImport(AppKit)
        CGFloat(md)
        #else
        CGFloat(lg)
        #endif
    }
}
```

### A7. Test-environment detection is an ambient dependency

**Severity:** Medium

**Evidence**

- `TestEnvironmentDetector` introspects environment variables, loaded Objective-C classes, and framework bundles and exposes multiple execution wrappers in [Sources/CodeEditorCommon/Utilities/TestEnvironmentDetector.swift](Sources/CodeEditorCommon/Utilities/TestEnvironmentDetector.swift#L6-L70) and [Sources/CodeEditorCommon/Utilities/TestEnvironmentDetector.swift](Sources/CodeEditorCommon/Utilities/TestEnvironmentDetector.swift#L73-L155).
- Its only production consumer skips memory cleanup registration in tests in [Sources/CodeEditorView/MemoryManagementCoordinator.swift](Sources/CodeEditorView/MemoryManagementCoordinator.swift#L127-L148).

**Impact**

Tests do not exercise the production lifecycle they are intended to validate. Process introspection is a hidden global dependency and can mis-detect preview hosts or alternative runners.

**Recommendation**

Inject an explicit cleanup-registration policy through runtime dependencies and default it to enabled. Tests that need isolation can disable it locally while lifecycle tests leave it enabled.

```swift
public struct MemoryManagementPolicy: Sendable {
    public var registersCleanupHandlers = true
}
```

## Pattern Consistency Review

### Positive patterns worth preserving

- **Platform detection is consistent.** The production tree contains no `#if os(...)` checks and uses `canImport` throughout.
- **Custom singleton state has been removed.** Searches found no framework-defined `static let shared`; remaining `.shared` references are Apple concurrency/application APIs.
- **Delegate ownership is explicit.** `CodeEditorView` documents the multiplexer invariant in [Sources/CodeEditorView/CodeEditorView.swift](Sources/CodeEditorView/CodeEditorView.swift#L154-L187), and lint enforces the sole assignment point in [.swiftlint.yml](.swiftlint.yml#L281-L291).
- **Configuration values are separated from live services.** The design intent in [Sources/CodeEditorView/EditorRuntime.swift](Sources/CodeEditorView/EditorRuntime.swift#L10-L15) is correct even though update semantics need refinement.
- **Cross-platform shared-state extraction works when applied.** `MinimapThemeState` is a good example of centralizing semantic state while leaving platform drawing separate in [Sources/CodeEditorView/Layout/MinimapView.swift](Sources/CodeEditorView/Layout/MinimapView.swift#L126-L153).

### P1. Target boundaries are undermined by umbrella dependencies

**Severity:** High

**Evidence**

- The umbrella file re-exports six modules and explicitly says opt-in subsystems remain explicit imports in [Sources/CodeEditorPlugin/CodeEditorPlugin.swift](Sources/CodeEditorPlugin/CodeEditorPlugin.swift#L1-L12).
- The umbrella target nevertheless declares dependencies on 18 internal targets, including annotations, completion, diagnostics, folding, LSP, layout, smart editing, symbols, and syntax highlighting in [Package.swift](Package.swift#L307-L330).
- Optional `CodeEditorUI` depends on the umbrella and six direct modules in [Package.swift](Package.swift#L336-L347). Most UI files import both `CodeEditorPlugin` and their specific modules, for example [Sources/CodeEditorUI/Breadcrumb/EditorBreadcrumbView.swift](Sources/CodeEditorUI/Breadcrumb/EditorBreadcrumbView.swift#L1-L5) and [Sources/CodeEditorUI/StatusBar/EditorStatusBar.swift](Sources/CodeEditorUI/StatusBar/EditorStatusBar.swift#L1-L4).

**Impact**

The package graph communicates opt-in modularity, but building optional UI pulls the umbrella, and the umbrella itself lists opt-in modules as dependencies. This increases build fan-out, hides accidental dependencies through re-exports, and makes target boundaries less enforceable.

**Recommendation**

Make each target import and depend on only the modules whose symbols it uses. Remove `CodeEditorPlugin` from `CodeEditorUI`, replace umbrella imports with exact imports, and trim unused direct dependencies from the umbrella. Add a CI script that compares `import CodeEditorX` statements with SPM dependencies.

```swift
.target(
    name: "CodeEditorUI",
    dependencies: [
        "CodeEditorDesignTokens",
        "CodeEditorLanguages",
        "CodeEditorSwiftUI",
        "CodeEditorSymbols",
        "CodeEditorTheming",
        "CodeEditorView"
    ]
)
```

### P2. SwiftUI reconciliation ignores runtime-only changes

**Severity:** High

**Evidence**

- `UpdateState` includes only text, language, and configuration in [Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift](Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift#L107-L129).
- `updateContainer` exits before applying `runtimeDependencies` whenever those three values are unchanged in [Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift](Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift#L460-L494).
- The completion closure had to be special-cased before that guard in [Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift](Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift#L478-L481), demonstrating that the reconciliation key is incomplete.

**Impact**

Changing a workspace root, event system, memory monitor, or other live dependency without also changing text/language/configuration is ignored by SwiftUI. This violates the framework’s environment-driven update model and invites more pre-guard special cases.

**Recommendation**

Reconcile value state and runtime state independently. Give reference dependencies stable identities or versions rather than trying to make the whole bag `Equatable`.

```swift
let valueChanged = shouldUpdate(text: text, language: language, configuration: configuration)
let runtimeChanged = runtimeSnapshot != RuntimeSnapshot(runtimeDependencies)

if runtimeChanged {
    textView.apply(runtimeDependencies: runtimeDependencies)
}
guard valueChanged else { return }
```

### P3. Event delivery has two buses plus direct notifications

**Severity:** High

**Evidence**

- Every `publishEvent` fans out to the view-local `EditorEventPublisher` and an optional runtime `UnifiedEventSystem` in [Sources/CodeEditorView/UnifiedEventSystem.swift](Sources/CodeEditorView/UnifiedEventSystem.swift#L404-L413).
- `EditorEventPublisher` is actor-backed and its synchronous bridge explicitly cannot guarantee ordering in [Sources/CodeEditorView/EditorEventPublisher.swift](Sources/CodeEditorView/EditorEventPublisher.swift#L143-L169).
- `UnifiedEventSystem` is main-actor synchronous, adds filters, history, typed state, Combine publishing, and handlers in [Sources/CodeEditorView/UnifiedEventSystem.swift](Sources/CodeEditorView/UnifiedEventSystem.swift#L11-L85).
- Selection changes additionally post `NotificationCenter` before publishing an `EditorEvent` in [Sources/CodeEditorView/CodeEditorView+ConfigurationExtensions.swift](Sources/CodeEditorView/CodeEditorView+ConfigurationExtensions.swift#L131-L141).

**Impact**

Subscribers can observe different order, filtering, history, and thread semantics depending on which surface they choose. Every new event requires a decision about up to three channels, and duplicate delivery is easy for hosts that bridge them.

**Recommendation**

Define one canonical `EditorEventBus` with explicit ordering. Treat Combine, weak handlers, and `NotificationCenter` as adapters at the boundary, not independent sources of truth.

```swift
@MainActor
protocol EditorEventBus: AnyObject {
    func publish(_ event: EditorEvent)
    func stream() -> AsyncStream<EditorEvent>
}

final class NotificationCenterEventAdapter {
    init(bus: any EditorEventBus) { /* translate only legacy notifications */ }
}
```

### P4. File decomposition and platform adaptation are applied inconsistently

**Severity:** Medium

**Evidence**

- Configuration behavior is split between nearly identical filenames: the public validated entry point is in [Sources/CodeEditorView/CodeEditorView+Configuration.swift](Sources/CodeEditorView/CodeEditorView+Configuration.swift#L10-L33), while the actual application pipeline is in [Sources/CodeEditorView/CodeEditorView+ConfigurationExtensions.swift](Sources/CodeEditorView/CodeEditorView+ConfigurationExtensions.swift#L11-L109).
- The generic catch-all [Sources/CodeEditorView/CodeEditorView+Extensions.swift](Sources/CodeEditorView/CodeEditorView+Extensions.swift#L11-L95) contains editing commands, while the same file also contains platform-specific selection and scrolling overrides in [Sources/CodeEditorView/CodeEditorView+Extensions.swift](Sources/CodeEditorView/CodeEditorView+Extensions.swift#L97-L287).
- `performCut`, `performCopy`, `performPaste`, and `performSelectAll` have identical `canImport` branches in [Sources/CodeEditorView/CodeEditorView+Extensions.swift](Sources/CodeEditorView/CodeEditorView+Extensions.swift#L15-L53).
- iOS selection setters repeat the same save-disable-set-restore-scroll sequence in [Sources/CodeEditorView/CodeEditorView+Extensions.swift](Sources/CodeEditorView/CodeEditorView+Extensions.swift#L146-L218) and [Sources/CodeEditorView/CodeEditorView+Extensions.swift](Sources/CodeEditorView/CodeEditorView+Extensions.swift#L220-L254).

**Impact**

Maintainers cannot reliably infer where a behavior lives from the filename. Redundant platform branches obscure the cases where platforms actually differ, and repeated state-preservation code can drift.

**Recommendation**

Rename by responsibility (`+ConfigurationApplication`, `+EditingActions`, `+SelectionScrolling`) and centralize platform-neutral code outside conditional branches.

```swift
#if canImport(UIKit)
private func preservingScrollPosition(_ operation: () -> Void) {
    let offset = contentOffset
    let wasEnabled = isScrollEnabled
    isScrollEnabled = false
    operation()
    isScrollEnabled = wasEnabled
    if contentOffset != offset { setContentOffset(offset, animated: false) }
}
#endif
```

### P5. The test architecture has not followed the production target split

**Severity:** Medium

**Evidence**

- `CodeEditorPluginTests` depends on nearly every internal target in [Package.swift](Package.swift#L378-L409).
- Of its 181 files, 172 import the umbrella testably, 177 import `CodeEditorView`, and 176 import `CodeEditorSwiftUI`; many tests therefore compile against three broad internal surfaces regardless of the feature under test.
- Separate targets exist only for design tokens, UI, and the sample in [Package.swift](Package.swift#L410-L462).

**Impact**

The monolithic test target weakens module-boundary feedback, increases incremental test compile time, and allows tests to rely on imports that production consumers do not have. A target can appear isolated while its tests still reach through the umbrella.

**Recommendation**

Create test targets along stable module seams, beginning with `CodeEditorCommonTests`, `CodeEditorTextModelTests`, `CodeEditorCompletionTests`, `CodeEditorLSPTests`, and `CodeEditorViewTests`. Keep a much smaller `CodeEditorPluginIntegrationTests` target for cross-module scenarios.

### P6. A stale lint path disables an intended architectural rule

**Severity:** Medium

**Evidence**

- The `forbidden_swiftui_extension_codeeditor` rule includes the deleted `Sources/CodeEditorPlugin/SwiftUI/` path and exempts a file under that deleted path in [.swiftlint.yml](.swiftlint.yml#L293-L303).
- The actual file is [Sources/CodeEditorSwiftUI/CodeEditor+FactoryExtensions.swift](Sources/CodeEditorSwiftUI/CodeEditor+FactoryExtensions.swift#L1-L12).
- Project guidance acknowledges the old umbrella directories were extracted in [AGENTS.md](AGENTS.md#L50-L64), yet the same guidance still claims only four products in [AGENTS.md](AGENTS.md#L31-L46), while `Package.swift` defines eleven products in [Package.swift](Package.swift#L52-L100).

**Impact**

The lint rule currently matches no current SwiftUI source, so a documented architecture constraint is not enforced. Documentation drift also makes the package graph harder to reason about and encourages stale automation.

**Recommendation**

Update the rule to `Sources/CodeEditorSwiftUI/.*\.swift`, update the exemption, add a regression fixture that must fail lint, and generate the product table from `swift package describe` or validate it in CI.

### P7. Logging policy is centralized syntactically but not semantically

**Severity:** Low

**Evidence**

- The codebase correctly avoids production `print` and enforces the wrapper in [.swiftlint.yml](.swiftlint.yml#L252-L265).
- However, 41 production call sites use the uncategorized `CrossPlatformLogger.logger()`, including [Sources/CodeEditorView/CodeEditorView+Extensions.swift](Sources/CodeEditorView/CodeEditorView+Extensions.swift#L146-L253).
- Categorized loggers use multiple subsystem conventions (`CodeEditorPlugin`, `com.codeeditor.plugin`, `com.codeeditor.lsp`, and others), as illustrated by [Sources/CodeEditorView/CodeEditorView.swift](Sources/CodeEditorView/CodeEditorView.swift#L127-L132), [Sources/CodeEditorView/MemoryManagementCoordinator.swift](Sources/CodeEditorView/MemoryManagementCoordinator.swift#L13-L21), and [Sources/CodeEditorLSP/LSPClient.swift](Sources/CodeEditorLSP/LSPClient.swift#L143-L146).

**Impact**

Logs are harder to filter by subsystem and feature, and high-frequency debug paths repeatedly construct default loggers. This is operational inconsistency rather than a design blocker.

**Recommendation**

Define canonical subsystem constants and one static logger per type/feature. Remove emoji-prefixed diagnostics from hot paths or gate them behind a dedicated rendering/interaction diagnostics switch.

## Duplication and Reuse Audit

### Duplication profile and classification

The 141 library clone pairs cluster primarily in theming (32 pairs), `CodeEditorView` (21), languages (13), syntax highlighting (10), layout (8), LSP (8), and SwiftUI (7). Raw counts should not drive refactors by themselves.

| Duplication family | Classification | Action |
|---|---|---|
| LRU linked-list kernels | Genuine redundancy | Consolidate immediately. |
| Debounce implementations | Genuine redundancy with divergent naming | Replace with one cancellation contract. |
| LSP string/integer wire values | Genuine codec duplication | Share an internal codec/value primitive. |
| JavaScript/TypeScript capture maps | Genuine data duplication | Derive TypeScript from JavaScript. |
| Completion cell theme/application state | Reusable cross-platform state | Extract state/model; retain native views. |
| Minimap drawing and platform view shells | Mixed | Share geometry/state; keep native drawing. |
| Theme semantic structs | Acceptable repetition | Preserve strong semantic types; share loader helpers only. |
| Language descriptors/folding providers | Mostly acceptable declarative repetition | Consolidate only identical bases or factories. |
| Apple representable/coordinator shells | Acceptable platform repetition | Keep explicit unless behavior is byte-for-byte identical. |

### D1. Two independent linked-list LRU caches implement the same kernel

**Severity:** High

**Evidence**

- `LRUCache` defines its own node, dictionary, head/tail bookkeeping, promotion, eviction, and removal in [Sources/CodeEditorDiagnostics/LRUCache.swift](Sources/CodeEditorDiagnostics/LRUCache.swift#L4-L24) and [Sources/CodeEditorDiagnostics/LRUCache.swift](Sources/CodeEditorDiagnostics/LRUCache.swift#L49-L171).
- `LinkedLRU` implements the same data structure in [Sources/CodeEditorCommon/LinkedLRU.swift](Sources/CodeEditorCommon/LinkedLRU.swift#L3-L39) and [Sources/CodeEditorCommon/LinkedLRU.swift](Sources/CodeEditorCommon/LinkedLRU.swift#L47-L136).
- Both are active: completion, viewport, and syntax caches use `LRUCache`, while paragraph style and layout caches use `LinkedLRU`.

**Impact**

Eviction correctness, capacity semantics, performance fixes, and tests must be maintained twice. The implementations already differ on invalid capacity (`max(1, capacity)` versus `precondition`) and available operations.

**Recommendation**

Make `LinkedLRU` the policy-free kernel in `CodeEditorCommon`; implement the monitored cache as a wrapper rather than another linked list.

```swift
@MainActor
public final class LRUCache<Key: Hashable & Sendable, Value: Sendable> {
    private let storage: LinkedLRU<Key, Value>
    private let memoryMonitor: MemoryMonitor

    public func get(_ key: Key) -> Value? { storage.value(forKey: key) }
    public func set(_ value: Value, forKey key: Key) {
        storage.setValue(value, forKey: key)
    }
}
```

### D2. “Optimized” debounce duplicates the standard implementation

**Severity:** High

**Evidence**

- `debounce` cancels, clears result/error dictionaries, creates a task, sleeps, stores a type-erased result, waits, and casts in [Sources/CodeEditorCommon/Utilities/AsyncOperationManager+DebouncingExtensions.swift](Sources/CodeEditorCommon/Utilities/AsyncOperationManager+DebouncingExtensions.swift#L42-L87).
- `debounceOptimized` repeats the same algorithm in [Sources/CodeEditorCommon/Utilities/AsyncOperationManager+OptimizedDebouncing.swift](Sources/CodeEditorCommon/Utilities/AsyncOperationManager+OptimizedDebouncing.swift#L21-L71). It still waits for completion and allocates an unused UUID at lines 33–34, contrary to its documentation.
- Shared result/error dictionaries are declared on the broad manager in [Sources/CodeEditorCommon/Utilities/AsyncOperationManager.swift](Sources/CodeEditorCommon/Utilities/AsyncOperationManager.swift#L156-L165).

**Impact**

The two APIs can drift while promising different performance characteristics. Both use type-erased shared result slots, and cancellation can surface as `noResult`, making the behavior harder to reason about.

**Recommendation**

Define one generic debounce state machine with an explicit cancellation result. Keep fire-and-forget as a small wrapper over the same scheduling primitive.

```swift
public func debounce<T: Sendable>(
    key: String,
    delay: Duration,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let task = replaceTask(for: key) {
        try await Task.sleep(for: delay)
        try Task.checkCancellation()
        return try await operation()
    }
    return try await task.value
}
```

### D3. LSP union codecs and capture maps repeat canonical data

**Severity:** Medium

**Evidence**

- `RequestId` and `DiagnosticCode` repeat the same `String | Int` Codable implementation in [Sources/CodeEditorLSP/LSPTypes.swift](Sources/CodeEditorLSP/LSPTypes.swift#L41-L79) and [Sources/CodeEditorLSP/LSPTypes.swift](Sources/CodeEditorLSP/LSPTypes.swift#L556-L588).
- JavaScript and TypeScript capture maps are identical in [Sources/CodeEditorSyntaxHighlighting/RegexQuery/QueryCaptureMap.swift](Sources/CodeEditorSyntaxHighlighting/RegexQuery/QueryCaptureMap.swift#L66-L106).

**Impact**

Wire-format bug fixes and capture-category updates must be applied in parallel. These are canonical-data duplicates, so divergence would be accidental rather than semantic.

**Recommendation**

Share a package-internal union value or codec and derive TypeScript from the JavaScript base.

```swift
package enum StringOrInteger: Codable, Hashable, Sendable {
    case string(String)
    case integer(Int)
}

package static let typescript = javascript
```

Public semantic wrappers can retain distinct names while delegating encode/decode to the shared primitive.

### D4. Cross-platform UI shares rendering state inconsistently

**Severity:** Medium

**Evidence**

- AppKit and UIKit completion cells duplicate theme-derived properties, configuration, and `apply(theme:)` in [Sources/CodeEditorLayout/CompletionCellComponents.swift](Sources/CodeEditorLayout/CompletionCellComponents.swift#L269-L357) and [Sources/CodeEditorLayout/CompletionCellComponents.swift](Sources/CodeEditorLayout/CompletionCellComponents.swift#L400-L486).
- Minimap AppKit/UIKit views duplicate placeholder layout, viewport geometry invocation, data updates, and line-number calculation in [Sources/CodeEditorView/Layout/MinimapView.swift](Sources/CodeEditorView/Layout/MinimapView.swift#L396-L467) and [Sources/CodeEditorView/Layout/MinimapView.swift](Sources/CodeEditorView/Layout/MinimapView.swift#L536-L601). The existing `MinimapThemeState` demonstrates the correct shared-state pattern.
- Toolbar item definitions for Replace/Symbols/Format are repeated between macOS and iPad in [Sources/CodeEditorView/Platform/ToolbarCoordinator.swift](Sources/CodeEditorView/Platform/ToolbarCoordinator.swift#L252-L299) and [Sources/CodeEditorView/Platform/ToolbarCoordinator.swift](Sources/CodeEditorView/Platform/ToolbarCoordinator.swift#L302-L349).

**Impact**

Visual state and command catalogs can drift across platforms even when native view/drawing code legitimately differs.

**Recommendation**

Extract shared semantic state and command descriptors, while preserving native platform views:

```swift
struct CompletionCellThemeState {
    private(set) var appliedTheme: Theme?
    private(set) var metrics: CompletionPopoverThemeMetrics

    mutating func apply(_ theme: Theme) -> Bool { /* equality gate */ }
}

private static let editingItems: [ToolbarItem] = [
    .init(title: "Replace", icon: "arrow.left.arrow.right", action: .replace, id: "replace"),
    .init(title: "Symbols", icon: "list.bullet.indent", action: .showSymbols, id: "symbol"),
    .init(title: "Format", icon: "text.alignleft", action: .format, id: "format")
]
```

### D5. Some repetition should remain explicit

**Severity:** Informational

**Evidence and rationale**

- `TextLevels` and `IconLevels` have parallel shapes in [Sources/CodeEditorTheming/TextLevels.swift](Sources/CodeEditorTheming/TextLevels.swift#L4-L90) and [Sources/CodeEditorTheming/IconLevels.swift](Sources/CodeEditorTheming/IconLevels.swift#L4-L90). They represent distinct public semantics and distinct external keys/fallbacks. Replacing them with one generic “five colors” type would weaken type meaning and complicate Codable compatibility.
- Platform `TextSelectionRect` implementations repeat stored properties in [Sources/CodeEditorTextModel/Text/TextSelectionRect.swift](Sources/CodeEditorTextModel/Text/TextSelectionRect.swift#L7-L53) and [Sources/CodeEditorTextModel/Text/TextSelectionRect.swift](Sources/CodeEditorTextModel/Text/TextSelectionRect.swift#L54-L100), but one must subclass `UITextSelectionRect` and one is a macOS compatibility value. A helper state struct would save little and add indirection.
- C/C++, JavaScript/TypeScript, and folding descriptors share declarative prefixes, for example [Sources/CodeEditorLanguages/Data/CLanguageDescriptor.swift](Sources/CodeEditorLanguages/Data/CLanguageDescriptor.swift#L7-L24) and [Sources/CodeEditorLanguages/Data/CppLanguageDescriptor.swift](Sources/CodeEditorLanguages/Data/CppLanguageDescriptor.swift#L7-L24). Their explicit files are discoverable and expected to evolve independently; consolidate only truly canonical bases.

**Recommendation**

Do not pursue a numeric duplication target. Refactor repeated *policy and algorithms* first; preserve repeated *semantic schemas and platform contracts* unless there is a concrete drift bug.

## Prioritized Refactoring Roadmap

### Phase 0 — Correctness and API truth (1–2 iterations)

1. **Make runtime updates state-preserving.** Fix `EditorRuntime.update(dependencies:)`, include runtime identity/version in SwiftUI reconciliation, and stop recreating completion/LSP owners when only the memory monitor changes.
2. **Quarantine placeholder public APIs.** Internalize or mark experimental `TextProcessingActor`, `TextKit2RenderingOptimizer`, and placeholder TextKit metrics until their operations are real. Replace fixed performance data with injected metric providers.
3. **Add focused regression coverage.** Prove completion providers, learned state, custom feature dependencies, LSP workspace roots, and event systems survive supported runtime updates.

**Expected impact:** Highest reduction in surprising behavior and false API guarantees.

### Phase 1 — Ownership boundaries (2–4 iterations)

4. **Introduce `EditorSession` feature controllers.** Move completion, highlighting, folding, and LSP lifecycle/state out of `CodeEditorView` one feature at a time while preserving public forwarding APIs.
5. **Decompose `CodeEditorBaseCoordinator`.** Extract binding, interaction-state, focus, and modifier-provider synchronization; make reconciliation inputs explicit values.
6. **Split completion and LSP internals.** Separate registries/ranking/caches from request orchestration, and JSON-RPC session/transport from LSP feature APIs.
7. **Choose one canonical event bus.** Retain Combine, weak-handler, and notification compatibility through adapters.

**Expected impact:** Largest long-term improvement in change isolation, testability, and onboarding.

### Phase 2 — Reuse high-value kernels (1–2 iterations)

8. **Unify LRU storage.** Wrap `LinkedLRU` with monitoring/statistics and delete the duplicate node implementation.
9. **Replace both debounce methods with one state machine.** Define cancellation and result semantics with tests before deleting compatibility shims.
10. **Share canonical wire/data definitions.** Consolidate string-or-integer LSP encoding and derive TypeScript capture mappings from JavaScript.
11. **Extract shared UI semantic state.** Apply the existing `MinimapThemeState` pattern to completion cells and toolbar command catalogs; retain platform-native rendering code.

**Expected impact:** Moderate code reduction with disproportionately high consistency benefit.

### Phase 3 — Enforce the architecture (1–3 iterations)

12. **Tighten target dependencies and imports.** Remove umbrella imports from `CodeEditorUI`, trim unused target dependencies, and validate imports against `Package.swift` in CI.
13. **Split the monolithic test target.** Establish module-specific unit-test targets and reserve umbrella tests for integration behavior.
14. **Delete speculative protocols and unused utility scales.** Prefer concrete types until an actual consumer requires substitution; use design tokens as the only spacing source.
15. **Repair lint/documentation drift.** Update the SwiftUI lint path, add a failing regression fixture, generate/validate product documentation, and remove stale source-path comments from live code.
16. **Normalize logging identity.** Centralize subsystem/category constants and remove high-volume uncategorized interaction logs.

**Expected impact:** Sustains the refactor by making architectural drift visible during review and CI.

## Closing Assessment

The codebase has already completed the difficult first step: its major domains are visible and mostly separated at the package level. The next improvement should not be another broad directory carve-out. It should be a **runtime ownership refactor** that makes each feature own its state, tasks, observers, caches, and cleanup lifecycle. Once those boundaries exist, the current target graph will become meaningful rather than aspirational, and duplication cleanup can proceed through small, low-risk kernel extractions.

The recommended roadmap intentionally preserves public façades and native platform implementations. Its goal is not maximal abstraction or minimal line count; it is to ensure that every abstraction corresponds to real substitutability, every owner has a coherent lifecycle, and repeated code remains only where explicit semantic or platform differences justify it.
