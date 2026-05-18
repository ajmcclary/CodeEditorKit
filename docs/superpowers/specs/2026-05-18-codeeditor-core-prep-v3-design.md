# §6.2.12c Core/ prep v3 — design

**Date:** 2026-05-18
**Status:** Spec, awaiting plan
**Predecessors:** [`2026-05-18-codeeditor-core-prep-design.md`](2026-05-18-codeeditor-core-prep-design.md) (§6.2.12a, landed `d129070` / `7f498a8` / `f3b89fc` / `280b82e`); [`2026-05-18-codeeditor-core-prep-v2-design.md`](2026-05-18-codeeditor-core-prep-v2-design.md) (§6.2.12b, landed `7cd4421` / `29e4a70`+`5bbb5b7` / `d26527e`)
**Next:** §6.2.12 main Core/ split (the riskiest single move in the restructure series)

---

## 1. Goal & shape

§6.2.12c is the third incremental Core/ prep round. Three bundled actions:

1. **Bucket A — Relocate 3 pure-Foundation state types from umbrella `Core/` to `CodeEditorCommon/`** (`SelectionState`, `EditorInteractionState`, `DirtyTracker`).
2. **Bucket B — Delete the 4-file `TextSystem` dead-code cluster** (`TextSystem`, `TextSystemStyler`, `ThreePhaseTextSystemStyler`, `TokenSystemValidator`).
3. **Bucket C — Split `AsyncOperationErrors.swift`**: delete the dead `CompletionAsyncError`, relocate `ErrorRecoveryCoordinator` to `CodeEditorCommon/`, delete the now-empty file.

Per-bucket shape, in order from cheapest to most involved. Six commits total (one per relocation/deletion + one doc commit), each green on `swift build && swiftlint && swift test --parallel`.

- No new SPM targets.
- No productization changes.
- **Two public API removals** (Bucket B's `TextSystem` cluster, Bucket C's `CompletionAsyncError`) — first §6.2.12 prep round to remove public surface. Matches §6.2.8d `selectMatch` and §6.2.9a Debugger precedents.
- After this round, umbrella `Core/` shrinks **126 → 118** (-8, -6.3%); the umbrella `Sources/CodeEditorPlugin/` total drops correspondingly. `CodeEditorCommon/` grows by 4 files.
- The §6.2.12a audit table gains 3 row updates (Bucket 3 "Defer / re-audit" → "Moved" for Bucket A files) and the §6.2.12a / §6.2.12b summary line ticks down.
- The two §10 architectural questions (F3 glue policy, `ToolbarItem` routing) stay **deferred to §6.2.12 main**.

This chunk targets the lowest-risk remainders of the §6.2.12a Bucket 3 "Defer" list: pure-value state types that have nowhere natural to go but Common; orphaned scaffolding that should be deleted, not preserved; and a hybrid file whose two halves go in opposite directions.

---

## 2. Per-file dispositions

### 2.1 Bucket A — Relocate to `CodeEditorCommon`

| File | LOC | Current | Move target | `CodeEditorView` refs | Internal deps (post-move) | Promotions |
|---|---|---|---|---|---|---|
| `SelectionState.swift` | ~30 | `Sources/CodeEditorPlugin/Core/` | `Sources/CodeEditorCommon/` | 0 | Foundation only | 0 (already `public`) |
| `EditorInteractionState.swift` | ~60 | `Sources/CodeEditorPlugin/Core/` | `Sources/CodeEditorCommon/` | 0 | Foundation + CoreGraphics | 0 (already `public`; carries `EditorCursorPosition`) |
| `DirtyTracker.swift` | ~30 | `Sources/CodeEditorPlugin/Core/` | `Sources/CodeEditorCommon/` | 0 | Foundation only | 4 — `struct DirtyTracker` + `setBaseline(_:)` + `isDirty(currentText:)` + `markClean(currentText:)` (internal → public) |

Per-file rationale:

