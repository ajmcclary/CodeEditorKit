# §6.2.12a Core/ Prep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shrink `Sources/CodeEditorPlugin/Core/` by relocating ~10 files into existing sibling SPM targets, leaving the 138-file Core/ pile classified and audit-trail-ready for the §6.2.12 main editor-surface split.

**Architecture:** Per-bucket sweeps in dep-direction order (least-coupled first). Each sweep does a deeper audit on first-pass Move candidates, executes the moves that survive (zero-touch or cheap-break per §6.2.7/§6.2.11 precedent), and adds `import <SiblingTarget>` to umbrella + test consumers. No new SPM targets. No access-modifier promotions wider than `package`. Documentation task at the end consolidates findings into a new NEXT.md §6.2.12a deviations block.

**Tech Stack:** Swift 6.3 SPM package, multi-target layered architecture, SwiftLint strict mode, Swift Testing + XCTest hybrid test targets.

**Source spec:** `docs/superpowers/specs/2026-05-18-codeeditor-core-prep-design.md`

**Plan-time deeper-screening adjustments to the spec:**
- `Core/Documents/` (2 files): **both reclassified Keep** — `EditorDocument.swift` and `EditorDocuments.swift` use `Language?` from CodeEditorLanguages load-bearingly (property + parameter types). Languages is downstream of TextModel; no in-bounds target fits.
- `Core/Text/`: **3 of 7 first-pass candidates reclassified Keep**. `ModernTextKitHelper.swift` imports `CodeEditorSyntaxHighlighting` (downstream of TextModel). `TextKit2PerformanceHelper.swift` imports `CodeEditorDiagnostics` (downstream of TextModel). `TextKit2RenderingOptimizer.swift` imports both. None can move to TextModel without inverting dep direction.
- `Core/Platform/`: **1 of 5 first-pass candidates reclassified Keep**. `PlatformConfigurations.swift` imports `CodeEditorDiagnostics`; CodeEditorConfiguration does NOT depend on Diagnostics (Diagnostics → Configuration would form a cycle), so the file cannot move to Configuration.
- `Core/Platform/`: **target re-assignment**. All 4 Move-eligible Platform candidates target `CodeEditorConfiguration` (not Platform), because each imports CodeEditorConfiguration — they cannot live in Platform without inverting dep direction. The spec's "Platform or Configuration" hedge resolves entirely to Configuration.

**Final Move-eligible tally:** 10 files (4 Platform → Configuration; 4 Text → TextModel; 1 root → Configuration; 1 root → Symbols). 138 → 128 in Core/.

---

## Task 1: Pre-flight

**Files:**
- Read-only: working tree state, current build

- [ ] **Step 1: Verify clean tree**

Run: `git status`
Expected: `On branch main` with `nothing to commit, working tree clean`. If dirty, stop and triage with the user — do not proceed.

- [ ] **Step 2: Verify baseline build green**

Run: `swift build`
Expected: build succeeds with no errors.

- [ ] **Step 3: Verify baseline lint green**

Run: `swiftlint --fix && swiftlint`
Expected: zero violations after fix. If violations remain post-fix, stop and triage with the user.

- [ ] **Step 4: Verify baseline tests green (targeted smoke)**

Run: `swift test --filter PlatformAbstractionTests`
Expected: PASS.

Run: `swift test --filter EditorDocumentTests`
Expected: PASS.

No commit for Task 1 — pre-flight only.

---

## Task 2: Step 1b — Core/Platform/ sweep (4 files → CodeEditorConfiguration)

**Files:**
- Move: `Sources/CodeEditorPlugin/Core/Platform/DeviceType+RecommendedConfiguration.swift` → `Sources/CodeEditorConfiguration/DeviceType+RecommendedConfiguration.swift`
- Move: `Sources/CodeEditorPlugin/Core/Platform/PlatformAdjustments+Extensions.swift` → `Sources/CodeEditorConfiguration/PlatformAdjustments+Extensions.swift`
- Move: `Sources/CodeEditorPlugin/Core/Platform/PlatformCapabilities+RecommendedConfiguration.swift` → `Sources/CodeEditorConfiguration/PlatformCapabilities+RecommendedConfiguration.swift`
- Move: `Sources/CodeEditorPlugin/Core/Platform/TextInputFeatures.swift` → `Sources/CodeEditorConfiguration/TextInputFeatures.swift`
- Stays in `Core/Platform/`: `PlatformConfigurations.swift` (Diagnostics dep cycle)
- Verify-only: consumers of moved files inside umbrella + tests

- [ ] **Step 1: Per-file pre-audit (verify no umbrella-private reaches)**

Run for each moving file:
```bash
for f in Sources/CodeEditorPlugin/Core/Platform/DeviceType+RecommendedConfiguration.swift \
         Sources/CodeEditorPlugin/Core/Platform/PlatformAdjustments+Extensions.swift \
         Sources/CodeEditorPlugin/Core/Platform/PlatformCapabilities+RecommendedConfiguration.swift \
         Sources/CodeEditorPlugin/Core/Platform/TextInputFeatures.swift; do
  echo "--- $(basename "$f") ---"
  grep -nE "(CodeEditorDependencies|CodeEditorView|@testable)" "$f" || echo "  (none — pass)"
done
```

Expected: each file outputs `(none — pass)`. If any file shows a hit, reclassify that file as **Keep** and remove it from the move list. Document the blocker for the Task 7 audit table.

- [ ] **Step 2: Inventory consumers of the moving files**

Run:
```bash
for sym in "DeviceType.recommendedConfiguration" "PlatformAdjustments" "PlatformCapabilities.recommendedConfiguration" "TextInputFeatures\\b" "TextInputFeaturesFactory" "TextInputFeatureTarget"; do
  echo "--- consumers of $sym ---"
  grep -rln "$sym" Sources/ Tests/ 2>/dev/null | grep -v "Core/Platform/" | grep -v ".build/"
done
```

Record the file list — these files will need `import CodeEditorConfiguration` if they don't already have it. (CodeEditorConfiguration is already a dep of every umbrella file via transitive imports, but a direct consumer of a symbol needs a direct import per SwiftLint conventions.)

