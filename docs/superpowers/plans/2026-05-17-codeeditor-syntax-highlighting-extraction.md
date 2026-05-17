# CodeEditorSyntaxHighlighting Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Carve out `Sources/CodeEditorPlugin/SyntaxHighlighting/` into a new SPM target `CodeEditorSyntaxHighlighting` (NEXT.md §6.2.7). Move 36 pure-engine files to a new sibling source root; relocate 9 umbrella-coupled controllers/adapters to `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/` (they continue to compile under the umbrella target where `CodeEditorView` lives); inline 5 `CodeEditorDependencies.makePlatformCapabilities()` factory call sites in `AdaptiveColorSystem.swift`.

**Architecture:** Four commits on `main`. Commit 1 is a pure relocation of the 9 stay-in-umbrella files (no Package.swift edit). Commit 2 is the factory-inline (standalone, bisectable). Commit 3 declares the new SPM target, `git mv`s 36 files to `Sources/CodeEditorSyntaxHighlighting/`, sweeps imports across umbrella + tests, drops `SwiftSyntax`/`SwiftParser` from the umbrella's deps, and handles strict-concurrency / access-modifier diagnostics as they surface. Commit 4 updates `NEXT.md` + `CLAUDE.md`. No new tests — the existing test suite is the regression net.

**Tech Stack:** Swift 6.3, SPM (with `path:` target argument), SwiftLint (strict), Swift Testing + XCTest hybrid, `SwiftSyntax` / `SwiftParser` (swiftlang/swift-syntax), `IssueReporting` (xctest-dynamic-overlay), `Dependencies` (pointfreeco/swift-dependencies).

**Source spec:** `docs/superpowers/specs/2026-05-17-codeeditor-syntax-highlighting-extraction-design.md` (commit `1ba72122`).

---

## Pre-flight context (read before Task 1)

Working directory is `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin`. Working branch is `main`. The user works directly on `main` per stored feedback (`feedback_branch_strategy.md`).

Seven extracted SPM targets currently exist alongside the umbrella `CodeEditorPlugin` target: `CodeEditorCommon`, `CodeEditorTextModel`, `CodeEditorPlatform`, `CodeEditorConfiguration`, `CodeEditorTheming`, `CodeEditorLanguages`, `CodeEditorDiagnostics` (plus the historical `CodeEditorDesignTokens`). The umbrella `CodeEditorPlugin` target's `exclude:` list is `["Info.plist", "Languages", "Performance"]`. After this plan lands, it becomes `["Info.plist", "Languages", "Performance", "SyntaxHighlighting"]` — the new target's `path:` is a sibling source root (`Sources/CodeEditorSyntaxHighlighting/`), so SwiftPM doesn't need to be told to exclude it, **but** the umbrella `SyntaxHighlighting/` directory will be empty after the moves and the `exclude:` defensively names directories that SwiftPM might otherwise pick up — confirm via `swift package describe` whether the entry is needed (the Diagnostics extraction kept its `"Performance"` exclude entry for the same defensive reason).

Phase A baseline (commit `8bac96cb`) promoted 116 symbols to `package` access. `package` is sufficient across same-package target boundaries; promote to `public` **only** if an external consumer of `CodeEditorPlugin` needs the symbol.

The auto-memory `feedback_test_confirmations.md` says: skip full `swift test --parallel` after additive-only steps; trust the build and run targeted tests instead. This plan honors that — Tasks 2 and 3 (commits 1 + 2) run targeted tests; Task 4 (commit 3, the actual extraction) runs the full pipeline.

The auto-memory `feedback_no_stash.md` says: don't shuffle tracked changes via `git stash` — reason from the diff instead.

If any task fails mid-way, rollback is `git restore .` (uncommitted work) or `git reset --hard HEAD~1` (last commit). See the "Rollback procedures" section at the end.

The user has already approved the four-commit sequencing during brainstorming. Do not split commits 1, 2, 3, or 4 further.

---

## Task 1: Precondition verification (no commit)

**Files:**
- Read-only: `Sources/CodeEditorPlugin/SyntaxHighlighting/`, `Sources/CodeEditorPlugin/Core/CodeEditorDependencies.swift`, `Package.swift`

**Context:** Spec was written 2026-05-17 against `main` at commit `1ba72122`. Confirm the assumptions still hold before touching anything.

- [ ] **Step 1.1: Verify SyntaxHighlighting/ inventory matches the spec**

```bash
ls Sources/CodeEditorPlugin/SyntaxHighlighting/
ls Sources/CodeEditorPlugin/SyntaxHighlighting/Parsing/
ls Sources/CodeEditorPlugin/SyntaxHighlighting/RegexQuery/
```

Expected (35 root entries — 34 `.swift` files plus `Parsing/` and `RegexQuery/` directories; 6 in Parsing/; 5 in RegexQuery/; 45 `.swift` files total):

Root (34 files + 2 dirs): `AdaptiveColorSystem.swift`, `AsyncSyntaxHighlighter.swift`, `BackgroundHighlightingActor.swift`, `BackgroundHighlightingTypes.swift`, `BackgroundSyntaxHighlighter.swift`, `FastJSONTokenizer.swift`, `HighlightProviderState.swift`, `HighlightingStrategyExecutor.swift`, `LanguageRegistry.swift`, `OptimizedSyntaxHighlightingCoordinator.swift`, `Parsing/`, `RangeAttributeApplier.swift`, `RangeBasedHighlightingController.swift`, `RangeHighlightProviding.swift`, `RegexQuery/`, `RegexSyntaxHighlighter+BuilderExtensions.swift`, `RegexSyntaxHighlighter+IntervalTreeExtensions.swift`, `RegexSyntaxHighlighter+LanguagesExtensions.swift`, `RegexSyntaxHighlighter+TypesExtensions.swift`, `RegexSyntaxHighlighter.swift`, `SmartTokenCache.swift`, `StreamingHighlighter.swift`, `StyleElement.swift`, `StyledRangeContainer.swift`, `SwiftSyntaxHighlighter+SharedExtensions.swift`, `SwiftSyntaxHighlighter.swift`, `SyntaxColorScheme.swift`, `SyntaxHighlighterRangeAdapter.swift`, `SyntaxHighlightingCoordinator+Extensions.swift`, `SyntaxHighlightingCoordinator.swift`, `SyntaxHighlightingPerformanceMonitor.swift`, `SyntaxHighlightingPerformanceTracker.swift`, `Theme+TokenColor.swift`, `TokenName.swift`, `ViewportSyntaxCoordinator.swift`.

