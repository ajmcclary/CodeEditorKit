# CodeEditorView Extraction (§6.2.12) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract all 118 files from `Sources/CodeEditorPlugin/Core/` into a new SPM target `CodeEditorView` at `Sources/CodeEditorView/`. Productized as `.library(name: "CodeEditorView", targets: ["CodeEditorView"])` per NEXT.md §6.3. Umbrella `CodeEditorPlugin` adds the new target as a direct dependency (matches §6.2.9 LSP / §6.2.10 Diagnostics / §6.2.11 Layout precedent — productized + umbrella-coupled). Public API surface of `import CodeEditorPlugin` is unchanged.

**Architecture:** Five commits. (1) Scaffold the new target with a placeholder `.swift` file + `Package.swift` edits. (2) **Optional** mid-execution cross-target relocations if Task 1 audit surfaces any. (3) Bulk `git mv Sources/CodeEditorPlugin/Core Sources/CodeEditorView`, umbrella `Package.swift` cleanup, consumer-import updates across umbrella `SwiftUI/`, `CodeEditorUI`, `CodeEditorSample`, and tests, plus all access-modifier promotions surfaced by compile errors. (4) End-of-chunk verification — full `swift build && swiftlint --fix && swiftlint && swift test --parallel`. (5) Documentation updates to `NEXT.md` §6.0 / §6.2 / §10, `CLAUDE.md` "Source Tree" and "What Will Go Wrong", and any `docs/Diagrams/` references to the old `Sources/CodeEditorPlugin/Core/` path.

**Tech Stack:** Swift 6.3 SPM package, `StrictConcurrency` enabled. New target deps (subject to plan-time verification in Task 1): `CodeEditorAnnotations`, `CodeEditorCommon`, `CodeEditorCompletion`, `CodeEditorConfiguration`, `CodeEditorDesignTokens`, `CodeEditorDiagnostics`, `CodeEditorFolding`, `CodeEditorLanguages`, `CodeEditorLayout`, `CodeEditorLSP`, `CodeEditorPlatform`, `CodeEditorSymbols`, `CodeEditorSyntaxHighlighting`, `CodeEditorTextModel`, `CodeEditorTheming` (15 internal targets). External: `Dependencies` (swift-dependencies), `IssueReporting` (xctest-dynamic-overlay), plus `SwiftSyntax`+`SwiftParser` if `Core/SyntaxHighlighting/` stay-set consumes them.

**Spec:** `docs/superpowers/specs/2026-05-18-codeeditor-view-extraction-design.md` (commit `bc45a2d`).

**Lessons baked in:**

- §6.2.7 SH: compile-driven access-modifier promotions; WIP checkpoint if promotion count exceeds ~30.
- §6.2.8b Symbols / §6.2.8g Completion / §6.2.12c: synth-init asymmetry — `public` structs / actors / classes that have implicit inits and are cross-target-constructed need explicit `public init(…)`. SwiftLint `missing_docs` bites on actor inits but not struct inits — add `///` to actor inits.
- §6.2.8d Search: do NOT blanket-drop `@testable import CodeEditorPlugin` from tests; internal umbrella symbols may still be required.
- §6.2.8e Annotations: bare-word grep (`\b<TypeName>\b`) catches consumers that compound-name grep misses; run bare-word follow-up before declaring the consumer inventory final.
- §6.2.8f Workspace: SwiftPM requires at least one `.swift` file for a target with a `.library` product — scaffold with a placeholder file in Task 2, delete it during the bulk move in Task 4.
- §6.2.9 LSP / §6.2.10 Diagnostics / §6.2.11 Layout: productized + umbrella-coupled pattern. `.library` entry exposes a standalone product; the umbrella keeps a direct dep so its public API surface is preserved.
- §6.2.11 Layout: SwiftLint's `sorted_imports` rule decides alphabetical order; don't hand-write the import order — let `swiftlint --fix` apply it.
- §6.2.12b: `git mv` followed by `git add` must stage both sides of the rename in the same commit. Verify each commit builds standalone before pushing — no broken-rename intermediates. If a single `git add` errors on a removed source path, abandon and re-stage with both destination + deletion explicitly.
- §6.2.12c: when a commit moves a public type, update `CLAUDE.md` "What Will Go Wrong" with a one-line note for external consumers (this is part of Task 6).

**Estimated effort:** half-day per NEXT.md §10. Most time is the per-commit verification loop and the compile-driven promotion enumeration in Task 4.

---

### Task 1: Pre-flight audit

**Files:** read-only.

This task gathers facts that drive Tasks 2-6. Record the output of each step in the conversation so subsequent tasks can reference it. Do not edit any file.

- [ ] **Step 1: Confirm carry-set inventory matches spec**

Run:
```bash
find Sources/CodeEditorPlugin/Core -name '*.swift' | wc -l
```

Expected: `118` (or close to it; record exact count).

Run:
```bash
find Sources/CodeEditorPlugin/Core -maxdepth 1 -name '*.swift' | wc -l
```

Expected: `52` (root-level files).

Run:
```bash
find Sources/CodeEditorPlugin/Core -type d | sort
```

Expected sub-directories (14 dirs incl. root):
```
Sources/CodeEditorPlugin/Core
Sources/CodeEditorPlugin/Core/Actors
Sources/CodeEditorPlugin/Core/Annotations
Sources/CodeEditorPlugin/Core/Configuration
Sources/CodeEditorPlugin/Core/Documents
Sources/CodeEditorPlugin/Core/Folding
Sources/CodeEditorPlugin/Core/LSP
Sources/CodeEditorPlugin/Core/Layout
Sources/CodeEditorPlugin/Core/Platform
Sources/CodeEditorPlugin/Core/Search
Sources/CodeEditorPlugin/Core/Symbols
Sources/CodeEditorPlugin/Core/SyntaxHighlighting
Sources/CodeEditorPlugin/Core/SyntaxHighlighting/RegexQuery
Sources/CodeEditorPlugin/Core/Text
```

- [ ] **Step 2: Enumerate umbrella SwiftUI/ slice and its current imports**

Run:
```bash
find Sources/CodeEditorPlugin/SwiftUI -name '*.swift' | sort
```

Expected: 17 files (per spec).