- [ ] **Step 3: Execute the moves with `git mv`**

```bash
git mv Sources/CodeEditorPlugin/Core/Platform/DeviceType+RecommendedConfiguration.swift \
       Sources/CodeEditorConfiguration/DeviceType+RecommendedConfiguration.swift
git mv Sources/CodeEditorPlugin/Core/Platform/PlatformAdjustments+Extensions.swift \
       Sources/CodeEditorConfiguration/PlatformAdjustments+Extensions.swift
git mv Sources/CodeEditorPlugin/Core/Platform/PlatformCapabilities+RecommendedConfiguration.swift \
       Sources/CodeEditorConfiguration/PlatformCapabilities+RecommendedConfiguration.swift
git mv Sources/CodeEditorPlugin/Core/Platform/TextInputFeatures.swift \
       Sources/CodeEditorConfiguration/TextInputFeatures.swift
```

- [ ] **Step 4: First build attempt — collect missing-import errors**

Run: `swift build 2>&1 | grep "cannot find" | head -40`

Expected: a list of "cannot find type X in scope" / "cannot find Y in scope" errors. Each error names a file that needs `import CodeEditorConfiguration`.

If zero errors: skip to Step 6.

- [ ] **Step 5: Add `import CodeEditorConfiguration` to each missing-import file**

For each file the previous step named, edit the import block to add `import CodeEditorConfiguration` in sorted-imports position. Use the Edit tool with the existing import block as `old_string` and the same block with the new line inserted as `new_string`. SwiftLint's `sorted_imports` rule will fix ordering in Step 7 if needed.

Use this template per file (replace ABC with the existing import line that should follow `CodeEditorConfiguration` alphabetically):

```
old_string:
import ABC
import Foundation

new_string:
import ABC
import CodeEditorConfiguration
import Foundation
```

- [ ] **Step 6: Rebuild after import additions**

Run: `swift build`
Expected: build succeeds.

If new errors surface (e.g., missing CodeEditorPlatform import because PlatformAdjustments+Extensions.swift drags `PlatformColor` references that were previously umbrella-resident), add those imports too and rebuild. Cap retries at 3 — if errors persist after 3 import-add rounds, stop and triage with the user.

- [ ] **Step 7: Lint**

Run: `swiftlint --fix && swiftlint`
Expected: zero violations after fix. SwiftLint will reorder any out-of-order imports added in Step 5.

- [ ] **Step 8: Targeted tests**

Run: `swift test --filter PlatformAbstractionTests`
Run: `swift test --filter PlatformCapabilitiesTests`
Run: `swift test --filter PlatformPresetsTests`
Run: `swift test --filter PlatformExtensionTests`
Run: `swift test --filter PlatformConfigurationsLoggingTest`
Run: `swift test --filter ConfigurationBasicTests`
Run: `swift test --filter ConfigurationIntegrationTests`
Run: `swift test --filter CrossPlatformCoordinatorTests`

Expected: all PASS.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Relocate Core/Platform/ Move-eligible files (§6.2.12a prep)

Moves 4 zero-CodeEditorView-ref files from umbrella Core/Platform/
to CodeEditorConfiguration: DeviceType+RecommendedConfiguration,
PlatformAdjustments+Extensions, PlatformCapabilities+RecommendedConfiguration,
TextInputFeatures. PlatformConfigurations stays in umbrella
(CodeEditorDiagnostics dep would cycle with Configuration).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Step 1c — Core/Text/ sweep (4 files → CodeEditorTextModel)

**Files:**
- Move: `Sources/CodeEditorPlugin/Core/Text/BackgroundProcessor.swift` → `Sources/CodeEditorTextModel/BackgroundProcessor.swift`
- Move: `Sources/CodeEditorPlugin/Core/Text/ParagraphStyleCache.swift` → `Sources/CodeEditorTextModel/ParagraphStyleCache.swift`
- Move: `Sources/CodeEditorPlugin/Core/Text/TemporaryAttributesStore.swift` → `Sources/CodeEditorTextModel/TemporaryAttributesStore.swift`
- Move: `Sources/CodeEditorPlugin/Core/Text/TextLayoutFragment.swift` → `Sources/CodeEditorTextModel/TextLayoutFragment.swift`
- Stays in `Core/Text/`: `ModernTextKitHelper.swift`, `TextKit2PerformanceHelper.swift`, `TextKit2RenderingOptimizer.swift` (downstream-dep blockers), `LineGeometryEditHandler.swift`, `TextEditEventHub.swift`, `TextKitBridge.swift`, `TextKitLineNumberHelper.swift` (CodeEditorView refs)
- Verify-only: consumers in umbrella + tests

- [ ] **Step 1: Per-file pre-audit (verify no umbrella-private reaches)**

Run:
```bash
for f in Sources/CodeEditorPlugin/Core/Text/BackgroundProcessor.swift \
         Sources/CodeEditorPlugin/Core/Text/ParagraphStyleCache.swift \
         Sources/CodeEditorPlugin/Core/Text/TemporaryAttributesStore.swift \
         Sources/CodeEditorPlugin/Core/Text/TextLayoutFragment.swift; do
  echo "--- $(basename "$f") ---"
  grep -nE "(CodeEditorDependencies|CodeEditorView|@testable)" "$f" || echo "  (none — pass)"
done
```

Expected: each file outputs `(none — pass)`. If a hit appears, reclassify and remove from the move list.

- [ ] **Step 2: Inventory consumers of the moving files**

Run:
```bash
for sym in "BackgroundProcessor" "ParagraphStyleCache" "TemporaryAttributesStore" "TextLayoutFragment\\b"; do
  echo "--- consumers of $sym ---"
  grep -rln "$sym" Sources/ Tests/ 2>/dev/null | grep -v ".build/" | grep -v "Core/Text/"
done
```

Record the consumer list. Consumers will need `import CodeEditorTextModel` if they don't already have it.

- [ ] **Step 3: Execute the moves**

