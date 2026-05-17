# CodeEditorFolding Extraction (§6.2.8a) — Design

Carve-out extraction of the pure code-folding engine from the
`CodeEditorPlugin` umbrella target into a new `CodeEditorFolding`
SPM target. The umbrella-coupled glue (`CodeFoldingCoordinatorService`,
`EditorRuntime` lifecycle, `CodeEditorView+*Extensions` slices that
touch the engine, and the `EditorConfiguration+CodeFolding` bridge)
stays where it is. Mirrors how §6.2.7 SH handled its nine
`CodeEditorView`-coupled files: leave the surface coupling in
umbrella, lift the leaf engine.

## Goals

1. Lift the pure folding engine (engine, providers registry, region/store
   adapters, storage primitives, presentation strategy, operations
   service, configuration struct) into its own SPM target so changes
   to fold-region detection or storage stop rebuilding the umbrella.
2. Compile-time enforce the internal layering. The umbrella-coupled
   service facade (`CodeFoldingCoordinatorService`, the `EditorRuntime`
   registration, the `CodeEditorView+SetupExtensions.setupCodeFoldingEngine`
   call site, and the related `+Extensions` slices) stays in the
   umbrella as editor-surface glue.
3. Resolve NEXT.md §10 question 2 (`CodeFoldingConfiguration` home) by
   keeping the type with the engine. The umbrella bridge file
   `Core/Configuration/EditorConfiguration+CodeFolding.swift` continues
   to translate `EditorConfiguration` → `CodeFoldingConfiguration` and
   gains `import CodeEditorFolding`. Configuration does **not** gain a
   Folding dep.

## Non-goals

- Not productizing the new target. No `.library(name: "CodeEditorFolding", …)`
  entry in `Package.swift`. Matches the Languages / SyntaxHighlighting
  precedent (§6.2.6 / §6.2.7). Folding is core to the editor; no
  consumer would opt out.
- Not refactoring the folding pipeline. No logic changes in
  `CodeFoldingEngine`, `FoldingProviderRegistry`, `FoldRegionAdapter`,
  `FoldPresentationStrategy`, `FoldingOperationsService`, or
  `LineFoldStorage`.
- Not abstracting `CodeEditorView` out of `CodeFoldingCoordinatorService`.
  The service's `isFoldable(at:in:)` / `toggleFold(at:in:)` signatures
  accept `CodeEditorView` directly; introducing a protocol to lift the
  service into the new target is §6.2.12 Core-split territory, not
  this session.
- Not pulling `FoldStoreElement` / `LineFoldStorage` / `FoldInfo` into
  `CodeEditorTextModel`. They conform to `RangeStoreElement` (a
  TextModel protocol post-§6.2.7) but they are fold-specific data
  shapes that travel with the engine. TextModel stays free of
  feature-specific storage types.
- Not splitting `Features/` directory yet. `SearchReplaceEngine.swift`,
  `SymbolNavigator.swift`, `SmartEditing/`, etc. stay put; their
  extractions follow in §6.2.8b–g.
- Not splitting test targets. `CodeEditorPluginTests` gains
  `CodeEditorFolding` as a direct dependency. Per-target test split
  is deferred to §6.2.15 (`CodeEditorTestSupport`).
- Not renaming the package or moving to `~/Workspace/packages/`. Those
  are §6.2.14 / §6.2.16 territory.

## Target shape & dependency edges

New target at `Sources/CodeEditorFolding/`. Direct dependencies
derived from the import survey across the 8 moving files:

```swift
.target(
    name: "CodeEditorFolding",
    dependencies: [
        "CodeEditorCommon",
        "CodeEditorDiagnostics",
        "CodeEditorLanguages",
        "CodeEditorPlatform",
        "CodeEditorSyntaxHighlighting",
        "CodeEditorTextModel"
    ],
    swiftSettings: swiftSettings
)
```

Phase 4. Sits alongside the other phase-4 engine targets that will land
in §6.2.8b–g (Symbols, SmartEditing, Search, Annotations, Workspace,
Completion).

