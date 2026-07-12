# Code Quality Remediation Design

**Status:** Approved architecture, pending implementation plan

**Source audit:** `CODE_QUALITY_AUDIT.md`

**Objective:** Fully remediate every finding and recommendation in the structural code-quality audit while preserving stable editor-facing APIs and allowing removal of public APIs that are explicitly placeholder, unused, or misleading.

## 1. Design Principles

1. Runtime ownership, not file count, defines decomposition success.
2. Every long-lived feature owner must own its tasks, observers, caches, injected dependencies, and teardown lifecycle.
3. Stable editor-facing APIs remain source compatible unless the audit identifies the API itself as placeholder or unused.
4. Placeholder behavior is not retained behind a compatibility shim. It is implemented with real behavior, replaced with an honest metrics-only API, or removed.
5. One canonical implementation owns each cross-cutting policy: runtime reconciliation, event ordering, LRU storage, debouncing, logging identity, and target dependency declarations.
6. Platform-native view and drawing code remains explicit where AppKit and UIKit contracts genuinely differ.
7. Each behavior change follows test-driven development. Structural changes gain tests that prove ownership, dependency direction, API surface, or state preservation.

## 2. Compatibility Boundary

### Stable APIs to preserve

- `CodeEditorView`
- SwiftUI `CodeEditor`
- `EditorConfiguration`, `EditorSetup`, and supported runtime injection entry points
- `CompletionManager` public behavior
- `LSPClient` public behavior
- public search, workspace, annotations, symbols, theming, and UI products
- existing Combine, handler, and notification event entry points, implemented as compatibility adapters over one event bus

Stable façade types may delegate to new internal components. Their observable behavior, ordering guarantees, and documented error semantics remain compatible or become stricter where the existing behavior is defective.

### APIs that may be removed or narrowed

- placeholder text processors and rendering optimizers
- fixed or simulated performance-metric surfaces
- public protocols with no consumer or injection point
- unused public factories and duplicated spacing utilities
- redundant “optimized” APIs that do not provide distinct behavior

Where an external consumer could plausibly have adopted a non-placeholder API, retain a deprecated forwarding alias for one release. Do not retain shims whose only effect is to preserve simulated or identity behavior.

## 3. Completion Requirements

The implementation is complete only when every row below is satisfied by current source and verification evidence.

| Audit item | Required end state | Proof |
|---|---|---|
| A1 | `CodeEditorView` delegates feature lifecycle to `EditorSession` feature owners; teardown is centralized and idempotent. | Ownership tests plus reduced view-owned feature state. |
| A2 | SwiftUI coordination is split into binding, interaction, modifier-provider, and render reconciliation components. | Focused unit tests and coordinator responsibility check. |
| A3 | Completion and LSP façades delegate to focused internal components. | Unit tests for each component and façade integration tests. |
| A4 | Runtime and memory-monitor updates preserve custom feature dependencies, completion providers/learning, and LSP state. | Identity/state-preservation regression tests. |
| A5 | Placeholder public processors, optimizers, and fixed metrics are implemented honestly or removed. | Placeholder scan plus behavioral metrics tests. |
| A6 | Zero-consumer protocols/factories/utilities are deleted or backed by a real consumer. | Symbol/reference and public API checks. |
| A7 | Production lifecycle does not branch on process-level test detection. | No production `TestEnvironmentDetector` use; injected policy tests. |
| P1 | Target dependencies and imports match actual symbol use; `CodeEditorUI` does not import the umbrella. | Import/dependency verifier and clean build. |
| P2 | Runtime-only SwiftUI changes reconcile independently from value-state changes. | Runtime-only update tests. |
| P3 | One ordered event bus is canonical; all legacy surfaces adapt from it. | Cross-adapter ordering and single-delivery tests. |
| P4 | Extension files are responsibility-named; identical platform branches and scroll-preservation near-clones are removed. | Source scans and behavior tests. |
| P5 | Major modules have focused test targets; umbrella tests are integration-only. | `Package.swift` and full test run. |
| P6 | SwiftLint paths and product documentation match the current target graph. | Lint fixture and documentation verifier. |
| P7 | Logger subsystem/category identities are canonical; no uncategorized hot-path logging remains. | Logging source scan. |
| D1 | One linked-list LRU kernel remains. | Type/source scan and cache tests. |
| D2 | One debounce state machine defines cancellation and result semantics. | Concurrency tests and obsolete API scan. |
| D3 | LSP string/integer coding and JS/TS capture maps share canonical definitions. | Codec round-trip and identity tests. |
| D4 | Completion-cell state, toolbar catalog, and scroll preservation share reusable semantic helpers. | Platform tests and clone scan. |
| D5 | Semantic schemas and true platform contracts remain explicit. | Review of retained clone classifications. |

