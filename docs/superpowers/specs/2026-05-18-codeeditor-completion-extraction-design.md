# §6.2.8g CodeEditorCompletion extraction — design

**Status:** spec for the next session.

**Position in the restructure:** continues §6.2.8 feature-engine extractions. Per NEXT.md §10 / §6.2.8, Completion is sequenced **last** in the feature engines ("most call sites"). With Completion landed, the §6.2.8 series is complete except for `SmartEditing` (deferred to §6.2.12 — every public entry takes `CodeEditorView`) and the `Debugger` confirm-or-delete decision (not yet a feature engine carve-out).

**Precedents this builds on:**

- §6.2.7 `CodeEditorSyntaxHighlighting` (`f2798287`) — first carve-out (36 moved, 9 stayed). ~107 access-modifier promotions.
- §6.2.8a `CodeEditorFolding` (`76abf928`) — carve-out (4 moved, 4 stayed).
- §6.2.8b `CodeEditorSymbols` (`fefe8f93`) — carve-out (2/3 moved, 1 stayed; +1 split-out file).
- §6.2.8d `CodeEditorSearch` (`18f9d43a`) — carve-out (1 moved, 1 stayed in umbrella, 1 migrated to sample; first cross-restructure public-API removal).
- §6.2.8e `CodeEditorAnnotations` (`9ce2934a`) — carve-out (7 moved, 1 stayed). Zero access-modifier promotions.
- §6.2.8f `CodeEditorWorkspace` (`c1739137`) — clean extraction, productized opt-in, zero promotions.

**Why Completion is different from the carve-out precedents:** none of the 19 files in `Sources/CodeEditorPlugin/Completion/` references `CodeEditorView` structurally. Subagent audit (this session) confirmed all `CodeEditorView` mentions are doc-comment only; no init/parameter/property/method-access coupling exists. The carve-outs from §6.2.7 through §6.2.8e were forced by structural `CodeEditorView` references in the moving set. Completion has none. The audit's surface "UI-files-feel-umbrella-ish" recommendation was data-incongruent.

---

## 1. Goal

Extract the 19-file `Sources/CodeEditorPlugin/Completion/` subsystem into a new SPM target `CodeEditorCompletion`. **Clean full extraction — no carve-out.** All 19 files move. The umbrella `CodeEditorPlugin` target gains `CodeEditorCompletion` as a direct dependency (umbrella-route only, not productized).

Net result: 19 files move; ~12 umbrella files gain `import CodeEditorCompletion`; ~2 top-level access-modifier promotions plus 0–10 member-level promotions (TBD at compile time, low end of the series per audit findings).

---

## 2. Scope

### 2.1 Files that move to `Sources/CodeEditorCompletion/`

All 19 files from `Sources/CodeEditorPlugin/Completion/`:

| Group | File | Top-level type / modifier | Notes |
|---|---|---|---|
| Model / events | `CompletionEvent.swift` | `public struct CompletionEvent` | Sendable + Hashable value type |
| | `CompletionEventBroadcaster.swift` | `final class` (no modifier = internal) | Internal broadcaster; same-target consumer only |
| Engine | `CompletionManager.swift` | `public final class CompletionManager` + `public final class CompletionStatistics` | Orchestration, debouncing, ranking integration |
| | `CompletionDebouncer.swift` | `public final class` + supporting types | Public debouncing + priority + error types |
| | `CompletionRankingModel.swift` | `public final class` | Ranking |
| | `CompletionContextExtractor.swift` | `internal final class` | Same-target consumer only |
| Provider helpers | `CompletionProviderUtilities.swift` | `public enum` | Static utility namespace |
| | `CompletionParsingHelpers.swift` | `public enum` | Static utility namespace |
| | `CodePatterns.swift` | `public protocol CodePattern` + 4 conforming structs + `CodePatternRegistry` | All public |
| | `OptimizedFuzzyMatcher.swift` | `public struct` + nested `Configuration`, `MatchResult` | Reused by Symbols' `SymbolNavigator` |
| Built-in providers | `LanguageKeywordCompletionProvider.swift` | `internal final class` | Same-target consumer only (CompletionManager line 188) |
| | `SwiftUIClosureCompletionProvider.swift` | `internal final class` | Cross-target consumer: `SwiftUI/CodeEditor+CoordinatorsExtensions.swift` — promotion required |
| Adapter & item protocol | `CompletionItem.swift` | `public protocol CompletionItemView` | Public protocol; AppKit/UIKit conditional |
| | `CompletionItemAdapter.swift` | `internal struct` | Cross-target consumers: LSP + Core/PlatformSpecificExtensions — promotion required |
| View controllers | `CompletionViewController.swift` | `public final class` + nested `internal struct CompletionViewControllerAdapter` | Cross-platform popup; AppKit/UIKit conditional |
| | `CompletionViewControllerBase.swift` | `open class` | Cross-module subclassing supported |
| | `CompletionViewControllerDelegate.swift` | `public protocol` + `PlatformTextMovement` typealias/enum | Public delegate protocol |
| | `CompletionViewControllerRepresentable.swift` | `public protocol` | Public protocol over `PlatformViewController` |
| | `CompletionViewModels.swift` | `public struct CompletionPopupState`, `CompletionContext`, `CompletionItem`, `SelectionDirection` | All public |

**Total moving: 19 files. Files staying in umbrella: 0.** No `Core/Completion/` carve-out bucket is created. This contrasts with §6.2.7 (`Core/SyntaxHighlighting/`), §6.2.8a (`Core/Folding/`), §6.2.8b (`Core/Symbols/`), §6.2.8d (`Core/Search/`), §6.2.8e (`Core/Annotations/`) — Completion is the second clean extraction in the series after §6.2.8f Workspace.

### 2.2 Directory layout

Flat at the new target root (matches Folding/Symbols/Annotations/Workspace precedent):

```
Sources/CodeEditorCompletion/
├── CodePatterns.swift
├── CompletionContextExtractor.swift
├── CompletionDebouncer.swift
├── CompletionEvent.swift
├── CompletionEventBroadcaster.swift
├── CompletionItem.swift
├── CompletionItemAdapter.swift
├── CompletionManager.swift
├── CompletionParsingHelpers.swift
├── CompletionProviderUtilities.swift
├── CompletionRankingModel.swift
├── CompletionViewController.swift
├── CompletionViewControllerBase.swift
├── CompletionViewControllerDelegate.swift
├── CompletionViewControllerRepresentable.swift
├── CompletionViewModels.swift
├── LanguageKeywordCompletionProvider.swift
├── OptimizedFuzzyMatcher.swift
└── SwiftUIClosureCompletionProvider.swift
```

### 2.3 Dependency edges for the new target

```
CodeEditorCompletion → CodeEditorCommon
CodeEditorCompletion → CodeEditorDiagnostics
CodeEditorCompletion → CodeEditorLanguages
CodeEditorCompletion → CodeEditorPlatform
CodeEditorCompletion → CodeEditorTextModel
```

**Correction to NEXT.md §4.1.** The original phase table claimed `Completion → Languages, TextModel`. Audit-grounded reality adds `Common, Platform, Diagnostics`:

- `CodeEditorCommon` — `CrossPlatformLogger` (used in `CompletionContextExtractor`, `CompletionManager`).
- `CodeEditorDiagnostics` — `LRUCache`, `MemoryMonitor` (used in `CompletionManager`).
- `CodeEditorPlatform` — `PlatformViewController`, `PlatformColors`, `PlatformFonts` (used across the view-controller family + `CompletionItem` + `CompletionItemAdapter`).