- **`SelectionState.swift` → `CodeEditorCommon`.** Foundation-only public struct (`line`, `column`, `selectionLength` — 1-based caret/selection position). 6 in-tree consumers (`EditorState`, `EditorStateBridge`, `SwiftUI/CodeEditor+CoordinatorsExtensions`, plugin tests, UI snapshot tests). Common is the natural home; the file is a sibling to `SourcePosition` relocated in §6.2.11.
- **`EditorInteractionState.swift` → `CodeEditorCommon`.** Foundation + CoreGraphics public struct with optional fields for serializable cursor/scroll/find-panel/fold state. Carries `EditorCursorPosition` (sibling public struct in the same file). 17 in-tree consumers across umbrella `Core/Documents/`, SwiftUI slice, sample app, and 7 test files. Common-resident matches the persistent-state pattern (`SourcePosition`).
- **`DirtyTracker.swift` → `CodeEditorCommon`.** Foundation-only `internal struct` (currently no modifiers) implementing baseline-comparison dirty tracking. Single in-tree caller (`SwiftUI/CodeEditor+CoordinatorsExtensions.swift`). The 4 access-modifier promotions are the only non-zero-touch work in Bucket A.

### 2.2 Bucket B — Delete dead `TextSystem` cluster

| File | LOC | Public surface | In-tree usage |
|---|---|---|---|
| `TextSystem.swift` | ~85 | `public protocol TextSystem`, plus extensions adding default impls and a `Styler` typealias | Zero conformers anywhere in `Sources/` or `Tests/` |
| `TextSystemStyler.swift` | ~95 | `public final class TextSystemStyler<Interface: TextSystem>` | Zero call sites outside the cluster |
| `ThreePhaseTextSystemStyler.swift` | ~165 | `public final class ThreePhaseTextSystemStyler<Interface: TextSystem>` | Referenced only by `TextSystem.swift`'s `Styler` typealias |
| `TokenSystemValidator.swift` | ~115 | `public final class TokenSystemValidator<Interface: TextSystem>` | Referenced only by the two styler classes |

Confirmed dead via grep:

- `grep -rn ': TextSystem\b\|extension.*: TextSystem\b\|class.*: TextSystem\b\|struct.*: TextSystem\b' Sources/ Tests/` returns only the three generic class declarations from within the cluster itself.
- `grep -rn 'TextSystemStyler(\|ThreePhaseTextSystemStyler(\|TokenSystemValidator(' Sources/ Tests/` returns only self-references.
- `grep -rn '\.Styler\b' Sources/ Tests/` returns zero hits (the typealias is never invoked).

Disposition: `git rm` all four files in a single commit.

Risk: external (out-of-tree) consumers using the `TextSystem` protocol or its conforming styler types. Mitigation: matches §6.2.9a Debugger precedent ("if a candidate target's symbols are all internal-by-use and have zero in-tree consumers, deletion is the answer, not extraction"). These are self-evident TextKit2 styling-experiment scaffolding from earlier development that never wired up to anything shipping; no consumer in `~/Workspace/` references them.

### 2.3 Bucket C — Split `AsyncOperationErrors.swift`

The file currently houses two unrelated types: `CompletionAsyncError` (dead) and `ErrorRecoveryCoordinator` (live). The split removes the dead half, relocates the live half, and deletes the file.

