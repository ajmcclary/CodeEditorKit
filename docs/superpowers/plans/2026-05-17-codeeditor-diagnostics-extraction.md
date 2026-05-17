# CodeEditorDiagnostics Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract `Sources/CodeEditorPlugin/Performance/` into a new SPM target `CodeEditorDiagnostics` (NEXT.md §6.2.10, reordered ahead of §6.2.7 to unblock SyntaxHighlighting). Delete two dead Performance files, relocate one misfiled file to umbrella `Layout/`, and split a hybrid extension file in `SyntaxHighlighting/` so the `MemoryMonitor` extension travels with `MemoryMonitor`.

**Architecture:** Three commits on `main`. Commit 1 is umbrella-only cleanup (purely additive/subtractive). Commit 2 declares the new SPM target + product, `git mv`s the directory, and sweeps imports across umbrella + tests. Commit 3 is doc updates (NEXT.md + CLAUDE.md). No new tests — existing test suite is the regression net.

**Tech Stack:** Swift 6.3, SPM, SwiftLint (strict), Swift Testing + XCTest hybrid, `IssueReporting` (from `xctest-dynamic-overlay`).

**Source spec:** `docs/superpowers/specs/2026-05-17-codeeditor-diagnostics-extraction-design.md` (commit `b2aa322f`).

---

## Pre-flight context (read before Task 1)

Six new SPM targets currently exist alongside the umbrella `CodeEditorPlugin` target: `CodeEditorCommon`, `CodeEditorTextModel`, `CodeEditorPlatform`, `CodeEditorConfiguration`, `CodeEditorTheming`, `CodeEditorLanguages`, and the historical `CodeEditorDesignTokens`. The umbrella `CodeEditorPlugin` target's `exclude:` list is `["Info.plist", "Languages"]`. After this plan lands, it becomes `["Info.plist", "Languages", "Performance"]` (or `["Info.plist", "Performance"]` if you `git mv` the Languages source-root first — don't; that's a separate concern).

Phase A baseline (commit `8bac96cb`) promoted 116 symbols to `package` access. `package` is sufficient across same-package target boundaries; promote to `public` **only** if an external consumer of `CodeEditorPlugin` needs the symbol.

Working directory is `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin`. Working branch is `main`. The user works directly on `main` per stored feedback (`feedback_branch_strategy.md`).

The auto-memory `feedback_test_confirmations.md` says: skip full `swift test --parallel` after additive-only steps; trust the build and run targeted tests instead. This plan honors that — Task 2's cleanup commit uses `swift build` + targeted tests; Task 3's extraction commit runs the full pipeline.

If any task fails mid-way, rollback is `git restore .` (uncommitted work) or `git reset --hard HEAD~1` (last commit). The auto-memory `feedback_no_stash.md` says: don't shuffle tracked changes via `git stash` — reason from the diff instead.

The user has already approved the three-commit sequencing during brainstorming. Do not break commit 1's actions into multiple commits — keep them squashed into a single cleanup commit as the spec specifies.

---

## Task 1: Precondition verification (no commit)

**Files:**
- Read-only: `Sources/CodeEditorPlugin/Performance/*.swift`, `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator+Extensions.swift`, `Package.swift`

**Context:** The spec was written 2026-05-17 against `main` at commit `c95a1ea1`. Confirm the assumptions still hold before touching anything. Audit `HardwareAcceleration.swift` to decide whether it's dead code (and should be deleted alongside the other two) or alive (and rides along into Diagnostics).

- [ ] **Step 1.1: Verify Performance/ contents match the spec**

```bash
ls Sources/CodeEditorPlugin/Performance/
```

Expected output: exactly 17 `.swift` files — `AdaptivePerformanceMode.swift`, `FrameRateMonitor.swift`, `HardwareAcceleration.swift`, `IOSLargeFileOptimizer.swift`, `IncrementalSyntaxHighlighter.swift`, `LRUCache.swift`, `MemoryMonitor.swift`, `OptimizedLineIndexCache.swift`, `PerformanceBudget.swift`, `PerformanceInsights.swift`, `PerformanceMonitor.swift`, `PerformanceObservation.swift`, `PerformanceTypes.swift`, `PerformanceViews.swift`, `ProductionPerformanceMetrics.swift`, `UnifiedPerformanceSystem.swift`, `ViewportManager.swift`.

If a file is missing or new files exist, STOP and re-validate the spec inventory before continuing.

- [ ] **Step 1.2: Verify IncrementalSyntaxHighlighter has zero callers**

```bash
grep -rln 'IncrementalSyntaxHighlighter' Sources/ Tests/ 2>/dev/null | grep -v '/Performance/IncrementalSyntaxHighlighter.swift'
```