## 4. Target Runtime Architecture

### 4.1 `EditorSession` composition root

`CodeEditorView` remains the public platform view. It no longer directly owns each feature manager. A package-internal `EditorSession` owns feature controllers and attaches them to one view.

```swift
@MainActor
package final class EditorSession {
    package let highlighting: HighlightingController
    package let completion: CompletionController
    package let folding: FoldingController
    package let events: EditorEventBus
    #if canImport(AppKit)
    package let lsp: LSPDocumentController
    #endif

    package func attach(to view: CodeEditorView)
    package func update(_ change: EditorSessionChange)
    package func detach()
}
```

Each controller:

- owns its feature tasks, observers, caches, and cleanup token;
- accepts narrow dependency values at initialization;
- exposes idempotent `attach`, `update`, and `detach` operations;
- does not retain the view beyond the attached lifecycle;
- can be tested without constructing unrelated services.

The session does not become a new God object. It coordinates lifecycle only; feature policy stays in the controllers.

### 4.2 Runtime dependency updates

`EditorRuntime` separates stable feature ownership from replaceable infrastructure.

- `EditorFeatureRuntimeDependencies` is created once unless a host explicitly replaces it.
- `EditorRuntimeDependencies` changes produce a typed `EditorRuntimeChange`.
- `EditorSession` applies the change to affected controllers.
- Memory-monitor changes re-register cleanup handlers without replacing feature controllers.
- Workspace-root changes update only LSP document/connection state.
- Event-bus changes swap the adapter target without rebuilding completion, highlighting, or folding.

No supported infrastructure update discards provider registration, learned completion state, caches unrelated to that dependency, or a live LSP connection.

### 4.3 Memory management

Feature owners conform to a package-internal rebinding contract:

```swift
@MainActor
package protocol MemoryMonitorUsing: AnyObject {
    func setMemoryMonitor(_ monitor: MemoryMonitor)
}
```

Rebinding unregisters the old cleanup token, registers with the new monitor, and retains feature state. Cleanup estimates must be derived from actual removed entries or explicitly reported as unknown; fixed per-item byte claims are removed unless measured.

The production path receives an explicit `MemoryManagementPolicy`. Tests disable periodic behavior through this dependency rather than process introspection.

## 5. SwiftUI Bridge Architecture

`CodeEditorBaseCoordinator` becomes a lifecycle shell containing four focused collaborators:

1. `EditorBindingSynchronizer`: text binding, debounce, feedback-loop prevention, and text callbacks.
2. `EditorInteractionSynchronizer`: selection, cursor restoration, dirty baseline, and `EditorState` mirroring.
3. `CompletionModifierRegistry`: lifecycle of the SwiftUI closure completion provider.
4. `EditorRenderReconciler`: value-state and runtime-state diffing, mount/update ordering, and theme/configuration application.

`EditorRenderSnapshot` tracks value state. `EditorRuntimeSnapshot` tracks identity/version for runtime-only dependencies. A runtime change is applied before any early return based on text/language/configuration equality.

The coordinator retains platform delegate conformance only where Apple APIs require it. Common initializer state is defined once; platform-specific subclasses add only genuine platform behavior.

## 6. Completion and LSP Decomposition

### 6.1 Completion

The public `CompletionManager` delegates to:

- `CompletionProviderRegistry`
- `CompletionRequestCoordinator`
- `CompletionResponseCache`
- `CompletionLearningStore`
- `CompletionRanker`
- `CompletionEventSink`

