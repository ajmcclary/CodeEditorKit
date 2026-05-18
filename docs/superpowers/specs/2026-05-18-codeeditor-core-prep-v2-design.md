# §6.2.12b Core/ prep v2 — design

**Date:** 2026-05-18
**Status:** Spec, awaiting plan
**Predecessor:** [`2026-05-18-codeeditor-core-prep-design.md`](2026-05-18-codeeditor-core-prep-design.md) (§6.2.12a, landed `d129070` / `7f498a8` / `f3b89fc` / `280b82e`)
**Next:** §6.2.12 main Core/ split (the riskiest single move in the restructure series)

---

## 1. Goal & shape

§6.2.12b is a Core/ prep round that extends §6.2.12a: **3 zero/cheap-touch file moves out of umbrella `Core/` into existing sibling SPM targets**, three commits, each green on `swift build && swift test`.

- No new SPM targets.
- No productization changes.
- No public-API removals from the umbrella.
- After this round, umbrella `Core/` shrinks **129 → 126** (-3, -2.3%); umbrella total shrinks **223 → 220** (-1.3%).
- The §6.2.12a audit table gains 3 row updates (Bucket 3 "Defer / re-audit" → "Moved").
- The two §10 architectural questions (F3 glue policy, `ToolbarItem` routing) stay **deferred to §6.2.12 main**.

This chunk is the §6.2.12a author's stated priority worklist: NEXT.md §10 explicitly flagged `LanguageDetectionService`, `SendableTypes`, and `TabModel` as "possible Move candidates" needing re-audit. The re-audit confirms all three are Move-eligible to existing sibling targets — no carve-outs, no nested-type extractions, no marker-protocol gymnastics.

---

## 2. Per-file dispositions

| File | LOC | Current | Move target | `CodeEditorView` refs | Internal deps (post-move) | Disposition |
|---|---|---|---|---|---|---|
| `SendableTypes.swift` | 42 | `Sources/CodeEditorPlugin/Core/` | `Sources/CodeEditorCommon/` | 0 | Foundation only | Move (zero-touch) |
| `TabModel.swift` | 42 | `Sources/CodeEditorPlugin/Core/` | `Sources/CodeEditorPlugin/Languages/` | 0 | `CodeEditorLanguages` (same-target post-move; stores `Language?`) | Move (zero-touch) |
| `LanguageDetectionService.swift` | 433 | `Sources/CodeEditorPlugin/Core/` | `Sources/CodeEditorPlugin/Languages/` | 0 | `CodeEditorCommon`, `CodeEditorLanguages` (`Language` enum is same-target post-move) | Move (cheap-break — drop `import CodeEditorLanguages` line) |

Forced-disposition note: the three moves are forced by the dep graph because (a) all three files are zero-`CodeEditorView`-coupled, (b) each has a viable upstream sibling target whose existing deps already cover the file's import list, and (c) no file splits in two (no carve-out). There is no meaningful branching point on file→target placement.

Per-file rationale:

- **`SendableTypes.swift` → `CodeEditorCommon`.** Both types (`SendablePerformanceMetric`, `FileChangeNotification`) are `public Sendable` structs, Foundation-only. Three umbrella consumers (`ActorCoordinator.swift`, `Actors/PerformanceMetricsActor.swift`, `Actors/FileSystemActor.swift`) all already transitively depend on `CodeEditorCommon`; the explicit `import CodeEditorCommon` may need adding to each (verify pre-flight). Cleanest sibling-target placement.
- **`TabModel.swift` → `CodeEditorLanguages`.** Mirrors §6.2.12a's `BreadcrumbComponent → CodeEditorSymbols` precedent: host-owned UI model whose natural home is the sibling target whose type it stores (`Language?`). Already imports `CodeEditorLanguages`; that import line becomes redundant after the move and is removed.
- **`LanguageDetectionService.swift` → `CodeEditorLanguages`.** Service for detecting `Language` from file extension/path/filename/content. Co-locating with `Language` and `LanguageDescriptor` is the natural fit. Imports `CodeEditorCommon` (for `CrossPlatformLogger`) + `CodeEditorLanguages` (`Language`, `LanguageInfo`). The `Languages` target already depends on `Common`, so the cross-target dep is satisfied. Already imports `CodeEditorLanguages` — that line gets removed after the move. The doc-comment reference in `Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift` (line 24) becomes a same-target reference, slightly cleaner.