Expected output: empty (no lines). If any file is returned, STOP — the spec's dead-code claim no longer holds and the file needs to either stay or have its consumers refactored first.

- [ ] **Step 1.3: Verify OptimizedLineIndexCache has zero callers**

```bash
grep -rln 'OptimizedLineIndexCache' Sources/ Tests/ 2>/dev/null | grep -v '/Performance/OptimizedLineIndexCache.swift'
```

Expected output: empty. Same stop condition as Step 1.2 if anything is returned.

- [ ] **Step 1.4: Verify ViewportManager has only the documented test consumers**

```bash
grep -rln 'ViewportManager' Sources/ Tests/ 2>/dev/null | grep -v '/Performance/ViewportManager.swift'
```

Expected output: exactly two files — `Tests/CodeEditorPluginTests/IntegrationTests.swift` and `Tests/CodeEditorPluginTests/LargeFilePerformanceTests.swift`. Both are in the umbrella test target, so the relocation within umbrella source is invisible to them. If any **production** code under `Sources/` references `ViewportManager`, STOP — that consumer needs handling.

- [ ] **Step 1.5: Audit HardwareAcceleration for consumers**

```bash
grep -rln 'HardwareAcceleration' Sources/ Tests/ 2>/dev/null | grep -v '/Performance/HardwareAcceleration.swift'
```

Record the result. Two possible outcomes:
- **Output is empty** → `HardwareAcceleration` is dead code. Fold its deletion into Task 2.
- **Output is non-empty** → `HardwareAcceleration` has consumers. It rides along into Diagnostics in Task 3 as `internal`. No change to Task 2.

- [ ] **Step 1.6: Verify SH coordinator extension file has the expected two-extension shape**

```bash
grep -n '^extension ' Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator+Extensions.swift
```

Expected output: two lines, one `extension SyntaxHighlightingCoordinator` near the top and one `extension MemoryMonitor` further down. If the shape has changed, re-confirm the line numbers before doing the split in Task 2.

- [ ] **Step 1.7: Confirm baseline build is green**

```bash
swift build
```

Expected: success. If the build is already broken on `main`, STOP — the extraction should start from a green baseline.

- [ ] **Step 1.8: Confirm baseline test suite is green (targeted, not full)**

```bash
swift test --filter MemoryMonitorResetPeakTests
swift test --filter FrameRateMonitorTests
swift test --filter UnifiedPerformanceSystemNonThrowingTrackTests
```

Expected: each invocation reports passing tests. If any of these baseline tests fail before any change, STOP and investigate — the regression net is the existing test suite, so a red baseline means no signal.

---

## Task 2: Commit 1 — Pre-extraction cleanup

**Files:**
- Delete: `Sources/CodeEditorPlugin/Performance/IncrementalSyntaxHighlighter.swift`
- Delete: `Sources/CodeEditorPlugin/Performance/OptimizedLineIndexCache.swift`
- Conditionally delete: `Sources/CodeEditorPlugin/Performance/HardwareAcceleration.swift` (only if Step 1.5 returned empty)
- Move: `Sources/CodeEditorPlugin/Performance/ViewportManager.swift` → `Sources/CodeEditorPlugin/Layout/ViewportManager.swift`
- Modify: `Sources/CodeEditorPlugin/Performance/LRUCache.swift` (remove `import CodeEditorLanguages`)
- Modify: `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator+Extensions.swift` (remove the `extension MemoryMonitor` block at lines 39–67)
- Create: `Sources/CodeEditorPlugin/Performance/MemoryMonitor+AvailableMemory.swift` (the extracted MemoryMonitor extension)

**Context:** This task lands as a single commit. All its sub-steps must be green together before the commit happens. The file relocations stay inside the umbrella's source tree — no `Package.swift` edits in this task.

- [ ] **Step 2.1: Delete IncrementalSyntaxHighlighter.swift**

```bash
git rm Sources/CodeEditorPlugin/Performance/IncrementalSyntaxHighlighter.swift
```

- [ ] **Step 2.2: Delete OptimizedLineIndexCache.swift**

```bash
git rm Sources/CodeEditorPlugin/Performance/OptimizedLineIndexCache.swift
```

- [ ] **Step 2.3: Conditionally delete HardwareAcceleration.swift**

Only if Step 1.5 returned **empty** (no consumers):

```bash
git rm Sources/CodeEditorPlugin/Performance/HardwareAcceleration.swift
```

Otherwise skip this step.

- [ ] **Step 2.4: Drop the stale `import CodeEditorLanguages` from LRUCache.swift**