Notably **not** included (no folding file imports them):
`CodeEditorConfiguration` (intentionally — the bridge stays in
umbrella), `CodeEditorTheming`, `CodeEditorDesignTokens`, `SwiftSyntax`/
`SwiftParser`.

Umbrella target `Package.swift` changes:

- Add `"CodeEditorFolding"` to `CodeEditorPlugin`'s `dependencies:`.
- Add `"CodeEditorFolding"` to `CodeEditorPluginTests`'s `dependencies:`.
- No new `exclude:` entries needed. After `git mv` removes the 8 files
  from `Sources/CodeEditorPlugin/Features/`, the directory still
  contains the Smart/Search/Symbols/Annotations/Workspace/Completion
  files (those move in subsequent §6.2.8 sub-steps). The new target's
  `path:` defaults to `Sources/CodeEditorFolding/` — a sibling source
  root.
- `CodeEditorUI` and `CodeEditorSample`: dependency to be added only if
  Step 0 pre-flight finds direct Folding-type references. Initial
  expectation is no — both consume `display.isCodeFoldingEnabled` from
  the Configuration target, not the engine.

## File map

### Moves into new `Sources/CodeEditorFolding/` (8 files)

All from `Sources/CodeEditorPlugin/Features/`:

| File | Owns |
|---|---|
| `CodeFoldingEngine.swift` | `@MainActor` engine, `ObservableObject`, `TextEditEventObserving` |
| `FoldableRegion.swift` | `FoldableRegion` struct + `CodeFoldingConfiguration` struct |
| `FoldStoreElement.swift` | `FoldStoreElement` (`RangeStoreElement` conformer) + `FoldingType` enum |
| `LineFoldStorage.swift` | `LineFoldStorage` (wraps `RangeStore<FoldStoreElement>`) + `FoldInfo` |
| `FoldRegionAdapter.swift` | `FoldRegionAdapter` (region → store) |
| `FoldPresentationStrategy.swift` | `FoldPresentationStrategy` protocol + `AttributeFoldPresentationStrategy` |
| `FoldingOperationsService.swift` | `FoldingOperationsService` + `extension NSAttributedString.Key` |
| `FoldingProviderRegistry.swift` | `FoldingProviderRegistry` (seeds 14 default providers) |

### Stays in umbrella (`CodeEditorView`-coupled, parallel to §6.2.7's nine SH carve-outs)

| File | Why it stays |
|---|---|
| `Core/CodeFoldingCoordinatorService.swift` | `public` API; methods take `CodeEditorView`; exposes nested `FoldControlLayout` / `FoldControlType` consumed by `Layout/GutterViewModel.swift` |
| `Core/EditorRuntime.swift` | Owns `codeFoldingEngine` / `codeFoldingCoordinatorService` lifecycle; throws `CodeEditorError.serviceUnavailable("CodeFoldingEngine")` |
| `Core/CodeEditorView+SetupExtensions.swift` (`setupCodeFoldingEngine` slice) | Extends umbrella `CodeEditorView` |
| `Core/CodeEditorView+CodeFoldingExtensions.swift` | Extends umbrella `CodeEditorView` |
| `Core/CodeEditorView+ConfigurationExtensions.swift` (`updateCodeFoldingConfiguration` slice) | Extends umbrella `CodeEditorView`; calls the bridge |
| `Core/CodeEditorView+CoreExtensions.swift` | References `codeFoldingEngine` on `CodeEditorView` |
| `Core/CodeEditorView+SyntaxHighlightingExtensions.swift` | References fold state on `CodeEditorView` |
| `Core/Configuration/EditorConfiguration+CodeFolding.swift` | Bridge between `CodeEditorConfiguration` and `CodeEditorFolding`; only umbrella can depend on both without a cycle |

### Stays in Layout (umbrella for now; moves with §6.2.11)

`Layout/FoldChevronAnimation.swift`, `Layout/GutterInteractionHandler.swift`,
`Layout/GutterViewModel.swift`, `Layout/GutterViewRenderer.swift`,
`Layout/CodeEditorContainerView+AppKitExtensions.swift`. Each gains
`import CodeEditorFolding`.

