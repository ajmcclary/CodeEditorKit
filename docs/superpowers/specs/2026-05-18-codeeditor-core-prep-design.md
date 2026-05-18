# §6.2.12 Prep — `Core/` Inventory and Bounded Relocations

**Date:** 2026-05-18
**NEXT.md section:** §6.2.12a (prep step that precedes the §6.2.12 main split — naming follows the §6.2.9a precedent for "prerequisite before the main step")
**Status:** Design, awaiting user review

---

## 1. Scope and Goals

### Goal

Shrink and classify `Sources/CodeEditorPlugin/Core/` before the §6.2.12 editor-surface extraction, so that the §6.2.12 session inherits a smaller, fully-classified surface instead of an unaudited pile.

### Scope (in)

1. **F3 sub-bucket sweep.** Audit each of the 10 F3 sub-buckets in `Core/` — `Annotations/` (1 file), `Configuration/` (1), `Documents/` (2), `Folding/` (4), `LSP/` (2), `Platform/` (14), `Search/` (1), `Symbols/` (1), `SyntaxHighlighting/` (9), `Text/` (11). For every file: is its umbrella coupling zero-touch or cheap-break (per §6.2.7 / §6.2.8d / §6.2.8g precedent)? If yes, relocate into the matching sibling SPM target. If no, keep, and document the blocker for §6.2.12.
2. **Top-level Core/ root triage.** Classify the 64 root files into three buckets:
   - **Bucket 1:** `CodeEditorView.swift`, the 24 `CodeEditorView+*Extensions.swift` slices, `CodeEditorViewDelegate*` / `CodeEditorViewProtocol.swift`, `UnifiedTextView+Extensions.swift` — definitely editor-surface, stay.
   - **Bucket 2:** Cross-target glue (extends a non-umbrella type) — relocate to the owning sibling target if coupling allows.
   - **Bucket 3:** Standalone services (`ActorCoordinator`, `MemoryManagementCoordinator`, orchestration services, event-system cluster, text-system styler cluster, per-language detection / sizing / layout services, etc.) — classify only; defer the actual move to §6.2.12.

### Scope (out)

- **Zero new SPM targets.**
- **`Core/Actors/`** (6 files) is bucket-1-equivalent — defer to §6.2.12.
- **`Core/Layout/`** (21 files) is already-settled §6.2.11 stay-set — defer to §6.2.12.
- **The 33 standalone-service files in bucket 3 are documented but not moved.**
- **SmartEditing** (deferred §6.2.8c) is unrelated — separate spec.

### Success criteria

1. `swift build && swiftlint --fix && swiftlint && swift test --parallel` green at every commit.
2. Every F3 sub-bucket file is either moved or has a one-line rationale recorded.
3. Every top-level Core/ root file has a bucket label (1/2/3) recorded.
4. Net Core/ file count drops measurably (target: small but non-zero — exact number depends on the audit, no advance promise).

---

## 2. Methodology

### Per-bucket procedure

For each of the 10 F3 sub-buckets, in order:

1. **Inventory.** List the files in the bucket and the matching sibling SPM target (e.g., `Core/Annotations/` ↔ `CodeEditorAnnotations`, `Core/Text/` ↔ `CodeEditorTextModel`).
2. **Per-file coupling audit.** For each file, grep for direct `CodeEditorView` references (storage, parameter types, return types, casts), partial-file extensions of `CodeEditorView` or other umbrella-owned types, and reaches into umbrella-only symbols (`CodeEditorDependencies`, umbrella-private services).
3. **Classify each file** into one of:
   - **Move (zero-touch):** file already compiles against the sibling target's dep set. Move with `git mv`. Add `import CodeEditorPlugin → import <SiblingTarget>` only where consumers need it.
   - **Move (cheap-break):** moveable after one of the four documented break patterns:
     - **(a) Nested-type extraction** into its own file in the carry-set (precedent: §6.2.7 `RangeQueryParser`; §6.2.11 `EditorLayoutTypes`).
     - **(b) Inline a single `CodeEditorDependencies.make…()` fallback** (precedent: §6.2.7 SH; §6.2.10 Diagnostics).
     - **(c) Relocate a free-standing helper / error / marker type across targets** (precedent: §6.2.7 `RangeStore` → TextModel; §6.2.8g `SendableError` → Common; §6.2.11 `SourcePosition` → Common, `EditorConfiguration: Hashable` → Configuration).
     - **(d) Migrate a public-API entry point out of umbrella to the sample** (precedent: §6.2.8d `EditorController+SelectMatch.swift`).
     - Move size capped at "a few lines" per file; anything larger is reclassified as **Keep**.
   - **Keep:** file is genuinely editor-surface-coupled. Record the blocker in one line ("stores `CodeEditorView?` weak ref", "protocol requirement takes `CodeEditorView`", "extends `CodeEditorView`") for §6.2.12 input.