| Action | Detail |
|---|---|
| Delete `CompletionAsyncError` | Public enum (6 cases, ~140 LOC including recovery-strategy switches). Zero in-tree callers — verified by `grep -rn 'CompletionAsyncError' Sources/ Tests/` returning only the declaration itself. Dead from early completion-error design. |
| Move `ErrorRecoveryCoordinator` → `CodeEditorCommon/ErrorRecoveryCoordinator.swift` | Generic public actor coordinating retry/fallback strategies. Currently uses `SyntaxHighlightingError.cancelled` (line 258) as the default thrown error in an unreachable code path; swap for `CancellationError()` to drop the `CodeEditorSyntaxHighlighting` import. Remaining deps (Common's `RecoverableAsyncError`, `RecoveryStrategy`, `BackoffStrategy`, `CrossPlatformLogger`) are all in-target post-move. |
| Delete `AsyncOperationErrors.swift` | File body becomes empty after the two prior steps (only comment block + imports remain). Remove the file in the same commit. |

Three umbrella-resident `ErrorRecoveryCoordinator` callers, all already `import CodeEditorCommon`:

- `Sources/CodeEditorPlugin/Core/ActorCoordinator.swift`
- `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/AsyncSyntaxHighlighter.swift`
- `Sources/CodeEditorPlugin/Core/Actors/TextProcessingActor.swift`

Zero import edits required at the call sites. The error-semantics tweak (line 258) is in the "all retries exhausted with no captured error" fall-through — practically unreachable because `retryWithBackoff` only reaches that line if at least one attempt threw and assigned to `lastError`. Risk is theoretical; document the swap explicitly in the commit message and the NEXT.md deviations block.

---

## 3. Commit shape

Six commits, smallest first. Matches §6.2.12b's per-commit-green discipline.

### Commit 1: `Relocate SelectionState to CodeEditorCommon (§6.2.12c prep)`

- **Operation:** `git mv Sources/CodeEditorPlugin/Core/SelectionState.swift Sources/CodeEditorCommon/`
- **Content edits:** none.
- **Promotions:** 0 (already `public`).
- **Consumer ripple — `import CodeEditorCommon` added where missing:**
  - `Sources/CodeEditorPlugin/Core/EditorStateBridge.swift`
  - `Sources/CodeEditorPlugin/Core/EditorState.swift`
  - `Tests/CodeEditorPluginTests/Core/EditorStateTests.swift`
  - `Tests/CodeEditorPluginTests/Core/EditorStateConformanceTests.swift`
  - `Tests/CodeEditorUITests/Snapshots/EditorStatusBarSnapshots.swift`
  - `SwiftUI/CodeEditor+CoordinatorsExtensions.swift` — already imports Common, no edit.
- **Package.swift edit:** `CodeEditorUITests` target gains `CodeEditorCommon` as a direct dep (currently has `Configuration`, `Languages`, `Symbols`, `UI` only). One-line addition, alphabetical slot before `CodeEditorConfiguration`.

### Commit 2: `Relocate EditorInteractionState to CodeEditorCommon (§6.2.12c prep)`

- **Operation:** `git mv Sources/CodeEditorPlugin/Core/EditorInteractionState.swift Sources/CodeEditorCommon/`
- **Content edits:** none. The `swiftlint:disable discouraged_optional_boolean discouraged_optional_collection` pragma travels with the file unchanged.
- **Promotions:** 0 (already `public`).
- **Consumer ripple — `import CodeEditorCommon` added where missing.** Pre-flight grep at plan time:
  - Umbrella `Core/Documents/`: `EditorDocument.swift`, `EditorDocuments.swift` — verify.
  - SwiftUI slice (6 files): `CodeEditor.swift`, `CodeEditor+AppKitExtensions.swift`, `CodeEditor+UIKitExtensions.swift`, `CodeEditorRepresentableHelper.swift`, `CodeEditorIntent.swift`, `CodeEditor+ModifiersExtensions.swift` — most already import Common via prior phases; verify.
  - Sample (1 file): `Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift`.
  - Tests (7 files): `Tests/CodeEditorPluginTests/Core/EditorInteractionStateTests.swift`, `Documents/EditorDocumentsBindingTests.swift`, `Documents/ActiveDocumentModifierTests.swift`, `Documents/EditorDocumentTests.swift`, `SwiftUI/CodeEditorIntentTests.swift`, `SwiftUI/ModifierChainCompositionTests.swift`, `SwiftUI/EditorInteractionStateBindingTests.swift`.
- **Package.swift edit:** none (Commit 1 already added `CodeEditorCommon` to `CodeEditorUITests`; the other consumers are in `CodeEditorPluginTests` and `CodeEditorSampleTests`, which already depend on Common).

### Commit 3: `Relocate DirtyTracker to CodeEditorCommon (§6.2.12c prep)`

- **Operation:** `git mv Sources/CodeEditorPlugin/Core/DirtyTracker.swift Sources/CodeEditorCommon/`
- **Content edits:** promote `struct DirtyTracker` to `public struct DirtyTracker`; promote `setBaseline(_:)`, `isDirty(currentText:)`, `markClean(currentText:)` to `public`. The struct's stored properties stay `private` (single internal baseline string).
- **Promotions:** 4 (struct + 3 methods).
- **Consumer ripple:** zero new imports. The single consumer (`SwiftUI/CodeEditor+CoordinatorsExtensions.swift`) already imports `CodeEditorCommon`.
- **Package.swift edit:** none.

### Commit 4: `Delete TextSystem dead-code cluster (§6.2.12c prep)`

- **Operation:** `git rm Sources/CodeEditorPlugin/Core/TextSystem.swift Sources/CodeEditorPlugin/Core/TextSystemStyler.swift Sources/CodeEditorPlugin/Core/ThreePhaseTextSystemStyler.swift Sources/CodeEditorPlugin/Core/TokenSystemValidator.swift`.
- **Content edits:** none.
- **Promotions:** N/A (deletion).
- **Consumer ripple:** zero — verified dead by grep before commit.
- **Package.swift edit:** none.
- **Public-API impact:** removes `TextSystem` protocol, `TextSystemStyler<Interface>`, `ThreePhaseTextSystemStyler<Interface>`, `TokenSystemValidator<Interface>` from `CodeEditorPlugin`'s public surface. First Bucket-level public-API removal in the §6.2.12 prep series.

### Commit 5: `Split AsyncOperationErrors: delete CompletionAsyncError, relocate ErrorRecoveryCoordinator (§6.2.12c prep)`

- **Operation, in order:**
  1. Edit `Sources/CodeEditorPlugin/Core/AsyncOperationErrors.swift`: delete the `CompletionAsyncError` enum block (lines ~10–151).
  2. Edit the remaining `ErrorRecoveryCoordinator` block: swap line 258 `throw lastError ?? SyntaxHighlightingError.cancelled` → `throw lastError ?? CancellationError()`. Remove `import CodeEditorLanguages` and `import CodeEditorSyntaxHighlighting` (now unused).
  3. `git mv Sources/CodeEditorPlugin/Core/AsyncOperationErrors.swift Sources/CodeEditorCommon/ErrorRecoveryCoordinator.swift`.
  4. Strip the file's leading `// RecoverableAsyncError... live in CodeEditorCommon...` comment (the comment is `Core/`-era residual; types now sit in the same target as the comment's referenced types).
