# §6.2.9a CodeEditorDebugger confirm-or-delete — design (delete)

**Status:** spec for the next session.

**Position in the restructure:** §6.2.9a is the confirm-or-delete gate that NEXT.md §8.2 and §10 flagged as a prerequisite for §6.2.9b LSP extraction. With this decision landed as **delete**, the §6.2.9 LSP extraction can proceed as a single-target session (no sibling Debugger target). Closes the last open item in §6.2.8 territory (`SmartEditing` remains deferred to §6.2.12).

**Precedents this builds on:**

- §6.2.8d `CodeEditorSearch` (`18f9d43a`) — first cross-restructure public-API removal (`EditorController.selectMatch` deleted from umbrella). Establishes that removing umbrella surface is a normal restructure operation.
- NEXT.md §8.2 risk #2 — *"`DebuggerIntegration*` may be design-only — confirm before promoting it to its own target. If it's not shipping, delete it instead of splitting it (matches CLAUDE.md's 'don't ship half-finished' stance)."* This spec is the execution of that risk's "delete" branch.
- CLAUDE.md "Watch for stale claims in diagrams" — `PluginManager` / `PluginAPI` are listed as non-existent symbols whose archived diagrams stay in `docs/archive/Diagrams/`. The Debugger code physically exists but matches the same dead-code pattern; archiving its design diagram follows the same precedent.

**Why deletion (not extraction):** the audit conducted during this brainstorming session (transcript 2026-05-18) found, across the 7 candidate files (1,410 LOC):

1. **Zero `public` declarations.** Every top-level type is `internal` or default-internal. External consumers cannot link these symbols.
2. **Zero in-tree consumers.** No file in `Sources/` (umbrella, LSP, Sample, UI) and no test references `DebuggerIntegrationCore`, `DebugAdapter`, `DebugSession`, the framework's `Breakpoint` struct, `StackFrame`, `Variable`, `LaunchConfiguration`, `DebugCapabilities`, or `DebugError`. The Sample's "Toggle Breakpoint" command uses `AnnotationsHub` (red `ERROR` annotation badges), which `AnnotationsHub.swift:16` explicitly comments *stands in for* the debugger gutter. `GutterDebugSupport` / `GutterViewModel` track breakpoint lines as `Set<Int>` — unrelated to the framework's `Breakpoint` struct.
3. **Zero `EditorConfiguration` wiring.** No debug/breakpoint/debugger field exists.
4. **Zero LSP wiring.** Despite `docs/Diagrams/20-debugging-integration.md:398` claiming `DebuggerIntegrationCore --> LSPIntegration`, no LSP file references any Debugger type.
5. **Zero test coverage.** No test file references any Debugger type.
6. **Ten-month dormancy.** Last substantive touch `fd3fa8bf` 2025-07-13. Commits since are incidental (Common import sweep, review remediation, doc polish).
7. **Design-only self-admission.** `docs/Diagrams/20-debugging-integration.md:3`: *"The `DebugAdapter` protocol is defined but concrete adapter implementations (LLDB, Node.js, Python) are planned and not yet shipped."*
8. **User confirmation (2026-05-18):** debugger integration is **not** on the 6–12 month roadmap.

The kept-and-extracted alternative would require promoting internal types to public, wiring to Configuration, adding tests, and re-validating the design — none of which serves a planned product. The soft-delete alternative (compile-flag guards) preserves the dead-code maintenance cost (strict concurrency, SwiftLint) without benefit. Deletion is the move.

---

## 1. Goal

Delete the unreachable Debugger scaffold (7 source files, 1,410 LOC) and reconcile docs and NEXT.md with its absence. Strictly subtractive: no functional code changes outside the deleted files; no new abstractions; no replacement.

Net result:
- `Sources/CodeEditorPlugin/Features/` shrinks from 12 → 5 files (the NEXT.md §3 table baseline of "23" predates the §6.2.8 series; it has been stale through 6 prior extractions, and refreshing the whole table is out of scope for this step — see §4 row 2).
- Umbrella source-file count (per CLAUDE.md): 282 → 275.
- One design-only diagram moves to `docs/archive/Diagrams/`.
- Two live diagrams lose their Debugger sub-sections.
- `docs/Diagrams/README.md` and NEXT.md edited (14 row-level edits + a new §6.2.9a deviations block).
- `swift build` and `swiftlint` remain green by construction. Full `swift test --parallel` run is optional given zero test references to Debugger (see §6 step 3).