`Parsing/` (6 files): `LanguagePatternDetector.swift`, `PatternExtractor.swift`, `SyntaxTreeParser.swift`, `TextParsingUtilities.swift`, `TokenExtractor.swift`, `WordBoundaryFinder.swift`.

`RegexQuery/` (5 files): `HeuristicFoldProvider.swift`, `HeuristicSymbolProviderFacade.swift`, `QueryCaptureMap.swift`, `RegexIncrementalRangeQueryParser.swift`, `RegexRangeHighlightProvider.swift`.

If the inventory doesn't match, STOP and re-validate the spec before continuing.

- [ ] **Step 1.2: Verify the 9 umbrella-coupled files still reference `CodeEditorView`**

```bash
grep -l 'CodeEditorView\b' \
  Sources/CodeEditorPlugin/SyntaxHighlighting/RangeAttributeApplier.swift \
  Sources/CodeEditorPlugin/SyntaxHighlighting/VisibleRangeProvider.swift \
  Sources/CodeEditorPlugin/SyntaxHighlighting/HighlightProviderState.swift \
  Sources/CodeEditorPlugin/SyntaxHighlighting/RangeBasedHighlightingController.swift \
  Sources/CodeEditorPlugin/SyntaxHighlighting/RangeHighlightProviding.swift \
  Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlighterRangeAdapter.swift \
  Sources/CodeEditorPlugin/SyntaxHighlighting/AsyncSyntaxHighlighter.swift \
  Sources/CodeEditorPlugin/SyntaxHighlighting/StreamingHighlighter.swift \
  Sources/CodeEditorPlugin/SyntaxHighlighting/RegexQuery/RegexRangeHighlightProvider.swift
```

Expected: all 9 paths printed (each file references `CodeEditorView`).

- [ ] **Step 1.3: Verify AdaptiveColorSystem.swift still has 5 factory call sites**

```bash
grep -n 'CodeEditorDependencies\.makePlatformCapabilities' Sources/CodeEditorPlugin/SyntaxHighlighting/AdaptiveColorSystem.swift
```

Expected (exactly 5 hits, line numbers may have drifted):
```
29:        textBackgroundColor(capabilities: CodeEditorDependencies.makePlatformCapabilities())
44:        selectionColor(capabilities: CodeEditorDependencies.makePlatformCapabilities())
59:        lineNumberColor(capabilities: CodeEditorDependencies.makePlatformCapabilities())
74:        gutterBackgroundColor(capabilities: CodeEditorDependencies.makePlatformCapabilities())
97:        let capabilities = capabilities ?? CodeEditorDependencies.makePlatformCapabilities()
```

- [ ] **Step 1.4: Verify the `liveValue` closure is still `{ PlatformCapabilities() }`**

```bash
grep -A 3 'private enum PlatformCapabilitiesKey' Sources/CodeEditorPlugin/Core/CodeEditorDependencies.swift
```

Expected:
```swift
private enum PlatformCapabilitiesKey: DependencyKey {
    static var liveValue: @MainActor @Sendable () -> PlatformCapabilities {
        { PlatformCapabilities() }
    }
```

If `liveValue` differs from `{ PlatformCapabilities() }`, STOP — the factory-inline replacement (Task 3) is no longer safe and needs to be re-derived.

- [ ] **Step 1.5: Verify only `AsyncSyntaxHighlighter` imports `CodeEditorConfiguration` from the SH directory**

```bash
grep -rln '^import CodeEditorConfiguration' Sources/CodeEditorPlugin/SyntaxHighlighting/
```

Expected: exactly one line, `Sources/CodeEditorPlugin/SyntaxHighlighting/AsyncSyntaxHighlighter.swift`. (This is a stay-in-umbrella file, so the new target does **not** need `CodeEditorConfiguration` as a dep.)

- [ ] **Step 1.6: Verify only `HighlightProviderState` imports `IssueReporting` from the SH directory**

```bash
grep -rln '^import IssueReporting' Sources/CodeEditorPlugin/SyntaxHighlighting/
```

Expected: exactly one line, `Sources/CodeEditorPlugin/SyntaxHighlighting/HighlightProviderState.swift`. (This is a stay-in-umbrella file, so the new target does **not** need `IssueReporting` as a dep.)

- [ ] **Step 1.7: Verify the umbrella's current `exclude:` list**

```bash
grep -B 0 -A 4 'name: "CodeEditorPlugin",' Package.swift | grep -A 4 exclude:
```

Expected list contains: `"Info.plist"`, `"Languages"`, `"Performance"`. After this plan, add `"SyntaxHighlighting"` to that list.

- [ ] **Step 1.8: Baseline build + lint to confirm a clean starting state**

```bash
swift build && swiftlint
```

Expected: build succeeds; SwiftLint reports 0 violations. If either fails, STOP and resolve before touching files — the plan assumes a clean baseline.

---

## Task 2: Commit 1 — Relocate 9 umbrella-coupled SH files to `Core/SyntaxHighlighting/`

**Files:**
- Create directory: `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/`
- Create directory: `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/RegexQuery/`
- Move (9): `Sources/CodeEditorPlugin/SyntaxHighlighting/{RangeAttributeApplier,VisibleRangeProvider,HighlightProviderState,RangeBasedHighlightingController,RangeHighlightProviding,SyntaxHighlighterRangeAdapter,AsyncSyntaxHighlighter,StreamingHighlighter}.swift` and `Sources/CodeEditorPlugin/SyntaxHighlighting/RegexQuery/RegexRangeHighlightProvider.swift` → `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/{,RegexQuery/}`