```bash
git mv Sources/CodeEditorPlugin/Core/Text/BackgroundProcessor.swift \
       Sources/CodeEditorTextModel/BackgroundProcessor.swift
git mv Sources/CodeEditorPlugin/Core/Text/ParagraphStyleCache.swift \
       Sources/CodeEditorTextModel/ParagraphStyleCache.swift
git mv Sources/CodeEditorPlugin/Core/Text/TemporaryAttributesStore.swift \
       Sources/CodeEditorTextModel/TemporaryAttributesStore.swift
git mv Sources/CodeEditorPlugin/Core/Text/TextLayoutFragment.swift \
       Sources/CodeEditorTextModel/TextLayoutFragment.swift
```

- [ ] **Step 4: First build attempt — collect missing-import errors**

Run: `swift build 2>&1 | grep "cannot find" | head -40`

Expected: list of missing-import errors. Each error names a file that needs `import CodeEditorTextModel`.

- [ ] **Step 5: Add `import CodeEditorTextModel` to each missing-import file**

For each file the previous step named, edit the import block to add `import CodeEditorTextModel` in sorted-imports position (between `CodeEditorSyntaxHighlighting` / `CodeEditorTheming` / etc., per case-sensitive uppercase-before-lowercase rule from §6.2.9). Use the Edit tool.

- [ ] **Step 6: Rebuild after import additions**

Run: `swift build`
Expected: build succeeds. Cap retries at 3 import-add rounds.

- [ ] **Step 7: Lint**

Run: `swiftlint --fix && swiftlint`
Expected: zero violations.

- [ ] **Step 8: Targeted tests**

Run: `swift test --filter TextKit2OptimizationTests`
Run: `swift test --filter TextKitBridgeEditingTransactionTests`
Run: `swift test --filter ParagraphStyleCache`
Run: `swift test --filter BackgroundProcessor`
Run: `swift test --filter TemporaryAttributesStore`
Run: `swift test --filter TextLayoutFragment`

Expected: all PASS (filters with no matching test names are no-ops in SwiftPM and count as pass).

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Relocate Core/Text/ Move-eligible files to CodeEditorTextModel (§6.2.12a prep)

Moves 4 zero-CodeEditorView-ref, in-bounds-dep-set files from umbrella
Core/Text/ to CodeEditorTextModel: BackgroundProcessor, ParagraphStyleCache,
TemporaryAttributesStore, TextLayoutFragment. ModernTextKitHelper,
TextKit2PerformanceHelper, TextKit2RenderingOptimizer stay in umbrella
(import downstream targets — SyntaxHighlighting / Diagnostics — and
cannot move to TextModel without dep inversion).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Step 1d — Core/Documents/ audit-only (reclassify Keep)

**Files:** no moves; audit-table entry only.

- [ ] **Step 1: Verify the Languages dep is load-bearing**

Run:
```bash
grep -nE "Language\\b|LanguageID|LanguageDescriptor|FoldableRegion|DocumentSymbol" \
     Sources/CodeEditorPlugin/Core/Documents/EditorDocument.swift \
     Sources/CodeEditorPlugin/Core/Documents/EditorDocuments.swift
```

Expected: matches in both files (verified plan-time at lines `EditorDocument.swift:43` `var language: Language?` and `:57` `language: Language? = nil`, and `EditorDocuments.swift:93` `setLanguage(_ language: Language, of id: EditorDocument.ID)`).

If the references are still there: the import is load-bearing. Both files **stay** with rationale "consume `Language` (Languages target) load-bearingly; no in-bounds target fits — TextModel is upstream of Languages."

If the references are gone (because something else changed since plan-writing): the import may be removable. Try `swift build` after dropping the `import CodeEditorLanguages` line; if it builds, both files can move to TextModel. (This path is **not** expected; treat as a discovery.)

- [ ] **Step 2: Record finding for Task 7**

Document in a scratch note (will be folded into NEXT.md in Task 7):
> `Core/Documents/EditorDocument.swift` + `EditorDocuments.swift` — **Keep**. Both files store and accept `Language?` (from CodeEditorLanguages). Move target would need a Languages-downstream home, which doesn't currently exist for document model types. Defer to §6.2.12 main split.

No commit for Task 4 — audit-only outcome.

---

## Task 5: Step 2a — EditorConfiguration+ApplyTextInputFeatures.swift → CodeEditorConfiguration

**Files:**
- Move: `Sources/CodeEditorPlugin/Core/EditorConfiguration+ApplyTextInputFeatures.swift` → `Sources/CodeEditorConfiguration/EditorConfiguration+ApplyTextInputFeatures.swift`
- Depends on: Task 2 having shipped `TextInputFeatures.swift` into CodeEditorConfiguration. **If Task 2 reclassified TextInputFeatures as Keep, skip this task entirely.**

- [ ] **Step 1: Verify Task 2 success**

Run:
```bash
test -f Sources/CodeEditorConfiguration/TextInputFeatures.swift && echo "ok — TextInputFeatures landed" || echo "skip Task 5 — TextInputFeatures stayed in umbrella"
```

If "skip Task 5": stop, record `Core/EditorConfiguration+ApplyTextInputFeatures.swift` as **Keep** in the audit table, and move to Task 6.

- [ ] **Step 2: Pre-audit**

Run:
```bash
grep -nE "(CodeEditorDependencies|CodeEditorView|@testable)" \
     Sources/CodeEditorPlugin/Core/EditorConfiguration+ApplyTextInputFeatures.swift
```

Expected: no matches. (Verified plan-time: file body is 9 lines of pure-extension code.)

If matches appear: reclassify Keep and skip the rest of this task.

- [ ] **Step 3: Inventory consumers**

Run:
```bash
grep -rln "applyTextInputFeatures" Sources/ Tests/ 2>/dev/null | grep -v ".build/" | grep -v "Core/EditorConfiguration+ApplyTextInputFeatures.swift"
```

Record consumers — each will need `import CodeEditorConfiguration` if they don't have it.

- [ ] **Step 4: Execute the move**