The request coordinator owns cancellation and concurrent provider fan-out. The ranker is a pure value component. Cache and learning stores share the canonical LRU kernel but remain separate state owners.

### 6.2 LSP

The public `LSPClient` delegates to:

- `JSONRPCSession`: request IDs, pending continuations, encoding, response routing, and exactly-once completion;
- `LSPConnectionLifecycle`: local process/remote transport setup and teardown;
- `LSPDocumentSession`: open/change/close notifications and diagnostic state;
- `LSPLanguageFeatureClient`: completion, hover, definition, symbols, and semantic tokens.

The façade owns public observable state and projects component changes onto it. Transport errors and protocol errors retain their documented distinctions. Teardown remains idempotent and fails every pending continuation exactly once.

## 7. Canonical Event System

One main-actor `EditorEventBus` defines event ordering, filtering, history, and streams. Publishing is synchronous on the main actor; async callers hop to the main actor before publishing.

Compatibility adapters provide:

- `EditorEventPublisher` weak-handler and Combine surfaces;
- `UnifiedEventSystem` history/filter configuration where still public;
- legacy `NotificationCenter` names.

Adapters subscribe to the canonical bus. `CodeEditorView` publishes each event once. Adapters never republish into the bus, preventing loops and duplicate delivery.

The bus assigns monotonically increasing sequence numbers internally so tests can prove identical ordering across adapters.

## 8. Placeholder API Resolution

### Text processing

Remove `TextProcessingActor`, the actor-coordinator text-processing façade, and `CodeEditorView.processText` unless an operation can delegate to an existing real editing engine. Indentation, bracket matching, line wrapping, and whitespace normalization must not remain identity functions.

Real smart-editing behavior continues through `CodeEditorSmartEditing`. If a public convenience is retained, it delegates to the appropriate real engine and documents its supported operation.

### Rendering optimizer

Remove simulated fragment creation, recycling, and prefetching. Retain only truthful observation as `TextKit2RenderingMetrics` if its counters are sourced from real TextKit layout callbacks. Large-file behavior continues through real line geometry, viewport, and highlighting components.

### Performance insights

`PerformanceInsights` receives:

- `DocumentMetricsProviding`
- `TextLayoutMetricsProviding`
- existing memory, frame-rate, and performance monitors

Unavailable data is represented as unavailable, not a fixed default. Recommendations requiring unavailable metrics are omitted. Alert behavior remains local and deterministic.

## 9. Reuse Kernels

### LRU

`LinkedLRU` in `CodeEditorCommon` is the only node/list implementation. Monitored caches wrap it and add cleanup registration and statistics. Capacity handling becomes consistent and is tested at zero, one, update, promotion, eviction, and removal boundaries.

### Debouncing

One generic state machine owns keyed task replacement. It uses `Duration`, propagates cancellation as `CancellationError`, never stores type-erased results in shared dictionaries, and supports result-returning and fire-and-forget wrappers.

### Wire/data definitions

- A package-internal `StringOrInteger` provides LSP coding.
- Public `RequestId` and `DiagnosticCode` retain semantic names while delegating coding.
- TypeScript capture mappings derive from JavaScript and add only TypeScript-specific overrides.

### Cross-platform UI state

- `CompletionCellThemeState` mirrors the successful `MinimapThemeState` pattern.
- `ToolbarCatalog` owns common command descriptors; platform builders select subsets.
- UIKit selection mutation uses one `preservingScrollPosition` helper.
- Native view construction and drawing remain platform-specific.

## 10. Package and Test Boundaries

### Production targets

- Remove `CodeEditorPlugin` imports and dependency from `CodeEditorUI`.
- Import exact modules in every target.
- Trim umbrella dependencies to modules it re-exports or directly needs.
- Add `Scripts/verify-target-imports.py` to compare internal imports with declared target dependencies and reject umbrella imports from focused targets.

### Test targets

Create focused targets for:

- `CodeEditorCommonTests`
- `CodeEditorTextModelTests`
- `CodeEditorCompletionTests`
- `CodeEditorLSPTests`
- `CodeEditorViewTests`
- `CodeEditorSwiftUITests`