**Context:** Pure `git mv` of the umbrella-coupled glue. No `Package.swift` edit (files stay in the umbrella target via the umbrella's `Sources/CodeEditorPlugin/` source root). No import-statement changes (the relocated files keep the same module visibility). This commit's purpose is to clear the way for Task 4's `Sources/CodeEditorPlugin/SyntaxHighlighting/` → `Sources/CodeEditorSyntaxHighlighting/` rename so the directory has nothing left in it.

- [ ] **Step 2.1: Create the destination subdirectories**

```bash
mkdir -p Sources/CodeEditorPlugin/Core/SyntaxHighlighting/RegexQuery
```

- [ ] **Step 2.2: `git mv` the 8 root-level files**

```bash
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/RangeAttributeApplier.swift              Sources/CodeEditorPlugin/Core/SyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/VisibleRangeProvider.swift               Sources/CodeEditorPlugin/Core/SyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/HighlightProviderState.swift             Sources/CodeEditorPlugin/Core/SyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/RangeBasedHighlightingController.swift   Sources/CodeEditorPlugin/Core/SyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/RangeHighlightProviding.swift            Sources/CodeEditorPlugin/Core/SyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlighterRangeAdapter.swift      Sources/CodeEditorPlugin/Core/SyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/AsyncSyntaxHighlighter.swift             Sources/CodeEditorPlugin/Core/SyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/StreamingHighlighter.swift               Sources/CodeEditorPlugin/Core/SyntaxHighlighting/
```

- [ ] **Step 2.3: `git mv` the one `RegexQuery/` file**

```bash
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/RegexQuery/RegexRangeHighlightProvider.swift \
       Sources/CodeEditorPlugin/Core/SyntaxHighlighting/RegexQuery/
```

- [ ] **Step 2.4: Verify the moves landed correctly**

```bash
ls Sources/CodeEditorPlugin/Core/SyntaxHighlighting/
ls Sources/CodeEditorPlugin/Core/SyntaxHighlighting/RegexQuery/
```

Expected at `Core/SyntaxHighlighting/`: the 8 root files plus `RegexQuery/` directory (9 entries total).
Expected at `Core/SyntaxHighlighting/RegexQuery/`: `RegexRangeHighlightProvider.swift` (1 entry).

```bash
git status --short
```

Expected: 9 `R  ` (rename) entries.

- [ ] **Step 2.5: Build + targeted tests (additive-only, skip full --parallel)**

```bash
swift build
swift test --filter SyntaxHighlighting
swiftlint
```

Expected: build succeeds; targeted tests pass; SwiftLint reports 0 violations.

If a build error appears, the most likely cause is a stale reference path in a `// swiftlint:disable_file` comment or a doc-comment `[[link]]` — fix in place and reverify.

- [ ] **Step 2.6: Commit**

```bash
git commit -m "$(cat <<'EOF'
Relocate umbrella-coupled SH glue to Core/SyntaxHighlighting/

Pre-extraction cleanup for §6.2.7. The nine files that directly
reference CodeEditorView (RangeHighlightProviding + conformers,
RangeAttributeApplier, RangeBasedHighlightingController,
HighlightProviderState, VisibleRangeProvider, AsyncSyntaxHighlighter,
StreamingHighlighter, RegexRangeHighlightProvider) cannot move into the
new SH target because CodeEditorView lives in the umbrella. Relocate
them under Core/SyntaxHighlighting/ so the soon-to-extract directory
holds only the pure-engine files. No Package.swift change.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Commit 2 — Inline `CodeEditorDependencies.makePlatformCapabilities()` in `AdaptiveColorSystem`

**Files:**
- Modify: `Sources/CodeEditorPlugin/SyntaxHighlighting/AdaptiveColorSystem.swift` (5 sites)

**Context:** `AdaptiveColorSystem.swift` calls `CodeEditorDependencies.makePlatformCapabilities()` at 5 sites. When the file moves to the new target in Task 4, it can no longer reach `CodeEditorDependencies` (which lives in the umbrella). Verified in Task 1.4 that the `liveValue` for `PlatformCapabilitiesKey` is `{ PlatformCapabilities() }` — so the replacement is `CodeEditorDependencies.makePlatformCapabilities()` → `PlatformCapabilities()`. Same pattern Diagnostics used in `PerformanceInsights.swift` / `AdaptivePerformanceMode.swift` (commit `e60f7857`).

- [ ] **Step 3.1: Replace the 5 factory call sites**

In `Sources/CodeEditorPlugin/SyntaxHighlighting/AdaptiveColorSystem.swift`, edit:

Line 29:
```swift
// before
        textBackgroundColor(capabilities: CodeEditorDependencies.makePlatformCapabilities())
// after
        textBackgroundColor(capabilities: PlatformCapabilities())
```

Line 44:
```swift
// before
        selectionColor(capabilities: CodeEditorDependencies.makePlatformCapabilities())
// after
        selectionColor(capabilities: PlatformCapabilities())
```

Line 59:
```swift
// before
        lineNumberColor(capabilities: CodeEditorDependencies.makePlatformCapabilities())
// after
        lineNumberColor(capabilities: PlatformCapabilities())
```

Line 74:
```swift
// before
        gutterBackgroundColor(capabilities: CodeEditorDependencies.makePlatformCapabilities())
// after
        gutterBackgroundColor(capabilities: PlatformCapabilities())
```

Line 97:
```swift
// before
        let capabilities = capabilities ?? CodeEditorDependencies.makePlatformCapabilities()
// after
        let capabilities = capabilities ?? PlatformCapabilities()
```

Use `Edit` with `replace_all: true` and `old_string: "CodeEditorDependencies.makePlatformCapabilities()"`, `new_string: "PlatformCapabilities()"` to apply all 5 at once.

- [ ] **Step 3.2: Verify there are no remaining `CodeEditorDependencies.` calls in the file**

```bash
grep -n 'CodeEditorDependencies' Sources/CodeEditorPlugin/SyntaxHighlighting/AdaptiveColorSystem.swift
```

Expected: empty output.

- [ ] **Step 3.3: Build + targeted tests**

```bash
swift build
swift test --filter AdaptiveColorSystem
swift test --filter SyntaxHighlighting
swiftlint
```

Expected: build succeeds; targeted tests pass; SwiftLint reports 0 violations.

If the build fails with "cannot find 'PlatformCapabilities' in scope", verify the file imports `CodeEditorPlatform` at the top (it does — line 1). If the test fails, the `liveValue` and the direct init must have drifted — STOP and inspect both before proceeding.

- [ ] **Step 3.4: Commit**

```bash
git commit -am "$(cat <<'EOF'
Inline PlatformCapabilities() in AdaptiveColorSystem

Replace the five CodeEditorDependencies.makePlatformCapabilities()
sites in AdaptiveColorSystem.swift with direct PlatformCapabilities()
construction. AdaptiveColorSystem moves into the new
CodeEditorSyntaxHighlighting target in the next commit and can no
longer reach CodeEditorDependencies (which lives in the umbrella).

The PlatformCapabilitiesKey.liveValue closure is { PlatformCapabilities() },
so the inline is equivalent to the factory call. Same pattern as
Diagnostics extraction (commit e60f7857).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Commit 3 — Extract `CodeEditorSyntaxHighlighting` target

**Files:**
- Create directory: `Sources/CodeEditorSyntaxHighlighting/`
- Create directory: `Sources/CodeEditorSyntaxHighlighting/Parsing/`
- Create directory: `Sources/CodeEditorSyntaxHighlighting/RegexQuery/`
- Move (36): all remaining files in `Sources/CodeEditorPlugin/SyntaxHighlighting/` → `Sources/CodeEditorSyntaxHighlighting/`
- Modify: `Package.swift` (add new target, update umbrella deps + excludes, update test target deps)
- Modify (umbrella import sweep, ~19 files): see Step 4.5
- Modify (test import sweep, up to 18 files): see Step 4.6

**Context:** The actual target extraction. Carve out 36 pure-engine files into a sibling source root, declare the target with its 7 internal + 2 external dependencies, drop `SwiftSyntax`/`SwiftParser` from the umbrella's deps (those products travel with `SwiftSyntaxHighlighter` into the new target), and sweep `import CodeEditorSyntaxHighlighting` into every umbrella + test file that references a moved type. Strict-concurrency and access-modifier diagnostics are expected; resolve them as they surface.

- [ ] **Step 4.1: Create the new target's source-root subdirectories**

```bash
mkdir -p Sources/CodeEditorSyntaxHighlighting/Parsing
mkdir -p Sources/CodeEditorSyntaxHighlighting/RegexQuery
```

- [ ] **Step 4.2: `git mv` the 26 root-level pure-engine files**

```bash
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/AdaptiveColorSystem.swift                       Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/BackgroundHighlightingActor.swift               Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/BackgroundHighlightingTypes.swift               Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/BackgroundSyntaxHighlighter.swift               Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/FastJSONTokenizer.swift                         Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/HighlightingStrategyExecutor.swift              Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift                          Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/OptimizedSyntaxHighlightingCoordinator.swift    Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/RegexSyntaxHighlighter.swift                    Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/RegexSyntaxHighlighter+BuilderExtensions.swift  Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/RegexSyntaxHighlighter+IntervalTreeExtensions.swift Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/RegexSyntaxHighlighter+LanguagesExtensions.swift Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/RegexSyntaxHighlighter+TypesExtensions.swift    Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/SmartTokenCache.swift                           Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/StyleElement.swift                              Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/StyledRangeContainer.swift                      Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/SwiftSyntaxHighlighter.swift                    Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/SwiftSyntaxHighlighter+SharedExtensions.swift   Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxColorScheme.swift                         Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator.swift             Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator+Extensions.swift  Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingPerformanceMonitor.swift      Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingPerformanceTracker.swift      Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/Theme+TokenColor.swift                          Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/TokenName.swift                                 Sources/CodeEditorSyntaxHighlighting/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/ViewportSyntaxCoordinator.swift                 Sources/CodeEditorSyntaxHighlighting/
```

- [ ] **Step 4.3: `git mv` the 6 `Parsing/` files**

```bash
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/Parsing/LanguagePatternDetector.swift Sources/CodeEditorSyntaxHighlighting/Parsing/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/Parsing/PatternExtractor.swift        Sources/CodeEditorSyntaxHighlighting/Parsing/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/Parsing/SyntaxTreeParser.swift        Sources/CodeEditorSyntaxHighlighting/Parsing/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/Parsing/TextParsingUtilities.swift    Sources/CodeEditorSyntaxHighlighting/Parsing/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/Parsing/TokenExtractor.swift          Sources/CodeEditorSyntaxHighlighting/Parsing/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/Parsing/WordBoundaryFinder.swift      Sources/CodeEditorSyntaxHighlighting/Parsing/
```

- [ ] **Step 4.4: `git mv` the 4 `RegexQuery/` files and remove the now-empty source directory**

```bash
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/RegexQuery/HeuristicFoldProvider.swift         Sources/CodeEditorSyntaxHighlighting/RegexQuery/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/RegexQuery/HeuristicSymbolProviderFacade.swift Sources/CodeEditorSyntaxHighlighting/RegexQuery/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/RegexQuery/QueryCaptureMap.swift               Sources/CodeEditorSyntaxHighlighting/RegexQuery/
git mv Sources/CodeEditorPlugin/SyntaxHighlighting/RegexQuery/RegexIncrementalRangeQueryParser.swift Sources/CodeEditorSyntaxHighlighting/RegexQuery/
```

Now both source subdirectories are empty:

```bash
rmdir Sources/CodeEditorPlugin/SyntaxHighlighting/RegexQuery
rmdir Sources/CodeEditorPlugin/SyntaxHighlighting/Parsing
rmdir Sources/CodeEditorPlugin/SyntaxHighlighting
```

Verify:

```bash
test ! -d Sources/CodeEditorPlugin/SyntaxHighlighting && echo "umbrella SH dir is gone"
ls Sources/CodeEditorSyntaxHighlighting/ | wc -l
ls Sources/CodeEditorSyntaxHighlighting/Parsing/ | wc -l
ls Sources/CodeEditorSyntaxHighlighting/RegexQuery/ | wc -l
```

Expected: "umbrella SH dir is gone"; 28 entries at the root (26 `.swift` + `Parsing/` + `RegexQuery/`); 6 in Parsing/; 4 in RegexQuery/. Total moved: 36.

- [ ] **Step 4.5: Edit `Package.swift` — add the new target, update the umbrella, update test deps**

Three edits in `Package.swift`:

**4.5.a — Insert the new target** before the `CodeEditorPlugin` umbrella target (after the `CodeEditorDiagnostics` target, around line 146):

```swift
        .target(
            name: "CodeEditorSyntaxHighlighting",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ],
            path: "Sources/CodeEditorSyntaxHighlighting",
            swiftSettings: swiftSettings
        ),
```

**4.5.b — Update the `CodeEditorPlugin` umbrella target** — add `"CodeEditorSyntaxHighlighting"` to its dependencies and add `"SyntaxHighlighting"` to its `exclude:` list. Drop `SwiftSyntax` / `SwiftParser` products from the umbrella's dependencies (they move to the new target).

Before:
```swift
        .target(
            name: "CodeEditorPlugin",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            exclude: [
                "Info.plist",
                "Languages",
                "Performance"
            ],
            swiftSettings: swiftSettings
        ),
```

After:
```swift
        .target(
            name: "CodeEditorPlugin",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            exclude: [
                "Info.plist",
                "Languages",
                "Performance",
                "SyntaxHighlighting"
            ],
            swiftSettings: swiftSettings
        ),
```

**4.5.c — Update the `CodeEditorPluginTests` test target** — add `"CodeEditorSyntaxHighlighting"` to its dependencies.

Before:
```swift
        .testTarget(
            name: "CodeEditorPluginTests",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
                "CodeEditorTextModel",
                "CodeEditorTheming",
```

After:
```swift
        .testTarget(
            name: "CodeEditorPluginTests",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorTheming",
```

Do **not** add `CodeEditorSyntaxHighlighting` to `CodeEditorSampleTests`, `CodeEditorUITests`, or `CodeEditorDesignTokensTests` — Task 1's grep shows those targets don't reference moved types.

Verification:

```bash
swift package describe 2>&1 | grep -A 2 'CodeEditorSyntaxHighlighting'
```

Expected: at least one `CodeEditorSyntaxHighlighting` block listing 36 `.swift` source files. If the file count is wrong, recheck the `git mv` commands.

- [ ] **Step 4.6: Build, capture the import errors, and sweep umbrella imports**

```bash
swift build 2>&1 | head -100
```

Expected: dozens of "cannot find … in scope" errors. These point at files that reference moved types and need `import CodeEditorSyntaxHighlighting`. Most are in:

Umbrella files (10 outside `SyntaxHighlighting/`):
- `Sources/CodeEditorPlugin/Completion/CompletionEventBroadcaster.swift`
- `Sources/CodeEditorPlugin/Core/ActorCoordinator.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+Theme.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`
- `Sources/CodeEditorPlugin/Core/SyntaxHighlightingService.swift`
- `Sources/CodeEditorPlugin/Core/Text/ModernTextKitHelper.swift`
- `Sources/CodeEditorPlugin/Features/FoldingProviderRegistry.swift`
- `Sources/CodeEditorPlugin/Features/SymbolProviderCatalog.swift`
- `Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift`
- `Sources/CodeEditorPlugin/Layout/MinimapStyleDataSource.swift`

Umbrella files relocated in Task 2 (the 9 in `Core/SyntaxHighlighting/`):
- `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/RangeAttributeApplier.swift`
- `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/VisibleRangeProvider.swift`
- `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/HighlightProviderState.swift`
- `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/RangeBasedHighlightingController.swift`
- `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/RangeHighlightProviding.swift`
- `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/SyntaxHighlighterRangeAdapter.swift`
- `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/AsyncSyntaxHighlighter.swift`
- `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/StreamingHighlighter.swift`
- `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/RegexQuery/RegexRangeHighlightProvider.swift`

For each file, add `import CodeEditorSyntaxHighlighting` near the top, sorted alphabetically among existing imports. Use the existing import-block style — keep imports alphabetized.

To sanity-check the sweep, re-grep after the edits:

```bash
TYPES='AdaptiveColorSystem|BackgroundHighlightingActor|BackgroundHighlightingTypes|BackgroundSyntaxHighlighter|FastJSONTokenizer|HighlightingStrategyExecutor|LanguageRegistry|OptimizedSyntaxHighlightingCoordinator|RegexSyntaxHighlighter|SmartTokenCache|StyleElement|StyledRangeContainer|SwiftSyntaxHighlighter|SyntaxColorScheme|SyntaxHighlightingCoordinator|SyntaxHighlightingPerformanceMonitor|SyntaxHighlightingPerformanceTracker|TokenName|ViewportSyntaxCoordinator|LanguagePatternDetector|PatternExtractor|SyntaxTreeParser|TokenExtractor|WordBoundaryFinder|HeuristicFoldProvider|HeuristicSymbolProviderFacade|QueryCaptureMap|RegexIncrementalRangeQueryParser|HighlightedToken'
for f in $(grep -rlE "($TYPES)" Sources/CodeEditorPlugin/ --include='*.swift'); do
    if ! grep -q '^import CodeEditorSyntaxHighlighting' "$f"; then
        # No import yet — verify the reference isn't only a doc-comment mention
        if grep -nE "($TYPES)" "$f" | grep -vE '^\s*([0-9]+:)?\s*(//|/\*|\*)' | head -1 | grep -q .; then
            echo "MISSING import in $f"
        fi
    fi
done
```

Expected: no `MISSING import in …` lines. If any print, add the import.

Edge cases:
- **`Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift`** and **`Sources/CodeEditorPlugin/Languages/Data/JsonLanguageDescriptor.swift`** mention moved types **only in doc comments**. Do **not** add the import — Languages cannot depend on SH (would form a cycle).
- If a moved type's name collides with an unrelated identifier (`TokenType` is reasonably generic), prefer adjusting the import order over renaming.

- [ ] **Step 4.7: Build, capture remaining errors, sweep test imports**

```bash
swift build 2>&1 | head -100
```

Expected: a smaller set of errors, this time in the test target. Add `import CodeEditorSyntaxHighlighting` to each of the following:

- `Tests/CodeEditorPluginTests/ConfigurationBasicTests.swift`
- `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift`
- `Tests/CodeEditorPluginTests/LanguageDetectionTests.swift`
- `Tests/CodeEditorPluginTests/Languages/SwiftSyntaxHighlighterTests.swift`
- `Tests/CodeEditorPluginTests/Layout/MinimapStyleDataSourceTests.swift`
- `Tests/CodeEditorPluginTests/MemoryLeakTests.swift`
- `Tests/CodeEditorPluginTests/PerformanceBenchmarkTests.swift`
- `Tests/CodeEditorPluginTests/PerformanceStressTests.swift`
- `Tests/CodeEditorPluginTests/RegexHighlighterPerformanceTests.swift`
- `Tests/CodeEditorPluginTests/RegexRangeHighlightProviderTests.swift`
- `Tests/CodeEditorPluginTests/SyntaxHighlighting/RangeBasedHighlightingIntegrationTests.swift`
- `Tests/CodeEditorPluginTests/SyntaxHighlighting/SmartTokenCacheCoverageTests.swift`
- `Tests/CodeEditorPluginTests/SyntaxHighlighting/SqlCaseInsensitiveKeywordTests.swift`
- `Tests/CodeEditorPluginTests/SyntaxHighlightingPerformanceOptimizationTests.swift`
- `Tests/CodeEditorPluginTests/SyntaxHighlightingPerformanceTests.swift`
- `Tests/CodeEditorPluginTests/SyntaxHighlightingTests.swift`
- `Tests/CodeEditorPluginTests/TestIsolationHelper.swift`
- `Tests/CodeEditorPluginTests/Text/SyntaxColorAndSelectionTests.swift`

Each file has an existing `@testable import CodeEditorPlugin` line — add `@testable import CodeEditorSyntaxHighlighting` immediately after it (or alphabetized — match the file's existing style).

Use `@testable` so `internal` and `package` symbols are reachable; this is consistent with the rest of `CodeEditorPluginTests` which uses `@testable` against most targets.

- [ ] **Step 4.8: Resolve strict-concurrency / access-modifier diagnostics**

```bash
swift build 2>&1 | head -200
```

Expected categories (handle each in place — minimum-bump policy):

1. **`'X' inaccessible due to 'internal' protection level`** — promote the type or member to `package`. Likely candidates: `SmartTokenCache`, internal helpers on `SyntaxHighlightingCoordinator`, mutation methods on `StyledRangeContainer`, `BackgroundHighlightingActor`. Bump `internal` → `package` (not `public`); `package` is sufficient across same-package target boundaries.

2. **`type 'X' does not conform to protocol 'Sendable'`** — add `Sendable` conformance to value types newly crossing the target boundary. Reference: Diagnostics' `FoldingType: Sendable` precedent (§6.2.10). Candidates: payload/result types in `StyledRangeContainer`, `BackgroundHighlightingTypes`.

3. **`stored property 'X' of 'Sendable'-conforming class has non-sendable type`** — refactor minimally: switch the property type to a `Sendable` alternative, or mark the class `final` + add `@unchecked Sendable` only if the property is mutated under a lock / actor isolation (document the rationale in a one-line comment).

4. **`cannot find 'Y' in scope`** for a type defined in the new SH target — the import wasn't added. Go back to Step 4.5 / 4.6.

Iterate `swift build` until clean. Time-box: if a single diagnostic blocks for more than 15 minutes, write down the file + diagnostic and ping the user before forcing it.

- [ ] **Step 4.9: SwiftLint pass**

```bash
swiftlint --fix
swiftlint
```

Expected: 0 violations. Likely auto-fixed: import order, trailing whitespace.

- [ ] **Step 4.10: Verify target boundaries via `swift package describe`**

```bash
swift package describe 2>&1 | grep -A 1 'CodeEditorSyntaxHighlighting'
```

Expected: the new target lists exactly 36 source files; `path:` shows `Sources/CodeEditorSyntaxHighlighting`. Cross-reference with `find Sources/CodeEditorSyntaxHighlighting -name '*.swift' | wc -l` (should also be 36).

```bash
swift build --target CodeEditorSyntaxHighlighting
```

Expected: builds in isolation in <10s.

- [ ] **Step 4.11: Full test suite**

```bash
swift test --parallel
```

Expected: full suite passes. If a test that previously used `CodeEditorView.someHighlightingMethod()` fails with a missing-import error, sweep the test file (Step 4.7) and rerun.

- [ ] **Step 4.12: Sample-app smoke test**

```bash
./Scripts/run-sample.sh debug
```

Expected: sample app launches. Manually verify:
- Open the default Swift file — syntax highlighting renders.
- Paste a Python snippet (`def foo(x): return x + 1`) — keywords are colored.
- Paste a JSON snippet (`{"a": 1, "b": [2, 3]}`) — keys, values, brackets are colored.
- Open Find/Replace (Cmd+F), type a query — matches highlight (uses `StyledRangeContainer`).
- Inspect the minimap (if visible in the layout) — colored runs render (uses `MinimapStyleDataSource` → `StyledRangeContainer`).

Quit the app once verified.

- [ ] **Step 4.13: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Extract CodeEditorSyntaxHighlighting target (§6.2.7)

Carve out the pure syntax-highlighting engine into a new SPM target.
36 files move to Sources/CodeEditorSyntaxHighlighting/; the 9
controllers/adapters that directly reference CodeEditorView remain in
the umbrella (relocated to Core/SyntaxHighlighting/ in the previous
commit). Net effect: tokenizer / theme-mapping changes stop rebuilding
the umbrella target.

Dependencies on the new target: Common, DesignTokens, Diagnostics,
Languages, Platform, TextModel, Theming + SwiftSyntax/SwiftParser
products. SwiftSyntax/SwiftParser drop off the umbrella's dep list.

Internal target only — no `.library` product. Matches Languages
precedent (§6.2.6).

~19 umbrella files + ~18 test files gain `import CodeEditorSyntaxHighlighting`.
Access-modifier promotions internal → package as build errors
surfaced. Strict-concurrency Sendable conformances added where the
new target boundary required them.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Commit 4 — Doc updates (NEXT.md + CLAUDE.md)

**Files:**
- Modify: `NEXT.md` (§6.0 status table row, §6.2.7 step status, §10 "Suggested next session")
- Modify: `CLAUDE.md` ("Other source roots" list, line counts in source-tree paragraph)

**Context:** Final commit. Mirror the Diagnostics extraction's doc-update commit (`11243e2e`). Capture the deviations that surfaced during execution.

- [ ] **Step 5.1: Update `NEXT.md` §6.0 status table**

Add a new row after the `CodeEditorDiagnostics` row:

| Target | Commit | What landed | Direct deps |
|---|---|---|---|
| `CodeEditorSyntaxHighlighting` | `<commit-hash-from-task-4.13>` | 36 of 45 SH files (pure engine: color schemes, tokenizers, parsing, regex/SwiftSyntax highlighters, scheme cache, descriptor execution, performance instrumentation). 9 umbrella-coupled files relocated to `Core/SyntaxHighlighting/` in commit 1; 5 `CodeEditorDependencies.makePlatformCapabilities()` sites inlined in `AdaptiveColorSystem.swift` in commit 2. | Common, DesignTokens, Diagnostics, Languages, Platform, TextModel, Theming + SwiftSyntax/SwiftParser products |

Use `git log --oneline -5` to grab the hash from Task 4.13 (the last commit before this doc update). The Task 2 (commit 1) and Task 3 (commit 2) hashes also belong in the description column if you want full traceability.

- [ ] **Step 5.2: Update `NEXT.md` §6.2.7 step status**

Change:

```markdown
6. **Extract `CodeEditorSyntaxHighlighting`** — move `SyntaxHighlighting/`. Depends on `Languages`, `TextModel`, `Theming`.
```

to:

```markdown
6. **[done — carve-out, see §6.0]** **Extract `CodeEditorSyntaxHighlighting`** — moved 36 of 45 SH files; the 9 `CodeEditorView`-coupled files (RangeHighlightProviding + conformers, RangeAttributeApplier, RangeBasedHighlightingController, HighlightProviderState, VisibleRangeProvider, AsyncSyntaxHighlighter, StreamingHighlighter) stayed in umbrella under `Core/SyntaxHighlighting/`. Full deps: Common, DesignTokens, Diagnostics, Languages, Platform, TextModel, Theming + SwiftSyntax/SwiftParser. (`<extraction-hash>` + pre-relocation `<commit-1-hash>` + factory-inline `<commit-2-hash>`)
```

- [ ] **Step 5.3: Update `NEXT.md` §6.0 deviations subsection — add SH section**

After the existing "Deviations during §6.2.10 `CodeEditorDiagnostics`" subsection, add a new subsection:

```markdown
**Deviations during §6.2.7 `CodeEditorSyntaxHighlighting` (commit `<extraction-hash>`):**

- **Not "near-mechanical".** NEXT.md §10's claim was wrong. Nine SH files directly reference the umbrella `CodeEditorView` class (`RangeAttributeApplier`, `VisibleRangeProvider`, `HighlightProviderState`, `RangeBasedHighlightingController`, `RangeHighlightProviding` protocol + conformers `SyntaxHighlighterRangeAdapter` and `RegexRangeHighlightProvider`, `AsyncSyntaxHighlighter`, `StreamingHighlighter`). Carve-out adopted: those 9 stayed in umbrella relocated under `Core/SyntaxHighlighting/`; 36 pure-engine files moved to `Sources/CodeEditorSyntaxHighlighting/`. `CodeEditorViewProtocol` was not promoted — keeping `CodeEditorView` references in umbrella was cheaper than introducing a new abstraction.
- **`SwiftSyntax` / `SwiftParser` products moved off the umbrella's deps.** Both `SwiftSyntaxHighlighter` files are in the moving set; the products travel with them to the new target. Umbrella's dep list shrinks by 2.
- **No `CodeEditorConfiguration` or `IssueReporting` on the new target.** Only `AsyncSyntaxHighlighter` imports Configuration (stays in umbrella); only `HighlightProviderState` imports IssueReporting (stays in umbrella). New target's dep list trims to 7 internal + 2 external.
- **`AdaptiveColorSystem`'s 5 `CodeEditorDependencies.makePlatformCapabilities()` sites inlined** to `PlatformCapabilities()`. `liveValue` reduces to the same — equivalent. Same pattern Diagnostics used. `AsyncSyntaxHighlighter`'s `makeProductionPerformanceMetrics()` call stays untouched (file remains in umbrella).
- **Productization deliberately skipped.** No `.library(name: "CodeEditorSyntaxHighlighting", ...)` product. Matches Languages precedent.
- **Access-modifier promotions to bridge the new target boundary:** <enumerate the specific symbols that needed `internal` → `package`, captured from Task 4.8>.
- **Sendable conformances added at the boundary:** <enumerate the specific types, captured from Task 4.8>.
- **`CodeEditorPluginTests` target gained `CodeEditorSyntaxHighlighting` as a direct dependency.** ~37 umbrella + test files gained `import CodeEditorSyntaxHighlighting`. The umbrella target gained `"SyntaxHighlighting"` in its `exclude:` list.
```

Fill in the placeholders (`<extraction-hash>`, `<commit-1-hash>`, `<commit-2-hash>`, and the two enumerate-here brackets) from the actual Task 4 work product before saving.

- [ ] **Step 5.4: Update `NEXT.md` §10 "Suggested next session" — remove §6.2.7 entry, add unblocked work**

Remove the bullet for `6.2.7 CodeEditorSyntaxHighlighting`. The next chunk is `6.2.8 feature engines` (Folding, Symbols, SmartEditing, Search, Annotations, Workspace, Completion).

Update the §6.2.8 bullet to acknowledge the SH dep is now available:

```markdown
- **6.2.8 feature engines** — `Folding`, `Symbols`, `SmartEditing`, `Search`, `Annotations`, `Workspace`, `Completion`. One session per engine. Completion last (most call sites). `Features/Debugger*` may be design-only — confirm-or-delete before promoting. `Folding`, `Symbols` can now `import CodeEditorSyntaxHighlighting` for `HighlightedToken`/`TokenType`/`StyledRangeContainer` (post-§6.2.7).
```

- [ ] **Step 5.5: Update `CLAUDE.md` "Other source roots" section**

Add to the list (currently has `CodeEditorCommon`, `CodeEditorDesignTokens`, `CodeEditorDiagnostics`, `CodeEditorPlugin/Languages`, `CodeEditorPlatform`, `CodeEditorTextModel`, `CodeEditorConfiguration`, `CodeEditorTheming`, `CodeEditorUI`, `CodeEditorSample`, `CodeEditorTreeSitterLanguages`):

```markdown
- `Sources/CodeEditorSyntaxHighlighting/` — syntax-highlighting engine: color schemes, tokenizers, regex/SwiftSyntax highlighters, parsing helpers, descriptor execution, performance instrumentation (phase 3.5).
```

- [ ] **Step 5.6: Update `CLAUDE.md` line counts**

Find the paragraph that reads:

```
19 top-level directories, 358 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions), and 588 Swift source files under `Sources/`.
```

Re-count after the extraction:

```bash
find Sources/CodeEditorPlugin -name '*.swift' | wc -l
find Sources -name '*.swift' | wc -l
ls -d Sources/CodeEditorPlugin/*/ | wc -l
```

Update the numbers to match the fresh counts. Top-level directory count likely drops by 1 (the empty `SyntaxHighlighting/` is gone). Umbrella file count drops by 36, total stays the same.

- [ ] **Step 5.7: Verify nothing else in `docs/` claims `SyntaxHighlighting/` is in the umbrella**

```bash
grep -rln 'Sources/CodeEditorPlugin/SyntaxHighlighting' docs/ Sources/ CLAUDE.md NEXT.md
```

Expected: no matches outside `docs/archive/` and `docs/superpowers/` (specs/plans freeze in time and are exempt). If a `docs/*.md` file outside those still references the old path, update it.

- [ ] **Step 5.8: Final build + lint**

```bash
swift build && swiftlint
```

Expected: clean.

- [ ] **Step 5.9: Commit**

```bash
git add NEXT.md CLAUDE.md
git commit -m "$(cat <<'EOF'
Update NEXT.md and CLAUDE.md for CodeEditorSyntaxHighlighting extraction

Mark §6.2.7 done with the carve-out deviation list (9 of 45 files
stayed in umbrella under Core/SyntaxHighlighting/; SwiftSyntax /
SwiftParser products migrated; no productization; access + Sendable
promotions captured). Add Sources/CodeEditorSyntaxHighlighting/ to
the CLAUDE.md source-root list. Refresh file counts.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Rollback procedures (per commit, in case of failure)

**Before any commit, work-in-progress:**

```bash
git restore --staged .
git restore .
git clean -fd Sources/CodeEditorSyntaxHighlighting Sources/CodeEditorPlugin/Core/SyntaxHighlighting
```

The `git clean` step removes any new directories created at Step 2.1 or 4.1 that didn't end up tracked.

**After Task 2's commit (Commit 1 — relocation):**

```bash
git reset --hard HEAD~1
```

Files revert to `Sources/CodeEditorPlugin/SyntaxHighlighting/`.

**After Task 3's commit (Commit 2 — factory inline):**

```bash
git reset --hard HEAD~1
```

`AdaptiveColorSystem.swift` reverts to the 5 `CodeEditorDependencies.makePlatformCapabilities()` sites.

**After Task 4's commit (Commit 3 — extraction):**

```bash
git reset --hard HEAD~1
```

`Sources/CodeEditorSyntaxHighlighting/` disappears; files return to `Sources/CodeEditorPlugin/SyntaxHighlighting/`; `Package.swift` reverts.

**After Task 5's commit (Commit 4 — docs):**

```bash
git reset --hard HEAD~1
```

Docs revert. Code is still extracted.

Do **not** use `git stash` for any rollback (per `feedback_no_stash.md`).

---

## What this plan deliberately doesn't do

- **No `HighlightableTextView` protocol.** The 9 `CodeEditorView`-coupled files stay in umbrella. Not introducing an abstraction over `CodeEditorView` is explicit per the spec (§2 Non-goals).
- **No productization.** No `.library(name: "CodeEditorSyntaxHighlighting", ...)` entry. Internal target only.
- **No new tests.** Existing test suite is the regression net. The 17 `Tests/CodeEditorPluginTests/*Syntax*` files plus the snapshot suites cover the surfaces that matter.
- **No `Features/` engine extractions.** `Folding`, `Symbols`, `SmartEditing`, etc. are §6.2.8 territory — separate plans, separate sessions.
- **No `Core/` split.** `Core/SyntaxHighlighting/` is a placement decision, not a target split. The actual `Core/` decomposition is §6.2.12.
- **No package rename.** `CodeEditorPlugin` stays `CodeEditorPlugin`. Workspace relocation is §6.2.16.
- **No `Sendable` conformance audit beyond what the compiler demands.** Don't proactively add `Sendable` to types the compiler doesn't complain about — those changes belong in their own dedicated audit pass.
- **No access-modifier audit beyond what the compiler demands.** Same principle: bump `internal` → `package` only as build errors surface, not preemptively.