### Stays in SwiftUI (umbrella for now; moves with §6.2.13)

`SwiftUI/CodeEditor+ModifiersExtensions.swift`. Gains `import CodeEditorFolding`.

### Stays in Languages target (already there since §6.2.6)

`Languages/CodeFoldingInterfaces.swift` (the `CodeFoldingProvider`
protocol) and the 11 per-language `*FoldingProvider.swift` files. No
change. Their `package` access modifiers from §6.2.6 already let
`FoldingProviderRegistry` reach them from the new target.

### Stays in SyntaxHighlighting target (since §6.2.7)

`SyntaxHighlighting/RegexQuery/HeuristicFoldProvider.swift`. Already
`package`-promoted. `FoldingProviderRegistry` keeps its
`import CodeEditorSyntaxHighlighting`.

## Access-modifier promotions

Pattern from §6.2.6 / §6.2.7: `internal` → `package` for types and
members reached across the new boundary; private helpers stay
`private`. Initial promotion surface (build errors drive the precise
list):

| Symbol | Touched from | To |
|---|---|---|
| `CodeFoldingEngine` (class + init + every member called by umbrella/tests) | umbrella, tests | `package` |
| `CodeFoldingEngine.lineSpan(of:in:)` (static) | `CodeFoldingEngineLineSpanTests` | `package` |
| `CodeFoldingConfiguration` (struct + all fields) | umbrella bridge | `package` |
| `FoldableRegion` (struct + fields) | umbrella, tests | verify (already `public` from §6.2.6) |
| `FoldingType` (enum) | umbrella, tests | `package` (verify `Sendable` carries) |
| `FoldStoreElement` (struct + init + fields) | umbrella, tests | `package` |
| `LineFoldStorage` (struct + methods + init) | umbrella, tests | `package` |
| `FoldInfo` (struct + fields) | umbrella, tests | `package` |
| `FoldRegionAdapter` (class + init + methods) | umbrella | `package` |
| `FoldPresentationStrategy` (protocol) | umbrella | `package` |
| `AttributeFoldPresentationStrategy` (class + init + methods) | umbrella | `package` |
| `FoldingOperationsService` (class + init + methods) | umbrella | `package` |
| `FoldingProviderRegistry` (class + init + methods) | umbrella, tests | `package` |
| `extension NSAttributedString.Key` static (in `FoldingOperationsService.swift`) | umbrella | `package` if read across boundary, else stays `internal` |

`@Published` properties on `CodeFoldingEngine` may need special
handling if `package`-level `@Published` misbehaves under Swift 6.3 —
fall back to `public` for those specific properties as the escape
hatch. Mitigation deferred until a real compiler error appears.

## Consumer impact (imports to add)

Discovered via grep before move:

- **Umbrella (`Sources/CodeEditorPlugin/`):**
  - `Core/CodeFoldingCoordinatorService.swift`
  - `Core/EditorRuntime.swift`
  - `Core/CodeEditorView.swift`
  - `Core/CodeEditorView+SetupExtensions.swift`
  - `Core/CodeEditorView+CodeFoldingExtensions.swift`
  - `Core/CodeEditorView+ConfigurationExtensions.swift`
  - `Core/CodeEditorView+CoreExtensions.swift`
  - `Core/CodeEditorView+SyntaxHighlightingExtensions.swift`
  - `Core/Configuration/EditorConfiguration+CodeFolding.swift`
  - `Layout/GutterViewModel.swift`
  - `Layout/GutterViewRenderer.swift`
  - `Layout/GutterInteractionHandler.swift`
  - `Layout/FoldChevronAnimation.swift`
  - `Layout/CodeEditorContainerView+AppKitExtensions.swift`
  - `SwiftUI/CodeEditor+ModifiersExtensions.swift`

- **Tests (`Tests/CodeEditorPluginTests/`):**
  - `FeatureBehaviorTests.swift`
  - `ComprehensivePerformanceTests.swift`
  - `Features/CodeFoldingEngineLineSpanTests.swift`
  - `Features/CodeFoldingEngineCacheEvictionTests.swift`
  - `Features/LineFoldStorageTests.swift`
  - `Features/FoldingProviderOutputTests.swift`