Run:
```bash
grep -h '^import\|^@testable import' Sources/CodeEditorPlugin/SwiftUI/*.swift | sort -u
```

Record the unique import set. Expected to include `Foundation`, `SwiftUI`, `CodeEditor*` targets the umbrella already declares as deps. Note any that today rely on same-target visibility into `Core/` (they should be zero `import` statements since same-target doesn't need imports).

- [ ] **Step 3: Survey consumer references to `Core/` types**

Run (verify SwiftUI/ references types currently in Core/):
```bash
grep -l 'CodeEditorView\|EditorController\|EditorConfiguration\|EditorRuntime\|EditorEvent\|EditorState' Sources/CodeEditorPlugin/SwiftUI/*.swift | sort
```

Run (survey CodeEditorUI):
```bash
grep -rln 'CodeEditorView\|EditorController\|EditorRuntime\|UnifiedEventSystem\|CodeEditorAPI' Sources/CodeEditorUI/
```

Run (survey CodeEditorSample):
```bash
grep -rln 'CodeEditorView\|EditorController\|EditorRuntime\|CodeEditorAPI' Sources/CodeEditorSample/
```

Run (survey tests):
```bash
grep -rln '@testable import CodeEditorPlugin' Tests/ | sort
```

Record counts and file lists. These drive Task 4's import-update sub-steps.

- [ ] **Step 4: Audit `Core/SyntaxHighlighting/` for SwiftSyntax/SwiftParser usage**

Run:
```bash
grep -rln 'import SwiftSyntax\|import SwiftParser' Sources/CodeEditorPlugin/Core/
```

If any files match, `CodeEditorView` declares `SwiftSyntax`/`SwiftParser` as direct deps; umbrella drops them. If zero matches, the umbrella retains those deps (its SwiftUI slice doesn't use them).

- [ ] **Step 5: Audit `CodeEditorPlugin.swift` root file**

Run:
```bash
grep -E '^import |^@testable import ' Sources/CodeEditorPlugin/CodeEditorPlugin.swift
```

Expected (per file inspection at plan time): only `Foundation`, `AppKit`, `UIKit`, `SwiftUI` — no `CodeEditor*` imports. Record the actual output. If any `CodeEditor*` imports are present, Task 4 must update them.

- [ ] **Step 6: Audit access-modifier surface — internal symbols in Core/ referenced by SwiftUI/**

This is the largest pre-flight task. Run for each candidate symbol type:

```bash
# Find top-level internal types in Core/ (those without public/package/open/private modifiers and not nested)
grep -rEhn '^(internal )?(final )?(class|struct|enum|actor|protocol) [A-Z][A-Za-z0-9_]+' Sources/CodeEditorPlugin/Core/ | sort -u > /tmp/core_internal_types.txt
wc -l /tmp/core_internal_types.txt
```

```bash
# For each type, check if SwiftUI/ references it
while read -r line; do
  type=$(echo "$line" | grep -oE '(class|struct|enum|actor|protocol) [A-Z][A-Za-z0-9_]+' | awk '{print $2}')
  count=$(grep -rln "\b$type\b" Sources/CodeEditorPlugin/SwiftUI/ 2>/dev/null | wc -l)
  if [ "$count" -gt 0 ]; then
    echo "$type — used by $count SwiftUI/ files"
  fi
done < /tmp/core_internal_types.txt
```

Record the list. Each type that the SwiftUI slice uses needs at minimum `package` (cross-target same-package access) when it moves to `CodeEditorView`.

- [ ] **Step 7: Audit for dead code candidates**

Run:
```bash
# List public top-level types in Core/
grep -rEhn '^public (final )?(class|struct|enum|actor|protocol) [A-Z][A-Za-z0-9_]+' Sources/CodeEditorPlugin/Core/ | grep -oE '(class|struct|enum|actor|protocol) [A-Z][A-Za-z0-9_]+' | awk '{print $2}' | sort -u > /tmp/core_public_types.txt
```

```bash
# For each, check in-tree consumer count
while read -r type; do
  count=$(grep -rln "\b$type\b" Sources/ Tests/ 2>/dev/null | wc -l)
  if [ "$count" -lt 2 ]; then
    echo "$type — $count consumers (CANDIDATE for dead-code audit)"
  fi
done < /tmp/core_public_types.txt
```

Report any candidates with 0–1 consumers. Per §6.2.9a / §6.2.12c precedent, if a public type has zero in-tree callers + zero tests + zero archived-doc references, it's a candidate for deletion in its own commit before the bulk move. Carry forward the list of candidates to Task 3 (mid-execution cleanup), or note "no candidates" if all public types have ≥2 consumers.

- [ ] **Step 8: Audit cross-target relocation candidates**

The §6.2.7 / §6.2.8g / §6.2.11 precedent: small types in moving files that are needed by both `CodeEditorView` and a sibling-target upstream of it should be relocated to the sibling target as a separate pre-bulk commit.

Heuristic candidates to check:

```bash
# Find top-level public types in Core/ that are also referenced from Sources/CodeEditor<Other>/ (sibling targets)
grep -rEhn '^public (final )?(class|struct|enum|actor) [A-Z][A-Za-z0-9_]+' Sources/CodeEditorPlugin/Core/ | grep -oE '(class|struct|enum|actor) [A-Z][A-Za-z0-9_]+' | awk '{print $2}' | sort -u > /tmp/core_public_movable.txt

while read -r type; do
  hits=$(grep -rln "\b$type\b" Sources/ 2>/dev/null | grep -v 'CodeEditorPlugin/Core' | grep -v 'CodeEditorPlugin/SwiftUI' | head -5)
  if [ -n "$hits" ]; then
    echo "=== $type ==="
    echo "$hits"
  fi
done < /tmp/core_public_movable.txt
```

If any type is referenced by a sibling target (not just umbrella, sample, UI, or tests), it's a relocation candidate. Record the list. If no candidates, Task 3 is skipped.

- [ ] **Step 9: Confirm baseline build + test green**

Run:
```bash
swift build 2>&1 | tail -5
```

Expected: `Build complete!` with zero warnings/errors.

Run (lint):
```bash
swiftlint 2>&1 | tail -3
```

Expected: `0 violations`.

Run (targeted to catch any pre-existing flakiness):
```bash
swift test --parallel 2>&1 | tail -10
```

Expected: all suites pass with at most the 1 pre-existing known issue noted in §6.2.12c (record its name if it surfaces). DO NOT proceed to Task 2 if the baseline is broken.

- [ ] **Step 10: Record audit summary**

Write a short summary in the conversation:
- Carry-set count (expected 118; actual ___)
- SwiftUI/ slice consumer count (expected 17; actual ___)
- Test files using `@testable import CodeEditorPlugin` (expected ~50+; actual ___)
- SwiftSyntax/SwiftParser usage in Core/ (expected yes per §6.2.7 carve-out files; actual ___)
- Internal-types-promoted-to-package surface (expected 10–50; actual ___)
- Dead-code deletion candidates (expected 0; actual ___)
- Cross-target relocation candidates (expected 0; actual ___)
- Baseline green: yes/no.

This summary informs whether Task 3 runs (if cross-target relocation or dead-code surface non-zero) and what the access-modifier promotion script in Task 4 needs to handle.

---

### Task 2: Scaffold `CodeEditorView` target (Commit 1)

**Files:**
- Create: `Sources/CodeEditorView/_ScaffoldPlaceholder.swift`
- Modify: `Package.swift` (add product entry + target definition + umbrella dep)

- [ ] **Step 1: Create placeholder source file**

Create `Sources/CodeEditorView/_ScaffoldPlaceholder.swift`:

```swift
// Scaffold placeholder — deleted in Task 4 once real sources move in.
// SwiftPM requires at least one `.swift` file for a target with a
// `.library` product (§6.2.8f Workspace lesson).

internal enum _CodeEditorViewScaffoldPlaceholder {
    case placeholder
}
```

- [ ] **Step 2: Add new product entry to Package.swift**

In `Package.swift` between the existing `.library(name: "CodeEditorUI", ...)` and `.library(name: "CodeEditorWorkspace", ...)` entries, add:

```swift
        .library(
            name: "CodeEditorView",
            targets: ["CodeEditorView"]
        ),
```

The `products:` array stays in alphabetical order — `CodeEditorView` slots between `CodeEditorUI` and `CodeEditorWorkspace`.

- [ ] **Step 3: Add new target definition to Package.swift**

In `Package.swift`, between the existing `.target(name: "CodeEditorTextModel", ...)` declaration and `.target(name: "CodeEditorTheming", ...)` would be the alphabetical slot; but the existing targets file is grouped by phase, not alphabetical. Insert the new target after `.target(name: "CodeEditorSymbols", ...)` and before `.target(name: "CodeEditorWorkspace", ...)`:

```swift
        .target(
            name: "CodeEditorView",
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorFolding",
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorLayout",
                "CodeEditorPlatform",
                "CodeEditorSymbols",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            swiftSettings: swiftSettings
        ),
```

**If Task 1 Step 4 reported that `Core/SyntaxHighlighting/` uses SwiftSyntax/SwiftParser** (expected yes), also add to the `dependencies:` array:

```swift
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
```

Maintain alphabetical order within the dependencies array; `SwiftParser` precedes `SwiftSyntax`.

- [ ] **Step 4: Add umbrella dep on CodeEditorView**

In `Package.swift`, modify the `.target(name: "CodeEditorPlugin", ...)` block's `dependencies:` array. After `"CodeEditorTheming"` and before the swift-dependencies/IssueReporting product lines, insert:

```swift
                "CodeEditorView",
```

The umbrella's dep array stays alphabetical for the internal-target entries (which `"CodeEditorView"` slots into between `"CodeEditorTheming"` and the `.product(...)` entries).

- [ ] **Step 5: Verify Package.swift parses**

Run:
```bash
swift package describe --type json | head -50
```

Expected: valid JSON output describing the package with the new `CodeEditorView` target. No parse errors.

- [ ] **Step 6: Build the new target standalone**

Run:
```bash
swift build --target CodeEditorView 2>&1 | tail -10
```

Expected: `Build complete!`. The placeholder file compiles; deps resolve.

- [ ] **Step 7: Build the umbrella with the new dep**

Run:
```bash
swift build --target CodeEditorPlugin 2>&1 | tail -10
```

Expected: `Build complete!`. Umbrella picks up `CodeEditorView` as a (currently-empty-ish) transitive dep without any source-change-required.

- [ ] **Step 8: Full build green**

Run:
```bash
swift build 2>&1 | tail -5
```

Expected: `Build complete!`. All targets compile.

- [ ] **Step 9: Lint clean**

Run:
```bash
swiftlint --fix && swiftlint 2>&1 | tail -3
```

Expected: `0 violations`. The new placeholder file's `_` prefix is permitted; the file may need a top-comment that satisfies `missing_docs` (the `internal enum` doesn't require docs, but if SwiftLint complains, prefix with `///` doc comment).

- [ ] **Step 10: Commit scaffold**

```bash
git add Package.swift Sources/CodeEditorView/_ScaffoldPlaceholder.swift
git commit -m "$(cat <<'EOF'
Scaffold CodeEditorView target (§6.2.12 step 1/5)

Adds .library product, target definition, and umbrella dep for the
new CodeEditorView target. Includes a _ScaffoldPlaceholder.swift to
satisfy SwiftPM's "non-empty target" requirement (§6.2.8f Workspace
lesson); the placeholder is deleted in step 3/5 (bulk move).

No Core/ files moved yet. Build green.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Verify the commit was created:
```bash
git log -1 --format='%h %s'
```

---

### Task 3 (CONDITIONAL): Mid-execution relocations or dead-code deletions (Commit 2)

**Run this task ONLY if Task 1 Step 7 or Step 8 surfaced candidates.** Otherwise skip directly to Task 4.

Each cross-target relocation OR dead-code deletion goes in its own commit, NOT bundled with the bulk move. This preserves bisectability per §6.2.12b lesson.

**Sub-task 3a (per relocation candidate from Task 1 Step 8):**

- [ ] **Step 1: Identify destination target**

For each candidate type, decide the destination based on consumer pattern:
- Used by `CodeEditorCommon` consumers and only `Foundation` types → `CodeEditorCommon`
- Used by `CodeEditorConfiguration` consumers + `EditorConfiguration` → `CodeEditorConfiguration`
- Used by `CodeEditorTextModel` consumers + Foundation/TextKit2 → `CodeEditorTextModel`
- Else: stays in `CodeEditorView`

- [ ] **Step 2: `git mv` the file**

```bash
git mv Sources/CodeEditorPlugin/Core/<path>/<File>.swift Sources/CodeEditor<Target>/<File>.swift
```

- [ ] **Step 3: Update imports in the relocated file**

The relocated file's own `import` statements may need to drop the target it now lives in. If it imports a symbol that's now same-target, remove that import.

- [ ] **Step 4: Update consumer imports**

For each file that referenced the relocated type:
- If it was umbrella-resident and the relocated file went to a sibling target the umbrella already depends on, no new import is needed.
- If the consumer is a non-umbrella target that didn't previously depend on the destination, add it to `Package.swift`.

- [ ] **Step 5: Verify build + lint + targeted tests green**

```bash
swift build && swiftlint --fix && swiftlint
swift test --filter <RelevantTestSuiteName>
```

- [ ] **Step 6: Commit per relocation**

```bash
git add Sources/ Package.swift
git commit -m "Relocate <Type> from umbrella Core/ to CodeEditor<Target> (§6.2.12 step 2/5)"
```

**Sub-task 3b (per dead-code deletion candidate from Task 1 Step 7):**

- [ ] **Step 1: Confirm zero in-tree consumers**

Re-verify with a final grep before deleting:
```bash
grep -rln '\b<TypeName>\b' Sources/ Tests/ docs/ | grep -v archive
```

Expected: zero or only the defining file. If anything else surfaces, the candidate is NOT dead — drop it.

- [ ] **Step 2: Delete the file**

```bash
git rm Sources/CodeEditorPlugin/Core/<path>/<File>.swift
```

- [ ] **Step 3: Verify build + lint green**

```bash
swift build && swiftlint --fix && swiftlint
```

- [ ] **Step 4: Commit per deletion**

```bash
git commit -m "Delete dead code <TypeName> from umbrella Core/ (§6.2.12 step 2/5)"
```

**If Task 3 has no candidates, skip directly to Task 4.**

---

### Task 4: Bulk move `Core/` → `CodeEditorView/` + consumer fixes + promotions (Commit 3)

**Files:**
- Move: `Sources/CodeEditorPlugin/Core/**/*.swift` → `Sources/CodeEditorView/**/*.swift` (118 files)
- Delete: `Sources/CodeEditorView/_ScaffoldPlaceholder.swift`
- Modify: `Package.swift` (umbrella `exclude:` cleanup + dep cleanup)
- Modify: ~17 files in `Sources/CodeEditorPlugin/SwiftUI/` (add `import CodeEditorView`)
- Modify: any `Sources/CodeEditorUI/`, `Sources/CodeEditorSample/`, `Tests/` files that reference former-Core/ types
- Modify: moved-Core/ files with `internal → package` access-modifier promotions surfaced by compile errors

This is the largest task. The pattern: `git mv` → update Package.swift → bulk-add imports → fix compile errors via promotions → run tests.

- [ ] **Step 1: Move the entire Core/ tree**

`Sources/CodeEditorView/` already exists (from Task 2's scaffold). Move every child of `Core/` into it, preserving sub-directory structure:

```bash
git mv Sources/CodeEditorPlugin/Core/* Sources/CodeEditorView/
rmdir Sources/CodeEditorPlugin/Core
```

(The second command removes the now-empty `Core/` directory. SwiftPM and `git mv` track this via the staged renames.)

End state: every former `Sources/CodeEditorPlugin/Core/<X>` is now at `Sources/CodeEditorView/<X>`, with sub-directory structure preserved. The scaffold placeholder from Task 2 still lives at `Sources/CodeEditorView/_ScaffoldPlaceholder.swift`; it goes in Step 2.

Verify the move:
```bash
find Sources/CodeEditorView -name '*.swift' | wc -l
```

Expected: `119` (118 moved files + the placeholder, until Step 2 deletes it).

```bash
ls Sources/CodeEditorPlugin/Core 2>&1
```

Expected: `No such file or directory`.

```bash
git status --short | head -10
```

Expected: a stream of `R  Sources/CodeEditorPlugin/Core/... -> Sources/CodeEditorView/...` rename entries.

- [ ] **Step 2: Delete the scaffold placeholder**

```bash
git rm Sources/CodeEditorView/_ScaffoldPlaceholder.swift
```

Verify:
```bash
find Sources/CodeEditorView -name '*.swift' | wc -l
```

Expected: `118`.

- [ ] **Step 3: Update umbrella's Package.swift dependencies and exclude list**

In `Package.swift`, the umbrella `.target(name: "CodeEditorPlugin", ...)`:

The `dependencies:` array stays as-is — the umbrella still needs every entry because its remaining `SwiftUI/` slice will gain `import` statements that name these targets directly. (Conservative default per spec §3.2: only drop entries verified unused after Step 5's import updates. Verify with `swift build` at the end of Task 4.)

The `exclude:` array currently reads:
```swift
            exclude: [
                "Info.plist",
                "Languages",
                "Layout"
            ],
```

`"Layout"` excluded the originally-carved-out `Sources/CodeEditorPlugin/Layout/` (now empty except an empty `Glass/` subdir). It can stay or be removed depending on whether the empty directory is also deleted as part of cleanup. Conservative: leave it; the empty directory is harmless. No edit needed for §6.2.12 since `Core/` was never explicitly excluded — it was a source root that SwiftPM auto-included.

Result for Task 4 Step 3: **no Package.swift edit needed in this step** unless Step 4's pre-flight surfaces a needed change. Skip and move on.

- [ ] **Step 4: First compile attempt — catalogue failures**

Run:
```bash
swift build 2>&1 | tee /tmp/build_after_move.txt | tail -50
```

Expected: many errors. The most likely categories:
1. `error: no such module 'CodeEditorView'` from the umbrella `SwiftUI/` slice files.
2. `error: cannot find type 'CodeEditorView' (or 'EditorController' or other former-Core/ types) in scope` from the umbrella `SwiftUI/`, `CodeEditorUI/`, `CodeEditorSample/`, and tests.
3. `error: '<symbol>' is inaccessible due to 'internal' protection level` from moved files referenced by external consumers.
4. `error: cannot find type '<sibling-target type>' in scope` from moved Core/ files — they need to declare the now-cross-target `import` themselves.

Record categories and total error count for the conversation log.

- [ ] **Step 5: Add `import CodeEditorView` to umbrella SwiftUI/ slice files**

Add `import CodeEditorView` to every file in `Sources/CodeEditorPlugin/SwiftUI/` (17 files). Use the Edit tool per file, inserting the line in the existing import block — the exact position within the block doesn't matter because `swiftlint --fix` will sort.

Concrete pattern: for each file, find a representative existing import line (e.g., `import Foundation`) and insert `import CodeEditorView` adjacent to it.

After all 17 edits, run `swiftlint --fix` to sort imports alphabetically (ASCII order — note `CodeEditorLanguages` < `CodeEditorLayout` < `CodeEditorLSP` because uppercase 'S' < lowercase 'a'):

```bash
swiftlint --fix Sources/CodeEditorPlugin/SwiftUI/
```

Verify all 17 files now have the import:
```bash
grep -L '^import CodeEditorView' Sources/CodeEditorPlugin/SwiftUI/*.swift
```

Expected: empty output (every file has the import).

- [ ] **Step 6: Add per-file imports to non-SwiftUI/ umbrella files (if any)**

Per Task 1 Step 5, the umbrella's root `CodeEditorPlugin.swift` typically has no `CodeEditor*` imports. Verify:

```bash
grep '^import CodeEditor' Sources/CodeEditorPlugin/CodeEditorPlugin.swift
```

Expected: zero output. Skip if so. If anything appears, ensure each former-Core/ type's source target is imported.

- [ ] **Step 7: Add `CodeEditorView` to consumer targets in Package.swift**

`CodeEditorUI` target's `dependencies:` array (currently 5 entries) gains `"CodeEditorView"`:

```swift
        .target(
            name: "CodeEditorUI",
            dependencies: [
                "CodeEditorDesignTokens",
                "CodeEditorLanguages",
                "CodeEditorPlugin",
                "CodeEditorSymbols",
                "CodeEditorTheming",
                "CodeEditorView"
            ],
            swiftSettings: swiftSettings
        ),
```

`CodeEditorSample` executableTarget's `dependencies:` array gains `"CodeEditorView"` (alphabetical slot: after `"CodeEditorUI"`, before `"CodeEditorWorkspace"`):

```swift
        .executableTarget(
            name: "CodeEditorSample",
            dependencies: [
                ...
                "CodeEditorUI",
                "CodeEditorView",
                "CodeEditorWorkspace"
            ],
            ...
        ),
```

`CodeEditorPluginTests` testTarget gains `"CodeEditorView"` (alphabetical slot: after `"CodeEditorTheming"`, before the `.product(...)` entries):

```swift
        .testTarget(
            name: "CodeEditorPluginTests",
            dependencies: [
                ...
                "CodeEditorTheming",
                "CodeEditorView",
                .product(name: "CustomDump", ...),
                ...
            ],
            ...
        ),
```

`CodeEditorUITests` testTarget gains `"CodeEditorView"` IF the SwiftUI snapshot tests reference any former-Core/ public type. Verify pre-flight:

```bash
grep -rln 'CodeEditorView\|EditorController\|EditorRuntime' Tests/CodeEditorUITests/
```

If non-empty, add the dep.

`CodeEditorSampleTests` testTarget gains `"CodeEditorView"` IF the sample tests reference former-Core/ types. Verify:

```bash
grep -rln 'CodeEditorView\|EditorController\|EditorRuntime' Tests/CodeEditorSampleTests/
```

If non-empty, add the dep.

- [ ] **Step 8: Add `import CodeEditorView` to CodeEditorUI / CodeEditorSample / Tests source files**

For each file surfaced by Step 4's compile errors that references a former-Core/ type, use the Edit tool to add `import CodeEditorView` to its import block. After the batch, run `swiftlint --fix` over the affected directories so imports sort.

Files in scope:
- `Sources/CodeEditorUI/**/*.swift` (typically 0–5 files per spec)
- `Sources/CodeEditorSample/**/*.swift` (typically 5–15 files per spec)
- `Tests/CodeEditorPluginTests/**/*.swift` (typically 60–120 files per spec — the largest cohort)
- `Tests/CodeEditorSampleTests/**/*.swift` (typically 0–5 files)
- `Tests/CodeEditorUITests/**/*.swift` (typically 0–5 files)

For tests, add `@testable import CodeEditorView` alongside `@testable import CodeEditorPlugin` for files that need access to internal-now-package symbols. Use `@testable import` (not plain `import`) when reaching for internal `func testOnly_*` or test-helper internals.

**Iteration loop:**
1. Run `swift build 2>&1 | grep -E 'error:|warning:' | head -20`.
2. For each `no such module` or `cannot find type` error: add the missing import.
3. Run `swiftlint --fix`.
4. Repeat until errors of categories 1–2 from Step 4 are zero.

- [ ] **Step 9: Promote internal symbols surfaced by category-3 errors**

For each `'<symbol>' is inaccessible due to 'internal' protection level` error:

1. Identify the defining file in `Sources/CodeEditorView/`.
2. Identify the symbol's enclosing type's modifier:
   - If enclosing type is `public`, promote the inaccessible member `internal → package` (or `→ public` only if consumed by `CodeEditorUI` / `CodeEditorSample` external API).
   - If symbol is itself a top-level type (`class`, `struct`, `enum`, `actor`, `protocol`), promote `internal → package`.
3. If the symbol is a synthesized init on a now-cross-target-constructed type, add an explicit `package init(...)` or `public init(...)` per §6.2.8b / §6.2.8g / §6.2.12c precedent.
4. If a `public actor` has an `init` that fails `missing_docs` lint, add a one-line `///` doc comment (§6.2.12c lesson).

Iterate:
1. Run `swift build 2>&1 | grep "inaccessible due to" | head -10`.
2. Apply promotions.
3. Re-run.

When the promotion count exceeds ~30, save progress with a WIP commit per §6.2.7 SH precedent:
```bash
git add Sources/CodeEditorView/
git commit -m "WIP §6.2.12 bulk move — access promotions in progress"
```

Continue iterating until zero `inaccessible due to` errors.

- [ ] **Step 10: Fix category-4 errors — moved-Core/ files needing new imports**

Some moved Core/ files reference sibling-target types they didn't need to import when they were umbrella-resident (because the umbrella's deps made them transitively available). Now in `CodeEditorView`, they need explicit imports.

For each `cannot find type '<SiblingType>' in scope` error in a moved file:
1. Identify which sibling target hosts the type (e.g., `Annotation` → `CodeEditorAnnotations`).
2. Add `import CodeEditor<Sibling>` to the moved file.
3. Run `swiftlint --fix` to sort imports.

Verify `CodeEditorView`'s declared deps in `Package.swift` already include the sibling. If not, add it.

Iterate until `swift build --target CodeEditorView` is green.

- [ ] **Step 11: Full build green**

Run:
```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!`. Zero errors.

If still errors, iterate Steps 8–10 until green.

- [ ] **Step 12: SwiftLint clean**

Run:
```bash
swiftlint --fix && swiftlint 2>&1 | tail -5
```

Expected: `0 violations`.

If violations appear (likely `missing_docs` on synth inits, `sorted_imports`, `no_print_statements`), fix per the message guidance.

- [ ] **Step 13: Targeted test pass (sanity check)**

Run a small filter to catch any obvious test failure before the full parallel run:

```bash
swift test --filter EditorStateTests 2>&1 | tail -10
swift test --filter SyntaxHighlightingTests 2>&1 | tail -10
swift test --filter LSPIntegrationTests 2>&1 | tail -10
```

Expected: green. If any test fails, identify the failure category (missing import, missing promotion, broken @testable) and fix.

- [ ] **Step 14: Commit the bulk move**

Stage everything:
```bash
git add -A
git status
```

Verify the staged change set: 118 file renames (Core/* → CodeEditorView/*), one deletion (placeholder), import additions, Package.swift edits, access-modifier promotions.

Commit:
```bash
git commit -m "$(cat <<'EOF'
Move Core/ to CodeEditorView target (§6.2.12 step 3/5)

Bulk move of 118 files from Sources/CodeEditorPlugin/Core/ to the new
Sources/CodeEditorView/ target, preserving sub-directory structure.
Deletes the scaffold placeholder. Adds CodeEditorView as a direct dep
to CodeEditorUI / CodeEditorSample / CodeEditorPluginTests (and
UITests / SampleTests if their pre-flight surveys surfaced
references). Adds `import CodeEditorView` to 17 SwiftUI/ slice files
plus the ~60-130 plugin-test files reaching former-Core/ internals
via @testable. Applies N access-modifier promotions surfaced by
compile errors.

Public API surface of import CodeEditorPlugin unchanged (umbrella's
new transitive dep on CodeEditorView preserves all previously-public
former-Core/ types).

Build green; targeted suites green. End-of-chunk verification follows
in step 4/5.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Verify:
```bash
git log -1 --stat | head -20
```

Replace `N` in the commit message with the actual promotion count from Step 9 (record it from `git diff --stat HEAD~1`).

---

### Task 5: End-of-chunk verification (Commit 4 if any fixes needed; otherwise verification-only)

**Files:** read-only (unless a pre-existing test failure surfaces — fix per memory "Fix pre-existing failures, don't document them").

- [ ] **Step 1: Full parallel test pass**

Run:
```bash
swift test --parallel 2>&1 | tee /tmp/test_full.txt | tail -30
```

Expected: 100% pass rate (or matching the pre-§6.2.12 baseline from Task 1 Step 9 — the 1 pre-existing known issue is allowed).

If a previously-green test fails:
1. Determine if the failure is a stale path string (per §6.2.8e precedent — fix inline).
2. Determine if the failure is a missing `@testable import CodeEditorView` (add it).
3. Determine if the failure is a missing access-modifier promotion (apply it).
4. Determine if the failure is genuine regression (debug systematically; per memory, do not document — fix).

For each fix:
```bash
git add <fixed-file>
git commit -m "Fix <TestName> regression from §6.2.12 bulk move (§6.2.12 step 4/5)"
```

- [ ] **Step 2: Sample app launches and types a character**

Run the sample app and exercise basic input (per the NSTextView-init-invariant memory: typing must work, not just selection):

```bash
./Scripts/run-sample.sh debug
```

Manually verify in the resulting GUI:
1. The window opens with the editor visible.
2. Click into the editor and type a few characters.
3. Verify the text appears.
4. Quit the sample.

This step cannot be automated; it requires human verification. Record the outcome.

- [ ] **Step 3: Build-from-clean sanity check**

```bash
swift package clean
swift build 2>&1 | tail -5
```

Expected: `Build complete!`. The clean build catches transient SPM cache issues that incremental builds might hide.

- [ ] **Step 4: `swift package describe` verification**

```bash
swift package describe | grep -A5 'CodeEditorView'
```

Expected output: shows `CodeEditorView` target with its 15 internal deps + 2–3 external products + sources at `Sources/CodeEditorView`.

- [ ] **Step 5: Verify per-commit bisectability**

For each commit in this chunk (Tasks 2 / 3 / 4):
```bash
git stash
git checkout <commit-hash>
swift build 2>&1 | tail -3
git checkout main
git stash pop
```

Expected: every commit in the chunk builds green standalone. Per the §6.2.12b lesson — no broken-rename intermediates.

If any commit fails to build standalone, identify the cause and either:
- Squash the offending commit into the previous one (only safe if not yet pushed).
- Apply a fix-up commit and document the bisect-broken commit explicitly in the deviations block.

---

### Task 6: Documentation updates (Commit 5)

**Files:**
- Modify: `NEXT.md` (append §6.0 deviations block; update §6.2.12 step row; update §10)
- Modify: `CLAUDE.md` (add `Sources/CodeEditorView/` to "Other source roots"; add §6.2.12 entries to "What Will Go Wrong"; update file counts in "Source Tree")
- Modify (if applicable): `docs/Diagrams/*.md` files that reference `Sources/CodeEditorPlugin/Core/` paths

- [ ] **Step 1: Append `§6.2.12` deviations block to NEXT.md §6.0**

Insert after the `§6.2.12c` deviations block (currently the last in §6.0), following the pattern of previous deviations blocks. Template:

```markdown
**Deviations during §6.2.12 `CodeEditorView` (commits `<hash1>`, `<hash2>`, ..., `<hashN>`):**

- **Carry-set total: 118 files** moved from `Sources/CodeEditorPlugin/Core/` to `Sources/CodeEditorView/`. Clean full extraction — no carve-out residue. First extraction since the §6.2.4 phase where this was structurally possible (no upward `CodeEditorView` reference to constrain it; this IS the editor surface).
- **NEXT.md §4.1's dep claim was [correct / incomplete].** §4.1 said "Everything in phases 1–7". Final deps: <list>. <Drops/Adds explanation>.
- **Productized + umbrella-coupled.** New `.library(name: "CodeEditorView", ...)` product. Umbrella `CodeEditorPlugin` gains `CodeEditorView` as direct dep. Matches §6.2.9 LSP / §6.2.10 Diagnostics / §6.2.11 Layout precedent.
- **Access-modifier promotion count: N** (record actual). <Highlights of which symbol families were promoted.>
- **Consumer ripple:** N umbrella SwiftUI/ imports added; N CodeEditorUI imports; N CodeEditorSample imports; N plugin-test imports (`@testable` co-add); N umbrella tests; N sample tests. (Record actuals from the bulk move.)
- **Mid-execution relocations:** <list any from Task 3 — e.g., "X relocated to CodeEditorCommon", or "none — no candidates surfaced".>
- **Dead-code deletions:** <list any from Task 3 — e.g., "none — surface clean post-§6.2.12c".>
- **Synth-init quirks bit N times.** <Describe any actor/struct synth-init promotions needed, per §6.2.12c precedent.>
- **SwiftLint <surprise>.** <If any, describe.>
- **Sample app verified manually:** typing works. NSTextView-init-invariant memory holds.
- **Net `Sources/CodeEditorPlugin/` file count drop:** ~214 → ~96 (the umbrella loses 118 files from Core/; retains CodeEditorPlugin.swift + SwiftUI/ + Features/SmartEditing + Languages/ via path:). Record actual numbers.
```

Fill in all `<placeholder>` values from Tasks 2–5's actual outcomes.

- [ ] **Step 2: Update NEXT.md §6.2 step 12 entry**

In NEXT.md §6.2 step-by-step section, find the entry for step 12 (currently begins "**Split `Core/`** — (preceded by §6.2.12a prep..."). Replace its status from in-progress to `[done — see §6.0]` following the pattern of completed steps:

```markdown
12. **[done — see §6.0]** **Split `Core/`** (§6.2.12) — all 118 files in `Sources/CodeEditorPlugin/Core/` moved to new SPM target `Sources/CodeEditorView/`. Productized as `.library(name: "CodeEditorView", ...)` per §6.3; umbrella DOES depend on it (matches §6.2.9 LSP / §6.2.10 Diagnostics / §6.2.11 Layout precedent). Clean full extraction — no carve-out. Final deps: <15 internal targets + 2–3 external products>. (`<hash1>` ... `<hash5>`)
```

- [ ] **Step 3: Update NEXT.md §10 "Suggested next session"**

Find the §6.2.12 bullet in NEXT.md §10. Replace it with a "done — see §6.0" reference. The remaining work in §10 narrows to §6.2.13, §6.2.14, §6.2.15, and the workspace move.

- [ ] **Step 4: Update NEXT.md §6.0 status paragraph**

The opening status paragraph of §6.0 ("**Phases 0–5 done; phase 7 carved out.**" ...) gains a phase-8 reference:

```markdown
**Phases 0–5 done; phases 7–8 carved out.** ... §6.2.12 `CodeEditorView` carved out next as a clean full extraction (118 files — all of `Core/`); the umbrella now retains only `CodeEditorPlugin.swift`, `SwiftUI/` (awaiting §6.2.13), `Features/SmartEditing` (deferred §6.2.8c), `Languages/` (own target via `path:`), and `Resources/Info.plist`.
```

Adapt to match the existing paragraph's prose style.

- [ ] **Step 5: Update NEXT.md status table**

Add a new row to the §6.0 status table for `CodeEditorView`, matching the table's existing column conventions:

```markdown
| `CodeEditorView` | `<hash>` | 118 files moved from `Sources/CodeEditorPlugin/Core/` to new target — clean full extraction, no carve-out. Productized + umbrella-coupled (matches LSP/Diagnostics/Layout). N access-modifier promotions. M consumer-import additions across umbrella SwiftUI/ + CodeEditorUI + CodeEditorSample + tests. <Other notable points>. | Annotations, Common, Completion, Configuration, DesignTokens, Diagnostics, Folding, Languages, Layout, LSP, Platform, Symbols, SyntaxHighlighting, TextModel, Theming + Dependencies + IssueReporting (+ SwiftSyntax/SwiftParser if needed) |
```

Slot the row after the `CodeEditorLayout` row (which is alphabetical for the carve-out series), and update the "as of YYYY-MM-DD" header line.

- [ ] **Step 6: Update CLAUDE.md "Source Tree" section**

In `CLAUDE.md`'s "Source Tree" section, add a new bullet under "Other source roots":

```markdown
- `Sources/CodeEditorView/` — editor-surface target: `CodeEditorView` class + 24 `+Extensions` slices + delegate companions + actor/event/state/orchestration services + carve-out residues from `Annotations/`, `Configuration/`, `Documents/`, `Folding/`, `Layout/`, `LSP/`, `Platform/`, `Search/`, `Symbols/`, `SyntaxHighlighting/`, `Text/`. 118 files (§6.2.12). Productized as opt-in `.library` per NEXT.md §6.3; umbrella `CodeEditorPlugin` DOES depend on it (matches §6.2.9 / §6.2.10 / §6.2.11 pattern).
```

Adjust the existing umbrella-target description to reflect that `Core/` no longer lives there:

Find: `Sources/CodeEditorPlugin/├── Core/                    # ...`
Replace: drop the `Core/` line from the umbrella tree diagram, keeping `Features/`, `Languages/`, `SwiftUI/`, `Resources/`, etc. as appropriate. Update file counts in the prose.

- [ ] **Step 7: Update CLAUDE.md "What Will Go Wrong" section**

Add new entries describing §6.2.12-specific gotchas surfaced during execution. Templates:

```markdown
- **`CodeEditorView` is now both a target name AND a class name.** Modules and types live in separate namespaces in Swift, so `import CodeEditorView` followed by `CodeEditorView()` is unambiguous. The unusual shape is intentional; do not rename the target or the class.

- **All former-`Core/` types are now reachable via `import CodeEditorView` (or transitively via `import CodeEditorPlugin`).** External consumers doing `import CodeEditorPlugin` see no API change. Consumers that need direct access to specific types (e.g., for `@testable` reaches) should `import CodeEditorView`.

- **`@testable import CodeEditorPlugin` is still useful for internals that stayed in the umbrella's residual SwiftUI/ slice.** Don't blanket-drop it from tests; keep alongside `@testable import CodeEditorView` per §6.2.8d lesson.
```

Add other gotcha entries based on what Task 4 surfaced (e.g., specific promotions, specific synth-init quirks).

- [ ] **Step 8: Update `docs/Diagrams/` (if any)**

Run:
```bash
grep -rln 'Sources/CodeEditorPlugin/Core' docs/Diagrams/
```

For each non-archive match, decide whether the path reference is:
- Historical (e.g., describing the pre-restructure layout) → leave as-is.
- Current (describing post-restructure architecture) → update to `Sources/CodeEditorView/`.

For each updated diagram, also update the diagram's prose if it describes target boundaries.

- [ ] **Step 9: Verify documentation build green (no test impact)**

```bash
swift build && swiftlint --fix && swiftlint 2>&1 | tail -3
```

Expected: `Build complete!`, `0 violations`. Doc changes shouldn't affect source compilation, but the package-level lint may flag any stray Markdown-embedded Swift.

- [ ] **Step 10: Commit documentation**

```bash
git add NEXT.md CLAUDE.md docs/
git commit -m "$(cat <<'EOF'
Document §6.2.12 CodeEditorView extraction in NEXT.md and CLAUDE.md

Adds the §6.2.12 deviations block to NEXT.md §6.0, marks NEXT.md §6.2
step 12 done, updates §10 "Suggested next session" to remove §6.2.12,
expands the §6.0 status table with the CodeEditorView row, updates
the §6.0 status paragraph to mark phases 7-8 carved out.

Updates CLAUDE.md "Source Tree" to add Sources/CodeEditorView/ as a
real SPM target and adjusts the umbrella's tree to reflect Core/
moving out. Adds "What Will Go Wrong" entries for the target/class
name collision and the @testable import shifts.

Updates docs/Diagrams/ where current-architecture references to the
old Sources/CodeEditorPlugin/Core/ path needed adjusting.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Verify:
```bash
git log -1 --stat | head -20
```

---

### Task 7: Final chunk verification

**Files:** read-only.

- [ ] **Step 1: End-of-chunk full pipeline**

Run:
```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel 2>&1 | tail -20
```

Expected:
- `Build complete!`
- `0 violations`
- All test suites pass (or matching pre-§6.2.12 baseline).

- [ ] **Step 2: Commit-by-commit bisectability check**

```bash
git log --oneline | head -10
```

Identify the §6.2.12 commit range (typically Task 2's scaffold commit through Task 6's docs commit). For each commit in the range:

```bash
git checkout <commit-hash>
swift build 2>&1 | tail -3
```

Expected: every commit standalone-builds green. Return to main: `git checkout main`.

- [ ] **Step 3: Confirm spec success criteria from `2026-05-18-codeeditor-view-extraction-design.md` §14**

Verify each:
1. ✅ `Sources/CodeEditorView/` exists as a real SPM target with `.library` product.
2. ✅ `Sources/CodeEditorPlugin/Core/` no longer exists.
3. ✅ Umbrella `CodeEditorPlugin` target's `dependencies:` includes `CodeEditorView`.
4. ✅ `swift build && swiftlint --fix && swiftlint && swift test --parallel` green.
5. ✅ Sample app launches and types a character (Task 5 Step 2).
6. ✅ Public API surface of `import CodeEditorPlugin` is unchanged.
7. ✅ NEXT.md / CLAUDE.md / `docs/Diagrams/` updated.
8. ✅ §6.2.13 SwiftUI extraction is unblocked.
9. ✅ §6.2.14 umbrella re-export is unblocked.

All ✅ → chunk complete.

If any criterion is unmet, identify the gap and either fix in-place (if minor — e.g., a missed doc update) or document as a known follow-up. Don't claim completion until every criterion is met.

- [ ] **Step 4: Optional pre-push sanity check**

If pushing to a remote:

```bash
git log --oneline origin/main..HEAD
```

Expected: 4–6 new commits in the §6.2.12 range. Review the commit subjects for clarity. None should mention `--no-verify` or `--amend` (per Git Safety Protocol).

```bash
git status
```

Expected: clean working tree.

---

## Out-of-scope reminders

- **No** SwiftUI/ extraction (§6.2.13) — separate chunk.
- **No** umbrella strip-down to `@_exported import` (§6.2.14) — separate chunk.
- **No** rename to `CodeEditorToolkit` (§6.2.16) — deferred to workspace move.
- **No** sub-target factoring (event-system cluster, glue target) — single `CodeEditorView` target this chunk.
- **No** `CodeEditorTestSupport` extraction (§6.2.15) — separate chunk.
- **No** feature-code rewrites. Per NEXT.md §9: "import-graph surgery, not feature work."

---

## Estimated commit count

Realistic range: **4–6 commits** in the chunk.

- 1 scaffold (Task 2) — mandatory.
- 0–2 mid-execution relocations or dead-code deletions (Task 3) — conditional on Task 1 audit.
- 1 bulk move (Task 4) — mandatory. Possibly 1 WIP intermediate per §6.2.7 precedent if promotion count exceeds ~30.
- 0–1 verification fix (Task 5) — only if a pre-existing test surfaces a fixable regression.
- 1 docs (Task 6) — mandatory.

Most likely shape: 3 commits (scaffold + bulk + docs) if everything goes smoothly, scaling to 5–6 if relocations / WIP / verification fixes are needed.