---

## 3. Carry-set details & access-modifier promotions

Three commits, smallest first.

### Commit 1: `SendableTypes.swift → CodeEditorCommon`

- **Operation:** `git mv Sources/CodeEditorPlugin/Core/SendableTypes.swift Sources/CodeEditorCommon/`
- **Content edits:** none (Foundation-only file).
- **Access-modifier promotions:** 0. `SendablePerformanceMetric`, `FileChangeNotification`, and `FileChangeNotification.ChangeType` are already `public Sendable`, with `public init`s and `public` stored members.
- **Consumer ripple (verify each has `import CodeEditorCommon`; add if missing):**
  - `Sources/CodeEditorPlugin/Core/ActorCoordinator.swift`
  - `Sources/CodeEditorPlugin/Core/Actors/PerformanceMetricsActor.swift`
  - `Sources/CodeEditorPlugin/Core/Actors/FileSystemActor.swift`
- **Test-file ripple:** none. No tests directly reference `SendablePerformanceMetric` or `FileChangeNotification`.
- **Package.swift:** no change. Umbrella already depends on `CodeEditorCommon`.

### Commit 2: `TabModel.swift → CodeEditorLanguages`

- **Operation:** `git mv Sources/CodeEditorPlugin/Core/TabModel.swift Sources/CodeEditorPlugin/Languages/`
- **Content edits:** remove the now-redundant `import CodeEditorLanguages` line (becomes same-target after move).
- **Access-modifier promotions:** 0. `TabModel` is already `public struct` with `public let id`, `public var name/url/language/isDirty`, `public init`.
- **Consumer ripple (verify each has `import CodeEditorLanguages`; add if missing):**
  - Umbrella (4 files): `Core/EditorState.swift`, `Core/Documents/EditorDocument.swift`, `Core/Documents/EditorDocuments.swift`, `SwiftUI/EditorController.swift`
  - `CodeEditorUI` target (3 files): `TabStrip/EditorTabStrip.swift`, `TabStrip/EditorTabStripStyle.swift`, `TabStrip/EditorTab.swift`
  - Tests (5 files): `Tests/CodeEditorPluginTests/Core/EditorStateConformanceTests.swift`, `Core/EditorStateTests.swift`, `Documents/EditorDocumentsBindingTests.swift`, `Tests/CodeEditorUITests/StyleProtocolTests.swift`, `Snapshots/EditorTabStripSnapshots.swift`
  - Sample `README.md` doc-only — no import needed.
- **Package.swift edit:** **`CodeEditorUITests` target gains `CodeEditorLanguages` as a direct dep.** `CodeEditorUI` itself already has `CodeEditorLanguages` (Package.swift line 281, post-§6.2.6 / pre-§6.2.12b). `CodeEditorSample`, `CodeEditorPluginTests`, `CodeEditorSampleTests` also already have it. Only `CodeEditorUITests` is missing it. Matches §6.2.12a's `BreadcrumbComponent` Package.swift footprint but narrower (§6.2.12a added the dep to 2 targets; §6.2.12b only adds to 1).

### Commit 3: `LanguageDetectionService.swift → CodeEditorLanguages`