- **Promotions:** 0 (`ErrorRecoveryCoordinator`, `RecoveryTask`, `recover(from:operation:)` already `public`/`internal`-appropriate).
- **Consumer ripple:** zero new imports. The three callers already `import CodeEditorCommon`.
- **Package.swift edit:** none.
- **Public-API impact:** removes `CompletionAsyncError` from `CodeEditorPlugin`'s public surface. `ErrorRecoveryCoordinator` becomes a `CodeEditorCommon` public type (was umbrella-public; consumers doing `import CodeEditorPlugin` keep access via Common's existence as an umbrella transitive dep, but external consumers may need an explicit `import CodeEditorCommon` to see the type — flag in NEXT.md as a soft surface relocation).

### Commit 6: `Document §6.2.12c Core/ prep v3 in NEXT.md and CLAUDE.md`

NEXT.md updates (§5 of this spec) + CLAUDE.md line-count updates. No source changes.

### Verification per commit

Per the user-memory note "skip full `swift test --parallel` after additive-only steps; trust the build and run targeted tests instead", the gate for each per-relocation/deletion commit is `swift build && swiftlint --fix && swiftlint` plus targeted tests scoped to the affected surface. The end-of-chunk gate (before Commit 6) runs the full test suite once:

| Commit | Build gate | Test gate | Lint gate |
|---|---|---|---|
| 1: SelectionState | `swift build` | `swift test --filter SelectionState` + `--filter EditorState` + `--filter EditorStatusBar` | `swiftlint --fix && swiftlint` |
| 2: EditorInteractionState | `swift build` | `swift test --filter EditorInteractionState` + `--filter EditorDocument` + `--filter CodeEditorIntent` + `--filter ModifierChainComposition` | `swiftlint --fix && swiftlint` |
| 3: DirtyTracker | `swift build` | `swift test --filter Coordinator` | `swiftlint --fix && swiftlint` |
| 4: TextSystem cluster delete | `swift build` | (no targeted tests; dead-code deletion) | `swiftlint --fix && swiftlint` |
| 5: AsyncOperationErrors split | `swift build` | `swift test --filter ErrorRecovery` + `--filter ActorCoordinator` | `swiftlint --fix && swiftlint` |
| End-of-chunk | `swift build` | **full** `swift test --parallel` | `swiftlint --fix && swiftlint` |