- **Sample / UI:** confirmed by Step 0 pre-flight. Expected none.

## Execution plan

Each step leaves `swift build` green except Step 2 (`git mv`) → Step 5
(promotion loop), which is the expected red window.

**Step 0 — Pre-flight audit (~10 min).**

- Grep `CodeEditorSample` and `CodeEditorUI` for Folding-type references
  (`CodeFoldingEngine`, `FoldableRegion`, `FoldStoreElement`,
  `LineFoldStorage`, `FoldInfo`, `FoldingType`, `FoldRegionAdapter`,
  `FoldPresentationStrategy`, `AttributeFoldPresentationStrategy`,
  `FoldingOperationsService`, `FoldingProviderRegistry`,
  `CodeFoldingConfiguration`). If any hit, plan import additions.
  Most likely only `CodeFoldingCoordinatorService` (umbrella public
  API) is touched, which doesn't require a new dep.
- Confirm the carry-set is exactly the 8 files in §"Moves into new
  `Sources/CodeEditorFolding/`". Check no late references like a
  tenth file in `Extensions/` or `Models/` referencing fold types.
- Verify `CodeEditorError.serviceUnavailable("CodeFoldingEngine")`
  identifier string stays stable (asserted by
  `ReviewRemediationRegressionTests`).

**Step 1 — Scaffold target (no source moves yet).**

- Create empty `Sources/CodeEditorFolding/` directory (placeholder file
  or `.gitkeep` so SPM accepts the target).
- Add the target stanza to `Package.swift` (see §"Target shape").
- Add `"CodeEditorFolding"` to umbrella + test target `dependencies:`.
- `swift build` — should be green; the new target has no sources yet,
  the umbrella keeps all 8 files.

**Step 2 — `git mv` the 8 files.**

```
git mv Sources/CodeEditorPlugin/Features/CodeFoldingEngine.swift            Sources/CodeEditorFolding/
git mv Sources/CodeEditorPlugin/Features/FoldableRegion.swift               Sources/CodeEditorFolding/
git mv Sources/CodeEditorPlugin/Features/FoldStoreElement.swift             Sources/CodeEditorFolding/
git mv Sources/CodeEditorPlugin/Features/LineFoldStorage.swift              Sources/CodeEditorFolding/
git mv Sources/CodeEditorPlugin/Features/FoldRegionAdapter.swift            Sources/CodeEditorFolding/
git mv Sources/CodeEditorPlugin/Features/FoldPresentationStrategy.swift     Sources/CodeEditorFolding/
git mv Sources/CodeEditorPlugin/Features/FoldingOperationsService.swift     Sources/CodeEditorFolding/
git mv Sources/CodeEditorPlugin/Features/FoldingProviderRegistry.swift      Sources/CodeEditorFolding/
```

Delete the placeholder file from Step 1. Build is now red on missing
imports + visibility.

**Step 3 — Add `import CodeEditorFolding` to umbrella + test callers.**

Insert the import alphabetically. List from §"Consumer impact".

**Step 4 — Access-modifier promotions (`internal` → `package`).**

Bulk-promote per §"Access-modifier promotions". Apply in
`Sources/CodeEditorFolding/`, not the call sites.

**Step 5 — Compile loop until green.**

`swift build 2>&1 | tail -60` → fix → repeat. Expect 2–4 rounds for
straggler access modifiers and `@Published` cross-target visibility.

**Step 6 — Test + lint.**

```
swift test --filter Folding
swift test --filter FeatureBehavior
swift test --filter ComprehensivePerformance
swift test --filter LineFoldStorage
swift build --target CodeEditorSample
swiftlint --fix && swiftlint
```

Targeted filters honor the memory rule about not over-running the
suite after additive-only steps. Full `swift test --parallel` is not
required to declare success.

**Step 7 — Docs.**