Move tests by the primary module under test. `CodeEditorPluginTests` becomes integration-only and imports public products unless a specific cross-module invariant requires package access.

### Lint and documentation

- Repair the SwiftUI extension-rule paths.
- Add a lint fixture/verifier that proves a forbidden extension fails.
- Generate or verify the AGENTS product table against `swift package describe`.
- Update live comments and diagrams when types or ownership change.
- Archived documents remain historical and are not rewritten solely for path changes.

## 11. Logging

`CodeEditorLog` defines canonical subsystem identifiers and category construction. Each long-lived type owns a static categorized logger. Production code does not call the uncategorized factory. High-volume interaction diagnostics route through an explicit diagnostics gate and omit decorative emoji prefixes.

```swift
enum CodeEditorLog {
    static let subsystem = "com.codeeditor.plugin"

    static func logger(_ category: Category) -> Logger {
        CrossPlatformLogger.logger(subsystem: subsystem, category: category.rawValue)
    }
}
```

LSP and sample code retain separate canonical subsystems where operational filtering benefits from it.

## 12. Error Handling and State Migration

- Runtime updates are atomic on the main actor.
- If a component cannot accept a dependency change in place, the API reports that a session restart is required before mutating state.
- Rebuilt components receive an explicit state snapshot; silent state loss is forbidden.
- Event adapters cannot throw from publication. Subscriber failures are isolated at adapter boundaries.
- Completion provider failures remain isolated per provider and emit one failure event.
- LSP pending requests complete exactly once on response, send failure, timeout, or teardown.
- Removed placeholder APIs are recorded in migration documentation with real replacements where available.

## 13. Implementation Waves

### Wave 1: Runtime correctness and API truth

- state-preserving runtime updates
- runtime-only SwiftUI reconciliation
- memory policy injection
- placeholder API removal/replacement
- real performance metric providers

### Wave 2: Ownership boundaries

- `EditorSession`
- feature controllers
- SwiftUI collaborator extraction
- completion decomposition
- LSP decomposition
- canonical event bus and adapters

### Wave 3: Reuse kernels

- linked LRU consolidation
- debounce consolidation
- LSP codec/capture-map consolidation
- completion-cell, toolbar, and scroll-preservation helpers
- responsibility-based extension file moves

### Wave 4: Architecture enforcement

- exact target imports/dependencies
- focused test targets
- unused abstraction removal
- lint/documentation verification
- canonical logging
- diagram updates

Each wave must leave the package buildable and its scoped tests passing. Compatibility façades are removed only after their replacement tests pass.

## 14. Test Strategy

Every behavior change follows red-green-refactor:

1. add a focused test that fails for the current defect or missing boundary;
2. run the narrow test and confirm the expected failure;
3. implement the smallest complete behavior;
4. run the narrow test, affected target tests, and then the full suite at wave completion.

Required structural verification includes:

- import/dependency graph verification;
- public placeholder and unused-protocol scans;
- uncategorized logger scan;
- stale path and lint-fixture verification;
- normalized exact-clone scan using the audit methodology;
- source ownership metrics for `CodeEditorView` and the SwiftUI coordinator;
- diagram reference validation;
- `swift build` and `swift build --target CodeEditorSample`;
- `swiftlint --fix`, `swiftlint`, and `swift test --parallel`.

Tests must validate outcomes rather than only object creation, mutable property assignment, or “does not throw” behavior.

## 15. Completion Gate

The goal is achieved only when:

1. all 19 audit findings have a resolved evidence entry;
2. no placeholder behavior identified by the audit remains reachable as production API;
3. stable façade behavior is covered by integration tests;
4. retained duplication is explicitly classified as semantic schema or platform contract repetition;
5. the target graph, test graph, lint rules, docs, and diagrams match current source;
6. build, lint, full tests, audit citation validation, structural verifiers, and clone metrics all pass from a clean checkout;
7. `CODE_QUALITY_AUDIT.md` is updated with a remediation appendix linking each finding to its implementation evidence.