---

## 2. Scope

### 2.1 Files deleted from `Sources/CodeEditorPlugin/Features/`

All 7 are unreachable. Top-level types listed for the deletion record.

| File | LOC | Top-level types (all `internal` or default-internal) |
|---|---|---|
| `DebuggerIntegration.swift` | 9 | `typealias DebuggerIntegration = DebuggerIntegrationCore` |
| `DebuggerIntegrationCore.swift` | 327 | `class DebuggerIntegrationCore: ObservableObject` |
| `DebuggerIntegration+Breakpoints.swift` | 97 | `extension DebuggerIntegrationCore` |
| `DebuggerIntegration+Evaluation.swift` | 106 | `extension DebuggerIntegrationCore` |
| `DebuggerIntegration+Execution.swift` | 63 | `extension DebuggerIntegrationCore` |
| `DebuggerModels.swift` | 306 | `DebugSession`, `LaunchConfiguration`, `Breakpoint`, `Source`, `StackFrame`, `Variable`, `Scope`, `Module`, `InlineValue`, `HoverEvaluation`, `EvaluateContext`, `StoppedReason`, `DebugCapabilities`, `DebugError`, plus a `Notification.Name` extension |
| `DebugAdapter.swift` | 502 | `AdapterError`, `DebugAdapter` protocol, `SourceBreakpoint`, `DebugEvent`, `BaseDebugAdapter`, `LLDBAdapter`, `NodeDebugAdapter`, `PythonDebugAdapter` |
| **Total** | **1,410** | |

### 2.2 Files explicitly NOT touched

The audit found names that *look* Debugger-related but belong to other subsystems. None of these is in scope:

- `Sources/CodeEditorSample/EditorActions/AnnotationsHub.swift` — sample's `toggleBreakpoint(at:)` and `clearAllBreakpoints()` operate on the annotations system. Doc-comment line 16 references `DebuggerIntegrationCore` as the framework's-version-which-this-sample-replaces. Update or leave? **Leave.** The comment is a contextual note that survives deletion intact — removing it is editorial scope creep.
- `Sources/CodeEditorSample/Sidebars/AnnotationsInspectorPanel.swift`, `Sources/CodeEditorSample/KnobPanels/AnnotationsKnobsSection.swift`, `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift` — sample UI for the annotations-based breakpoint stand-in. Unrelated to framework Debugger. Untouched.
- `Sources/CodeEditorPlugin/Layout/GutterDebugSupport.swift`, `Sources/CodeEditorPlugin/Layout/GutterViewModel.swift` — gutter-side breakpoint *display* (a `Set<Int>` of line numbers + a `hasBreakpoint: Bool` flag). Independent of the framework Debugger struct of the same name. Untouched.
- `Sources/CodeEditorPlugin/Core/Platform/ContextMenuCoordinator.swift` — has a "Toggle Breakpoint" menu item whose action is a local `performToggleBreakpoint` that does not reference any Debugger type. Untouched.
- `Sources/CodeEditorAnnotations/Annotation.swift:39` — doc comment lists "Breakpoints and debug notes" as an example annotation use case. Untouched.
- `Tests/CodeEditorSampleTests/AnnotationsHubDiagnosticsTests.swift` — tests the sample's annotations-based breakpoint flow, not the framework Debugger. Untouched.
- `docs/Internals/architecture-overview.md:58` — historical note `"Removed DebuggerIntegration subdirectory"` describes a *prior* removal. Stays as history.
- `docs/superpowers/plans/2026-05-18-codeeditor-search-extraction.md:242` — frozen-in-time executed plan referencing Debugger as a Features/ sibling. Stays as history.

### 2.3 Non-goals

- **No `EditorConfiguration` changes.** No debugger field exists; nothing to remove.
- **No LSP changes.** No LSP file references Debugger.
- **No test changes.** Zero tests reference Debugger types.
- **No sample-app changes.** Sample's breakpoint UI is annotation-based and orthogonal.
- **No CLAUDE.md changes required.** Grep confirms zero direct references; the document's "Watch for stale claims" stance is already aligned with this deletion.
- **No `Package.swift` changes.** Debugger never had its own target.
- **No public-API impact.** Zero `public` symbols to remove from the umbrella surface (the deleted symbols were all `internal`).
- **No archive of `Notification.Name` extension semantics.** The 7 notification names declared in `DebuggerModels.swift:303` have no in-tree posters or observers (audit-confirmed); they vanish with the file.