If end-of-chunk reveals a regression, fix in a new commit (per the `feedback_fix_pre_existing_failures` memory: "if the fix is a one-line stale-reference, just fix it"), not a `--amend`.

---

## 4. Aggregate surface

| Metric | Count |
|---|---|
| Files moved | 4 (`SelectionState`, `EditorInteractionState`, `DirtyTracker`, `ErrorRecoveryCoordinator`-from-`AsyncOperationErrors`) |
| Files deleted | 5 (`TextSystem`, `TextSystemStyler`, `ThreePhaseTextSystemStyler`, `TokenSystemValidator`, `AsyncOperationErrors`) |
| Access-modifier promotions | 4 (`DirtyTracker` struct + 3 methods) |
| New SPM targets | 0 |
| Productization changes | 0 |
| New SPM target deps | 1 (`CodeEditorUITests` gains `CodeEditorCommon`) |
| New explicit `import` lines added | ~5 (Commit 1) + 0–5 (Commit 2, plan-time verify) + 0 (Commit 3) + 0 (Commit 4) + 0 (Commit 5) ≈ 5–10 total |
| Public API removed | 5 types — `TextSystem`, `TextSystemStyler`, `ThreePhaseTextSystemStyler`, `TokenSystemValidator`, `CompletionAsyncError` |
| Public API relocated | 1 type — `ErrorRecoveryCoordinator` (umbrella → `CodeEditorCommon`) |
| `Core/` file delta | 126 → 118 (-8, -6.3%) |
| `CodeEditorCommon/` file delta | +4 (`SelectionState`, `EditorInteractionState`, `DirtyTracker`, `ErrorRecoveryCoordinator`) |
| `Sources/CodeEditorPlugin/` total delta | -8 (4 moves + 5 deletions, all out of the umbrella source tree; one of those files reincarnates in `CodeEditorCommon/` but that's a sibling source tree) |

---

## 5. NEXT.md / CLAUDE.md updates

### NEXT.md edits

1. **§6.0 status header** — append §6.2.12c to the "phase 7 carved out" sentence: replace "§6.2.12a / §6.2.12b Core/ prep extractions" with "§6.2.12a / §6.2.12b / §6.2.12c Core/ prep extractions."

2. **§6.0 status table** — add new row beneath the existing §6.2.12b row:

   > `§6.2.12c Core/ prep` | `<c1>`, `<c2>`, `<c3>`, `<c4>`, `<c5>` | 3 files relocated from umbrella `Core/` to `CodeEditorCommon/` (`SelectionState`, `EditorInteractionState`, `DirtyTracker`). 1 file split: `CompletionAsyncError` deleted (dead public enum), `ErrorRecoveryCoordinator` relocated to `CodeEditorCommon/ErrorRecoveryCoordinator.swift`, `AsyncOperationErrors.swift` deleted. 4-file `TextSystem` dead-code cluster deleted (`TextSystem`, `TextSystemStyler`, `ThreePhaseTextSystemStyler`, `TokenSystemValidator`). 4 access-modifier promotions (`DirtyTracker` struct + 3 methods). 1 Package.swift edit (`CodeEditorUITests` gains `CodeEditorCommon` dep). Core/ shrinks 126 → 118 (-8, -6.3%). First §6.2.12-prep round with public-API removals (5 types). See §6.2.12c deviation block. | (no new target)

3. **§6.0 deviations during §6.2.12c block** (new sibling block to the §6.2.12a / §6.2.12b ones). Skeleton — body filled in post-execution:
   - Spec / plan / execution count: 9 spec files (4 move + 5 delete) / 9 plan / actual.
   - All 3 Bucket A moves zero-touch (modulo `DirtyTracker`'s 4 promotions).
   - All 4 Bucket B deletions confirmed dead via in-tree grep.
   - Bucket C split: `CompletionAsyncError` deleted (zero callers); `ErrorRecoveryCoordinator` relocated with `CancellationError()` swap.
   - Promotion surface: 4. Smaller than §6.2.12a (4 on `TextLayoutFragment`); ties §6.2.12a's count.
   - Productization unchanged.
   - **First public-API removal round in the §6.2.12 prep series** — 5 types removed.
   - Consumer ripple counts per commit (per `git log -1 --stat`).
   - No new test targets (per-target test split still deferred to §6.2.15).
   - **`ErrorRecoveryCoordinator` location change is a soft public-API relocation.** External consumers doing `import CodeEditorPlugin` continue to see the type transitively; consumers that explicitly named the umbrella module in their code path may need to add `import CodeEditorCommon`. Document in `What Will Go Wrong`.

4. **§6.2.12a F3 sub-bucket audit table** — no edits. None of the moving/deleted files appear in that table; they are all root files.

5. **§6.2.12a root-file triage table** — update rows:
   - `SelectionState.swift`: Bucket 3 (Defer) → Bucket 2: Move (zero-touch); target `CodeEditorCommon/`; "Moved in `<c1>` (§6.2.12c)."
   - `EditorInteractionState.swift`: Bucket 3 (Defer) → Bucket 2: Move (zero-touch); target `CodeEditorCommon/`; "Moved in `<c2>` (§6.2.12c)."
   - `DirtyTracker.swift`: Bucket 3 (Defer) → Bucket 2: Move (cheap-break — 4 `internal → public` promotions); target `CodeEditorCommon/`; "Moved in `<c3>` (§6.2.12c)."
   - `AsyncOperationErrors.swift`: Bucket 3 (Defer) → Deleted (`ErrorRecoveryCoordinator` relocated to `CodeEditorCommon/`); target row noted as split-and-deleted in `<c5>` (§6.2.12c).
   - **Five new rows** (or appended note) for the deleted dead-code cluster: `TextSystem.swift`, `TextSystemStyler.swift`, `ThreePhaseTextSystemStyler.swift`, `TokenSystemValidator.swift` — each Bucket 4 (Deleted) per §6.2.12c. (Author's call whether to expand the table or just note in the summary; recommend a single appended summary line per dead-code cluster to avoid table bloat.)

6. **§6.2.12a root-file triage table summary line** — update from "65 root files audited at §6.2.12a start; 2 moved (§6.2.12a); 3 moved (§6.2.12b); 60 remain. Of the 60: 29 Bucket 1 Stay; 31 Bucket 3 Defer to §6.2.12." to: "65 root files audited at §6.2.12a start; 2 moved (§6.2.12a); 3 moved (§6.2.12b); 4 moved + 5 deleted (§6.2.12c); 51 remain. Of the 51: 29 Bucket 1 Stay; 22 Bucket 3 Defer to §6.2.12."

7. **§10 first bullet ("6.2.12 split Core/")** — update Core/ file count and Bucket 3 count: "126 files post-§6.2.12b" → "118 files post-§6.2.12c (down from 138; §6.2.12a removed 9, §6.2.12b removed 3, §6.2.12c removed 9 = 5 deletions + 4 relocations)." Update Bucket 3 Defer count from 31 to 22.

8. **§10 architectural questions 1 & 3** — unchanged (F3 glue policy + ToolbarItem stay deferred to §6.2.12 main).

### CLAUDE.md edits

1. **Source-tree line counts.** Currently reads "222 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.11 / §6.2.12a / §6.2.12b)". Update "222" → "214" and append "/ §6.2.12c".

2. **`CodeEditorCommon` description.** Currently: "utilities, models, extensions, errors, `RecoverableAsyncError`+`RecoveryStrategy`+`BackoffStrategy` infra (phase 0; expanded in §6.2.7); `SendablePerformanceMetric` + `FileChangeNotification` (added §6.2.12b)." Append: "+ `SelectionState` + `EditorInteractionState` + `EditorCursorPosition` + `DirtyTracker` + `ErrorRecoveryCoordinator` (added §6.2.12c)."

3. **"What Will Go Wrong" entry** — add a one-line note about the soft API relocation:

   > **`ErrorRecoveryCoordinator` is now in `CodeEditorCommon`**: previously umbrella-public, relocated in §6.2.12c. External consumers that explicitly `import CodeEditorPlugin` continue to see it via the umbrella's transitive dep on `CodeEditorCommon`; consumers that need direct access should `import CodeEditorCommon`. `CompletionAsyncError` was removed entirely (zero in-tree callers; matches §6.2.9a Debugger and §6.2.8d `selectMatch` deletion precedents).

### No other docs touched

- No `docs/Diagrams/` updates (file moves + dead-code deletions, no type renames or new architectural shapes).
- No `docs/superpowers/specs/` archival.
- No `docs/archive/` movement.

---

## 6. Risks & non-risks

### Risks

1. **Bucket B is a public-API removal.** `TextSystem`, `TextSystemStyler`, `ThreePhaseTextSystemStyler`, `TokenSystemValidator` are all `public`. In-tree audit is conclusive (zero conformers, zero callers), but external consumers depending on these break. Mitigation: matches §6.2.9a Debugger precedent. Document removal explicitly in NEXT.md §6.2.12c deviations block and CLAUDE.md "What Will Go Wrong."
2. **Bucket C `CompletionAsyncError` removal.** Same public-API caveat. Zero in-tree callers verified.
3. **`ErrorRecoveryCoordinator`'s error-semantics tweak.** The line-258 swap from `SyntaxHighlightingError.cancelled` to `CancellationError()` changes the thrown type in the practically-unreachable "all retries failed with no captured error" path. Callers pattern-matching on `SyntaxHighlightingError` would break, but inspection shows the three in-tree callers don't pattern-match (they propagate via `try await`). Document in commit message.
4. **Bare-word grep miss (§6.2.8e lesson).** During plan-writing, run bare-word grep for each moved/deleted symbol across `Sources/` + `Tests/` + `Scripts/`:
   - `\bSelectionState\b`, `\bEditorInteractionState\b`, `\bEditorCursorPosition\b`, `\bDirtyTracker\b`
   - `\bTextSystem\b`, `\bTextSystemStyler\b`, `\bThreePhaseTextSystemStyler\b`, `\bTokenSystemValidator\b`
   - `\bCompletionAsyncError\b`, `\bErrorRecoveryCoordinator\b`

   Doc-comment-only matches don't need imports (per §6.2.8d / §6.2.8f precedent). Scripts/ scan catches any tooling that touches these symbols (unlikely).
5. **`ReviewRemediationRegressionTests` stale path strings.** §6.2.8e and §6.2.12a both repaired pre-existing stale-path assertions as collateral cleanup. Pre-flight, grep `Tests/CodeEditorPluginTests/` for the literal path strings `Sources/CodeEditorPlugin/Core/SelectionState.swift`, `Sources/CodeEditorPlugin/Core/EditorInteractionState.swift`, `Sources/CodeEditorPlugin/Core/DirtyTracker.swift`, `Sources/CodeEditorPlugin/Core/TextSystem.swift` (and the 3 styler/validator files), `Sources/CodeEditorPlugin/Core/AsyncOperationErrors.swift`. If any test asserts on these paths, update in the same commit as the move/delete.
6. **`SelectionState` and `EditorInteractionState` cross-module `Codable` conformances.** Both conform to `Codable`. Synthesis is per-module; moving the file shouldn't change conformance behavior. If any consumer encodes/decodes in a way that pins to module name (rare), it surfaces as a test failure during the end-of-chunk full test run.
7. **`@testable import CodeEditorPlugin` defensive retention (§6.2.8d lesson).** Do **not** blanket-drop `@testable import CodeEditorPlugin` from any test gaining a new explicit `import CodeEditorCommon`. Add the new import alongside the existing `@testable`; verify each test's reachability before pruning.
8. **TabModel-style broken-rename-commit risk (§6.2.12b lesson).** Stage destination paths first to avoid `git add` short-circuiting on removed source paths. Specifically for Commit 5 (the `AsyncOperationErrors` split), do the edits before the `git mv` so the destination file exists with finalized content before staging.

### Non-risks

- No new SPM targets → no scaffolding-placeholder dance (`.gitkeep` + `_ScaffoldPlaceholder.swift` lesson from §6.2.8f does not apply).
- No productization changes → no consumer opt-in/opt-out decisions.
- No diagram updates needed.
- `DirtyTracker`'s 4 promotions don't break any consumer — the single consumer doesn't reach the symbol via `@testable` (uses regular `import`).
- No `@MainActor` / Sendable cross-target gotchas (all moving types are `Sendable` value types or already-cross-target-tested types).

---

## 7. Open questions / non-decisions

This section is short — most of the design space was forced by the dep graph or the grep audit.

1. **`DirtyTracker` placement: Common vs. TextModel.** Both are valid. Going with Common because the type is pure-Foundation and has no TextKit2 surface (it's a string-baseline diff, not a layout-aware tracker). Common's existing role as the home for value-type primitives (`SourcePosition`, `SendableTypes`, `SelectionState` post-this-spec) is the natural fit. Counter-argument: `TextModel` houses other "dirty"-adjacent infra (e.g., paragraph-cache invalidation). Rejected because `DirtyTracker` doesn't touch any of that — it's a string-comparison utility.
2. **`AsyncOperationErrors.swift` whole-file delete vs. emptied-file delete.** Going with whole-file `git rm` in Commit 5 (after extracting `ErrorRecoveryCoordinator` to its new home). Alternative: leave the file with just `ErrorRecoveryCoordinator` and rename it. Rejected because (a) `ErrorRecoveryCoordinator` is a single type, and (b) the file's original name no longer reflects its contents post-`CompletionAsyncError`-deletion. A focused per-type file name (`ErrorRecoveryCoordinator.swift`) is cleaner.
3. **Bucket B granularity: one commit vs. four.** Going with one commit (all four dead files in one `git rm`). Alternative: per-file deletion commits. Rejected because (a) the four files form a single cluster (the protocol + its three generic conformers), (b) there's no bisect value to splitting them, and (c) `git log --stat` will show the deletion clearly.
4. **Per-target tests not split.** All test files stay in `CodeEditorPluginTests` / `CodeEditorUITests` with new imports added alongside existing `@testable import CodeEditorPlugin`. The per-target test split remains deferred to §6.2.15.
5. **`ErrorRecoveryCoordinator`'s actor-isolation semantics.** Currently `@available(macOS 13.0, iOS 16.0, *) public actor ErrorRecoveryCoordinator`. The version gate is no longer load-bearing (CLAUDE.md says the platform floor is macOS 26.3 / iOS 26.3, both well above the gate). Strictly out of scope for §6.2.12c; flag for cleanup in §6.2.12 main or a future cleanup pass.

---

## 8. After this chunk

§6.2.12c brings Core/ to 118 files (down from 138 at the start of §6.2.12). The next chunk is one of:

- **§6.2.12 main Core/ split** — the originally-planned single big move. With Core/ trimmed by 16% across three prep rounds, the remaining 22 Bucket 3 Defer root files + ~30 F3 sub-bucket files are the focus. NEXT.md §10's two open architectural questions (F3 glue-file policy + `ToolbarItem` routing) answer in that session.
- **§6.2.12d further prep** if any newly-isolated movable cohorts emerge (the §6.2.12a → §6.2.12b → §6.2.12c pattern has so far revealed 12 movables across 3 rounds from an audit that initially flagged only 9; further re-audit may surface more).
- **§6.2.13 `CodeEditorSwiftUI`** if the user prefers to skip ahead — `SwiftUI/` (19 files) is reportedly "straightforward after 6.2.12" and may be cleanly extractable without waiting for the Core/ split if the SwiftUI surface doesn't structurally reach umbrella-only types.

The recommended next step remains §6.2.12 main per NEXT.md §10, but the door is open.