- `CLAUDE.md`:
  - Add `Sources/CodeEditorFolding/` row under "Other source roots".
  - Update umbrella file count (`Features/` shrinks by 8).
  - Update the `Features/` directory description (drop the folding
    bullet).
- `NEXT.md` §6.0:
  - Add row for `CodeEditorFolding` with commit SHA, what landed,
    direct deps.
  - Add a "Deviations during §6.2.8a `CodeEditorFolding`" block (any
    surprises uncovered during execution).
- `NEXT.md` §6.2.8: mark Folding sub-step as `[done]`.
- `NEXT.md` §10: mark question 2 resolved
  (`CodeFoldingConfiguration` stays in `CodeEditorFolding`; umbrella
  bridge file unchanged in shape, gains an import).

**Step 8 — Single commit.** Subject mirrors the §6.2.7 commit style:
`Extract CodeEditorFolding target (§6.2.8a)`. Body lists carry-set,
deps, and major deviations.

## Risks & open-but-acceptable items

1. **`CodeFoldingEngine` is `@MainActor ObservableObject` with
   `@Published` properties.** Cross-target `@Published` access has
   historically been fine in Swift 6.3, but verify no Combine-related
   visibility errors after promotion. Mitigation: fall back to
   `public` for the specific properties if `package` misbehaves.

2. **`FoldingProviderRegistry.init()` seeds 14 concrete providers.**
   `BraceFoldingProvider()`, `IndentationFoldingProvider()`,
   `MarkdownFoldingProvider()`, `XMLFoldingProvider()`,
   `ShellFoldingProvider()`, `SQLFoldingProvider()`,
   `RubyFoldingProvider()`, `DockerfileFoldingProvider()`,
   `TomlFoldingProvider()`, `LuaFoldingProvider()` (Languages target)
   + `HeuristicFoldProvider(language:)` (SH target). All required
   inits were promoted to `package init()` in §6.2.6 / §6.2.7. Should
   just work; if not, the failing call shows the specific missing
   modifier.

3. **`EditorConfiguration+CodeFolding.swift` import shape.** This
   bridge file currently `import CodeEditorConfiguration` only. After
   the move it needs `import CodeEditorFolding` to see
   `CodeFoldingConfiguration`. Function stays in umbrella because
   only the umbrella can depend on both Configuration and Folding
   without creating a cycle.

4. **`Core/Configuration/` umbrella sub-bucket grows by one import,
   not by files.** CLAUDE.md flags this as an F3 dumping ground; this
   extraction does not make it worse, just adds one more import to
   the existing bridge file. Will be re-evaluated during §6.2.12 Core
   split.

5. **No CodeFoldingCoordinatorService refactor.** The service still
   takes `CodeEditorView` directly. Lifting the service into the new
   target would require either an `EditorViewProtocol` or
   `@_implementationOnly` import gymnastics — both out of scope.
   Coordinator stays in umbrella.

6. **`FoldStoreElement` / `LineFoldStorage` / `FoldInfo` placement.**
   Chosen to stay with the engine. These types depend on TextModel's
   `RangeStoreElement` but TextModel does not depend on them. The
   inverse direction (pulling them down to TextModel) would let
   Layout reach them without a Folding import once Layout extracts,
   but it would make TextModel know about fold-specific data shapes
   — a worse trade.

## Verification

Definition of done:

- `swift build` green for all targets.
- `swift test --filter Folding`, `--filter FeatureBehavior`,
  `--filter ComprehensivePerformance`, `--filter LineFoldStorage`
  all pass.
- `swift build --target CodeEditorSample` green.
- `swiftlint` reports zero violations (strict mode is on).
- 8 files appear under `Sources/CodeEditorFolding/`; `Features/` no
  longer contains any `*Fold*` files.
- `CodeEditorPlugin` and `CodeEditorPluginTests` list
  `CodeEditorFolding` in their `dependencies:`.
- `CLAUDE.md` and `NEXT.md` updated per Step 7.
- Sample-app smoke (manual): launch, open a Swift file, fold/unfold a
  region with the gutter chevron — no regression vs. pre-change.