Open `Sources/CodeEditorPlugin/Performance/LRUCache.swift` and remove the line `import CodeEditorLanguages` (currently line 1). Save.

Verify with:

```bash
grep -n 'CodeEditorLanguages\|^import' Sources/CodeEditorPlugin/Performance/LRUCache.swift | head -5
```

Expected output: the `import CodeEditorLanguages` line is gone; `import Foundation` remains.

- [ ] **Step 2.5: Relocate ViewportManager.swift to Layout/**

```bash
git mv Sources/CodeEditorPlugin/Performance/ViewportManager.swift Sources/CodeEditorPlugin/Layout/ViewportManager.swift
```

- [ ] **Step 2.6: Read the existing SH coordinator extension file**

Open `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator+Extensions.swift` and confirm:
- Lines 1–38 contain `import CodeEditorLanguages`, `import Foundation`, the `// MARK: - SyntaxHighlightingCoordinator Extensions` block, and `extension SyntaxHighlightingCoordinator { ... }` (with `supportsLanguage`, `supportedLanguages`, `highlighter(for:)`).
- Lines 39–67 contain `// MARK: - MemoryMonitor Extension for Available Memory` and `extension MemoryMonitor { @MainActor public var availableMemoryMB: Double { ... } }`.

If the file shape has drifted from Step 1.6's check, re-confirm the line ranges before editing.

- [ ] **Step 2.7: Create the new MemoryMonitor extension file**

Create `Sources/CodeEditorPlugin/Performance/MemoryMonitor+AvailableMemory.swift` with the following exact contents:

```swift
import Foundation

// MARK: - MemoryMonitor Extension for Available Memory

extension MemoryMonitor {
    /// Get available memory in MB (estimated based on current usage)
    @MainActor
    public var availableMemoryMB: Double {
        // For simplicity, assume we have at least 100MB available if not under pressure
        // This is a reasonable assumption for modern devices
        let pressure = getMemoryPressure()

        switch pressure {
        case .normal:
            return 500.0 // Plenty of memory available

        case .warning:
            return 100.0 // Some memory available

        case .critical:
            return 50.0 // Very limited memory

        case .urgent:
            return 10.0 // Almost no memory
        }
    }
}
```

This file deliberately lives in `Performance/` (not `SyntaxHighlighting/`) because Task 3 will `git mv` `Performance/` wholesale into `Sources/CodeEditorDiagnostics`. Don't add `import CodeEditorLanguages` — the extension doesn't reference any Language types.

- [ ] **Step 2.8: Remove the MemoryMonitor extension from the SH coordinator file**

Edit `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator+Extensions.swift` to remove lines 39–67 (the `// MARK: - MemoryMonitor Extension for Available Memory` block and the entire `extension MemoryMonitor { ... }` that follows). Keep lines 1–38 (imports + `extension SyntaxHighlightingCoordinator` block) exactly as they are.

After the edit, verify the file no longer contains a MemoryMonitor extension:

```bash
grep -n 'extension MemoryMonitor\|extension SyntaxHighlightingCoordinator' Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator+Extensions.swift
```

Expected output: exactly one line, the `extension SyntaxHighlightingCoordinator` declaration. No `extension MemoryMonitor`.

- [ ] **Step 2.9: Build the umbrella**

```bash
swift build
```

Expected: success. The umbrella is still a single source tree, so the relocated and split files compile together with the rest of the umbrella code. If the build fails on a same-target visibility issue, the extension's call to `getMemoryPressure()` may need an access modifier check on `MemoryMonitor` — but same-target rules should make this a no-op.

- [ ] **Step 2.10: SwiftLint --fix then lint**

```bash
swiftlint --fix && swiftlint
```

Expected: zero violations after `--fix`. SwiftLint strict mode is enabled — warnings escalate to errors.

- [ ] **Step 2.11: Targeted test verification**

```bash
swift test --filter MemoryMonitorResetPeakTests
swift test --filter FrameRateMonitorTests
swift test --filter SyntaxHighlightingPerformanceOptimizationTests
swift test --filter IntegrationTests
```

Expected: each invocation reports passing tests. `IntegrationTests` is included because it's one of the two files that references `ViewportManager`; the relocation should be invisible to it (same target).

- [ ] **Step 2.12: Commit**

```bash
git add -A
git status
```

Confirm the staged changes match the spec: deletions of dead files, the `git mv` of ViewportManager, the new `MemoryMonitor+AvailableMemory.swift`, the modified `LRUCache.swift` and `SyntaxHighlightingCoordinator+Extensions.swift`. Then:

```bash
git commit -m "$(cat <<'EOF'
Cleanup Performance/ before CodeEditorDiagnostics extraction

Drop two dead files (IncrementalSyntaxHighlighter, OptimizedLineIndexCache —
both zero callers), relocate ViewportManager.swift into Layout/ for the
future CodeEditorLayout extraction (§6.2.11), split the hybrid extension
file in SyntaxHighlighting/ so the MemoryMonitor extension travels with
MemoryMonitor into the next commit's Diagnostics target, and drop a
stale `import CodeEditorLanguages` from LRUCache.swift.

Pre-flight for §6.2.10. Umbrella stays single-source-tree; no Package.swift
changes. swift build + targeted tests green.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

If Step 2.3 was executed (HardwareAcceleration deleted), add a line to the commit body: "Also dropped HardwareAcceleration.swift after grep confirmed zero consumers."

- [ ] **Step 2.13: Confirm clean status**

```bash
git status && git log --oneline -3
```

Expected: working tree clean; the new commit appears at HEAD.

---

## Task 3: Commit 2 — Extract CodeEditorDiagnostics

**Files:**
- Modify: `Package.swift` (add target, add product, add to umbrella deps, add to test deps, add to umbrella exclude)
- Move: `Sources/CodeEditorPlugin/Performance/` → `Sources/CodeEditorDiagnostics/` (all 14 remaining files including `MemoryMonitor+AvailableMemory.swift`; or 13 if HardwareAcceleration was deleted in Task 2)
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorDependencies.swift` (add `import CodeEditorDiagnostics`)
- Modify: ~28 umbrella source files (add `import CodeEditorDiagnostics`)
- Modify: ~20+ test files (add `import CodeEditorDiagnostics`)
- Conditionally modify: `Sources/CodeEditorUI/`, `Sources/CodeEditorSample/` (add imports + Package.swift dependencies if they reference moved symbols)

**Context:** This is the main extraction commit. The build will fail repeatedly after the `git mv` until every consumer gains its `import CodeEditorDiagnostics`. The compiler is the source of truth for which files need updating — don't try to enumerate exhaustively up front.

- [ ] **Step 3.1: Read Package.swift to locate insertion points**

Open `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Package.swift`. Locate:
- The `products:` array around lines 53–90. Find the existing `.library(name: "CodeEditorDesignTokens", ...)` declaration — the new product entry will sit alongside it.
- The `targets:` array. Find the existing `.target(name: "CodeEditorLanguages", ...)` declaration (around line 121) — the new target entry will sit immediately after it (alphabetical-ish ordering matches existing pattern).
- The `.target(name: "CodeEditorPlugin", ...)` umbrella declaration (around line 131) — its `dependencies:` and `exclude:` lists need editing.
- The `.testTarget(name: "CodeEditorPluginTests", ...)` declaration (around line 183) — its `dependencies:` list needs `"CodeEditorDiagnostics"`.

- [ ] **Step 3.2: Add the CodeEditorDiagnostics product to Package.swift**

In the `products:` array, after the existing `CodeEditorDesignTokens` library product entry, add:

```swift
        .library(
            name: "CodeEditorDiagnostics",
            targets: ["CodeEditorDiagnostics"]
        ),
```

Place it alphabetically — between `CodeEditorDesignTokens` and `CodeEditorPlugin`.

- [ ] **Step 3.3: Add the CodeEditorDiagnostics target to Package.swift**

In the `targets:` array, after the `CodeEditorLanguages` target declaration, add:

```swift
        .target(
            name: "CodeEditorDiagnostics",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorPlatform",
                "CodeEditorConfiguration",
                "CodeEditorLanguages",
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            path: "Sources/CodeEditorDiagnostics"
        ),
```

Do NOT add a `resources:` block — Performance/ has no resources (verified earlier).

- [ ] **Step 3.4: Add CodeEditorDiagnostics to the umbrella's dependencies and exclude list**

In the existing `.target(name: "CodeEditorPlugin", ...)` declaration:

Add `"CodeEditorDiagnostics"` to the `dependencies:` array (alphabetical placement: after `CodeEditorConfiguration`, before `CodeEditorLanguages`).

Add `"Performance"` to the `exclude:` array. After editing, the exclude list should be `["Info.plist", "Languages", "Performance"]` (order may vary; preserve existing order).

- [ ] **Step 3.5: Add CodeEditorDiagnostics to the test target's dependencies**

In the existing `.testTarget(name: "CodeEditorPluginTests", ...)` declaration, add `"CodeEditorDiagnostics"` to the `dependencies:` array.

- [ ] **Step 3.6: Move the Performance/ source root**

```bash
git mv Sources/CodeEditorPlugin/Performance Sources/CodeEditorDiagnostics
```

This carries all 14 (or 13) files including `MemoryMonitor+AvailableMemory.swift` introduced in Task 2.

- [ ] **Step 3.7: Add the import to CodeEditorDependencies.swift**

Open `Sources/CodeEditorPlugin/Core/CodeEditorDependencies.swift`. After the existing `import` lines, add:

```swift
import CodeEditorDiagnostics
```

Preserve alphabetical ordering of imports if that's the file's convention.

- [ ] **Step 3.8: First build attempt — drives the import sweep**

```bash
swift build 2>&1 | grep -E "error:|cannot find" | head -40
```

This will produce a list of compile errors of the form "cannot find 'MemoryMonitor' in scope" or "cannot find 'ProductionPerformanceMetrics' in scope" — one per umbrella source file that needs `import CodeEditorDiagnostics`.

Record the unique file paths from the errors.

- [ ] **Step 3.9: Add `import CodeEditorDiagnostics` to each umbrella file the compiler flagged**

For each unique file path from Step 3.8, add `import CodeEditorDiagnostics` after the existing imports. Preserve alphabetical ordering.

The spec predicts ~28 umbrella source files. The compiler is authoritative — don't add the import to files the compiler didn't flag.

- [ ] **Step 3.10: Second build attempt — verify umbrella green**

```bash
swift build 2>&1 | tee /tmp/diagnostics-build.log | tail -30
```

If errors remain, repeat Step 3.9 with the newly-flagged files. If errors are about access modifiers (e.g. "'X' is inaccessible due to 'internal' protection level"), proceed to Step 3.11.

- [ ] **Step 3.11: Audit + promote internal symbols crossed by the new target boundary**

```bash
grep -rn '^internal \|    internal ' Sources/CodeEditorDiagnostics/*.swift | head -40
```

For each `internal` declaration that the umbrella now consumes across the target boundary, promote it to `package` (NOT `public` — match the phase 0–3 pattern from `8bac96cb`).

Likely candidates from the spec's R1 risk: methods on `MemoryMonitor`, `ProductionPerformanceMetrics`, `UnifiedPerformanceSystem` that the umbrella SH coordinators call. The compiler errors from Step 3.10 will point at them precisely.

After promotions, run `swift build` again until green.

- [ ] **Step 3.12: Third build — verify full umbrella + Diagnostics build green**

```bash
swift build
```

Expected: success. If still failing, return to Step 3.9 or 3.11 as appropriate.

- [ ] **Step 3.13: Run the test target — drives the test-side import sweep**

```bash
swift test --no-parallel 2>&1 | grep -E "error:|cannot find" | head -40
```

`--no-parallel` so the error output isn't interleaved. Record the unique test file paths flagged.

- [ ] **Step 3.14: Add `import CodeEditorDiagnostics` to each flagged test file**

For each unique test file path from Step 3.13, add `import CodeEditorDiagnostics` after the existing imports.

The spec predicts ~20+ test files including (but not limited to) `FrameRateMonitorTests.swift`, `MemoryMonitorResetPeakTests.swift`, `MemoryMonitorDITests.swift`, `PerformanceInsightsRealMetricsTests.swift`, `UnifiedPerformanceSystemNonThrowingTrackTests.swift`, `EditorConfigurationPerformanceUnifiedSystemTests.swift`, `AsyncSyntaxHighlighterInstrumentationTests.swift`, `XCTestCase+PerformanceBudget.swift`.

- [ ] **Step 3.15: Check CodeEditorUI and CodeEditorSample for Performance references**

```bash
grep -rln 'MemoryMonitor\|ProductionPerformanceMetrics\|UnifiedPerformanceSystem\|FrameRateMonitor\|AdaptivePerformanceMode\|PerformanceBudget\|PerformanceInsights\|PerformanceMonitor\|PerformanceViews\|IOSLargeFileOptimizer\|HardwareAcceleration\|LRUCache' Sources/CodeEditorUI/ Sources/CodeEditorSample/ 2>/dev/null
```

For each file returned:
1. Add `import CodeEditorDiagnostics` to the file.
2. Add `"CodeEditorDiagnostics"` to the corresponding target's `dependencies:` in `Package.swift` (the `CodeEditorUI` or `CodeEditorSample` target declaration).

If the grep returns nothing, skip this step's edits — no changes needed.

- [ ] **Step 3.16: Snapshot test guard — check for PerformanceStatusView consumers**

```bash
grep -rln 'PerformanceStatusView' Tests/ Sources/ 2>/dev/null
```

For each file returned that doesn't already have it, add `import CodeEditorDiagnostics`.

- [ ] **Step 3.17: Full build**

```bash
swift build
```

Expected: success. Repeat 3.9 / 3.11 / 3.14 as the compiler dictates if anything is still red.

- [ ] **Step 3.18: SwiftLint --fix then lint**

```bash
swiftlint --fix && swiftlint
```

Expected: zero violations. SwiftLint strict mode is enabled.

- [ ] **Step 3.19: Confirm the new target is visible via swift package describe**

```bash
swift package describe 2>&1 | grep -A 2 CodeEditorDiagnostics
```

Expected: the output shows `CodeEditorDiagnostics` as a library target with `path: Sources/CodeEditorDiagnostics` and the four target deps.

- [ ] **Step 3.20: Confirm isolated builds**

```bash
swift build --target CodeEditorDiagnostics
swift build --target CodeEditorPlugin
swift build --target CodeEditorSample
```

Expected: each invocation succeeds.

- [ ] **Step 3.21: Targeted test verification**

```bash
swift test --filter MemoryMonitorResetPeakTests
swift test --filter FrameRateMonitorTests
swift test --filter PerformanceInsightsRealMetricsTests
swift test --filter UnifiedPerformanceSystemNonThrowingTrackTests
swift test --filter EditorConfigurationPerformanceUnifiedSystemTests
swift test --filter AsyncSyntaxHighlighterInstrumentationTests
swift test --filter IntegrationTests
```

Expected: each invocation reports passing tests.

- [ ] **Step 3.22: Full parallel test suite**

```bash
swift test --parallel
```

Expected: all tests pass. The spec's "additive-only steps" guidance does NOT apply here — this is a target boundary change that could surface concurrency or visibility regressions, so the full pipeline runs once.

- [ ] **Step 3.23: Manual sample-app smoke**

```bash
swift run CodeEditorSample
```

In the sample app:
1. Confirm a code file opens.
2. Confirm syntax highlighting renders.
3. Confirm typing works (per the auto-memory `project_nstextview_init_invariant.md` — Diagnostics extraction shouldn't touch the AppKit text-system wiring, but verify anyway).
4. If a performance overlay is exposed in the sample, confirm it still renders.

Quit the sample app cleanly. If anything regressed, do not commit — diagnose first.

- [ ] **Step 3.24: Commit**

```bash
git add -A
git status
```

Confirm the staged changes include:
- The `Package.swift` edits (new product, new target, umbrella + test deps, exclude).
- The directory move (14 or 13 files now under `Sources/CodeEditorDiagnostics/`).
- The umbrella `import CodeEditorDiagnostics` sweep.
- The test `import CodeEditorDiagnostics` sweep.
- Any access-modifier promotions in the moved files.
- Any `CodeEditorUI` / `CodeEditorSample` edits from Step 3.15.

Then commit:

```bash
git commit -m "$(cat <<'EOF'
Extract CodeEditorDiagnostics target (§6.2.10)

Performance/ becomes a separate SPM library target + product. Diagnostics
declares deps on Common + Platform + Configuration + Languages (phase 4,
not the leaf claimed in NEXT.md §4.1 — same correction §6.0 documented
for other targets). Productization per NEXT.md §6.3 makes instrumentation
opt-in for consumers who want to omit it from release builds.

Unblocks §6.2.7 (CodeEditorSyntaxHighlighting): the back-references in
the six SH files documented in NEXT.md §6.0 now become routine
`import CodeEditorDiagnostics` lines with no new marker protocols.

Full quality pipeline green: build, swiftlint --fix && swiftlint,
swift test --parallel, isolated target builds, manual sample-app smoke.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3.25: Confirm clean status**

```bash
git status && git log --oneline -4
```

Expected: working tree clean; the new commit at HEAD; Task 2's cleanup commit immediately below it.

---

## Task 4: Commit 3 — Doc updates (NEXT.md + CLAUDE.md)

**Files:**
- Modify: `NEXT.md` (§6.0 status table + new "Deviations during §6.2.10" subsection)
- Modify: `CLAUDE.md` (Source Tree section)

**Context:** This is the documentation follow-up. It records what landed, what deviated from the spec, and which row in the Source Tree to update. If no deviations occurred and no Source Tree changes are warranted, skip this task.

- [ ] **Step 4.1: Read NEXT.md §6.0 to locate the status table**

Open `NEXT.md`. Find §6.0 (the status table around lines 250–290 listing the targets already extracted). The table has columns: `Target | Commit | What landed | Direct deps`.

- [ ] **Step 4.2: Add the CodeEditorDiagnostics row to the status table**

After the existing `CodeEditorLanguages` row, add:

```markdown
| `CodeEditorDiagnostics` | `<commit hash from Task 3.24>` | 14 of 17 `Performance/` files (3 misfiled/dead: 2 deleted, 1 relocated to umbrella `Layout/`) + 1 split-out `MemoryMonitor+AvailableMemory.swift` from SH | Common, Platform, Configuration, Languages, IssueReporting |
```

Get the actual commit hash with `git log --oneline -2 | head -1`.

If HardwareAcceleration was also deleted in Task 2, change `14 of 17` to `13 of 17` and `3 misfiled/dead` to `4 misfiled/dead: 3 deleted, 1 relocated`.

- [ ] **Step 4.3: Add a "Deviations during §6.2.10" subsection to NEXT.md §6.0**

After the existing "Deviations during §6.2.6 `CodeEditorLanguages`" subsection in §6.0, add a new subsection:

```markdown
**Deviations during §6.2.10 `CodeEditorDiagnostics` (commit `<hash>`):**

- **Diagnostics is not a phase-6 leaf.** NEXT.md §4.1 originally claimed `Diag → only Common`. Reality after auditing the moving files: `AdaptivePerformanceMode` extends `EditorConfiguration.Performance` (Configuration dep); `AdaptivePerformanceMode` + `ProductionPerformanceMetrics` bucket metrics by `Language` (Languages dep); `MemoryMonitor` + `HardwareAcceleration` + `PerformanceInsights` + `PerformanceViews` use Platform types (Platform dep). Diagnostics ends up at **phase 4**, alongside the feature engines.
- **Dead code dropped en route.** `IncrementalSyntaxHighlighter.swift` (zero callers, imported `CodeEditorLanguages + CodeEditorTextModel` for no consumer value) and `OptimizedLineIndexCache.swift` (`@available(*, deprecated)`, zero callers, replacement lives in `CodeEditorTextModel`) deleted. [If HardwareAcceleration was deleted: add it here too.]
- **`ViewportManager.swift` relocated to umbrella `Layout/`** rather than carried into Diagnostics. Only consumed by two test files (`IntegrationTests`, `LargeFilePerformanceTests`); structurally a viewport/layout helper that travels with the future §6.2.11 `CodeEditorLayout` target.
- **Hybrid extension file split.** `SyntaxHighlighting/SyntaxHighlightingCoordinator+Extensions.swift` previously bundled two unrelated extensions (`extension SyntaxHighlightingCoordinator` for language-support helpers + `extension MemoryMonitor` for `availableMemoryMB`). The MemoryMonitor extension moved out as `MemoryMonitor+AvailableMemory.swift` into Diagnostics; the SH-coordinator extension stayed.
- **Stale `import CodeEditorLanguages` removed from `LRUCache.swift`** — verified zero Language references in the file.
- **Productized.** Unlike Languages, Diagnostics exposes a `.library(name: "CodeEditorDiagnostics", ...)` product per NEXT.md §6.3 so consumers can omit instrumentation from release builds.
- **No marker protocols added to Common.** The original §6.0 deferred-decision option (a) — type-erase via `AnyMemoryMonitor` / `AnyProductionPerformanceMetrics` — is not needed; the umbrella's six SH files that referenced Performance symbols now `import CodeEditorDiagnostics` directly.
- **`UnifiedPerformanceTracking` marker in Common stays.** Removing it would force Configuration → Diagnostics and push Configuration out of phase 1; the marker pays its keep.
- **`CodeEditorPluginTests` gained `CodeEditorDiagnostics` dependency.** ~20+ existing Performance-touching test files gained `import CodeEditorDiagnostics`.
- **Access-modifier promotions:** [list any internal → package promotions actually made in Step 3.11. If none, write "none required — the existing public surface was sufficient across the new target boundary."]
```

- [ ] **Step 4.4: Update NEXT.md §10's "Suggested next session" list**

Find the bulleted list in §10 that mentions remaining work. Remove (or update) the `6.2.10 CodeEditorDiagnostics` bullet — it's done. Update the `6.2.7 CodeEditorSyntaxHighlighting` bullet to drop the "Blocked on Performance/Core back-refs" language; that blocker is now resolved.

A clean rewrite of that bullet:

```markdown
- **6.2.7 `CodeEditorSyntaxHighlighting`** — ~45 files (was 36 in the original plan; grew during phases 0–2 + the SwiftSyntaxHighlighter relocation in §6.2.6). Now unblocked by the §6.2.10 Diagnostics extraction (commit `<hash>`) — the six SH files that previously hard-referenced `MemoryMonitor`/`ProductionPerformanceMetrics`/`CodeEditorDependencies` now `import CodeEditorDiagnostics`. Extraction becomes near-mechanical.
```

- [ ] **Step 4.5: Update CLAUDE.md Source Tree section**

Open `CLAUDE.md`. Find the "Source Tree" section with the table listing top-level subdirectories.

Remove the `Performance/` row from the umbrella's directory listing.

Update the running totals: the umbrella now has 20 top-level directories (not 21) and approximately 466 Swift source files (480 − 17 Performance/ files + 0 Layout/ ViewportManager.swift counted there now − 2 deletions ≈ 463; recalculate precisely if needed by running `find Sources/CodeEditorPlugin -name '*.swift' | wc -l`).

Add a note (parallel to whatever exists for Languages) that diagnostics live in a separate SPM target `CodeEditorDiagnostics` at `Sources/CodeEditorDiagnostics/`.

If the current `CLAUDE.md` already has a "Other source roots:" subsection listing the extracted targets, add:

```markdown
- `Sources/CodeEditorDiagnostics/` — performance instrumentation and memory monitoring (separate SPM product; opt-in per NEXT.md §6.3).
```

- [ ] **Step 4.6: Final validation — build + lint after doc changes**

Doc changes don't affect the build, but run the basics to confirm nothing accidentally regressed:

```bash
swift build && swiftlint
```

Expected: success and zero violations.

- [ ] **Step 4.7: Commit**

```bash
git add NEXT.md CLAUDE.md
git status
```

Confirm only NEXT.md and CLAUDE.md are staged. Then:

```bash
git commit -m "$(cat <<'EOF'
Update NEXT.md and CLAUDE.md for CodeEditorDiagnostics extraction

Add a §6.0 status-table row for CodeEditorDiagnostics with the actual
commit hash, document the deviations from the original §4.1 dep-graph
plan (phase 4 not phase 6, three misfiled files handled, productization,
no marker protocols needed), update §10's "Suggested next session" to
mark §6.2.10 done and unblock §6.2.7. Drop the umbrella's `Performance/`
row from CLAUDE.md's Source Tree and add the new SPM target to "Other
source roots."

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4.8: Confirm final state**

```bash
git log --oneline -5
swift package describe | grep -A 1 'CodeEditorDiagnostics'
find Sources/CodeEditorDiagnostics -name '*.swift' | wc -l
```

Expected:
- Top three commits are this task's doc commit, Task 3's extraction commit, Task 2's cleanup commit.
- `swift package describe` reports `CodeEditorDiagnostics` as a library target.
- The Diagnostics source root contains 14 files (or 13 if HardwareAcceleration was deleted).

---

## Rollback procedures (per commit, in case of failure)

**If Task 2 ends in red state (uncommitted):**

```bash
git restore --staged .
git restore .
git clean -fd Sources/CodeEditorPlugin/Performance/ Sources/CodeEditorPlugin/Layout/
```

This restores the working tree to the pre-Task-2 state. The `git clean -fd` only removes untracked files in the named directories — confirm via `git status` first.

**If Task 2 has committed but Task 3 fails:**

```bash
swift build && swift test --filter MemoryMonitorResetPeakTests
```

If Task 2's commit is still green in isolation (it should be), leave it landed and diagnose Task 3 separately. Don't `git reset --hard HEAD~1` unless Task 2 itself is the regression source.

**If Task 3 has committed but smoke test reveals a regression:**

Identify the regression first (typing path, syntax highlighting, performance overlay). If it's a target-visibility issue, fix forward with an access-modifier promotion in a follow-up commit. If it's a structural issue (a missing import or a wrong dep), prefer fix-forward over revert — the extraction itself is correct; specific consumers may need adjustment.

`git revert <hash>` is the last-resort option. Don't `git reset --hard` to undo a published-on-main commit.

---

## What this plan deliberately doesn't do

- **Doesn't extract SyntaxHighlighting (§6.2.7).** That's the next spec's work; this plan only removes the blocker.
- **Doesn't introduce `CodeEditorDiagnosticsTests`.** Tests stay in `CodeEditorPluginTests` per the phase 0–3 pattern.
- **Doesn't touch `Core/MemoryManagementCoordinator.swift`.** It belongs in the eventual editor-surface target (§6.2.12).
- **Doesn't touch `Core/CodeEditorDependencies.swift` factory implementations.** Only adds the `import CodeEditorDiagnostics` statement.
- **Doesn't remove the `UnifiedPerformanceTracking` marker protocol in Common.** Removing it would push Configuration to phase 4+.
- **Doesn't rename the package or any target.** `CodeEditorPlugin` → `CodeEditorToolkit` is a separate decision.
- **Doesn't write new tests.** This is a refactor — the existing test suite is the regression net.
- **Doesn't run `swift test --parallel` after Task 2's additive-only cleanup commit.** Targeted runs only, per the auto-memory `feedback_test_confirmations.md`.