This correction joins the series-wide pattern (§6.2.5 Theming, §6.2.8b Symbols, §6.2.8e Annotations, §6.2.8f Workspace, §6.2.10 Diagnostics all corrected §4.1's speculative dep claims). NEXT.md should be updated to reflect the audited reality, not the speculation.

### 2.4 Phase placement

§4.1 labels Completion as phase 4 (feature engine). Build-graph reality: with a `Diagnostics` (phase 4) dep, Completion sits at phase ≥ 4. Label kept — it is a feature, not foundational infra. Matches the "semantic label ≠ build-graph slot" precedent set by Workspace, Search, and Annotations.

### 2.5 Productization

**No `.library(name: "CodeEditorCompletion", ...)` product entry.** Umbrella-route only.

Rationale:

- The umbrella `CodeEditorPlugin` target consumes Completion types from ~12 files (see §3.1 below), so umbrella must depend on `CodeEditorCompletion`.
- §6.3's "Optional / opt-in" pattern (Workspace, Search, Diagnostics) requires umbrella to *not* depend on the target. Structurally impossible here — `CodeEditorView+CompletionExtensions.swift` is a partial-file extension of `CodeEditorView` and cannot migrate out of umbrella.
- Matches Languages / SyntaxHighlighting / Folding / Symbols / Annotations precedent: feature engines that the umbrella drags in are not separately productized.

Future-state: if §6.2.12's Core split lifts the `CodeEditorView+CompletionExtensions.swift` slice out of umbrella into the new `CodeEditorView` target, productization remains umbrella-routed because the editor-surface target will still depend on Completion. Productization is not on the §6.2.8g table.

---

## 3. Execution shape

Two commits, matching §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e.

### 3.1 Pre-commit A — no umbrella relocation needed

Unlike SH / Folding / Symbols / Search / Annotations, no `Core/Completion/` semantic bucket is required because no umbrella-coupled completion files exist. Skip the pre-commit relocation step. This is the same shape as §6.2.8f Workspace.

(The implementation plan may still bake a guard step: a final `git grep -n 'CodeEditorView' Sources/CodeEditorPlugin/Completion/` immediately before the move, to verify the audit's "no structural coupling" finding has not regressed since this design was written. If new references have crept in, the design must be revisited before the move.)

### 3.2 Commit B — extract `CodeEditorCompletion`

1. **Create** `Sources/CodeEditorCompletion/` with a `.gitkeep` and a `_ScaffoldPlaceholder.swift` (one-line `// Placeholder` file). Both deleted at the end of this commit. SwiftPM resolves the package during the in-between state and needs at least one `.swift` file (lesson from §6.2.8f's plan author).

2. **Add the target to `Package.swift`:**
   ```swift
   .target(
       name: "CodeEditorCompletion",
       dependencies: [
           "CodeEditorCommon",
           "CodeEditorDiagnostics",
           "CodeEditorLanguages",
           "CodeEditorPlatform",
           "CodeEditorTextModel",
       ],
       path: "Sources/CodeEditorCompletion"
   ),
   ```

3. **Update the umbrella `CodeEditorPlugin` target:**
   - Add `"CodeEditorCompletion"` to its `dependencies:` (alphabetised).
   - Expand `exclude:` from `["Info.plist", "Languages", "Performance", "SyntaxHighlighting"]` to `["Completion", "Info.plist", "Languages", "Performance", "SyntaxHighlighting"]`.

4. **Add `"CodeEditorCompletion"` to `CodeEditorPluginTests`** target dependencies (alphabetised).

5. **No changes** to `CodeEditorSample`, `CodeEditorUI`, `CodeEditorSampleTests`, `CodeEditorUITests`, `CodeEditorDesignTokensTests` targets. Pre-flight (Plan Task 1 Step 2) verifies — if a sample/UI file imports any Completion type, the plan adds the dep then; default expectation is no change.

6. **`git mv` all 19 files** from `Sources/CodeEditorPlugin/Completion/` into `Sources/CodeEditorCompletion/`.

7. **Compile-error-driven access-modifier promotion.** Run `swift build`. The compiler enumerates required `package` promotions. Apply them in one focused pass, then rerun. Expected promotions are documented in §4 below.

8. **Add `import CodeEditorCompletion`** to the 12 cross-target consumer files (see §3.3 below) until `swift build` passes.

9. **Add `import CodeEditorCompletion`** to the 10 Completion test files. Retain `@testable import CodeEditorPlugin` (lesson from §6.2.8d: don't blanket-drop `@testable`).

10. **Delete `_ScaffoldPlaceholder.swift` and `.gitkeep`.**

11. **Run** `swift build && swiftlint --fix && swiftlint && swift test --filter Completion` followed by `swift test --parallel` as the final gate.

### 3.3 Cross-target consumers (12 files in umbrella + LSP + SwiftUI)

The implementation plan's grep + audit produced this list; the plan does a bare-word `\bCompletion\b` follow-up (lesson from §6.2.8e Annotations) to catch any consumer the compound-name grep missed.

| Path | Consumed Completion types |
|---|---|
| `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` | `CompletionViewController`, `CompletionViewControllerRepresentable`, `CompletionViewControllerDelegate` |
| `Sources/CodeEditorPlugin/Core/CodeEditorView+CompletionExtensions.swift` | `CompletionViewController`, `CompletionViewControllerRepresentable` |
| `Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformSpecificExtensions.swift` | `CompletionViewControllerRepresentable`, `CompletionItemAdapter` |
| `Sources/CodeEditorPlugin/Core/CodeEditorViewDelegate.swift` | `CompletionViewControllerRepresentable`, `CompletionViewController`, `CompletionViewControllerDelegate` |
| `Sources/CodeEditorPlugin/Core/CodeEditorViewDelegateProxy.swift` | `CompletionViewControllerRepresentable` |
| `Sources/CodeEditorPlugin/Core/TextViewDelegateParticipant.swift` | `CompletionViewControllerRepresentable` |
| `Sources/CodeEditorPlugin/Core/MemoryManagementCoordinator.swift` | `CompletionManager` |
| `Sources/CodeEditorPlugin/Core/Symbols/SymbolNavigator.swift` | `OptimizedFuzzyMatcher` |
| `Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift` | `CompletionProvider` (Languages), `CompletionManager`, `CompletionStatistics`, `CompletionEvent`, `CompletionItemModel` (Languages), `CompletionTriggerKind` (Languages) |
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift` | `CompletionManager`, `SwiftUIClosureCompletionProvider` |
| `Sources/CodeEditorPlugin/LSP/LSPCompletionProvider.swift` | `CompletionItemAdapter` |
| `Sources/CodeEditorPlugin/LSP/LSPManager.swift` | `CompletionItemAdapter` |

LSP currently lives in the umbrella source tree and is therefore an umbrella-internal consumer for §6.2.8g purposes. When §6.2.9 extracts `CodeEditorLSP`, that new target will gain `CodeEditorCompletion` as a direct dep.

### 3.4 Test ripple (`Tests/CodeEditorPluginTests/Completion/` — 10 files)

| Test file |
|---|
| `CompletionManagerBuiltInProviderTests.swift` |
| `CompletionManagerRankingTests.swift` |
| `CompletionManagerLearningTests.swift` |
| `CompletionEventStreamTests.swift` |
| `CompletionViewControllerTests.swift` |
| `CompletionViewWiringTests.swift` |
| `CodeEditorModifierCompletionIntegrationTests.swift` |
| `SwiftUIClosureCompletionProviderTests.swift` |
| `SwiftUIClosureLifecycleTests.swift` |
| `LanguageKeywordCompletionProviderTests.swift` |

Each gains `import CodeEditorCompletion` alongside its existing `@testable import CodeEditorPlugin`. SwiftLint's `sorted_imports` rule will rearrange order if the plan-written order is wrong (lesson from §6.2.8f Workspace).

---

## 4. Access-modifier promotions

### 4.1 Definite top-level promotions (`internal → package`)

| Symbol | File | Cross-target consumer | Cost |
|---|---|---|---|
| `CompletionItemAdapter` struct + `init` + stored properties | `CompletionItemAdapter.swift` | `Core/CodeEditorView+PlatformSpecificExtensions.swift`, `LSP/LSPCompletionProvider.swift`, `LSP/LSPManager.swift` | Promote struct, explicit `package init(...)`, promote stored properties read across boundary |
| `SwiftUIClosureCompletionProvider` class + `init` + stored properties | `SwiftUIClosureCompletionProvider.swift` | `SwiftUI/CodeEditor+CoordinatorsExtensions.swift` | Promote class, explicit `package init(...)`, promote stored properties |

### 4.2 No promotion needed

- **Already public:** `CompletionEvent`, `CompletionItemView`, `CompletionManager`, `CompletionStatistics`, `CompletionDebouncer` + supporting types, `CompletionRankingModel`, `CompletionViewController`, `CompletionViewControllerDelegate`, `CompletionViewControllerRepresentable`, `CompletionViewModels` types, `OptimizedFuzzyMatcher`, `CompletionProviderUtilities`, `CompletionParsingHelpers`, `CodePatterns`.
- **Already open:** `CompletionViewControllerBase` (cross-module subclassing already supported).
- **Same-target-only consumers:** `CompletionContextExtractor`, `CompletionEventBroadcaster`, `LanguageKeywordCompletionProvider`, `CompletionViewController.CompletionViewControllerAdapter` (nested). These stay `internal`.

### 4.3 Expected member-level promotions

§6.2.7 SH lesson: default-internal members of public/package enclosing types may need promotion even when the enclosing type is already public. Expected count: **0–10 member promotions** during the compile-driven pass. Likely sites:

- `CompletionItemAdapter`'s stored properties + synthesized init (low confidence; verify at compile time).
- `SwiftUIClosureCompletionProvider`'s init signature + stored closure properties.
- Any default-internal members of `CompletionViewController*` accessed from `Core/CodeEditorView*` files (audit found no obvious sites, but compile-time enumeration is authoritative).

If the count blows past 30, the implementation halts at a WIP checkpoint, mirrors the §6.2.7 fallback pattern (bulk script + manual review), and resumes.

### 4.4 No `public` promotions

All cross-target visibility is satisfied by `package`. The §6.2.7 series-wide convention is preserved: cross-target visibility uses `package`, not `public`. External API surface is unchanged.

---

## 5. Risks

1. **Cross-target subclassing of `CompletionViewControllerBase`.** Class is `open`, so cross-module subclass works. Mitigation: build verification confirms umbrella code still resolves. The only umbrella consumer chain is `CodeEditorView+PlatformSpecificExtensions.swift` and `CodeEditorViewDelegate.swift`, which use `CompletionViewController` (subclass in same target) not subclass `Base` directly. No expected breakage.

2. **Member-level promotion surprises.** §6.2.7 SH had 107 promotions; the audit predicts Completion at the low end. Mitigation: compile-driven enumeration. If the count exceeds 30, halt at WIP checkpoint and re-evaluate. The work splits cleanly at the move/promote boundary.

3. **`CompletionItemAdapter` stored-property access modifiers.** Once the struct is `package`, its synthesized `init` and stored properties default to the struct's modifier (`package`) but the struct's *property* default is still file-private to the enclosing module unless made explicit. §6.2.8b Symbols lesson: synthesized inits on `public` structs are still `internal`; need explicit `package init(...)`. Plan task 2 step 7 includes an explicit init declaration to head this off.

4. **`SwiftUIClosureCompletionProvider` closure shape.** Its `init` likely captures a SwiftUI closure with a specific signature. Promotion to `package init(...)` preserves the closure shape; the plan verifies the call site in `CodeEditor+CoordinatorsExtensions.swift` compiles unchanged.

5. **Doc-comment cross-module references.** Three doc comments in moving files reference `CodeEditorView` and `EditorController` (`CompletionManager` line 172; `LanguageKeywordCompletionProvider` line 9; `CompletionEvent` line 13). CLAUDE.md's no-DocC-catalog stance applies: doc comments aren't compiled symbol references; leave them as-is. They become cross-module doc-only mentions, same as §6.2.8e Annotations'.

6. **Sample-app visual regression.** Completion popup rendering is heavy on platform-specific layout that the test suite may not cover end-to-end. Mitigation: post-extraction sample-app smoke (run, type `.` in a Swift file, verify popup appears, navigate with arrows, accept with Return, verify text inserted).

7. **Audit re-verification.** The subagent audit catalogued the file-level coupling. Between writing this design and executing it, a new commit could add a `CodeEditorView` reference to a moving file. Plan task 1 step 1 runs the bare-word `git grep -n 'CodeEditorView' Sources/CodeEditorPlugin/Completion/` to confirm no regression.

---

## 6. Deviations expected (vs. NEXT.md §4.1)

- **Deps `Common, Languages, TextModel, Platform, Diagnostics` — not the spec's `Languages, TextModel`.** Pattern: §4.1 dep claims are speculative.
- **Section letter `8g`, not `8c`.** 8c is reserved for deferred SmartEditing.
- **No carve-out file in `Core/Completion/`.** Completion is the second clean extraction in the §6.2.8 series (after Workspace).
- **No `.library` product.** Umbrella-route only; not in §6.3's opt-in list.

---

## 7. Verification plan

Run after each implementation step:

1. **After file moves (no promotions yet):** `swift build` fails predictably on the ~12 umbrella consumer files. The failure surface should match §3.3's list. Surprise additional failures → halt, re-survey, amend the plan.
2. **After umbrella `import CodeEditorCompletion` adds:** `swift build` compiles the umbrella; tests still red on link.
3. **After test imports added:** `swift build && swift test --filter Completion` passes all 10 Completion tests.
4. **After full pass:** `swift build && swiftlint --fix && swiftlint && swift test --parallel` green.
5. **Sample-app visual:** run `CodeEditorSample`, open a Swift file, trigger completion (`.`/`(` after an identifier), verify popup renders, arrows navigate, Return inserts. Catches regressions the test suite misses.

---

## 8. Non-goals

- No public API additions or removals. Strict import-graph surgery.
- No DocC catalog reintroduction (CLAUDE.md).
- No `CodeEditorView` rewiring — that's §6.2.12.
- No SmartEditing extraction — deferred to §6.2.12.
- No Debugger work — pending confirm-or-delete decision.
- No LSP extraction — §6.2.9, separate session.
- No reorganisation of `Tests/CodeEditorPluginTests/Completion/` into its own `CodeEditorCompletionTests` target — that's §6.2.15.

---

## 9. NEXT.md updates landed alongside the extraction

1. **§6.0 status table:** new row for `CodeEditorCompletion` (commit SHA TBD post-merge), deps `Common, Languages, TextModel, Platform, Diagnostics`. Mark as clean full extraction.
2. **§6.0 deviations block:** §6.2.8g entry — clean extraction, no carve-out, ~2 top-level + 0–10 member promotions, deps correction vs. §4.1, no productization, section letter 8g.
3. **§6.2.8 step list:** mark `Completion` as `[done — clean extraction, see §6.0]` with sub-step §6.2.8g and commit SHA.
4. **§10 Suggested next session:** remove `Completion` from the remaining list; the §6.2.8 feature engines are then complete except for `SmartEditing` (deferred §6.2.12) and `Debugger` (pending confirm-or-delete).
5. **CLAUDE.md "Other source roots" list:** add a bullet for `Sources/CodeEditorCompletion/`.
6. **CLAUDE.md "Source Tree" file-count claim:** the "302 Swift source files in the umbrella target" line drops by 19 to 283. Update it (and the matching `find` count, if any) atomically with the extraction commit.

---

## 10. Summary

19 files. One new target. ~2 definite top-level promotions, low-end member promotion budget. ~12 umbrella files gain a single import. 10 tests gain a single import. No productization, no carve-out, no public-API changes, no `Core/Completion/` bucket. Second clean extraction in the §6.2.8 series.

Closes the §6.2.8 feature engines (modulo deferred SmartEditing and pending Debugger decision); next session targets §6.2.9 LSP / Debugger or the Debugger confirm-or-delete step that gates §6.2.9.