```bash
git mv Sources/CodeEditorPlugin/Core/EditorConfiguration+ApplyTextInputFeatures.swift \
       Sources/CodeEditorConfiguration/EditorConfiguration+ApplyTextInputFeatures.swift
```

- [ ] **Step 5: Build, add imports, rebuild**

Run: `swift build 2>&1 | grep "cannot find" | head -20`
Add `import CodeEditorConfiguration` to any file the errors name.
Run: `swift build`. Expected: green.

- [ ] **Step 6: Lint**

Run: `swiftlint --fix && swiftlint`
Expected: zero violations.

- [ ] **Step 7: Targeted tests**

Run: `swift test --filter ConfigurationBasicTests`
Run: `swift test --filter ConfigurationIntegrationTests`
Run: `swift test --filter SwiftUIEnvironmentConfigurationTests`

Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Relocate EditorConfiguration+ApplyTextInputFeatures to CodeEditorConfiguration (§6.2.12a prep)

Moves the 9-line bridge extension into CodeEditorConfiguration alongside
TextInputFeatures (relocated in §6.2.12a Task 2). Eliminates one root-level
cross-target glue file from umbrella Core/.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Step 2b — BreadcrumbComponent.swift → CodeEditorSymbols

**Files:**
- Move: `Sources/CodeEditorPlugin/Core/BreadcrumbComponent.swift` → `Sources/CodeEditorSymbols/BreadcrumbComponent.swift`
- Known consumers (verified plan-time): `Sources/CodeEditorPlugin/Core/EditorState.swift`, `Tests/CodeEditorPluginTests/Core/EditorStateConformanceTests.swift`, `Tests/CodeEditorPluginTests/Core/EditorStateTests.swift`, `Tests/CodeEditorUITests/Snapshots/EditorBreadcrumbSnapshots.swift`.
- Possibly modify: `Package.swift` (add `CodeEditorSymbols` dep to `CodeEditorUITests` target if not present).

- [ ] **Step 1: Pre-audit**

Run:
```bash
grep -nE "(CodeEditorDependencies|CodeEditorView|@testable)" \
     Sources/CodeEditorPlugin/Core/BreadcrumbComponent.swift
```

Expected: no matches. (Verified plan-time: file is a `public struct BreadcrumbComponent: Hashable, Identifiable, Sendable` data type, Foundation-only.)

- [ ] **Step 2: Check CodeEditorUITests Package.swift dep on CodeEditorSymbols**

Run:
```bash
grep -A 20 'name: "CodeEditorUITests"' Package.swift | head -25
```

Expected: shows the test target's dependencies. If `CodeEditorSymbols` is absent, note that Package.swift needs an edit in Step 5.

- [ ] **Step 3: Execute the move**

```bash
git mv Sources/CodeEditorPlugin/Core/BreadcrumbComponent.swift \
       Sources/CodeEditorSymbols/BreadcrumbComponent.swift
```

- [ ] **Step 4: Build, collect missing-import errors**

Run: `swift build 2>&1 | grep "cannot find\\|no such module" | head -20`

Expected errors will name:
- `Sources/CodeEditorPlugin/Core/EditorState.swift` — needs `import CodeEditorSymbols`
- `Tests/CodeEditorPluginTests/Core/EditorStateConformanceTests.swift` — needs `import CodeEditorSymbols`
- `Tests/CodeEditorPluginTests/Core/EditorStateTests.swift` — needs `import CodeEditorSymbols`
- `Tests/CodeEditorUITests/Snapshots/EditorBreadcrumbSnapshots.swift` — needs `import CodeEditorSymbols` AND the `CodeEditorUITests` test target needs `CodeEditorSymbols` added to its dependencies in `Package.swift`

- [ ] **Step 5: Add `import CodeEditorSymbols` to the 4 consumers**

For each file named in Step 4, edit the import block to add `import CodeEditorSymbols` in sorted-imports position (after `CodeEditorSwiftUI` if present, before `CodeEditorSyntaxHighlighting`).

If CodeEditorUITests' Package.swift target lacks `CodeEditorSymbols`, edit `Package.swift`:

```
old_string:
        .testTarget(
            name: "CodeEditorUITests",
            dependencies: [
                "CodeEditorDesignTokens",
                "CodeEditorUI",

new_string:
        .testTarget(
            name: "CodeEditorUITests",
            dependencies: [
                "CodeEditorDesignTokens",
                "CodeEditorSymbols",
                "CodeEditorUI",
```

(The actual `dependencies` array may have different members — adapt the Edit anchor to the actual content. Maintain alphabetical order.)

- [ ] **Step 6: Rebuild**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 7: Lint**

Run: `swiftlint --fix && swiftlint`
Expected: zero violations.

- [ ] **Step 8: Targeted tests**

Run: `swift test --filter EditorStateTests`
Run: `swift test --filter EditorStateConformanceTests`
Run: `swift test --filter EditorBreadcrumbSnapshots`

Expected: all PASS.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Relocate BreadcrumbComponent to CodeEditorSymbols (§6.2.12a prep)

Moves the 1-file pure data type (public struct, Hashable + Identifiable
+ Sendable) from umbrella Core/ to CodeEditorSymbols, where it belongs
alongside SymbolNavigationConfiguration and the other navigation-chrome
types. Adds CodeEditorSymbols dep to CodeEditorUITests target.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Step 3 — Documentation (NEXT.md §6.2.12a block)

**Files:**
- Modify: `NEXT.md` (add §6.2.12a entries: row in §6.0 status table, deviations block, audit tables)
- Modify: `CLAUDE.md` (update Core/ file count from 232-in-umbrella estimate)

- [ ] **Step 1: Run full test suite**

Run: `swift test --parallel`
Expected: all PASS. This is the first full run since pre-flight; if regressions surfaced between Tasks 2–6, this catches them.

If failures: stop, triage with the user. Do not amend prior commits — make a fix commit.

- [ ] **Step 2: Count post-move file totals**