### Per-bucket commit

Each sub-bucket's moves land in one commit (or pre-commit + commit, matching the §6.2.7 / §6.2.8a / §6.2.11 carve-out vocabulary). Commit message names the bucket. If a bucket has zero moves, no commit — but the classification still goes in the audit table.

### Move-permission red lines

- **No access-modifier promotions wider than `package`.** A move that requires `internal → public` is reclassified as **Keep** unless the symbol is already part of the public API surface.
- **No new SPM targets.** A move that needs a new target is reclassified as **Keep** and noted as §6.2.12 input.
- **No re-architecting protocol shapes.** Splitting an existing protocol to break a `CodeEditorView` parameter is reclassified as **Keep** — that's the kind of work that belongs *in* §6.2.12, not before it.

### Done bar per bucket

`swift build && swiftlint --fix && swiftlint` green; targeted tests for the affected sibling target pass (`swift test --filter <SiblingTarget>Tests`); full `swift test --parallel` deferred per the memory's additive-only rule until the end of the prep session.

---

## 3. Sub-bucket pre-audit

All counts are first-pass `grep CodeEditorView\b`; deeper audit happens during execution.

### Likely Keep (known blockers from prior deviation logs or first-pass View references)

| Bucket | Files | Status |
|---|---|---|
| `Core/Annotations/` | 1 (`AnnotationsDataSource`) | Keep — protocol method takes `CodeEditorView` (§6.2.8e) |
| `Core/Folding/` | 4 (`CodeFoldingEngine`, `FoldingOperationsService`, `FoldPresentationStrategy`, `CodeFoldingConfiguration`) | 3 known Keep (§6.2.8a); `CodeFoldingConfiguration` re-audit produces "still stays" unless its 3 consumers move first (none do in this prep) |
| `Core/LSP/` | 2 (`LSPContentCoordinator`, `LSPSemanticTokenProvider`) | Keep — store `CodeEditorView?` refs (§6.2.9) |
| `Core/Search/` | 1 (`SearchReplaceEngine`) | Keep — heavily View-coupled (§6.2.8d) |
| `Core/Symbols/` | 1 (`SymbolNavigator`) | Keep — 5 View member accesses (§6.2.8b) |
| `Core/SyntaxHighlighting/` | 9 (`AsyncSyntaxHighlighter`, `HighlightProviderState`, `RangeAttributeApplier`, `RangeBasedHighlightingController`, `RangeHighlightProviding`, `RegexQuery/RegexRangeHighlightProvider`, `StreamingHighlighter`, `SyntaxHighlighterRangeAdapter`, `VisibleRangeProvider`) | Keep — all 9 known View-coupled (§6.2.7) |
| `Core/Platform/` (View-ref subset) | 9 (`ContextMenuAction` × 1 ref, `ContextMenuBuilder` × 1, `ContextMenuCoordinator` × 31, `CrossPlatformCoordinator` + AppKit/UIKit ext × 9/9/11, `InputCoordinator` × 20, `ToolbarCoordinator` × 2, `UnifiedDrawingCoordinator` × 1) | Probable Keep; the four 1–2-ref files (`ContextMenuAction`, `ContextMenuBuilder`, `ToolbarCoordinator`, `UnifiedDrawingCoordinator`) get a per-file cheap-break inspection during execution |
| `Core/Text/` (View-ref subset) | 4 (`LineGeometryEditHandler` × 2, `TextEditEventHub` × 1, `TextKitBridge` × 1, `TextKitLineNumberHelper` × 3) | Probable Keep; the three 1–2-ref files (`TextEditEventHub`, `TextKitBridge`, `LineGeometryEditHandler`) get per-file cheap-break inspection |

**Sub-bucket Keep total:** ~31 files (more if cheap-break inspections fail).

### Likely Move (zero `CodeEditorView` refs at first-pass)