---

## 3. Documentation moves and edits

### 3.1 Move: design-only diagram → archive

```
git mv docs/Diagrams/20-debugging-integration.md \
       docs/archive/Diagrams/20-debugging-integration.md
```

`docs/archive/Diagrams/` already contains `20-debugging-integration-architecture.md` (the older extended design referenced by `docs/Diagrams/README.md:68`). The moved file uses its current name — no collision. Both archived versions sit side-by-side as point-in-time references per CLAUDE.md.

### 3.2 Edit: `docs/Diagrams/11-advanced-features-integration.md`

Remove the Debugger sub-section. Specifically:
- Class definition block `class DebuggerIntegrationCore { ... }` and its companion DebugSession-related entries (around lines 227–236).
- The four cross-component edges referencing `DebuggerIntegrationCore` (lines 369, 376, 398, 399, 400).
- The classDef assignment `class DebuggerIntegrationCore debugger` (line 444).
- The §6 prose block "Production-Ready Debugger & LSP Integration" — header (line 487), DebuggerIntegrationCore bullet (line 488), and the Cross-Component Collaboration bullet (line 490, which calls out "Debugger and LSP integration"). Retain the LSP-only content if the surrounding bullets reference LSP without Debugger; rewrite the section header to "Production-Ready LSP Integration".
- Any "%% Debugger" comment rows in the Mermaid source (line 227, 397) are removed in the same pass.

Net delta: ~22 lines removed across one Mermaid block, three classDef edges, one classDef assignment, and one prose subsection. The diagram retains its LSP, performance, search, smart-editing, and folding content.

### 3.3 Edit: `docs/Diagrams/01-high-level-architecture.md`

Drop the `DIC["Debugger<br/>Integration"]` node (line 43) and any edges incident on it. Verify the surrounding subgraph still renders by reading the file end-to-end after the edit.

### 3.4 Edit: `docs/Diagrams/README.md`

- Remove the `### 20. [Debugging Integration]` entry block (lines 67–68). The cross-link to the archived `20-debugging-integration-architecture.md` no longer makes sense because the "currently implemented" companion is now also archived.
- Line 9 (`"Design-only diagrams ... and the extended debugging-integration design ... live in [../archive/Diagrams/]"`) stays as-is — still factually correct after the move.
- Line 41 (description of diagram 11) — drop the phrase `"debugging integration,"` from the feature list; the diagram retains its other content.
- Line 77 (language matrix description: `"...debugging support for each language"`) stays as-is. The language matrix is a separate diagram that describes language *metadata* (whether each language has debug-adapter mapping in its descriptor) and is not affected by the framework-side Debugger deletion. Verify during execution that the matrix doesn't itself reference deleted types — if it does, that's a separate edit.

### 3.5 Documents explicitly NOT edited

- `docs/Internals/architecture-overview.md` — line 58 is historical context for a prior unrelated removal.
- `docs/superpowers/plans/2026-05-18-codeeditor-search-extraction.md` — executed plan, frozen in time.
- `CLAUDE.md` — no direct Debugger reference. Its stale-claims guidance already covers the case.

---

## 4. NEXT.md edits

14 row-level edits (table below) plus a new §6.2.9a deviations block (§4.1). All are subtractive or status-update. Each cited by current line number.