Run:
```bash
echo "Core/ total: $(find Sources/CodeEditorPlugin/Core -name "*.swift" | wc -l)"
echo "Core/ top-level: $(find Sources/CodeEditorPlugin/Core -maxdepth 1 -name "*.swift" | wc -l)"
echo "Umbrella total: $(find Sources/CodeEditorPlugin -name "*.swift" | wc -l)"
```

Expected (assuming all 10 moves landed):
- Core/ total: 138 - 10 = 128
- Core/ top-level: 64 - 2 = 62
- Umbrella total: previous 232 - 10 = 222

Record these for the CLAUDE.md update in Step 4.

- [ ] **Step 3: Add the §6.2.12a row to NEXT.md §6.0 status table**

In `NEXT.md`, locate the table that starts with `| Target | Commit | What landed | Direct deps |` (the §6.0 status table that lists `CodeEditorCommon` through `CodeEditorLayout`). Add a new row at the bottom of the table (after the `CodeEditorLayout` row):

```
old_string:
| `CodeEditorLayout` | `3a2aba83` | 22 files in new target ...

new_string:
| `CodeEditorLayout` | `3a2aba83` | 22 files in new target ...
| `§6.2.12a prep` | (this commit range) | 10 files relocated from umbrella `Core/` to existing sibling SPM targets — 4 from `Core/Platform/` to CodeEditorConfiguration (`DeviceType+RecommendedConfiguration`, `PlatformAdjustments+Extensions`, `PlatformCapabilities+RecommendedConfiguration`, `TextInputFeatures`); 4 from `Core/Text/` to CodeEditorTextModel (`BackgroundProcessor`, `ParagraphStyleCache`, `TemporaryAttributesStore`, `TextLayoutFragment`); 1 root file to CodeEditorConfiguration (`EditorConfiguration+ApplyTextInputFeatures`); 1 root file to CodeEditorSymbols (`BreadcrumbComponent`). Zero new SPM targets; zero access-modifier promotions wider than `package`. | (no new target) |
```

(Adapt the exact old_string anchor to the actual table cell content. Use a multi-line anchor if the existing row spans multiple lines.)

- [ ] **Step 4: Add a deviations block in NEXT.md §6.0**

Locate the last existing deviations block (`**Deviations during §6.2.11 \`CodeEditorLayout\`...**`). After it, add:

```markdown

**Deviations during §6.2.12a `Core/` prep (this commit range):**

- **Pre-execution scope was 16 files; deeper screening cut to 10.** Spec at `docs/superpowers/specs/2026-05-18-codeeditor-core-prep-design.md` estimated 16 Move-eligible files. Plan-time deeper screening reclassified 6 as Keep: both Documents files (load-bearing `Language` from CodeEditorLanguages — TextModel is upstream of Languages), `Core/Text/ModernTextKitHelper.swift` + `TextKit2PerformanceHelper.swift` + `TextKit2RenderingOptimizer.swift` (downstream `CodeEditorDiagnostics` / `CodeEditorSyntaxHighlighting` imports), and `Core/Platform/PlatformConfigurations.swift` (CodeEditorDiagnostics dep would form a cycle with Configuration). Joins the §4.1 / spec dep-claim correction pattern.
- **All Platform Move candidates targeted Configuration, not Platform.** Spec hedged "Platform or Configuration"; reality is 4 of 4 → Configuration (each imports CodeEditorConfiguration, and Platform is upstream of Configuration, so the files cannot live in Platform).
- **`Core/Configuration/EditorConfiguration+CodeFolding.swift` stayed in umbrella (pre-execution Keep).** Self-review during spec authoring reclassified it Keep — its single function returns `CodeFoldingConfiguration` which §6.2.8a kept in umbrella; moving the bridge would invert Configuration → umbrella dep direction. Recorded as the §6.2.8a "consumers stay where the type stays" pattern.
- **Zero access-modifier promotions.** Every moved type was already `public` (with explicit `public init`s where applicable) since each file's public surface had been audited during the original carve-out that filed the file into `Core/`. Smallest promotion surface in the entire §6.2.7→§6.2.12a series, tying §6.2.8d Search / §6.2.8f Workspace / §6.2.8e Annotations.
- **Productization unchanged.** No new `.library` products. Existing products (`CodeEditorConfiguration` not productized; `CodeEditorTextModel` not productized; `CodeEditorSymbols` not productized; etc.) keep their visibility through the umbrella as before. Consumers doing `import CodeEditorPlugin` see no API removal.
- **Consumer ripple counts** — derived via `git log -1 --stat <commit>` for each Task 2 / 3 / 5 / 6 commit. Insert one bullet per task with the actual numeric counts of files that gained imports. Task 6's count is verified plan-time: 4 files (`Core/EditorState.swift`, `EditorStateConformanceTests`, `EditorStateTests`, `EditorBreadcrumbSnapshots`); `CodeEditorUITests` target gained `CodeEditorSymbols` as a direct dep.
- **No public-API removals from umbrella.** All previously-public umbrella surface compiles unchanged.
- **No new test targets.** Per-target test split remains deferred to §6.2.15. All test consumers continue to live in `CodeEditorPluginTests` / `CodeEditorUITests` with new imports added alongside their existing `@testable import CodeEditorPlugin` (kept defensively per the §6.2.8d "don't blanket-drop @testable" lesson).
- **Net Core/ file count drop:** 138 → 128 (-10, -7.2%). Umbrella total: 232 → 222 (-4.3%).
```

Fill in the actual consumer counts after the execution-time greps complete.

- [ ] **Step 4b: Append the two audit tables to the deviations block**

Immediately after the deviations bullets in NEXT.md §6.0, append:

```markdown

**§6.2.12a F3 sub-bucket audit table.**

| File | Current location | Disposition | Target (if Move) | Rationale |
|---|---|---|---|---|
| `AnnotationsDataSource.swift` | `Core/Annotations/` | Keep | — | Protocol requirement takes `CodeEditorView` (§6.2.8e) |
| `EditorConfiguration+CodeFolding.swift` | `Core/Configuration/` | Keep | — | Returns `CodeFoldingConfiguration` (umbrella-resident §6.2.8a) — move would invert dep direction |
| `EditorDocument.swift` | `Core/Documents/` | Keep | — | Stores `Language?` (CodeEditorLanguages — downstream of TextModel) |
| `EditorDocuments.swift` | `Core/Documents/` | Keep | — | Accepts `Language` parameter (CodeEditorLanguages — downstream of TextModel) |
| `CodeFoldingConfiguration.swift` | `Core/Folding/` | Keep | — | Three consumers all umbrella-resident (§6.2.8a) |
| `CodeFoldingEngine.swift` | `Core/Folding/` | Keep | — | `CodeEditorView`-coupled (§6.2.8a) |
| `FoldingOperationsService.swift` | `Core/Folding/` | Keep | — | `CodeEditorView`-coupled (§6.2.8a) |
| `FoldPresentationStrategy.swift` | `Core/Folding/` | Keep | — | `CodeEditorView`-coupled (§6.2.8a) |
| `LSPContentCoordinator.swift` | `Core/LSP/` | Keep | — | Stores `CodeEditorView?` (§6.2.9) |
| `LSPSemanticTokenProvider.swift` | `Core/LSP/` | Keep | — | Stores `CodeEditorView?` (§6.2.9) |
| `ContextMenuAction.swift` | `Core/Platform/` | Keep | — | 1 `CodeEditorView` ref |
| `ContextMenuBuilder.swift` | `Core/Platform/` | Keep | — | 1 `CodeEditorView` ref |
| `ContextMenuCoordinator.swift` | `Core/Platform/` | Keep | — | 31 `CodeEditorView` refs |
| `CrossPlatformCoordinator.swift` | `Core/Platform/` | Keep | — | 9 `CodeEditorView` refs |
| `CrossPlatformCoordinator+AppKitExtensions.swift` | `Core/Platform/` | Keep | — | 9 `CodeEditorView` refs |
| `CrossPlatformCoordinator+UIKitExtensions.swift` | `Core/Platform/` | Keep | — | 11 `CodeEditorView` refs |
| `DeviceType+RecommendedConfiguration.swift` | `Core/Platform/` | Move (zero-touch) | `CodeEditorConfiguration` | No `CodeEditorView` ref; imports CodeEditorConfiguration + Platform + Foundation |
| `InputCoordinator.swift` | `Core/Platform/` | Keep | — | 20 `CodeEditorView` refs |
| `PlatformAdjustments+Extensions.swift` | `Core/Platform/` | Move (zero-touch) | `CodeEditorConfiguration` | No `CodeEditorView` ref; imports CodeEditorConfiguration + Foundation + AppKit/UIKit |
| `PlatformCapabilities+RecommendedConfiguration.swift` | `Core/Platform/` | Move (zero-touch) | `CodeEditorConfiguration` | No `CodeEditorView` ref; imports CodeEditorConfiguration + Platform + Foundation |
| `PlatformConfigurations.swift` | `Core/Platform/` | Keep | — | Imports CodeEditorDiagnostics → cycles with Configuration if moved |
| `TextInputFeatures.swift` | `Core/Platform/` | Move (zero-touch) | `CodeEditorConfiguration` | No `CodeEditorView` ref; imports CodeEditorConfiguration + Foundation + AppKit/UIKit |
| `ToolbarCoordinator.swift` | `Core/Platform/` | Keep | — | 2 `CodeEditorView` refs (`ToolbarItem` typealias bridge, §6.2.6) |
| `UnifiedDrawingCoordinator.swift` | `Core/Platform/` | Keep | — | 1 `CodeEditorView` ref |
| `SearchReplaceEngine.swift` | `Core/Search/` | Keep | — | Heavy `CodeEditorView` coupling (§6.2.8d) |
| `SymbolNavigator.swift` | `Core/Symbols/` | Keep | — | 5 `CodeEditorView` member accesses (§6.2.8b) |
| `AsyncSyntaxHighlighter.swift` | `Core/SyntaxHighlighting/` | Keep | — | `CodeEditorView`-coupled (§6.2.7) |
| `HighlightProviderState.swift` | `Core/SyntaxHighlighting/` | Keep | — | `CodeEditorView`-coupled (§6.2.7) |
| `RangeAttributeApplier.swift` | `Core/SyntaxHighlighting/` | Keep | — | `CodeEditorView`-coupled (§6.2.7) |
| `RangeBasedHighlightingController.swift` | `Core/SyntaxHighlighting/` | Keep | — | `CodeEditorView`-coupled (§6.2.7) |
| `RangeHighlightProviding.swift` | `Core/SyntaxHighlighting/` | Keep | — | `CodeEditorView`-coupled (§6.2.7) |
| `RegexQuery/RegexRangeHighlightProvider.swift` | `Core/SyntaxHighlighting/RegexQuery/` | Keep | — | `CodeEditorView`-coupled (§6.2.7) |
| `StreamingHighlighter.swift` | `Core/SyntaxHighlighting/` | Keep | — | `CodeEditorView`-coupled (§6.2.7) |
| `SyntaxHighlighterRangeAdapter.swift` | `Core/SyntaxHighlighting/` | Keep | — | `CodeEditorView`-coupled (§6.2.7) |
| `VisibleRangeProvider.swift` | `Core/SyntaxHighlighting/` | Keep | — | `CodeEditorView`-coupled (§6.2.7) |
| `BackgroundProcessor.swift` | `Core/Text/` | Move (zero-touch) | `CodeEditorTextModel` | No `CodeEditorView` ref; Foundation only |
| `LineGeometryEditHandler.swift` | `Core/Text/` | Keep | — | 2 `CodeEditorView` refs |
| `ModernTextKitHelper.swift` | `Core/Text/` | Keep | — | Imports CodeEditorSyntaxHighlighting (downstream of TextModel) |
| `ParagraphStyleCache.swift` | `Core/Text/` | Move (zero-touch) | `CodeEditorTextModel` | No `CodeEditorView` ref; AppKit + UIKit + Platform + Foundation |
| `TemporaryAttributesStore.swift` | `Core/Text/` | Move (zero-touch) | `CodeEditorTextModel` | No `CodeEditorView` ref; AppKit only |
| `TextEditEventHub.swift` | `Core/Text/` | Keep | — | 1 `CodeEditorView` ref |
| `TextKit2PerformanceHelper.swift` | `Core/Text/` | Keep | — | Imports CodeEditorDiagnostics (downstream of TextModel) |
| `TextKit2RenderingOptimizer.swift` | `Core/Text/` | Keep | — | Imports CodeEditorDiagnostics + CodeEditorSyntaxHighlighting (both downstream of TextModel) |
| `TextKitBridge.swift` | `Core/Text/` | Keep | — | 1 `CodeEditorView` ref |
| `TextKitLineNumberHelper.swift` | `Core/Text/` | Keep | — | 3 `CodeEditorView` refs |
| `TextLayoutFragment.swift` | `Core/Text/` | Move (zero-touch) | `CodeEditorTextModel` | No `CodeEditorView` ref; imports CodeEditorPlatform |

**Summary:** 46 F3 sub-bucket files; 8 Move (zero-touch); 38 Keep.

**§6.2.12a root-file triage table.**

| File | Disposition | Target (if Move) / §6.2.12 home (if Defer) | Rationale |
|---|---|---|---|
| `CodeEditorView.swift` | Bucket 1 (Stay) | editor-surface | The umbrella class |
| `CodeEditorView+AccessibilityExtensions.swift` ... `CodeEditorView+TrackPerformance.swift` (24 slices) | Bucket 1 (Stay) | editor-surface | Partial-file extensions of CodeEditorView |
| `CodeEditorViewDelegate.swift`, `CodeEditorViewDelegateProxy.swift`, `CodeEditorViewProtocol.swift` | Bucket 1 (Stay) | editor-surface | CodeEditorView companions |
| `UnifiedTextView+Extensions.swift` | Bucket 1 (Stay) | editor-surface | Extends UnifiedTextView (umbrella) |
| `EditorConfiguration+ApplyTextInputFeatures.swift` | Bucket 2: Move (zero-touch) | `CodeEditorConfiguration` | 9-line extension; depends on Task 2 shipping TextInputFeatures first |
| `BreadcrumbComponent.swift` | Bucket 2: Move (zero-touch) | `CodeEditorSymbols` | Pure data type; Foundation only |
| `ActorCoordinator.swift` | Bucket 3 (Defer) | editor-surface (Actors cluster) | §6.2.12 disposition |
| `AsyncOperationErrors.swift` | Bucket 3 (Defer) | editor-surface | Residual after §6.2.7 SH split |
| `CodeEditorAPI.swift` | Bucket 3 (Defer) | editor-surface | Public façade |
| `CodeEditorDependencies.swift` | Bucket 3 (Defer) | editor-surface | Dependency keys |
| `CodeEditorRenderingDiagnostics.swift` | Bucket 3 (Defer) | editor-surface | Rendering instrumentation |
| `CodeFoldingCoordinatorService.swift` | Bucket 3 (Defer) | editor-surface | Orchestrates Core/Folding/ |
| `DirtyTracker.swift` | Bucket 3 (Defer) | editor-surface | Consumed during typing |
| `EditorEvent.swift`, `EditorEventHandler.swift`, `EditorEventPublisher.swift`, `EditorEventTypes.swift` | Bucket 3 (Defer) | editor-surface (event-system cluster) | Possible sub-target candidate |
| `EditorInteractionState.swift`, `EditorState.swift`, `EditorStateBridge.swift`, `SelectionState.swift` | Bucket 3 (Defer) | editor-surface (state cluster) | §6.2.12 disposition |
| `EditorLayoutService.swift` | Bucket 3 (Defer) | editor-surface | §6.2.11 reclassification anchor |
| `EditorRuntime.swift` | Bucket 3 (Defer) | editor-surface | Top-level orchestrator |
| `GutterSizingService.swift`, `LineNumberCalculationService.swift` | Bucket 3 (Defer) | editor-surface | §6.2.11 reclassification anchor |
| `IOSLargeFileOptimizer.swift` | Bucket 3 (Defer) | editor-surface | 3 `CodeEditorView` casts (§6.2.10) |
| `LanguageDetectionService.swift` | Bucket 3 (Defer) | editor-surface — flag for §6.2.12 re-audit (possible move to CodeEditorLanguages) | |
| `MemoryManagementCoordinator.swift` | Bucket 3 (Defer) | editor-surface | Creates LSPManager, public API |
| `SendableTypes.swift` | Bucket 3 (Defer) | editor-surface — flag for §6.2.12 re-audit (possible move to Common) | |
| `SyntaxHighlightingService.swift` | Bucket 3 (Defer) | editor-surface | Orchestrates Core/SyntaxHighlighting/ |
| `TabModel.swift` | Bucket 3 (Defer) | editor-surface — flag for §6.2.12 re-audit (possible application-layer move) | |
| `TextEditingService.swift`, `TextKitSetupHelper.swift`, `TextSystem.swift`, `TextSystemStyler.swift`, `ThreePhaseTextSystemStyler.swift`, `TokenSystemValidator.swift` | Bucket 3 (Defer) | editor-surface (TextKit2 orchestration) | F3'd from Core/Text/ per §6.2.3 |
| `TextViewDelegateMultiplexer.swift`, `TextViewDelegateParticipant.swift` | Bucket 3 (Defer) | editor-surface | CodeEditorView delegate companions |
| `UnifiedEventSystem.swift` | Bucket 3 (Defer) | editor-surface (event-system cluster) | §6.2.12 disposition |

**Summary:** 64 root files; 29 Bucket 1 Stay; 2 Bucket 2 Move; 33 Bucket 3 Defer to §6.2.12.
```