- **Operation:** `git mv Sources/CodeEditorPlugin/Core/LanguageDetectionService.swift Sources/CodeEditorPlugin/Languages/`
- **Content edits:** remove the now-redundant `import CodeEditorLanguages` line (becomes same-target after move).
- **Access-modifier promotions:** 0. `LanguageDetectionService` is `@MainActor public final class`, with `public init()`, all public methods used by consumers (`detectLanguage(fromExtension:)`, `detectLanguage(fromPath:)`, `detectLanguage(fromFilename:)`, `detectLanguage(fromContent:)`, `getAllSupportedExtensions()`, `isExtensionSupported(_:)`, `getLanguageInfo(for:)`, `validateLanguageChange(from:to:)`, `clearCache()`, `clearContentCache()`). `LanguageInfo` and `LanguageChangeValidation` co-resident in the file are already `public`. Internal state (caches, logger, helper methods) stays `private`.
- **Consumer ripple (verify each has `import CodeEditorLanguages`; add if missing):**
  - Umbrella (1 file): `Core/EditorRuntime.swift`
  - Sibling target (1 file): `Languages/LanguageDescriptor.swift` — doc-comment-only reference (line 24); becomes same-target after move, no import edit.
  - Sample (1 file): `Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift`
  - Tests (2 files): `Tests/CodeEditorPluginTests/LanguageDetectionTests.swift`, `Tests/CodeEditorPluginTests/SyntaxHighlightingTests.swift`
- **Package.swift:** no change. All consumer targets already depend on `CodeEditorLanguages` post-§6.2.6.

### Aggregate surface across all 3 commits

| Metric | Count |
|---|---|
| Files moved | 3 |
| Access-modifier promotions | 0 (smallest in the carve-out series; ties §6.2.8d Search / §6.2.8e Annotations / §6.2.8f Workspace) |
| New SPM target deps | 1 target (`CodeEditorUITests` gains `CodeEditorLanguages`; `CodeEditorUI` itself already has the dep post-§6.2.6) |
| New explicit `import` lines added | ~10–14 source/test files (3 in Commit 1, 7–10 in Commit 2, 3–4 in Commit 3) |
| Public API removed | 0 |
| New SPM targets | 0 |
| Productization changes | 0 |
| Core/ file delta | 129 → 126 (-3, -2.3%) |
| Umbrella file delta | 223 → 220 (-1.3%) |

---

## 4. Verification & risks

### Per-commit verification

Matches §6.2.12a precedent — `swift build` mandatory; targeted tests sufficient per the "skip full `swift test --parallel` after additive-only steps" rule from memory; SwiftLint strict-mode gate before commit.

| Commit | Build gate | Test gate | Lint gate |
|---|---|---|---|
| 1: SendableTypes | `swift build` | `swift test --filter Actor` | `swiftlint --fix && swiftlint` |
| 2: TabModel | `swift build` | `swift test --filter EditorState` + `swift test --filter EditorTabStrip` + `swift test --filter EditorDocumentsBinding` | `swiftlint --fix && swiftlint` |
| 3: LanguageDetectionService | `swift build` | `swift test --filter LanguageDetection` + `swift test --filter SyntaxHighlighting` | `swiftlint --fix && swiftlint` |

**End-of-chunk gate:** one full `swift build && swiftlint --fix && swiftlint && swift test --parallel` before pushing. Catches anything the per-commit targeted runs missed.

### Risks

1. **Bare-word grep miss (§6.2.8e lesson).** Compound-name grep can miss consumers. During plan-writing, run bare-word grep for each moved symbol across `Sources/` + `Tests/` + `Scripts/`:
   - `\bTabModel\b`
   - `\bLanguageDetectionService\b`
   - `\bSendablePerformanceMetric\b`
   - `\bFileChangeNotification\b`

   Doc-comment-only matches don't need imports (per §6.2.8d/§6.2.8f precedent).
