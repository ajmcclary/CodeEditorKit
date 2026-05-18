# §6.2.12b Core/ prep v2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** [`docs/superpowers/specs/2026-05-18-codeeditor-core-prep-v2-design.md`](../specs/2026-05-18-codeeditor-core-prep-v2-design.md)

**Goal:** Move 3 zero-`CodeEditorView`-coupled files out of umbrella `Core/` into existing sibling SPM targets, in three independently revertible commits.

**Architecture:** Three `git mv` moves preceded by a pre-flight pass and followed by an end-of-chunk verification + a docs-update commit. Each commit leaves `swift build && swift test` green. Zero new SPM targets, zero access-modifier promotions, one Package.swift edit (`CodeEditorUITests` gains `CodeEditorLanguages` dep). Mirrors the §6.2.12a 4-commit pattern (`d129070` / `7f498a8` / `f3b89fc` / `280b82e`).

**Tech Stack:** Swift 6.3, SwiftPM, SwiftLint (strict mode), XCTest + Swift Testing.

---

## File Structure

This plan does **not** create or restructure files beyond renames. The 3 moves are pure `git mv` operations with minimal content edits.

**Files relocated:**

| From | To | Content edit |
|---|---|---|
| `Sources/CodeEditorPlugin/Core/SendableTypes.swift` | `Sources/CodeEditorCommon/SendableTypes.swift` | none |
| `Sources/CodeEditorPlugin/Core/TabModel.swift` | `Sources/CodeEditorPlugin/Languages/TabModel.swift` | remove now-redundant `import CodeEditorLanguages` line |
| `Sources/CodeEditorPlugin/Core/LanguageDetectionService.swift` | `Sources/CodeEditorPlugin/Languages/LanguageDetectionService.swift` | remove now-redundant `import CodeEditorLanguages` line |

**Files modified (import additions, edit per task):**

- Commit 1 consumers (1 file): `Sources/CodeEditorPlugin/Core/Actors/PerformanceMetricsActor.swift` (add `import CodeEditorCommon`).
- Commit 2 consumers (6 files): `Sources/CodeEditorUI/TabStrip/EditorTabStrip.swift`, `Sources/CodeEditorUI/TabStrip/EditorTabStripStyle.swift`, `Tests/CodeEditorPluginTests/Core/EditorStateConformanceTests.swift`, `Tests/CodeEditorPluginTests/Core/EditorStateTests.swift`, `Tests/CodeEditorPluginTests/Documents/EditorDocumentsBindingTests.swift`, `Tests/CodeEditorUITests/StyleProtocolTests.swift`, `Tests/CodeEditorUITests/Snapshots/EditorTabStripSnapshots.swift` (each adds `import CodeEditorLanguages`).
- Commit 2 Package.swift edit: `CodeEditorUITests` target gains `CodeEditorLanguages`.
- Commit 3 consumers: **0 net new imports** — every consumer already imports `CodeEditorLanguages`.

**Files modified (docs, Task 6):**

- `NEXT.md` — §6.0 header + status table + new deviations block + root-file triage table row flips + summary line + §10 first bullet.
- `CLAUDE.md` — source-tree count, Common bullet, Languages bullet.

---

## Task 1: Pre-flight checks

**Files:** none modified.

- [ ] **Step 1: Confirm clean working tree**

```bash
git status
```

Expected: `nothing to commit, working tree clean` on branch `main`. If anything is uncommitted, stop and surface to the user (per the no-stash rule from memory — reason from the diff, do not shuffle).

- [ ] **Step 2: Confirm starting commit**

```bash
git log -1 --oneline
```

Expected: `1deab763 Document §6.2.12a Core/ prep extraction in NEXT.md and CLAUDE.md` (or a descendant of it).

- [ ] **Step 3: Bare-word grep — verify consumer list matches spec**

Run each grep in `Sources/` and `Tests/`:

```bash
echo "=== SendableTypes ==="
grep -rln "\bSendablePerformanceMetric\b\|\bFileChangeNotification\b" Sources/ Tests/ | grep -v Core/SendableTypes.swift
echo "=== TabModel ==="
grep -rln "\bTabModel\b" Sources/ Tests/ | grep -v Core/TabModel.swift
echo "=== LanguageDetectionService ==="
grep -rln "\bLanguageDetectionService\b" Sources/ Tests/ | grep -v Core/LanguageDetectionService.swift
```