| Bucket | Files | Probable target | Status |
|---|---|---|---|
| `Core/Documents/` | 2 (`EditorDocument`, `EditorDocuments`) | `CodeEditorTextModel` (per §4.1 row) | Move — zero View refs; imports CodeEditorLanguages + SwiftUI + Observation. Verify CodeEditorLanguages dep is acceptable for TextModel (it isn't — TextModel is upstream of Languages); if blocked, target becomes Common or stays. |
| `Core/Configuration/EditorConfiguration+CodeFolding.swift` | 1 | (none — Keep) | **Keep** — although the file has no `CodeEditorView` ref and imports only `CodeEditorConfiguration` + Foundation, its single function returns `CodeFoldingConfiguration`, which stays in umbrella per §6.2.8a. Moving the bridge would force `CodeEditorConfiguration` to import the umbrella (dep direction inversion). Recorded as the §6.2.8a "consumers stay where the type stays" pattern. |
| `Core/Platform/` | 5 (`DeviceType+RecommendedConfiguration`, `PlatformAdjustments+Extensions`, `PlatformCapabilities+RecommendedConfiguration`, `PlatformConfigurations`, `TextInputFeatures`) | `CodeEditorPlatform` or `CodeEditorConfiguration` (the +RecommendedConfiguration pair extends `EditorConfiguration` via Device / Capabilities — Configuration is the natural home) | Move — zero View refs. The +RecommendedConfiguration pair is the §6.2.6 "method-only umbrella extensions" cited in the deviations log; verify whether their accumulated body still references only Platform + Configuration. |
| `Core/Text/` | 7 (`BackgroundProcessor`, `ModernTextKitHelper`, `ParagraphStyleCache`, `TemporaryAttributesStore`, `TextKit2PerformanceHelper`, `TextKit2RenderingOptimizer`, `TextLayoutFragment`) | `CodeEditorTextModel` (per §4.1 row) | Move — zero View refs. Verify no umbrella-private reaches (`CodeEditorDependencies` factory calls, etc.) before move. |

**Sub-bucket Move total:** ~14 files first-pass eligible (Documents 2 + Platform 5 + Text 7; Configuration's 1-file bucket is Keep per the §6.2.8a dep-direction blocker). Net Core/ sub-bucket reduction if all Move candidates pass deeper audit: ~30%.

### Caveats

The "zero View refs" screen is necessary but not sufficient — the same screen for `Core/Documents/` already revealed an awkward upward import (`import CodeEditorLanguages`) that may force a target change. The §4.1 dep claim corrections in §6.0 are a pattern: speculative target assignments don't survive contact with the code. The execution-time audit promotes each candidate from "probable Move" to a final disposition or back to **Keep** with rationale.

---

## 4. Top-level Core/ root triage (64 files)

### Bucket 1 — Editor-surface, definitely Stay (29 files)

Files that are `CodeEditorView` itself, partial-file extensions of it, or its delegate / protocol companions. No move analysis needed; recorded as §6.2.12 input.

- `CodeEditorView.swift`
- `CodeEditorView+*Extensions.swift` × 24 slices (Accessibility, Annotations, CodeEditorAPI, CodeFolding, Completion, Configuration, ConfigurationExtensions, Core, EdgeInsets, EnclosingScrollView, Extensions, Layout, LineNumbers, Performance, PlatformCapabilities, PlatformSpecific, RangeBasedHighlighting, Responder, Setup, SyntaxHighlighting, TextInputFeatureTarget, TextKit, Theme, TrackPerformance)
- `CodeEditorViewDelegate.swift`, `CodeEditorViewDelegateProxy.swift`, `CodeEditorViewProtocol.swift`
- `UnifiedTextView+Extensions.swift`

### Bucket 2 — Cross-target glue, Move candidates (2 files confirmed first-pass)

| File | Probable target | Verified | Notes |
|---|---|---|---|
| `EditorConfiguration+ApplyTextInputFeatures.swift` | `CodeEditorConfiguration` | Imports only `CodeEditorConfiguration` + Foundation; no `CodeEditorView` ref | Move depends on whether the body still references only `EditorConfiguration` + Platform's `TextInputFeatures`. If `TextInputFeatures` moves to `CodeEditorPlatform` per section 3, this file adds `import CodeEditorPlatform` and goes to `CodeEditorConfiguration`. |
| `BreadcrumbComponent.swift` | `CodeEditorSymbols` | Imports Foundation only; `public struct ... Hashable, Identifiable, Sendable`; no `CodeEditorView` ref | Pure data type used by symbol-navigation chrome. Move to CodeEditorSymbols is the natural home; verify no umbrella consumer chains require it stay first. |

A tighter audit during execution may surface 0–2 more candidates (e.g., one of the rendering-diagnostics types) but the first pass shows the bulk of root files are either bucket 1 or bucket 3.

### Bucket 3 — Standalone services, classify only (33 files)

These are the §6.2.12 split's actual decision space. Recorded with one-line provisional classifications; no moves in this session.

| File | Provisional §6.2.12 home |
|---|---|
| `ActorCoordinator.swift` | editor-surface (Actors cluster) |
| `AsyncOperationErrors.swift` | editor-surface (umbrella error types: `CompletionAsyncError`; residual after §6.2.7 split) |
| `CodeEditorAPI.swift` | editor-surface (public façade) |
| `CodeEditorDependencies.swift` | editor-surface (dependency keys for the editor target) |
| `CodeEditorRenderingDiagnostics.swift` | editor-surface (rendering instrumentation around the view) |
| `CodeFoldingCoordinatorService.swift` | editor-surface (orchestrates Core/Folding/) |
| `DirtyTracker.swift` | editor-surface (consumed by CodeEditorView during typing) |
| `EditorEvent.swift`, `EditorEventHandler.swift`, `EditorEventPublisher.swift`, `EditorEventTypes.swift` | editor-surface (event-system cluster — possibly a sub-target candidate in §6.2.12) |
| `EditorInteractionState.swift`, `EditorState.swift`, `EditorStateBridge.swift`, `SelectionState.swift` | editor-surface (state cluster) |
| `EditorLayoutService.swift` | editor-surface (consumes `GutterSizingService` → `LineNumberCalculationService` → CodeEditorView, see §6.2.11 reclassification) |
| `EditorRuntime.swift` | editor-surface (top-level orchestrator) |
| `GutterSizingService.swift`, `LineNumberCalculationService.swift` | editor-surface (the §6.2.11 reclassification anchor) |
| `IOSLargeFileOptimizer.swift` | editor-surface (3 CodeEditorView casts, §6.2.10) |
| `LanguageDetectionService.swift` | editor-surface — possible move to `CodeEditorLanguages`; flag for §6.2.12 audit |
| `MemoryManagementCoordinator.swift` | editor-surface (creates LSPManager, public API) |
| `SendableTypes.swift` | editor-surface or possibly Common — flag for §6.2.12 audit |
| `SyntaxHighlightingService.swift` | editor-surface (orchestrates Core/SyntaxHighlighting/) |
| `TabModel.swift` | editor-surface — possible move out; the umbrella's tab model is suspiciously application-layer. Flag for §6.2.12 audit. |
| `TextEditingService.swift`, `TextKitSetupHelper.swift`, `TextSystem.swift`, `TextSystemStyler.swift`, `ThreePhaseTextSystemStyler.swift`, `TokenSystemValidator.swift` | editor-surface (TextKit2 system orchestration; F3'd to root from Core/Text/ per §6.2.3) |
| `TextViewDelegateMultiplexer.swift`, `TextViewDelegateParticipant.swift` | editor-surface (CodeEditorView delegate companions) |
| `UnifiedEventSystem.swift` | editor-surface (event-system cluster) |

### Net root-file picture

29 Stay + 2 Move + 33 Defer = 64 files. The 33 deferred files are explicitly the §6.2.12 surface; this prep doesn't move them, but classifies them so §6.2.12 starts with concrete bucket labels instead of an unaudited pile.

Three flagged for §6.2.12 audit because they may move *out* of editor-surface: `LanguageDetectionService` (likely Languages), `SendableTypes` (possibly Common), `TabModel` (possibly application-layer, e.g., sample).

---

## 5. Execution Sequence

Easiest first, chains last.

### Step 1a — `Core/Configuration/` sweep

1 file (`EditorConfiguration+CodeFolding.swift`). Pre-flight self-review reclassified this as **Keep**: the file's single function returns `CodeFoldingConfiguration`, which is umbrella-resident per §6.2.8a. Moving the bridge would invert the dep direction.

**No commit.** Audit-table entry records the §6.2.8a dep-direction blocker. The plan still walks the bucket for completeness so any execution-time re-discovery is documented.

### Step 1b — `Core/Platform/` sweep

5 Move candidates: `DeviceType+RecommendedConfiguration`, `PlatformAdjustments+Extensions`, `PlatformCapabilities+RecommendedConfiguration`, `PlatformConfigurations`, `TextInputFeatures`. Verify per-file target: the two `+RecommendedConfiguration` files extend `EditorConfiguration`, so their natural home is `CodeEditorConfiguration` (not Platform). The other three are CodeEditorPlatform. Single commit even if it spans two targets, because the moves are coupled.

**Commit:** `Relocate Core/Platform/ Move-eligible files (§6.2.12 prep)`

### Step 1c — `Core/Text/` sweep

7 Move candidates: `BackgroundProcessor`, `ModernTextKitHelper`, `ParagraphStyleCache`, `TemporaryAttributesStore`, `TextKit2PerformanceHelper`, `TextKit2RenderingOptimizer`, `TextLayoutFragment` → `CodeEditorTextModel/`. Largest single-bucket move in the prep.

**Commit:** `Relocate Core/Text/ Move-eligible files to CodeEditorTextModel (§6.2.12 prep)`

### Step 1d — `Core/Documents/` sweep

2 files. Audit reveals an `import CodeEditorLanguages` that blocks the natural `TextModel` home. Plan-time resolution:

- **(a)** Drop the import if unused, move to TextModel.
- **(b)** If the Languages reference is load-bearing, reclassify both files as **Keep** for §6.2.12 (downstream-of-Languages target needed) and record the blocker.

Outcome decided during plan execution, not pre-decided here.

**Commit (if (a)):** `Relocate Core/Documents/ to CodeEditorTextModel (§6.2.12 prep)`. No commit if (b) — just an audit-table entry.

### Step 2 — Root-file bucket 2 chain

- **Step 2a** — `EditorConfiguration+ApplyTextInputFeatures.swift` → `CodeEditorConfiguration/`. Depends on Step 1b shipping `TextInputFeatures` to CodeEditorPlatform first. Commit: `Relocate EditorConfiguration+ApplyTextInputFeatures to CodeEditorConfiguration (§6.2.12 prep)`.
- **Step 2b** — `BreadcrumbComponent.swift` → `CodeEditorSymbols/`. Independent. Commit: `Relocate BreadcrumbComponent to CodeEditorSymbols (§6.2.12 prep)`.

### Step 3 — Documentation

Update NEXT.md with: a new **§6.2.12a** deviations block (per §6.2.9a's "prerequisite before main step" naming) holding deviations + per-bucket audit table; mark the 10 sub-buckets' move-eligible files relocated; the 33 root-file bucket 3 classifications recorded inline so §6.2.12 inherits them.

**Commit:** `Document §6.2.12 prep audit results in NEXT.md`

### Per-commit verification protocol

Each commit between Step 1b and Step 2b runs (in order):

1. `swift build` — full build green.
2. `swiftlint --fix` then `swiftlint` — strict mode green (CLAUDE.md rule).
3. `swift test --filter <RelevantTarget>Tests` — targeted test pass for the target that gained the file. For 1b: `CodeEditorPlatformTests` + `CodeEditorConfigurationTests`. For 1c / 1d: `CodeEditorTextModelTests`. For 2a: `CodeEditorConfigurationTests`. For 2b: `CodeEditorPluginTests` filtered by `Symbol`-named suites.

**Full `swift test --parallel` runs at the end of Step 2b and at the end of Step 3** — matching the memory's "skip full swift test --parallel after additive-only steps" rule: each move is technically "relocate-only", not additive, so we run it once at the end rather than after every commit.

### Failure handling

Same protocol as the prior carve-outs:
- If `swiftlint`'s `sorted_imports` fix touches >1 file or moves to a non-expected position (§6.2.8f / §6.2.9 lesson), let it.
- If a test fails on stale path string (§6.2.8e collateral), fix it in the same commit (per the memory's "fix pre-existing failures, don't document them" rule).
- If a build fails because a Move candidate has a deeper coupling than first-pass screening showed, reclassify as **Keep** with a one-line rationale and continue with the next sub-bucket.

### Net diff shape estimate

~16 files relocated (14 sub-bucket + 2 root). Plus the NEXT.md §6.2.12a deviations block. Plus the targets' `Package.swift` exclude lists may need updates if any sub-bucket becomes empty post-move (`Core/Documents/` is the only candidate — `Core/Configuration/` stays non-empty per Step 1a's Keep reclassification — but those are inside the umbrella target's source tree, no `exclude:` change needed since they're already inside the umbrella's `path:`).

---

## 6. Testing, Audit-Table Format, and Risks

### Audit-table format (lands in NEXT.md and the design doc)

Two tables: F3 sub-bucket audit, and root-file triage. Both have these columns:

```
| File | Current location | Disposition | Target (if Move) | Rationale |
```

`Disposition` is one of:
- **Move (zero-touch)**
- **Move (cheap-break-X)** with X identifying which break pattern (a/b/c/d from section 2)
- **Keep**
- **Defer to §6.2.12** (root-file bucket 3 only)

The root-file triage adds a bucket label (`1`, `2`, or `3`) in the `Disposition` column.

Both tables sit in NEXT.md as a child of the new `§6.2.12a` deviations block, mirroring the §6.0 deviations style.

### Testing strategy summary

- **Targeted tests per commit** (Step 1a–2b) — already specified in section 5. Covers cross-target test access ripples: any `@testable import CodeEditorPlugin` in a test that reaches an internal in a moving file gains `@testable import <SiblingTarget>` (precedent: every prior carve-out, including §6.2.11 Layout's 8 plugin-test `@testable import CodeEditorLayout` adoptions).
- **No new test target** introduced by this prep. Per-target test split is §6.2.15.
- **No snapshot tests affected.** The 16 candidate files are non-rendering — `TextKit2RenderingOptimizer` and `TextLayoutFragment` are layout primitives, not snapshot subjects.
- **Full `swift test --parallel`** runs at the end of Step 2b and at the end of Step 3 (per section 5).

### Risks worth calling out separately

1. **First-pass screen under-counts coupling.** A "zero View refs" file may still reach `CodeEditorDependencies`, an umbrella-private service, or an umbrella-only type alias. Mitigation: same as the carve-out precedents — if a deeper audit during execution promotes a Move to a Keep, that's a one-line audit-table change, not a spec rewrite.

2. **Sorted-imports surprises.** SwiftLint's `sorted_imports` rule treats target names case-sensitively (§6.2.9 lesson: `CodeEditorLSP` sorts *after* `CodeEditorLanguages`). Plan-writing won't pre-order new imports; `swiftlint --fix` is the source of truth.

3. **`Core/Documents/`'s `import CodeEditorLanguages`.** Pre-flight finding only; resolution happens in plan execution. If irresolvable, Documents reclassifies as Keep (zero loss to the prep) and the §6.2.12 audit table inherits the question.

4. **Bucket 3 classifications are provisional.** The 33 root files inherited a one-line classification, but §6.2.12 may revise (e.g., `LanguageDetectionService`, `SendableTypes`, `TabModel` are explicitly flagged for re-audit). The prep's classification is input, not output; §6.2.12 is the authority.

5. **`Package.swift` exclude-list churn.** None expected — the 16 candidate files all live inside the umbrella target's `path:` (`Sources/CodeEditorPlugin/`), and post-move their old directories may become empty but the umbrella's `path:` continues to compile cleanly. If any prior `exclude:` line ("Performance", "Languages", "Layout" etc., per §6.2 commits) becomes stale, that's a one-line cleanup in Step 3.

6. **No reach into §6.2.12's real work.** The boundary is "moves that don't require protocol surgery or new SPM targets." If a move starts to feel like it's reshaping the editor surface, reclassify as Keep and let §6.2.12 do the surgery.

---

## Appendix — Inventory at Spec Time (2026-05-18)

`Sources/CodeEditorPlugin/Core/` contains 138 files at spec time:

- 64 files at Core/ root
- 6 in `Core/Actors/` (deferred to §6.2.12)
- 21 in `Core/Layout/` (§6.2.11 stay-set; deferred to §6.2.12)
- 1 in `Core/Annotations/`, 1 in `Core/Configuration/`, 2 in `Core/Documents/`, 4 in `Core/Folding/`, 2 in `Core/LSP/`, 14 in `Core/Platform/`, 1 in `Core/Search/`, 1 in `Core/Symbols/`, 9 in `Core/SyntaxHighlighting/`, 11 in `Core/Text/` (the 10 F3 sub-buckets, 46 files total).

This spec targets the 46 F3-sub-bucket files (~30% Move candidate after self-review reclassified Configuration as Keep) and the 64 root files (Bucket 1: 29 stay; Bucket 2: 2 move; Bucket 3: 33 defer).

§6.2.12 inherits whichever subset of those 138 files don't move during this prep.