2. **`CodeEditorUI` Package.swift dep addition.** Adding `CodeEditorLanguages` to `CodeEditorUI` is a Package.swift edit; SwiftLint's `sorted_imports` rule dictates where new `import CodeEditorLanguages` lands in each `.swift` file (per §6.2.9 surprise where `CodeEditorLSP` sorted after `CodeEditorLanguages` despite the plan-written ordering being wrong). Let SwiftLint `--fix` settle ordering; do not hand-order.
3. **Test-target `@testable` regression (§6.2.8d lesson).** Do **not** blanket-drop `@testable import CodeEditorPlugin` from any test gaining a new explicit `import CodeEditorLanguages` or `import CodeEditorCommon`. Add new imports alongside existing ones; keep `@testable` defensively. Several of the affected tests likely reach internal symbols (e.g. `LanguageDetectionTests` constructs `LanguageDetectionService` via its public init, which works without `@testable`, but adjacent tests in the same file may not).
4. **`ReviewRemediationRegressionTests` stale path strings.** §6.2.8e and §6.2.12a both repaired pre-existing stale-path assertions as collateral cleanup. Pre-flight, grep `Tests/CodeEditorPluginTests/` for the literal path strings `Sources/CodeEditorPlugin/Core/LanguageDetectionService.swift`, `Sources/CodeEditorPlugin/Core/SendableTypes.swift`, `Sources/CodeEditorPlugin/Core/TabModel.swift`. If any test asserts on these paths, update in the same commit as the move (don't leave them as a known-broken baseline).
5. **`LanguageDetectionService` is `@MainActor`.** Moving an actor-isolated public class across targets has not bitten any §6.2 step so far, but verify Swift 6 strict-concurrency build passes after Commit 3. The class has internal `private var` caches (`extensionCache`, `contentCache`) which stay private and `@MainActor`-isolated; no concurrency-surface change expected.
6. **`TabModel: Codable` cross-target.** `TabModel` conforms to `Codable`. Codable synthesis is per-module — moving the file shouldn't change conformance behavior. If any consumer encodes/decodes `TabModel` in a way that pins to the module name (rare, would require manual `decoder.userInfo` lookup), it would surface as a test failure. No known consumer does this; flagged for sanity-check during Commit 2 verification.

### Non-risks

- No access-modifier promotions → no surface area expansion.
- No public-API removals → no consumer migration outside this repo.
- No new SPM targets → no scaffolding placeholder dance (§6.2.8f's `.gitkeep` + `_ScaffoldPlaceholder.swift` lesson does not apply).
- No productization changes → no consumer opt-in/opt-out decisions.
- No diagram updates needed (file moves, not type renames or shape changes).

---

## 5. NEXT.md / CLAUDE.md updates

### NEXT.md edits

1. **§6.0 status header** — append §6.2.12b to the "phase 7 carved out" sentence: replace "§6.2.12a Core/ prep extraction" with "§6.2.12a / §6.2.12b Core/ prep extractions."

2. **§6.0 status table** — add new row beneath the existing §6.2.12a row:

   > `§6.2.12b Core/ prep` | `<commit-1>`, `<commit-2>`, `<commit-3>` | 3 files relocated from umbrella `Core/` to existing sibling SPM targets — 1 to CodeEditorCommon (`SendableTypes`); 2 to CodeEditorLanguages (`TabModel`, `LanguageDetectionService`). Zero new SPM targets. 0 access-modifier promotions. 1 Package.swift edit (`CodeEditorUITests` target gains `CodeEditorLanguages` dep; `CodeEditorUI` already had it post-§6.2.6). Core/ shrinks 129 → 126 (-3, -2.3%). Umbrella shrinks 223 → 220 (-1.3%). See §6.2.12b deviation block. | (no new target)

3. **§6.0 deviations during §6.2.12b block** (new sibling block to the existing §6.2.12a one). Skeleton — body filled in post-execution:
   - Spec / plan / execution count: 3 → 3 → 3 expected; record actual.
   - All 3 moves Move (zero-touch) per audit table.
   - Promotion surface: 0 (matches §6.2.8d Search / §6.2.8e Annotations / §6.2.8f Workspace).
   - Productization unchanged.
   - Consumer ripple counts per commit (per `git log -1 --stat`).
   - No public-API removals.
   - No new test targets (per-target test split still deferred to §6.2.15).

4. **§6.2.12a F3 sub-bucket audit table** — **no edits.** None of the 3 moving files appear in that table; they are root files, not F3-sub-bucketed files.

5. **§6.2.12a root-file triage table** — three rows flip from "Bucket 3 (Defer)" to "Moved" with target column populated. Specifically:

   > `LanguageDetectionService.swift` | Bucket 2: Move (zero-touch) | `CodeEditorLanguages/` | Moved in `<commit-3>` (§6.2.12b)
   >
   > `SendableTypes.swift` | Bucket 2: Move (zero-touch) | `CodeEditorCommon/` | Moved in `<commit-1>` (§6.2.12b)
   >
   > `TabModel.swift` | Bucket 2: Move (zero-touch) | `CodeEditorLanguages/` | Moved in `<commit-2>` (§6.2.12b)

   (Each previously sat in Bucket 3 Defer with a "flag for §6.2.12 re-audit" note.)

6. **§6.2.12a root-file triage table summary line** — update from "65 root files audited at §6.2.12a start; 2 moved (§6.2.12a); 63 remain. Of the 63: 29 Bucket 1 Stay; 34 Bucket 3 Defer to §6.2.12." to: "65 root files audited at §6.2.12a start; 2 moved (§6.2.12a); 3 moved (§6.2.12b); 60 remain. Of the 60: 29 Bucket 1 Stay; 31 Bucket 3 Defer to §6.2.12."

7. **§10 first bullet ("6.2.12 split Core/")** — strike the "(`LanguageDetectionService`, `SendableTypes`, `TabModel` flagged for re-audit)" clause from the final sentence (the re-audit is now complete). Replace with: "§6.2.12b moved the 3 §6.2.12a-flagged files; the priority worklist for the main split is now the remaining 31 Bucket 3 Defer files."

8. **§10 architectural questions 1 & 3** — unchanged (F3 glue policy + ToolbarItem stay deferred to §6.2.12 main).

### CLAUDE.md edits

1. **Source-tree line counts.** Currently reads "223 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.11 / §6.2.12a)". Update "223" → "220" and append "/ §6.2.12b".

2. **`CodeEditorCommon` description.** Currently: "utilities, models, extensions, errors, `RecoverableAsyncError`+`RecoveryStrategy`+`BackoffStrategy` infra (phase 0; expanded in §6.2.7)". Append: "+ `SendablePerformanceMetric` + `FileChangeNotification` (§6.2.12b)."

3. **`CodeEditorLanguages` description.** Currently: "language descriptors + folding/symbol/completion-model interfaces (phase 3; physically inside the umbrella source tree but compiled as its own target via `path:`)". Append: "+ `TabModel` + `LanguageDetectionService` (§6.2.12b)."

### No other docs touched

- No `docs/Diagrams/` updates (file moves, not type renames or shape changes).
- No `docs/superpowers/specs/` archival.
- No `docs/archive/` movement.

---

## 6. Open questions / non-decisions

This section is deliberately short — most of the design space was forced by the dep graph.

1. **`@MainActor` survives the move.** `LanguageDetectionService` stays `@MainActor`. There is no plan-time signal that any consumer needs it to lose actor isolation; if a strict-concurrency build error surfaces during Commit 3, treat it as a Languages-target Swift 6 issue (not a §6.2.12b scope creep) and address with the minimal concurrency annotation that compiles.
2. **Per-target tests not split.** All test files stay in `CodeEditorPluginTests` / `CodeEditorUITests` with new imports added alongside existing `@testable import CodeEditorPlugin`. The per-target test split remains deferred to §6.2.15.
3. **`TabModel` placement vs. `CodeEditorUI`.** A reasonable counter-argument exists for putting `TabModel` in `CodeEditorUI` since most consumers are UI/chrome. Rejected because (a) `CodeEditorUI` depends on the umbrella, so umbrella consumers like `EditorState` / `EditorDocument` / `EditorController` cannot reach types in `CodeEditorUI` without an inverted dep edge; (b) `TabModel` stores `Language?`, making `CodeEditorLanguages` the natural Common-Ancestor target; (c) the §6.2.12a `BreadcrumbComponent → CodeEditorSymbols` precedent established exactly this pattern.

---

## 7. After this chunk

§6.2.12b closes out the §6.2.12a-flagged re-audit list. The next chunk is **§6.2.12 main Core/ split** — the riskiest single step in the restructure series, with 31 Bucket 3 Defer root files + the remaining F3 sub-buckets to disposition. NEXT.md §10's two open architectural questions (F3 glue-file policy + `ToolbarItem` routing) will be answered in that session, not this one.