- [ ] **Step 5: Update §6.2 Step 12 status note to reference §6.2.12a**

Locate `12. **Split \`Core/\`** —` in NEXT.md §6.2. Add a leading note:

```
old_string:
12. **Split `Core/`** — the `Actors/` subdirectory, `ActorCoordinator`, `CodeEditorAPI`, `CodeEditorDependencies`, `CodeEditorError`, `CodeEditorViewProtocol`,

new_string:
12. **Split `Core/`** — (preceded by §6.2.12a prep: 10 files moved out, audit tables recorded.) The `Actors/` subdirectory, `ActorCoordinator`, `CodeEditorAPI`, `CodeEditorDependencies`, `CodeEditorError`, `CodeEditorViewProtocol`,
```

- [ ] **Step 6: Update §10 Suggested next session**

Locate `Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8d, 6.2.8e, 6.2.8f, 6.2.8g, 6.2.9, 6.2.10, and 6.2.11 are done` in NEXT.md §10. Append `§6.2.12a` to the done list:

```
old_string:
Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8d, 6.2.8e, 6.2.8f, 6.2.8g, 6.2.9, 6.2.10, and 6.2.11 are done (see §6.0). Remaining work:

new_string:
Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8d, 6.2.8e, 6.2.8f, 6.2.8g, 6.2.9, 6.2.10, 6.2.11, and §6.2.12a (prep) are done (see §6.0). Remaining work:
```