Expected consumer lists (record actual output; if a new consumer surfaces, add it to the relevant task's import-edit step):

- SendableTypes: `Core/ActorCoordinator.swift`, `Core/Actors/PerformanceMetricsActor.swift`, `Core/Actors/FileSystemActor.swift` (3 files).
- TabModel: `Core/EditorState.swift`, `Core/Documents/EditorDocument.swift`, `Core/Documents/EditorDocuments.swift`, `SwiftUI/EditorController.swift`, `Sources/CodeEditorUI/TabStrip/EditorTabStrip.swift`, `EditorTabStripStyle.swift`, `EditorTab.swift`, 5 test files (`EditorStateConformanceTests`, `EditorStateTests`, `EditorDocumentsBindingTests`, `StyleProtocolTests`, `EditorTabStripSnapshots`), plus `Sources/CodeEditorSample/README.md` (doc-only).
- LanguageDetectionService: `Core/EditorRuntime.swift`, `Languages/LanguageDescriptor.swift` (doc-comment only), `Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift`, `Tests/CodeEditorPluginTests/LanguageDetectionTests.swift`, `Tests/CodeEditorPluginTests/SyntaxHighlightingTests.swift` (5 files).

If the actual greps return a superset of these lists, that is fine — extend the import-edit steps in the relevant task. If they return a **subset** (i.e. a spec-listed consumer is missing), investigate before proceeding.

- [ ] **Step 4: Scan tests for stale-path assertions** (§6.2.8e / §6.2.12a precedent)

```bash
grep -rn "Sources/CodeEditorPlugin/Core/LanguageDetectionService.swift\|Sources/CodeEditorPlugin/Core/SendableTypes.swift\|Sources/CodeEditorPlugin/Core/TabModel.swift" Tests/
```

Expected: no matches. If a test asserts on any of these literal paths (e.g. `ReviewRemediationRegressionTests`), record the file and update the assertion in the same commit as the corresponding move.

- [ ] **Step 5: Baseline build**

```bash
swift build
```

Expected: `Build complete!` (no errors, no warnings introduced by this branch).

- [ ] **Step 6: Baseline lint**

```bash
swiftlint --fix && swiftlint
```

Expected: zero violations. If the baseline has lint violations, stop and surface to the user (do not silently inherit a dirty baseline).

- [ ] **Step 7: Baseline test (targeted)**

```bash
swift test --filter "LanguageDetection\|EditorState\|EditorTabStrip\|Actor\|EditorDocumentsBinding\|SyntaxHighlighting"
```

Expected: all tests pass. Record the test count; the same filter rerun at end-of-chunk (Task 5) must show ≥ this count, all passing.

---

## Task 2: Commit 1 — `SendableTypes.swift` → `CodeEditorCommon`

**Files:**
- Move: `Sources/CodeEditorPlugin/Core/SendableTypes.swift` → `Sources/CodeEditorCommon/SendableTypes.swift`
- Modify: `Sources/CodeEditorPlugin/Core/Actors/PerformanceMetricsActor.swift` (add `import CodeEditorCommon`)
- Verify (no edit expected): `Sources/CodeEditorPlugin/Core/ActorCoordinator.swift`, `Sources/CodeEditorPlugin/Core/Actors/FileSystemActor.swift`

- [ ] **Step 1: Verify destination directory exists**

```bash
ls Sources/CodeEditorCommon/ | head -5
```

Expected: directory listing (e.g. shows `Extensions/`, `Errors/`, etc.). If the directory does not exist, stop (this means §6.2.12a state is wrong).

- [ ] **Step 2: Move the file**

```bash
git mv Sources/CodeEditorPlugin/Core/SendableTypes.swift Sources/CodeEditorCommon/SendableTypes.swift
```

Expected: no output. `git status` shows: `renamed: Sources/CodeEditorPlugin/Core/SendableTypes.swift -> Sources/CodeEditorCommon/SendableTypes.swift`.

- [ ] **Step 3: Verify consumer imports**

```bash
grep -l "import CodeEditorCommon" Sources/CodeEditorPlugin/Core/ActorCoordinator.swift Sources/CodeEditorPlugin/Core/Actors/FileSystemActor.swift Sources/CodeEditorPlugin/Core/Actors/PerformanceMetricsActor.swift
```

Expected output (2 of 3):

```
Sources/CodeEditorPlugin/Core/ActorCoordinator.swift
Sources/CodeEditorPlugin/Core/Actors/FileSystemActor.swift
```

(`PerformanceMetricsActor.swift` is absent because it does not yet import `CodeEditorCommon`.)

- [ ] **Step 4: Add `import CodeEditorCommon` to `PerformanceMetricsActor.swift`**

Open `Sources/CodeEditorPlugin/Core/Actors/PerformanceMetricsActor.swift`. Current imports:

```swift
import Foundation
```

Edit to:

```swift
import CodeEditorCommon
import Foundation
```

(SwiftLint's `sorted_imports` puts `CodeEditorCommon` alphabetically before `Foundation`; do not hand-order beyond that — let `swiftlint --fix` settle anything ambiguous.)

- [ ] **Step 5: Build**

```bash
swift build
```

Expected: `Build complete!`. If the build fails with "cannot find type 'SendablePerformanceMetric'" in a file not in the spec's consumer list, that's a missed bare-word grep — add the import to that file before proceeding.

- [ ] **Step 6: Lint**

```bash
swiftlint --fix && swiftlint
```

Expected: zero violations.

- [ ] **Step 7: Run targeted tests**

```bash
swift test --filter Actor
```

Expected: all tests pass. Record count vs. baseline.

- [ ] **Step 8: Commit**

```bash
git add Sources/CodeEditorCommon/SendableTypes.swift Sources/CodeEditorPlugin/Core/SendableTypes.swift Sources/CodeEditorPlugin/Core/Actors/PerformanceMetricsActor.swift
git commit -m "$(cat <<'EOF'
Relocate SendableTypes to CodeEditorCommon (§6.2.12b prep)

Move Sources/CodeEditorPlugin/Core/SendableTypes.swift to
Sources/CodeEditorCommon/SendableTypes.swift. Foundation-only file
with two public Sendable structs (SendablePerformanceMetric,
FileChangeNotification). Zero CodeEditorView coupling; zero
access-modifier promotions.

PerformanceMetricsActor gains `import CodeEditorCommon` (the other
two consumers already had it).

Closes the first of three §6.2.12b moves.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: `[main <hash>] Relocate SendableTypes to CodeEditorCommon (§6.2.12b prep)`. `git status` reports clean.

---

## Task 3: Commit 2 — `TabModel.swift` → `CodeEditorLanguages`

**Files:**
- Move: `Sources/CodeEditorPlugin/Core/TabModel.swift` → `Sources/CodeEditorPlugin/Languages/TabModel.swift`
- Modify (content edit): `Sources/CodeEditorPlugin/Languages/TabModel.swift` (remove redundant `import CodeEditorLanguages`)
- Modify (Package.swift): `CodeEditorUITests` target gains `CodeEditorLanguages` dep
- Modify (import adds, 7 files): `Sources/CodeEditorUI/TabStrip/EditorTabStrip.swift`, `Sources/CodeEditorUI/TabStrip/EditorTabStripStyle.swift`, `Tests/CodeEditorPluginTests/Core/EditorStateConformanceTests.swift`, `Tests/CodeEditorPluginTests/Core/EditorStateTests.swift`, `Tests/CodeEditorPluginTests/Documents/EditorDocumentsBindingTests.swift`, `Tests/CodeEditorUITests/StyleProtocolTests.swift`, `Tests/CodeEditorUITests/Snapshots/EditorTabStripSnapshots.swift`
- Verify (no edit expected): `Sources/CodeEditorPlugin/Core/EditorState.swift`, `Sources/CodeEditorPlugin/Core/Documents/EditorDocument.swift`, `Sources/CodeEditorPlugin/Core/Documents/EditorDocuments.swift`, `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`, `Sources/CodeEditorUI/TabStrip/EditorTab.swift`

- [ ] **Step 1: Verify destination directory exists**

```bash
ls Sources/CodeEditorPlugin/Languages/ | head -5
```

Expected: directory listing (shows existing language descriptor files, etc.).

- [ ] **Step 2: Move the file**

```bash
git mv Sources/CodeEditorPlugin/Core/TabModel.swift Sources/CodeEditorPlugin/Languages/TabModel.swift
```

- [ ] **Step 3: Remove redundant import in the moved file**

Open `Sources/CodeEditorPlugin/Languages/TabModel.swift`. Current imports:

```swift
import CodeEditorLanguages
import Foundation
```

Edit to:

```swift
import Foundation
```

(`CodeEditorLanguages` is now same-target; the explicit import is invalid Swift and would fail compile.)

- [ ] **Step 4: Add `import CodeEditorLanguages` to consumer files**

For each of these 7 files, add `import CodeEditorLanguages` alphabetically into the import block. The exact insertion point varies per file but every file already has at least one other `import CodeEditor*` — slot the new import alongside in alphabetical order; SwiftLint's `sorted_imports` will correct anything that drifts.

1. `Sources/CodeEditorUI/TabStrip/EditorTabStrip.swift` — currently has `import CodeEditorPlugin`, `import SwiftUI`. Add `import CodeEditorLanguages` between them.
2. `Sources/CodeEditorUI/TabStrip/EditorTabStripStyle.swift` — currently has `import CodeEditorDesignTokens`, `import CodeEditorPlugin`, `import SwiftUI`. Add `import CodeEditorLanguages` between `CodeEditorDesignTokens` and `CodeEditorPlugin`.
3. `Tests/CodeEditorPluginTests/Core/EditorStateConformanceTests.swift` — currently has `import CodeEditorSymbols`, `import Foundation`, `import Testing`. Add `import CodeEditorLanguages` between `CodeEditorSymbols` and `Foundation`. Keep existing `@testable import CodeEditorPlugin` if present (it is — verify post-edit).
4. `Tests/CodeEditorPluginTests/Core/EditorStateTests.swift` — currently has `import CodeEditorSymbols`, `import Foundation`, `import Observation`, `import Testing`. Add `import CodeEditorLanguages` between `CodeEditorSymbols` and `Foundation`.
5. `Tests/CodeEditorPluginTests/Documents/EditorDocumentsBindingTests.swift` — currently has `import SwiftUI`, `import XCTest`. Add `import CodeEditorLanguages` before `SwiftUI`.
6. `Tests/CodeEditorUITests/StyleProtocolTests.swift` — currently has `import CodeEditorPlugin`, `import CodeEditorUI`, `import Foundation`, `import SwiftUI`, `import Testing`. Add `import CodeEditorLanguages` between `CodeEditorPlugin` and `CodeEditorUI` (SwiftLint will resort if needed; alphabetical order is `CodeEditorLanguages` < `CodeEditorPlugin` < `CodeEditorUI`, so it actually slots **before** `CodeEditorPlugin`).
7. `Tests/CodeEditorUITests/Snapshots/EditorTabStripSnapshots.swift` — currently has `import CodeEditorUI`, `import SnapshotTesting`, `import SwiftUI`, `import XCTest`. Add `import CodeEditorLanguages` before `CodeEditorUI`.

After all 7 edits, run `swiftlint --fix` once to settle ordering.

- [ ] **Step 5: Add `CodeEditorLanguages` to `CodeEditorUITests` target in Package.swift**

Open `Package.swift`. Find the `CodeEditorUITests` target (around line 357). Current dependencies block:

```swift
.testTarget(
    name: "CodeEditorUITests",
    dependencies: [
        "CodeEditorConfiguration",
        "CodeEditorSymbols",
        "CodeEditorUI",
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
    ],
    exclude: [
        "Snapshots/__Snapshots__"
    ],
    swiftSettings: swiftSettings
),
```

Edit `dependencies:` array to:

```swift
    dependencies: [
        "CodeEditorConfiguration",
        "CodeEditorLanguages",
        "CodeEditorSymbols",
        "CodeEditorUI",
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
    ],
```

(Insert `"CodeEditorLanguages",` in alphabetical order between `CodeEditorConfiguration` and `CodeEditorSymbols`.)

- [ ] **Step 6: Build**

```bash
swift build
```

Expected: `Build complete!`. If a consumer file is missing `import CodeEditorLanguages`, the failure message will name the unresolved type (likely `TabModel` or `Language`); add the import to that file and rerun.

- [ ] **Step 7: Lint**

```bash
swiftlint --fix && swiftlint
```

Expected: zero violations. The `--fix` pass will resort any imports that drifted from alphabetical order.

- [ ] **Step 8: Run targeted tests**

```bash
swift test --filter "EditorState\|EditorTabStrip\|EditorDocumentsBinding\|StyleProtocol"
```

Expected: all tests pass. Particular sanity check: `EditorTabStripSnapshots` should pass without re-recording (file move shouldn't change rendered output).

- [ ] **Step 9: Commit**

```bash
git add Package.swift Sources/CodeEditorPlugin/Core/TabModel.swift Sources/CodeEditorPlugin/Languages/TabModel.swift Sources/CodeEditorUI/TabStrip/EditorTabStrip.swift Sources/CodeEditorUI/TabStrip/EditorTabStripStyle.swift Tests/CodeEditorPluginTests/Core/EditorStateConformanceTests.swift Tests/CodeEditorPluginTests/Core/EditorStateTests.swift Tests/CodeEditorPluginTests/Documents/EditorDocumentsBindingTests.swift Tests/CodeEditorUITests/StyleProtocolTests.swift Tests/CodeEditorUITests/Snapshots/EditorTabStripSnapshots.swift
git commit -m "$(cat <<'EOF'
Relocate TabModel to CodeEditorLanguages (§6.2.12b prep)

Move Sources/CodeEditorPlugin/Core/TabModel.swift to
Sources/CodeEditorPlugin/Languages/TabModel.swift. Public host-owned
UI model storing Language?; lives in CodeEditorLanguages per the
§6.2.12a BreadcrumbComponent → CodeEditorSymbols precedent (host-owned
model whose natural home is the sibling target whose type it stores).

Zero CodeEditorView coupling; zero access-modifier promotions; the
moved file drops its now-redundant `import CodeEditorLanguages` line.
7 consumer files gain `import CodeEditorLanguages`. Package.swift
adds CodeEditorLanguages to CodeEditorUITests (CodeEditorUI itself
already had it post-§6.2.6).

Closes the second of three §6.2.12b moves.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: `[main <hash>] Relocate TabModel to CodeEditorLanguages (§6.2.12b prep)`. `git status` reports clean.

---

## Task 4: Commit 3 — `LanguageDetectionService.swift` → `CodeEditorLanguages`

**Files:**
- Move: `Sources/CodeEditorPlugin/Core/LanguageDetectionService.swift` → `Sources/CodeEditorPlugin/Languages/LanguageDetectionService.swift`
- Modify (content edit): `Sources/CodeEditorPlugin/Languages/LanguageDetectionService.swift` (remove redundant `import CodeEditorLanguages`)
- Verify (no edit expected): all 4 source/test consumers already import `CodeEditorLanguages`
- Verify (no edit expected): `Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift` doc-comment reference becomes same-target

- [ ] **Step 1: Move the file**

```bash
git mv Sources/CodeEditorPlugin/Core/LanguageDetectionService.swift Sources/CodeEditorPlugin/Languages/LanguageDetectionService.swift
```

- [ ] **Step 2: Remove redundant import in the moved file**

Open `Sources/CodeEditorPlugin/Languages/LanguageDetectionService.swift`. Current imports:

```swift
import CodeEditorCommon
import CodeEditorLanguages
import Foundation
```

Edit to:

```swift
import CodeEditorCommon
import Foundation
```

(`CodeEditorLanguages` is now same-target — the explicit import is invalid Swift and would fail compile.)

- [ ] **Step 3: Verify consumer imports**

All 4 of the structural consumers already import `CodeEditorLanguages` — no edits expected. Sanity-grep:

```bash
grep -l "import CodeEditorLanguages" Sources/CodeEditorPlugin/Core/EditorRuntime.swift Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift Tests/CodeEditorPluginTests/LanguageDetectionTests.swift Tests/CodeEditorPluginTests/SyntaxHighlightingTests.swift
```

Expected: all 4 file paths printed (i.e. all 4 already have the import). If any file is absent, add `import CodeEditorLanguages` to it in alphabetical order.

- [ ] **Step 4: Verify the `LanguageDescriptor` doc-comment ref still compiles**

`Languages/LanguageDescriptor.swift:24` has a doc-comment reference to `LanguageDetectionService`. After the move it becomes a same-target reference (no change required to the file). Sanity check:

```bash
grep -n "LanguageDetectionService" Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift
```

Expected: 1 match at line 24, in a `///` doc comment block.

- [ ] **Step 5: Build**

```bash
swift build
```

Expected: `Build complete!`.

- [ ] **Step 6: Lint**

```bash
swiftlint --fix && swiftlint
```

Expected: zero violations.

- [ ] **Step 7: Run targeted tests**

```bash
swift test --filter "LanguageDetection\|SyntaxHighlighting"
```

Expected: all tests pass. `LanguageDetectionTests` exercises the public API; pass without modification.

- [ ] **Step 8: Commit**

```bash
git add Sources/CodeEditorPlugin/Core/LanguageDetectionService.swift Sources/CodeEditorPlugin/Languages/LanguageDetectionService.swift
git commit -m "$(cat <<'EOF'
Relocate LanguageDetectionService to CodeEditorLanguages (§6.2.12b prep)

Move Sources/CodeEditorPlugin/Core/LanguageDetectionService.swift to
Sources/CodeEditorPlugin/Languages/LanguageDetectionService.swift.
@MainActor public final class that detects Language from file
extension/path/filename/content/shebang/modeline. Naturally co-locates
with Language and LanguageDescriptor.

Zero CodeEditorView coupling; zero access-modifier promotions; the
moved file drops its now-redundant `import CodeEditorLanguages` line.
All 4 structural consumers (EditorRuntime, EditorDocuments+SampleExtras,
LanguageDetectionTests, SyntaxHighlightingTests) already imported
CodeEditorLanguages — no consumer ripple. The doc-comment ref in
LanguageDescriptor becomes a same-target reference.

Closes the third and last §6.2.12b move.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: `[main <hash>] Relocate LanguageDetectionService to CodeEditorLanguages (§6.2.12b prep)`. `git status` reports clean.

---

## Task 5: End-of-chunk verification

**Files:** none modified.

- [ ] **Step 1: Full build**

```bash
swift build
```

Expected: `Build complete!`. Warnings on this branch should be zero.

- [ ] **Step 2: Full lint (strict)**

```bash
swiftlint --fix && swiftlint
```

Expected: zero violations (`.swiftlint.yml` has `strict: true` — any warning would have been an error).

- [ ] **Step 3: Full parallel test suite**

```bash
swift test --parallel
```

Expected: all tests pass. Per the memory rule, the per-task targeted runs were sufficient confidence to commit; this is the end-of-chunk gate to catch anything missed.

If any unexpected failures surface, do **not** mark Task 5 complete. Diagnose:
- Stale snapshot in `__Snapshots__/`? Inspect the diff; if file move caused a content-only change to a snapshot, that's a real regression — investigate, do not blindly re-record.
- Stale path string in `ReviewRemediationRegressionTests`? Same pattern as §6.2.8e / §6.2.12a — update the path string in the same commit (amend Commit 3, or add a follow-up commit).
- A consumer file missed by the bare-word grep? Add the import in a follow-up commit referencing the missed file.

- [ ] **Step 4: Verify file-count math**

```bash
echo "Core/ root files (expected: 60):"
find Sources/CodeEditorPlugin/Core -maxdepth 1 -name "*.swift" | wc -l
echo "Umbrella total (expected: 220):"
find Sources/CodeEditorPlugin -name "*.swift" | wc -l
```

Expected: Core/ = 60 (was 63 pre-§6.2.12b), umbrella = 220 (was 223). If the numbers differ, the §6.2.12a baseline assumption was wrong — record the actual numbers and use them in Task 6's NEXT.md / CLAUDE.md edits.

---

## Task 6: NEXT.md + CLAUDE.md updates

**Files:**
- Modify: `NEXT.md` (§6.0 status header, §6.0 status table, new §6.2.12b deviations block, §6.2.12a root-file triage table row flips, summary line, §10 first bullet)
- Modify: `CLAUDE.md` (source-tree line count, `CodeEditorCommon` bullet, `CodeEditorLanguages` bullet)

The current state of these documents was set in commit `1deab763` "Document §6.2.12a Core/ prep extraction in NEXT.md and CLAUDE.md". The §6.2.12b edits parallel that update.

- [ ] **Step 1: Capture the 3 commit hashes**

```bash
git log --oneline -4
```

Record the three §6.2.12b commit hashes (excluding the spec commit `84f56a5` and the predecessor `1deab763`):

- `<commit-1>` — Commit 1 (SendableTypes)
- `<commit-2>` — Commit 2 (TabModel)
- `<commit-3>` — Commit 3 (LanguageDetectionService)

Use the short-hash form (first 7 chars) in the markdown edits below, matching §6.2.12a's table convention.

- [ ] **Step 2: Edit `NEXT.md` §6.0 status header**

Find the existing line near the start of §6.0:

> **Phases 0–5 done; phase 7 carved out.** `CodeEditorDiagnostics` (§6.2.10) landed ...

The trailing sentence currently ends with: "and `§6.2.12a Core/ prep` extraction in NEXT.md and CLAUDE.md". Replace with: "and `§6.2.12a` / `§6.2.12b Core/ prep` extractions".

(If the exact phrasing in NEXT.md differs by a word from what's quoted above, preserve the surrounding context and just append `§6.2.12b` to the §6.2.12a reference.)

- [ ] **Step 3: Add a new row to the §6.0 status table**

Find the table row for §6.2.12a (`§6.2.12a Core/ prep`). Add the following row immediately below it:

```markdown
| `§6.2.12b Core/ prep` | `<commit-1>`, `<commit-2>`, `<commit-3>` | 3 files relocated from umbrella `Core/` to existing sibling SPM targets — 1 to CodeEditorCommon (`SendableTypes`); 2 to CodeEditorLanguages (`TabModel`, `LanguageDetectionService`). Zero new SPM targets. 0 access-modifier promotions. 1 Package.swift edit (`CodeEditorUITests` target gains `CodeEditorLanguages` dep; `CodeEditorUI` already had it post-§6.2.6). Core/ shrinks 129 → 126 (-3, -2.3%). Umbrella shrinks 223 → 220 (-1.3%). See §6.2.12b deviation block. | (no new target) |
```

Substitute the actual commit hashes from Step 1.

- [ ] **Step 4: Add a new "Deviations during §6.2.12b" block**

Locate the existing `**Deviations during §6.2.12a Core/ prep (commits ...):**` block (around line 446 of the current NEXT.md). Immediately **after** the §6.2.12a deviations block ends and **before** the `**§6.2.12a F3 sub-bucket audit table.**` heading, insert a new block:

```markdown
**Deviations during §6.2.12b `Core/` prep (commits `<commit-1>`, `<commit-2>`, `<commit-3>`):**

- **Spec / plan / execution count: 3 → 3 → 3.** No count drift. All 3 files in §6.2.12a's root-file triage table Bucket 3 ("flag for §6.2.12 re-audit") confirmed Move-eligible to existing sibling targets — `SendableTypes → CodeEditorCommon`, `TabModel → CodeEditorLanguages`, `LanguageDetectionService → CodeEditorLanguages`. Dispositions forced by the dep graph; no carve-out, no nested-type extraction.
- **Promotion surface: 0.** All 3 files already had `public` API surface used by every cross-target consumer. Ties §6.2.8d Search, §6.2.8e Annotations, §6.2.8f Workspace as the smallest promotion surface in the carve-out series.
- **Productization unchanged.** No new `.library` products.
- **Consumer ripple counts** (per commit `git log -1 --stat`):
  - **Commit 1 SendableTypes → Common (`<commit-1>`):** 0 umbrella files needed a new import (2 of 3 consumers already had `import CodeEditorCommon`). 1 umbrella file gained `import CodeEditorCommon` (`Core/Actors/PerformanceMetricsActor.swift`). Zero test ripples. Zero Package.swift edits.
  - **Commit 2 TabModel → Languages (`<commit-2>`):** 2 source files gained `import CodeEditorLanguages` (`Sources/CodeEditorUI/TabStrip/EditorTabStrip.swift`, `EditorTabStripStyle.swift`). 5 test files gained `import CodeEditorLanguages` (`EditorStateConformanceTests`, `EditorStateTests`, `EditorDocumentsBindingTests`, `StyleProtocolTests`, `EditorTabStripSnapshots`). 1 Package.swift edit (`CodeEditorUITests` gains `CodeEditorLanguages` dep). The moved file drops `import CodeEditorLanguages` (becomes same-target).
  - **Commit 3 LanguageDetectionService → Languages (`<commit-3>`):** Zero consumer-import additions — all 4 structural consumers (`EditorRuntime`, `EditorDocuments+SampleExtras`, `LanguageDetectionTests`, `SyntaxHighlightingTests`) already imported `CodeEditorLanguages`. The moved file drops `import CodeEditorLanguages`. Zero Package.swift edits.
- **No public-API removals from umbrella.** All previously-public umbrella surface compiles unchanged.
- **No new test targets.** Per-target test split remains deferred to §6.2.15.
- **`LanguageDescriptor` doc-comment reference becomes same-target.** The pre-existing `///` reference to `LanguageDetectionService` in `Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift:24` was cross-module before Commit 3 (technically a doc-comment lint nit) and becomes same-target after. Strictly cleanup.
- **Net Core/ file count drop:** 129 → 126 (-3, -2.3%). Umbrella total: 223 → 220 (-1.3%).
```

If any of the above bullets is inaccurate vs. what actually landed (e.g. an unexpected consumer surfaced, or a stale-path test was repaired), edit the bullet to match reality before committing. Do **not** leave drift between the deviations block and what `git log -1 --stat` shows.

- [ ] **Step 5: Flip 3 rows in the §6.2.12a root-file triage table**

Find the `**§6.2.12a root-file triage table.**` table. Three rows currently classified as Bucket 3 ("Defer") need to flip to "Bucket 2: Move (zero-touch)":

For `LanguageDetectionService.swift`, replace the current row with:

```markdown
| `LanguageDetectionService.swift` | Bucket 2: Move (zero-touch) | `CodeEditorLanguages/` | Moved in `<commit-3>` (§6.2.12b) |
```

For `SendableTypes.swift`:

```markdown
| `SendableTypes.swift` | Bucket 2: Move (zero-touch) | `CodeEditorCommon/` | Moved in `<commit-1>` (§6.2.12b) |
```

For `TabModel.swift`:

```markdown
| `TabModel.swift` | Bucket 2: Move (zero-touch) | `CodeEditorLanguages/` | Moved in `<commit-2>` (§6.2.12b) |
```

- [ ] **Step 6: Update the §6.2.12a root-file triage table summary line**

Find the existing summary line (currently): "Summary: 65 root files audited at §6.2.12a start (plan-time inventory under-counted by 1; the actual root count is 65, not the spec's 64); 2 moved (`EditorConfiguration+ApplyTextInputFeatures`, `BreadcrumbComponent`); 63 remain. Of the 63: 29 Bucket 1 Stay; 34 Bucket 3 Defer to §6.2.12."

Replace with:

> **Summary:** 65 root files audited at §6.2.12a start (plan-time inventory under-counted by 1; the actual root count is 65, not the spec's 64); 2 moved in §6.2.12a (`EditorConfiguration+ApplyTextInputFeatures`, `BreadcrumbComponent`); 3 moved in §6.2.12b (`SendableTypes`, `TabModel`, `LanguageDetectionService`); 60 remain. Of the 60: 29 Bucket 1 Stay; 31 Bucket 3 Defer to §6.2.12.

- [ ] **Step 7: Update §10's first bullet**

Find the `**6.2.12 split `Core/`**` bullet near the bottom of NEXT.md (in §10 "Suggested next session"). The bullet currently ends with "The §6.2.12a audit-table bucket-3 list (`LanguageDetectionService`, `SendableTypes`, `TabModel` flagged for re-audit) is the priority worklist for the main split."

Replace that sentence with:

> §6.2.12b moved the 3 §6.2.12a-flagged files (`LanguageDetectionService`, `SendableTypes`, `TabModel`); the priority worklist for the main split is now the remaining 31 Bucket 3 Defer files.

Also update the count earlier in the bullet: "The `Core/` dir is 129 files post-§6.2.12a (down from 138)" → "The `Core/` dir is 126 files post-§6.2.12b (down from 138)". And update the breakdown: "0 root-bucket-2 candidates remaining (both shipped in §6.2.12a), 34 standalone-service files awaiting §6.2.12 disposition" → "0 root-bucket-2 candidates remaining (both shipped in §6.2.12a; 3 more shipped in §6.2.12b), 31 standalone-service files awaiting §6.2.12 disposition".

- [ ] **Step 8: Edit `CLAUDE.md` — source-tree count**

Find the line: "5 top-level directories in the umbrella target, 223 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.11 / §6.2.12a), and 589 Swift source files under `Sources/`."

Edit to: "5 top-level directories in the umbrella target, 220 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.11 / §6.2.12a / §6.2.12b), and 589 Swift source files under `Sources/`."

(The `Sources/` total stays 589 — files moved between sibling SPM targets, not added or removed.)

- [ ] **Step 9: Edit `CLAUDE.md` — `CodeEditorCommon` bullet**

Find: "`Sources/CodeEditorCommon/` — utilities, models, extensions, errors, `RecoverableAsyncError`+`RecoveryStrategy`+`BackoffStrategy` infra (phase 0; expanded in §6.2.7)."

Edit to: "`Sources/CodeEditorCommon/` — utilities, models, extensions, errors, `RecoverableAsyncError`+`RecoveryStrategy`+`BackoffStrategy` infra (phase 0; expanded in §6.2.7); `SendablePerformanceMetric` + `FileChangeNotification` (added §6.2.12b)."

- [ ] **Step 10: Edit `CLAUDE.md` — `CodeEditorLanguages` bullet**

Find: "`Sources/CodeEditorPlugin/Languages/` — language descriptors + folding/symbol/completion-model interfaces (phase 3; physically inside the umbrella source tree but compiled as its own target via `path:`)."

Edit to: "`Sources/CodeEditorPlugin/Languages/` — language descriptors + folding/symbol/completion-model interfaces; `TabModel` + `LanguageDetectionService` (added §6.2.12b) (phase 3; physically inside the umbrella source tree but compiled as its own target via `path:`)."

- [ ] **Step 11: Build + lint sanity (docs commit only)**

Docs-only changes can't break the build, but run a sanity pass to be sure nothing else slipped into the working tree:

```bash
git status
git diff --stat
```

Expected: only `NEXT.md` and `CLAUDE.md` modified.

- [ ] **Step 12: Commit**

```bash
git add NEXT.md CLAUDE.md
git commit -m "$(cat <<'EOF'
Document §6.2.12b Core/ prep v2 extraction in NEXT.md and CLAUDE.md

Record the 3 file moves in NEXT.md §6.0 status table and a new
§6.2.12b deviations block. Flip 3 rows in §6.2.12a's root-file triage
table from Bucket 3 Defer to Bucket 2: Moved. Update §10's first
bullet to remove the re-audit worklist (now closed) and reflect the
remaining 31 Bucket 3 Defer files. Update CLAUDE.md source-tree
counts (223 → 220) and the Common / Languages bullets to mention
the relocated symbols.

Closes §6.2.12b.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: `[main <hash>] Document §6.2.12b Core/ prep v2 extraction in NEXT.md and CLAUDE.md`. `git status` reports clean. Four commits total in §6.2.12b (3 moves + 1 docs).

- [ ] **Step 13: Final sanity log**

```bash
git log --oneline -6
```

Expected output shape (top 5 entries should be):

```
<hash-docs> Document §6.2.12b Core/ prep v2 extraction in NEXT.md and CLAUDE.md
<hash-3>    Relocate LanguageDetectionService to CodeEditorLanguages (§6.2.12b prep)
<hash-2>    Relocate TabModel to CodeEditorLanguages (§6.2.12b prep)
<hash-1>    Relocate SendableTypes to CodeEditorCommon (§6.2.12b prep)
84f56a5     Add §6.2.12b Core/ prep v2 design
1deab763    Document §6.2.12a Core/ prep extraction in NEXT.md and CLAUDE.md
```

§6.2.12b is complete. The next chunk is §6.2.12 main (the riskiest single step), per NEXT.md §10.

---

## Self-Review Notes (for plan author)

Coverage check vs. spec:
- Spec §1 (goal & shape): Tasks 2–4 implement the 3 moves; Task 5 verifies; Task 6 records in docs.
- Spec §2 (per-file dispositions): each row mapped to Task 2 / 3 / 4 respectively.
- Spec §3 (carry-set details): every "verify import" / "add import" / "Package.swift edit" item has a concrete step.
- Spec §4 (verification & risks): risks 1–6 addressed inline (bare-word grep in Task 1 Step 3, SwiftLint `--fix` in every commit task, no-blanket-drop `@testable` mentioned in Step 4 of Task 3, stale-path scan in Task 1 Step 4, full strict-concurrency build in Task 5, Codable sanity in Task 3 Step 8).
- Spec §5 (NEXT.md / CLAUDE.md edits): every edit in §5 has a concrete step in Task 6.
- Spec §6 (open questions): `@MainActor` survival noted in Task 4 success criteria; per-target tests not split (Task 6 deviations block reinforces); `TabModel`-in-`CodeEditorUI` counter-rejected (no plan step needed — settled in spec).
- Spec §7 (after this chunk): plan ends at Task 6 Step 13 with a forward-link to §6.2.12 main.

Placeholder scan: the only `<placeholder>` strings are the 3 commit hashes captured in Task 6 Step 1 — these are runtime values, not unfilled spec items. All test commands, file paths, edit content, and commit messages are filled.

Type consistency: file paths use the canonical `Sources/CodeEditorPlugin/Core/...` and `Sources/CodeEditorPlugin/Languages/...` forms throughout. Module names are spelled `CodeEditorCommon`, `CodeEditorLanguages`, `CodeEditorUI`, `CodeEditorUITests` consistently. `import` lines are alphabetized per SwiftLint's `sorted_imports`.