| # | NEXT.md line | Current text | Edit |
|---|---|---|---|
| 1 | §1.4 (line 12) | "LSP, Debugger, SwiftUI chrome, and Performance instrumentation should be opt-in libraries" | Drop "Debugger,". Result: "LSP, SwiftUI chrome, and Performance instrumentation". |
| 2 | §3 table (line 47) | `Features/ \| 23 \| Folding, smart editing, search/replace, symbol nav, debugger integration` | Drop ", debugger integration" from description, leaving "smart editing". **Leave the "23" count as-is.** That number has been stale since §6.2.8a (current actual is 12; post-deletion will be 5). Refreshing every §3 table row to current reality is its own session — propagating the deletion fix here while leaving Folding/Symbols/Search rows stale would create a false sense that §3 has been audited. Out of scope. |
| 3 | §4.1 table (line 89) | Row: `5 \| CodeEditorDebugger \| Features/Debugger*, Features/DebugAdapter* \| TextModel, Annotations` | Delete the row entirely. |
| 4 | §4.2 Mermaid (line 135) | `Debugger[CodeEditorDebugger]` inside `subgraph P5` | Delete the node. |
| 5 | §4.2 Mermaid (line 180) | `TextModel --> Debugger` | Delete the edge. |
| 6 | §4.2 Mermaid (line 181) | `Annotations --> Debugger` | Delete the edge. |
| 7 | §4.3 (line 210) | "`CodeEditorLSP` and `CodeEditorDebugger` are opt-in libraries." | Rewrite without Debugger: "`CodeEditorLSP` is an opt-in library." |
| 8 | §6.0 deviations (line 366) | "Sets precedent for §6.2.9 LSP / Debugger extractions where the umbrella's public surface may also thin." | Replace `LSP / Debugger` with `LSP`. |
| 9 | §6.0 deviations (line 402) | "remaining §6.2.8 work is `SmartEditing` (deferred §6.2.12) and `Debugger` (pending confirm-or-delete decision — not yet a feature-engine carve-out)." | Update to: "remaining §6.2.8 work is `SmartEditing` (deferred §6.2.12). `Debugger` deleted per §6.2.9a." |
| 10 | §6.2 step 9 (line 430) | "Extract `CodeEditorLSP` and `CodeEditorDebugger` — both depend on engines from step 8. Make them separate products..." plus the parenthetical about archived design | Rewrite as single-target step: "Extract `CodeEditorLSP` — depends on engines from step 8. Make it a separate product so consumers can opt out. (Debugger deleted §6.2.9a — no sibling target.)" |
| 11 | §6.3 (line 445) | "Optional / opt-in: `CodeEditorLSP`, `CodeEditorDebugger`, `CodeEditorDiagnostics`, `CodeEditorSearch`, `CodeEditorWorkspace`" | Drop `CodeEditorDebugger,`. |
| 12 | §8.2 risk #2 (line 463) | "`DebuggerIntegration*` may be design-only — confirm before promoting it to its own target. If it's not shipping, delete it instead of splitting it" | Rewrite as past tense: "`DebuggerIntegration*` was design-only — deleted in §6.2.9a (2026-05-18). Future debugger work, if any, starts green-field; the archived diagram in `docs/archive/Diagrams/` is the design starting point." |
| 13 | §9 non-goals (line 473) | "Don't combine it with debugger completion, tree-sitter expansion, or LSP changes." | Drop "debugger completion,". |
| 14 | §10 (line 484–485) | "`Debugger` (pending confirm-or-delete decision — not yet a feature-engine carve-out)." and "6.2.9 `CodeEditorLSP` + `CodeEditorDebugger`" | Rewrite the §10 bullet: "Debugger deleted in §6.2.9a (2026-05-18)." Remove `+ CodeEditorDebugger` from the §6.2.9 mention. |

### 4.1 New §6.2.9a deviations block

A new block under §6.0 (matching the §6.2.8a/§6.2.8b/etc. pattern), placed after the existing §6.2.8g block:

> **Deviations during §6.2.9a `CodeEditorDebugger` confirm-or-delete (commit \<TBD\>):**
>
> - **Outcome: delete.** Confirmed via audit (zero `public`, zero in-tree consumers, zero tests, zero Configuration wiring, zero LSP wiring, 10-month dormancy, self-admitted design-only diagram) and user confirmation (no roadmap in 6–12 months).
> - **Files deleted (7, 1,410 LOC):** `DebuggerIntegration.swift`, `DebuggerIntegrationCore.swift`, `DebuggerIntegration+Breakpoints.swift`, `DebuggerIntegration+Evaluation.swift`, `DebuggerIntegration+Execution.swift`, `DebuggerModels.swift`, `DebugAdapter.swift` — all in `Sources/CodeEditorPlugin/Features/`.
> - **Diagrams reconciled.** `docs/Diagrams/20-debugging-integration.md` → `docs/archive/Diagrams/`. Debugger sub-sections removed from `docs/Diagrams/11-advanced-features-integration.md` and `docs/Diagrams/01-high-level-architecture.md`. `docs/Diagrams/README.md` index entry §20 dropped; entry §11 description amended.
> - **Zero functional code change.** No file outside `Features/Debugger*` was edited for code reasons. No tests added or removed. No `EditorConfiguration` changes. No `Package.swift` changes (Debugger never had its own target). Public API surface of `CodeEditorPlugin` unchanged because every deleted symbol was `internal`.
> - **NEXT.md edits.** 14 row-level edits across §1.4 / §3 / §4.1 / §4.2 (3 edges/nodes) / §4.3 / §6.0 (2 deviations updates) / §6.2 / §6.3 / §8.2 / §9 / §10 (2 lines), plus this new deviations block. Removes the Debugger target row, the two Mermaid edges, the opt-in list mention, the deviations references, and the confirm-or-delete pending status.
> - **No precedent for "delete a target before extraction".** This is the first restructure step that *removes* a candidate target rather than carving one out. Sets a precedent for future audits: if a carve-out target's symbols are all `internal` and have zero in-tree consumers, deletion is the answer, not extraction.
> - **Closes the §6.2.9 prerequisite.** §6.2.9b LSP extraction can now proceed as a single-target session without an accompanying Debugger target.

---

## 5. Execution order

Single commit, one PR. Steps within the commit are ordered to keep the working tree compilable at every intermediate stage in case of mid-execution interruption.

1. **Delete the 7 source files** with `git rm`. Build expected to remain green (audit confirmed zero consumers, but verify with `swift build`).
2. **Move the design diagram** with `git mv docs/Diagrams/20-debugging-integration.md docs/archive/Diagrams/20-debugging-integration.md`.
3. **Edit the two live diagrams** (`11-advanced-features-integration.md`, `01-high-level-architecture.md`) per §3.2 / §3.3.
4. **Edit `docs/Diagrams/README.md`** per §3.4.
5. **Edit NEXT.md** with all 14 sites per §4.
6. **Run verification** per §6.
7. **Commit.**

---

## 6. Verification

After all edits in §5 steps 1–5:

1. `swift build` — expected green. No file outside `Features/Debugger*` references any deleted Debugger symbol (audit-verified). If this fails, the audit missed a consumer; investigate and update the audit notes before continuing.
2. `swiftlint --fix && swiftlint` — expected green. Custom rules (`no_print_statements`, `force_unwrapping`) target Swift source patterns; deleted files don't trigger them. Strict mode applies.
3. `swift test --parallel` — **optional**, expected green if run. Zero tests reference Debugger types (verified in §2 audit), so a successful `swift build` is already strong evidence. Per the project's `skip full swift test --parallel after additive-only steps` heuristic — extended here to subtractive-only steps with audit-confirmed zero consumer impact — running a targeted subset (e.g. `swift test --filter AnnotationsHubDiagnosticsTests` to confirm the sample's breakpoint stand-in still passes) is sufficient. Full parallel run is fine if the executor wants the extra confidence.
4. `swift run CodeEditorSample` — expected to launch and present the sample window. Smoke-test: trigger the "Toggle Breakpoint at Cursor" command via `⌘⇧P`. It should add a red `ERROR` annotation badge to the gutter via `AnnotationsHub` (the sample's stand-in path) without touching the deleted framework code.
5. **Diagram render check.** Open `docs/Diagrams/11-advanced-features-integration.md` and `docs/Diagrams/01-high-level-architecture.md` in a Mermaid-aware viewer (or VS Code preview). Both should render without syntax errors after the Debugger nodes/edges are removed.
6. **Doc reference re-grep.** Run `grep -rE "DebuggerIntegration|DebugAdapter|DebuggerModels|DebugSession" docs --include='*.md' | grep -v 'docs/archive'`. Expected output: only `docs/Internals/architecture-overview.md` (historical note) and `docs/superpowers/plans/2026-05-18-codeeditor-search-extraction.md` (frozen plan). Both are explicitly out of scope per §2.2.
7. **Source re-grep.** `grep -rE "DebuggerIntegrationCore|DebugAdapter|class DebugSession" Sources --include='*.swift'`. Expected: zero matches (the only remaining `DebuggerIntegrationCore` mention is the doc-comment in `Sources/CodeEditorSample/EditorActions/AnnotationsHub.swift`, which is explicitly retained per §2.2).

If any check fails, stop and re-audit before pressing on.

---

## 7. Risks & mitigations

1. **Private external consumer via `@testable import`.** Risk: a private app in `~/Workspace/` (Sonography / Bridge / PixelLift / etc.) may have reached into `CodeEditorPlugin` with `@testable` and used a `DebuggerIntegrationCore` symbol despite its `internal` visibility. Mitigation: the audit grep on this repo cannot see those repos. Posture is the same as §6.2.8d Search's `EditorController.selectMatch` removal — a private consumer was always relying on accidentally-exposed internals. If a consumer is found post-deletion, the recovery path is `git show <sha>:<path>` of any of the 7 deleted files; we are not rewriting history.
2. **Future restoration cost.** Risk: in 2027+ someone decides to ship debugger integration after all. Mitigation: the archived design diagram in `docs/archive/Diagrams/20-debugging-integration.md` plus the git history of the deleted files (recoverable via `git log --follow` and `git show`) provide a starting point. Restoration is informed-by-history, not green-field. The 10 months of dormancy suggests this restoration scenario is unlikely; if it happens, the 1,410 LOC was always going to need a rewrite anyway (Swift 6 strict concurrency landed after the original drafting).
3. **Doc-edit drift.** Risk: the manual Mermaid edits in `11-advanced-features-integration.md` and `01-high-level-architecture.md` could miss an incidental edge or classDef line. Mitigation: §6 step 5 (diagram render check) catches Mermaid syntax errors; §6 step 6 (doc re-grep) catches missed type references. The implementation plan will include a `git diff --stat` review step before commit.
4. **Sample comment with deleted-symbol mention.** `Sources/CodeEditorSample/EditorActions/AnnotationsHub.swift:16` retains a doc comment naming `DebuggerIntegrationCore`. Risk: a reader greps for the symbol post-deletion and finds the comment, then concludes the symbol still exists. Mitigation: per §2.2 we leave it intentionally — the comment's context is that this sample's annotation-based breakpoint UI replaces what the framework would have provided. Anyone investigating will follow the trail to this spec and the archived diagram. Editing the comment is out of scope and would be editorial drift.

---

## 8. Out-of-scope follow-ups (intentionally deferred)

- **Sample-side editorial cleanup** of `AnnotationsHub.swift:16` and `AnnotationsHub.swift:88` doc comments. The text reads fine without a Debugger reference, but rewriting it is sample-side scope and unrelated to the framework deletion.
- **README.md description trim** of `docs/Diagrams/README.md:41` could be further polished to remove the comma-separated reference to "debugging integration"; the minimum edit (drop the phrase) is in scope per §3.4. A larger restructure of that paragraph is out.
- **Audit of `DocumentSymbolKind.case .debugger` (or similar) in `CodeEditorLanguages`.** Out of scope unless §6 step 7 surfaces a reference. The Languages module's debug-related metadata (if any) is per-language descriptor data, not framework Debugger code.

---

## 9. Rollback

If `swift build` fails after step 1 (the audit was wrong):

1. `git checkout HEAD -- Sources/CodeEditorPlugin/Features/Debugger*.swift Sources/CodeEditorPlugin/Features/DebugAdapter.swift`
2. Re-grep to identify the missed consumer.
3. Update §2.2 of this spec with the new consumer.
4. Decide: (a) extract a minimal "stays in umbrella" carve-out for the load-bearing symbol(s), or (b) update the consumer to not use Debugger, or (c) abandon the deletion and re-spec as a keep-and-extract.

If diagram edits break rendering:

1. `git checkout HEAD -- docs/Diagrams/`
2. Redo the edits with a finer-grained `git diff` review.

The deletion is atomic — either the whole PR lands or none of it does.

---

## 10. Estimated execution time

Half a session. ~30 minutes for the deletion + doc edits, ~15 minutes for verification, ~15 minutes for the NEXT.md textual updates and the new §6.2.9a block. Optimistic upper bound: 90 minutes including PR description.

Smaller than every prior §6.2.* step: no new target, no `Package.swift` change, no access-modifier promotions, no consumer ripple, no test edits.