- [ ] **Step 7: Update §10 6.2.12 description to reflect smaller surface**

Locate `**6.2.12 split \`Core/\`** — the riskiest single step.` in NEXT.md §10. Update the file-count note:

```
old_string:
**6.2.12 split `Core/`** — the riskiest single step. Dedicated half-day. Don't combine with anything else. The `Core/` dir has grown during phases 0–4 — `Core/Annotations/`, `Core/Configuration/`, `Core/Documents/`, `Core/Folding/`, `Core/Layout/`, `Core/LSP/`, `Core/Platform/`, `Core/Search/`, `Core/Symbols/`, `Core/SyntaxHighlighting/`, `Core/Text/` subdirs were created as F3 catch-alls. Re-evaluate which semantic homes survive into the eventual `CodeEditorView` target vs. spill into other feature targets.

new_string:
**6.2.12 split `Core/`** — the riskiest single step. Dedicated half-day. Don't combine with anything else. The `Core/` dir is 128 files post-§6.2.12a (down from 138). The §6.2.12a audit table records the bucket-1 / bucket-2 / bucket-3 classifications for the 62 top-level Core/ files: 29 stay (CodeEditorView + 24 +Extensions + 3 delegate/protocol + UnifiedTextView+Extensions), 0 root-bucket-2 candidates remaining (both shipped in §6.2.12a), 33 standalone-service files awaiting §6.2.12 disposition. F3 sub-buckets still present: `Core/Annotations/` (1 — AnnotationsDataSource Keep), `Core/Configuration/` (1 — EditorConfiguration+CodeFolding Keep), `Core/Documents/` (2 — Keep), `Core/Folding/` (4 — Keep), `Core/LSP/` (2 — Keep), `Core/Platform/` (10 — 9 View-coupled Keep + PlatformConfigurations Keep), `Core/Search/` (1 — Keep), `Core/Symbols/` (1 — Keep), `Core/SyntaxHighlighting/` (9 — Keep), `Core/Text/` (7 — 4 View-coupled + 3 downstream-dep Keep). `Core/Layout/` (21) and `Core/Actors/` (6) are §6.2.11/§6.2.12 stay-sets. Re-evaluate which semantic homes survive into the eventual `CodeEditorView` target vs. spill into other feature targets. The §6.2.12a audit-table bucket-3 list (`LanguageDetectionService`, `SendableTypes`, `TabModel` flagged for re-audit) is the priority worklist.
```

- [ ] **Step 8: Update CLAUDE.md "232 Swift source files" estimate**

Locate `5 top-level directories in the umbrella target, 232 Swift source files in the umbrella target` in `CLAUDE.md`. Update the count:

```
old_string:
5 top-level directories in the umbrella target, 232 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.11), and 589 Swift source files under `Sources/`.

new_string:
5 top-level directories in the umbrella target, 222 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.11 / §6.2.12a), and 589 Swift source files under `Sources/`.
```

(If actual post-execution Core total differs from the 222 estimate, use the actual number from Step 2.)

- [ ] **Step 9: Commit documentation**

```bash
git add NEXT.md CLAUDE.md
git commit -m "$(cat <<'EOF'
Document §6.2.12a Core/ prep extraction in NEXT.md and CLAUDE.md

Adds §6.2.12a row + deviations block to NEXT.md §6.0; updates §6.2 Step 12
to reference the prep; updates §10's Core/ surface description with the
shrunk file count and remaining sub-bucket disposition. Updates CLAUDE.md
umbrella file count from 232 to 222.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Final verification

**Files:** read-only.

- [ ] **Step 1: Final full test run**

Run: `swift test --parallel`
Expected: all PASS. (This is the second full run; the first was Task 7 Step 1 before the documentation commit. This run confirms the documentation commit doesn't change behavior — purely a sanity check.)

- [ ] **Step 2: Verify Core/ post-state**

Run:
```bash
find Sources/CodeEditorPlugin/Core -maxdepth 1 -type f -name "*.swift" | wc -l
find Sources/CodeEditorPlugin/Core -name "*.swift" | wc -l
```

Expected (10 moves landed): 62 top-level; 128 total.

- [ ] **Step 3: Verify commit log**

Run: `git log --oneline -10`

Expected: 5 new commits since `1a4f3a9` (spec commit):
1. Relocate Core/Platform/ Move-eligible files (§6.2.12a prep)
2. Relocate Core/Text/ Move-eligible files to CodeEditorTextModel (§6.2.12a prep)
3. Relocate EditorConfiguration+ApplyTextInputFeatures to CodeEditorConfiguration (§6.2.12a prep)
4. Relocate BreadcrumbComponent to CodeEditorSymbols (§6.2.12a prep)
5. Document §6.2.12a Core/ prep extraction in NEXT.md and CLAUDE.md

If any commit is missing because a task reclassified its candidates to Keep mid-execution, that's fine — the commit count drops to match. Confirm with the user before pushing.

- [ ] **Step 4: Done**

Plan complete. The §6.2.12 main split can now proceed against a shrunk, audit-trail-documented `Core/`.
