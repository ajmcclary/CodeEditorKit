# CodeEditorCompletion Extraction (§6.2.8g) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract a new `CodeEditorCompletion` SPM target containing the 19 completion subsystem files from `Sources/CodeEditorPlugin/Completion/`. Clean full extraction — no carve-out, no umbrella relocation, no `Core/Completion/` bucket. Two definite top-level access-modifier promotions plus a compile-driven member-level pass (0–10 expected).

**Architecture:** Single-commit extraction. The umbrella `CodeEditorPlugin` target depends on the new target (Completion is core editor functionality; ~12 umbrella files use its types). Not productized — umbrella-route only, matching Languages/SH/Folding/Symbols/Annotations precedent. Closes the §6.2.8 feature engines modulo deferred SmartEditing and pending Debugger confirm-or-delete.

**Tech Stack:** Swift 6.3 SPM package, `StrictConcurrency` enabled. New target dependencies: `CodeEditorCommon`, `CodeEditorDiagnostics`, `CodeEditorLanguages`, `CodeEditorPlatform`, `CodeEditorTextModel` (verified by audit — corrects NEXT.md §4.1's speculative `Languages, TextModel` claim). No new third-party deps. AppKit/UIKit conditional imports preserved on view-controller / item / item-adapter files.

**Spec:** `docs/superpowers/specs/2026-05-18-codeeditor-completion-extraction-design.md` (commit `c1f415ad`).

**Lessons baked in:**

- §6.2.7 SH: compile-driven access-modifier promotions; WIP checkpoint if count exceeds ~30.
- §6.2.8b Symbols: synthesized `init`s on `public`/`package` structs default to `internal` — add explicit `package init(...)` when promoting the type.
- §6.2.8d Search: do NOT blanket-drop `@testable import CodeEditorPlugin` from tests; internal umbrella symbols may still be required.
- §6.2.8e Annotations: bare-word grep (`\bCompletion\b`) catches consumers that compound-name grep misses; run the bare-word follow-up before declaring the consumer inventory final.
- §6.2.8f Workspace: SwiftPM resolution between scaffold and `git mv` needs at least a `.gitkeep` placeholder; an empty target with a `.gitkeep` is fine when the target has no `.library` product (our case).

---

### Task 1: Pre-flight audit

**Files:** read-only.

- [ ] **Step 1: Confirm carry-set (19 files in `Completion/`) is unchanged since spec**

Run:
```bash
ls -1 Sources/CodeEditorPlugin/Completion/
```

Expected: exactly these 19 files (alphabetical):
```
CodePatterns.swift
CompletionContextExtractor.swift
CompletionDebouncer.swift
CompletionEvent.swift
CompletionEventBroadcaster.swift
CompletionItem.swift
CompletionItemAdapter.swift
CompletionManager.swift
CompletionParsingHelpers.swift
CompletionProviderUtilities.swift
CompletionRankingModel.swift
CompletionViewController.swift
CompletionViewControllerBase.swift
CompletionViewControllerDelegate.swift
CompletionViewControllerRepresentable.swift
CompletionViewModels.swift
LanguageKeywordCompletionProvider.swift
OptimizedFuzzyMatcher.swift
SwiftUIClosureCompletionProvider.swift
```

If any file is missing or extras appear, stop and consult the user — the spec is stale.

- [ ] **Step 2: Re-verify the audit's "no `CodeEditorView` structural coupling" finding**

Run:
```bash
grep -n "CodeEditorView" Sources/CodeEditorPlugin/Completion/*.swift
```

Expected: only doc-comment hits (lines starting with `///` or inside `/** ... */` blocks). The known sites from the spec audit:
- `CompletionManager.swift:172` — doc comment "`CodeEditorView` on language change"
- `LanguageKeywordCompletionProvider.swift:9` — doc comment "whenever `CodeEditorView.language` changes"
- `CompletionEvent.swift:13` — doc comment "`EditorController.completionEvents()`" (note: `EditorController`, not `CodeEditorView`)

If any *non-comment* `CodeEditorView` reference appears (init/parameter/property/method access), stop. The clean-extraction premise is invalidated and the spec needs revisiting before proceeding.

- [ ] **Step 3: Confirm consumer-ripple inventory (12 cross-target consumer files) matches the spec**

Run:
```bash
grep -rln -E "\bCompletion(Manager|Event|EventBroadcaster|ItemAdapter|ViewController(Base|Delegate|Representable)?|ViewModels|Item\b|Statistics|Debouncer|RankingModel|ContextExtractor|ProviderUtilities|ParsingHelpers)\b|\bCodePatterns\b|\bLanguageKeywordCompletionProvider\b|\bOptimizedFuzzyMatcher\b|\bSwiftUIClosureCompletionProvider\b" Sources/CodeEditorPlugin --include='*.swift' 2>/dev/null | grep -v "Sources/CodeEditorPlugin/Completion/" | sort -u
```

Expected: these 12 paths (sorted):
```
Sources/CodeEditorPlugin/Core/CodeEditorView+CompletionExtensions.swift
Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformSpecificExtensions.swift
Sources/CodeEditorPlugin/Core/CodeEditorView.swift
Sources/CodeEditorPlugin/Core/CodeEditorViewDelegate.swift
Sources/CodeEditorPlugin/Core/CodeEditorViewDelegateProxy.swift
Sources/CodeEditorPlugin/Core/MemoryManagementCoordinator.swift
Sources/CodeEditorPlugin/Core/Symbols/SymbolNavigator.swift
Sources/CodeEditorPlugin/Core/TextViewDelegateParticipant.swift
Sources/CodeEditorPlugin/LSP/LSPCompletionProvider.swift
Sources/CodeEditorPlugin/LSP/LSPManager.swift
Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift
Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift
```

If extras appear, capture the new paths — Task 5 needs to add them to the umbrella import list. Re-verify the spec hasn't drifted.

If any of the 12 expected paths is missing, the file may have been deleted between spec and execution — stop and re-read the affected file before continuing.

- [ ] **Step 4: Run the §6.2.8e bare-word grep follow-up**

Run:
```bash
grep -rln "\bCompletion\b" Sources/CodeEditorPlugin --include='*.swift' 2>/dev/null | grep -v "Sources/CodeEditorPlugin/Completion/" | sort -u
```

Expected: the same 12 paths from Step 3, possibly plus a few more (the bare-word grep over-matches into doc comments and unrelated identifiers like `CompletionAsyncError`). For each new path, open the file and verify whether it actually uses a Completion-target type or only a Languages/Diagnostics/Common type. Only Completion-target type usages need the new import. Add any newly-confirmed consumers to the Task 5 list.

- [ ] **Step 5: Verify Sample / UI targets need no new dep (audit default expectation)**

Run:
```bash
grep -rln -E "\bCompletion(Manager|Event|EventBroadcaster|ItemAdapter|ViewController|ViewModels|Item\b|Statistics|Debouncer|RankingModel|ContextExtractor|ProviderUtilities|ParsingHelpers)\b|\bCodePatterns\b|\bLanguageKeywordCompletionProvider\b|\bOptimizedFuzzyMatcher\b|\bSwiftUIClosureCompletionProvider\b" Sources/CodeEditorSample Sources/CodeEditorUI Tests/CodeEditorSampleTests Tests/CodeEditorUITests Tests/CodeEditorDesignTokensTests --include='*.swift' 2>/dev/null | sort -u
```

Expected: **no output**. If any path prints, that target needs `CodeEditorCompletion` added to its `dependencies:` in Task 2 — capture the paths and amend the plan.

- [ ] **Step 6: Confirm CodeEditorPluginTests/Completion/ test files are unchanged since spec**

Run:
```bash
ls -1 Tests/CodeEditorPluginTests/Completion/
```

Expected: exactly these 10 files (alphabetical):
```
CodeEditorModifierCompletionIntegrationTests.swift
CompletionEventStreamTests.swift
CompletionManagerBuiltInProviderTests.swift
CompletionManagerLearningTests.swift
CompletionManagerRankingTests.swift
CompletionViewControllerTests.swift
CompletionViewWiringTests.swift
LanguageKeywordCompletionProviderTests.swift
SwiftUIClosureCompletionProviderTests.swift
SwiftUIClosureLifecycleTests.swift
```

If extras appear or files are missing, amend Task 5 Step 4 below.

- [ ] **Step 7: Capture baseline test pass count**

Run:
```bash
swift test --filter Completion 2>&1 | tail -10
```

Expected: a pass count for the Completion tests. Note the number in a scratch buffer; Task 6 Step 2 verifies the same count after extraction. If any test is failing on baseline, do NOT proceed — apply memory `feedback_fix_pre_existing_failures.md` and fix the failure(s) first, then re-baseline.

- [ ] **Step 8: Verify clean working tree**

Run:
```bash
git status --short
```

Expected: no output (clean tree). If there are uncommitted changes, stop and ask the user.

- [ ] **Step 9: Capture starting SHA for the NEXT.md back-reference (Task 8 + Task 9)**

Run:
```bash
git log -1 --format=%h
```

Expected: a 7+ char short SHA (currently `c1f415ad` from the spec commit, or a follow-up if work has landed since). Save it.

---

### Task 2: Scaffold the `CodeEditorCompletion` target in `Package.swift`

**Files:**
- Create: `Sources/CodeEditorCompletion/.gitkeep`
- Modify: `Package.swift`

- [ ] **Step 1: Create the new source root with a placeholder**

Run:
```bash
mkdir -p Sources/CodeEditorCompletion
touch Sources/CodeEditorCompletion/.gitkeep
```

The `.gitkeep` lets Step 5's build succeed against an "empty" target. It's deleted in Task 3 Step 1 once the 19 swift files are moved in.

- [ ] **Step 2: Add the `.target` stanza to `Package.swift`**

In `Package.swift`, locate the `CodeEditorAnnotations` target stanza (currently at lines 170–178):

```swift
        .target(
            name: "CodeEditorAnnotations",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorPlatform",
                "CodeEditorTheming"
            ],
            swiftSettings: swiftSettings
        ),
```

Immediately after it (and before the `CodeEditorFolding` stanza at line 179), insert the new target stanza. Use `Edit` with `old_string`:

```swift
        .target(
            name: "CodeEditorAnnotations",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorPlatform",
                "CodeEditorTheming"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorFolding",
```

and `new_string`:

```swift
        .target(
            name: "CodeEditorAnnotations",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorPlatform",
                "CodeEditorTheming"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorCompletion",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorFolding",
```

Note: no `path:` override (default `Sources/CodeEditorCompletion/` is correct). No `exclude:` or `resources:`. No `.product` entry (umbrella-route only per spec §2.5).

- [ ] **Step 3: Add `"CodeEditorCompletion"` to the umbrella `CodeEditorPlugin` target's `dependencies:`**

In `Package.swift`, locate the `CodeEditorPlugin` umbrella target stanza (currently at lines 205–228). Its `dependencies:` array reads:

```swift
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorFolding",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorSymbols",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
```

Use `Edit` to insert `"CodeEditorCompletion"` alphabetically (between `"CodeEditorCommon"` and `"CodeEditorConfiguration"`). Replace `old_string`:

```swift
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorConfiguration",
```

with `new_string`:

```swift
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorConfiguration",
```

- [ ] **Step 4: Add `"CodeEditorCompletion"` to `CodeEditorPluginTests` target's `dependencies:`**

In `Package.swift`, locate the `CodeEditorPluginTests` test target stanza (currently around lines 264–289). Its `dependencies:` array reads:

```swift
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorFolding",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
                "CodeEditorSearch",
                "CodeEditorSymbols",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
```

Use `Edit` to insert `"CodeEditorCompletion"` alphabetically (between `"CodeEditorCommon"` and `"CodeEditorConfiguration"`). Replace `old_string`:

```swift
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorFolding",
```

with `new_string`:

```swift
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorFolding",
```

- [ ] **Step 5: Do NOT add `"CodeEditorCompletion"` to `CodeEditorSample` / `CodeEditorUI` / `CodeEditorSampleTests` / `CodeEditorUITests` / `CodeEditorDesignTokensTests`**

Task 1 Step 5 confirmed no consumers in those targets. Skip those edits. If Task 1 Step 5 surfaced unexpected consumers, add the dep here using the same alphabetical-insert pattern.

- [ ] **Step 6: Do NOT add a `.library(name: "CodeEditorCompletion", ...)` product entry**

Spec §2.5: umbrella-route only. Verify the `products:` array (lines 55–84) is unchanged. The existing list (Design Tokens, Diagnostics, Plugin, Search, UI, Workspace, executable Sample) gains no new entry.

- [ ] **Step 7: Verify build is green with the empty target**

Run:
```bash
swift build 2>&1 | tail -20
```

Expected: `Build complete!` with no errors. The new `CodeEditorCompletion` target compiles as an empty module (just `.gitkeep`); the umbrella build still resolves all Completion types through `Sources/CodeEditorPlugin/Completion/` because the files haven't moved yet.

If the build fails with `the source files for target 'CodeEditorCompletion' should be located under 'Sources/CodeEditorCompletion'`, the directory wasn't created — re-run Step 1.

- [ ] **Step 8: No commit yet**

This task bundles with Tasks 3–8 into the single extraction commit (Task 9). Do not commit here.

---

### Task 3: Move the 19 files into `Sources/CodeEditorCompletion/`

After this task, `Sources/CodeEditorPlugin/Completion/` is empty (and gets removed). The 19 files compile inside the new target. The build is RED in umbrella + LSP + SwiftUI + Tests because consumer files still resolve Completion types via the old umbrella surface — Tasks 4 and 5 fix the access-modifier issues and add imports.

**Files:**
- Delete: `Sources/CodeEditorCompletion/.gitkeep`
- Move (git mv): 19 files from `Sources/CodeEditorPlugin/Completion/` → `Sources/CodeEditorCompletion/`
- Delete (after move): `Sources/CodeEditorPlugin/Completion/` directory

- [ ] **Step 1: Delete the scaffold placeholder**

Run:
```bash
rm Sources/CodeEditorCompletion/.gitkeep
```

- [ ] **Step 2: `git mv` all 19 files**

Run as a single shell command (so any individual `mv` failure halts the rest):

```bash
git mv Sources/CodeEditorPlugin/Completion/CodePatterns.swift Sources/CodeEditorCompletion/CodePatterns.swift && \
git mv Sources/CodeEditorPlugin/Completion/CompletionContextExtractor.swift Sources/CodeEditorCompletion/CompletionContextExtractor.swift && \
git mv Sources/CodeEditorPlugin/Completion/CompletionDebouncer.swift Sources/CodeEditorCompletion/CompletionDebouncer.swift && \
git mv Sources/CodeEditorPlugin/Completion/CompletionEvent.swift Sources/CodeEditorCompletion/CompletionEvent.swift && \
git mv Sources/CodeEditorPlugin/Completion/CompletionEventBroadcaster.swift Sources/CodeEditorCompletion/CompletionEventBroadcaster.swift && \
git mv Sources/CodeEditorPlugin/Completion/CompletionItem.swift Sources/CodeEditorCompletion/CompletionItem.swift && \
git mv Sources/CodeEditorPlugin/Completion/CompletionItemAdapter.swift Sources/CodeEditorCompletion/CompletionItemAdapter.swift && \
git mv Sources/CodeEditorPlugin/Completion/CompletionManager.swift Sources/CodeEditorCompletion/CompletionManager.swift && \
git mv Sources/CodeEditorPlugin/Completion/CompletionParsingHelpers.swift Sources/CodeEditorCompletion/CompletionParsingHelpers.swift && \
git mv Sources/CodeEditorPlugin/Completion/CompletionProviderUtilities.swift Sources/CodeEditorCompletion/CompletionProviderUtilities.swift && \
git mv Sources/CodeEditorPlugin/Completion/CompletionRankingModel.swift Sources/CodeEditorCompletion/CompletionRankingModel.swift && \
git mv Sources/CodeEditorPlugin/Completion/CompletionViewController.swift Sources/CodeEditorCompletion/CompletionViewController.swift && \
git mv Sources/CodeEditorPlugin/Completion/CompletionViewControllerBase.swift Sources/CodeEditorCompletion/CompletionViewControllerBase.swift && \
git mv Sources/CodeEditorPlugin/Completion/CompletionViewControllerDelegate.swift Sources/CodeEditorCompletion/CompletionViewControllerDelegate.swift && \
git mv Sources/CodeEditorPlugin/Completion/CompletionViewControllerRepresentable.swift Sources/CodeEditorCompletion/CompletionViewControllerRepresentable.swift && \
git mv Sources/CodeEditorPlugin/Completion/CompletionViewModels.swift Sources/CodeEditorCompletion/CompletionViewModels.swift && \
git mv Sources/CodeEditorPlugin/Completion/LanguageKeywordCompletionProvider.swift Sources/CodeEditorCompletion/LanguageKeywordCompletionProvider.swift && \
git mv Sources/CodeEditorPlugin/Completion/OptimizedFuzzyMatcher.swift Sources/CodeEditorCompletion/OptimizedFuzzyMatcher.swift && \
git mv Sources/CodeEditorPlugin/Completion/SwiftUIClosureCompletionProvider.swift Sources/CodeEditorCompletion/SwiftUIClosureCompletionProvider.swift
```

Verify count:
```bash
ls -1 Sources/CodeEditorCompletion/ | wc -l
```

Expected: `19`.

- [ ] **Step 3: Remove the now-empty source directory**

Run:
```bash
rmdir Sources/CodeEditorPlugin/Completion
```

If `rmdir` fails with "Directory not empty", inspect:
```bash
ls -la Sources/CodeEditorPlugin/Completion/
```

The likely culprit is a `.DS_Store`. Remove it (`rm Sources/CodeEditorPlugin/Completion/.DS_Store`) and retry `rmdir`. `.DS_Store` files are not tracked by git and don't affect SwiftPM.

- [ ] **Step 4: Verify the new target compiles in isolation**

Run:
```bash
swift build --target CodeEditorCompletion 2>&1 | tail -30
```

Expected: `Build complete!` with the 19 files compiled. If errors appear, they're internal to the new target (e.g., one moved file references a symbol from another moved file that isn't visible across files inside the same target — unlikely because internal access works within a target). Read the errors carefully — internal-target errors are fixable without leaving the task.

- [ ] **Step 5: Build the full package to expose the consumer red wavefront**

Run:
```bash
swift build 2>&1 | tail -80
```

Expected: build FAILS in umbrella + LSP + SwiftUI + Tests. The error pattern across these files:

- `cannot find 'CompletionViewController' in scope` (umbrella `Core/CodeEditorView.swift`, `Core/CodeEditorViewDelegate.swift`, `Core/CodeEditorView+CompletionExtensions.swift`)
- `cannot find 'CompletionViewControllerRepresentable' in scope` (umbrella `Core/CodeEditorView*`, `Core/TextViewDelegateParticipant.swift`)
- `cannot find 'CompletionManager' in scope` (umbrella `Core/MemoryManagementCoordinator.swift`, `SwiftUI/EditorController+Completion.swift`, `SwiftUI/CodeEditor+CoordinatorsExtensions.swift`)
- `cannot find 'CompletionItemAdapter' in scope` (umbrella `Core/CodeEditorView+PlatformSpecificExtensions.swift`, `LSP/LSPCompletionProvider.swift`, `LSP/LSPManager.swift`) — note: even after import is added, this one will *also* fail with access-level error because `CompletionItemAdapter` is `internal`; promotion happens in Task 4
- `cannot find 'OptimizedFuzzyMatcher' in scope` (umbrella `Core/Symbols/SymbolNavigator.swift`)
- `cannot find 'SwiftUIClosureCompletionProvider' in scope` (umbrella `SwiftUI/CodeEditor+CoordinatorsExtensions.swift`) — also access-level after import added; promotion in Task 4
- Plus test-target equivalents

Capture the list of failing files. It should match the 12-file umbrella list from Task 1 Step 3 plus the 10-file test list from Task 1 Step 6. Surprise additional failures → stop, re-survey, amend Task 5.

---

### Task 4: Cross-target access-modifier promotions

Two definite top-level promotions plus a compile-driven member-level pass. Per spec §4: expected count is `~2 top-level + 0–10 member`. Per §6.2.7 lesson, if member count exceeds 30, halt at WIP checkpoint and re-evaluate.

**Files:**
- Modify: `Sources/CodeEditorCompletion/CompletionItemAdapter.swift`
- Modify: `Sources/CodeEditorCompletion/SwiftUIClosureCompletionProvider.swift`
- Modify (probable): zero to a handful of other moved files for member-level promotions surfaced by compile errors

- [ ] **Step 1: Read `CompletionItemAdapter.swift` to identify its surface**

Read `Sources/CodeEditorCompletion/CompletionItemAdapter.swift` in full. Identify:
- The top-level type (`internal struct CompletionItemAdapter` — verified by spec audit).
- Whether the file declares an explicit `init` or relies on the synthesized memberwise init.
- Every stored property and whether it has an explicit access modifier.
- Every method and whether it has an explicit access modifier.

Note the exact line numbers — Step 2 needs them for `Edit` calls.

- [ ] **Step 2: Promote `CompletionItemAdapter` from `internal` to `package`**

Use `Edit` to change:

```swift
internal struct CompletionItemAdapter
```

to:

```swift
package struct CompletionItemAdapter
```

(The exact `internal` keyword may be absent — Swift's default access is internal. If the declaration reads `struct CompletionItemAdapter` with no modifier, replace it with `package struct CompletionItemAdapter`.)

If the file lacks an explicit `init`, the synthesized memberwise init defaults to `internal` (Swift access rule). Add an explicit `package init(...)` mirroring the stored-property signature. Example shape (substitute the actual properties read in Step 1):

```swift
package init(
    /* exact stored properties in declaration order */
) {
    /* exact self.X = X assignments */
}
```

- [ ] **Step 3: Promote `CompletionItemAdapter` stored properties to `package` (if accessed cross-target)**

Build:
```bash
swift build 2>&1 | grep -E "(CompletionItemAdapter|inaccessible)" | head -20
```

If the umbrella / LSP build errors mention specific `CompletionItemAdapter` properties as "inaccessible" or "not visible to module 'CodeEditorPlugin'", promote each named property from default-internal to `package`. Example shape:

```swift
// before
let displayLabel: String

// after
package let displayLabel: String
```

Don't promote properties that aren't named in compile errors — they remain internal.

If the build now passes for `CompletionItemAdapter`-related errors, proceed to Step 4.

- [ ] **Step 4: Read `SwiftUIClosureCompletionProvider.swift` to identify its surface**

Read `Sources/CodeEditorCompletion/SwiftUIClosureCompletionProvider.swift` in full. Identify:
- The top-level type (`internal final class SwiftUIClosureCompletionProvider`).
- Its `init` signature (likely accepts a SwiftUI closure).
- Whether it has stored properties accessed from outside.

Note line numbers.

- [ ] **Step 5: Promote `SwiftUIClosureCompletionProvider` from `internal` to `package`**

Use `Edit` to change:

```swift
internal final class SwiftUIClosureCompletionProvider
```

to:

```swift
package final class SwiftUIClosureCompletionProvider
```

Also promote its `init` signature(s) by changing `internal init(...)` (or unmarked `init(...)`) to `package init(...)`. The single cross-target call site is `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift`.

- [ ] **Step 6: Build to surface remaining promotion needs (compile-driven)**

Run:
```bash
swift build 2>&1 | tee /tmp/codeditor-completion-build.log | tail -40
```

Inspect `/tmp/codeditor-completion-build.log` for remaining "inaccessible" / "not visible" errors. For each error:

1. Open the moved file with the error.
2. Promote the named symbol (type, init, property, method) from default-internal to `package`.
3. Save and re-run `swift build`.

Iterate until no access-level errors remain. (Other error types — "cannot find X in scope" — are addressed by adding imports in Task 5; do NOT add imports during this task.)

Expected iteration count: 0–3 rounds, surfacing 0–10 member promotions total. Likely candidates per spec §4.3:
- `CompletionItemAdapter` stored properties + synthesized init (already addressed in Step 3).
- `SwiftUIClosureCompletionProvider` init signature + any stored closure properties.

- [ ] **Step 7: WIP-checkpoint trigger if promotion count exceeds 30**

If the compile-driven iteration in Step 6 reveals >30 member promotions, halt:

```bash
git add -A
git status --short
echo "WIP: §6.2.8g promotion-count exceeds 30 — stopping for re-evaluation" > /tmp/wip-marker.txt
```

Do NOT commit. Re-read the spec §4 and §5 with the discovered scope and consult the user before proceeding. The §6.2.7 SH precedent (107 promotions) has a successful playbook (bulk script + manual revisions for duplicate-modifier artifacts), so 30+ is not a blocker — just worth a checkpoint to confirm the work is in scope.

If iterations complete with ≤30 promotions, no checkpoint needed; proceed to Step 8.

- [ ] **Step 8: Verify build state post-promotions**

Run:
```bash
swift build 2>&1 | tail -20
```

Expected: the build remains red, but only on `cannot find 'X' in scope` errors — never on access-level errors anymore. If access-level errors persist, return to Step 6.

---

### Task 5: Add `import CodeEditorCompletion` to consumer files

This task adds the new import to the 12 cross-target umbrella consumer files + 10 test files identified by Tasks 1 Step 3 / Step 4 / Step 6. Each file keeps its existing imports (notably `import CodeEditorPlugin` in umbrella consumers — that's untouched — and `@testable import CodeEditorPlugin` in tests — also untouched per §6.2.8d lesson).

SwiftLint's `sorted_imports` rule enforces alphabetical order within each `#if` block. Insert `import CodeEditorCompletion` at the position that keeps the block sorted.

**Files (umbrella — 8 files):**
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+CompletionExtensions.swift`
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformSpecificExtensions.swift`
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorViewDelegate.swift`
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorViewDelegateProxy.swift`
- Modify: `Sources/CodeEditorPlugin/Core/MemoryManagementCoordinator.swift`
- Modify: `Sources/CodeEditorPlugin/Core/Symbols/SymbolNavigator.swift`
- Modify: `Sources/CodeEditorPlugin/Core/TextViewDelegateParticipant.swift`

**Files (LSP + SwiftUI — 4 files):**
- Modify: `Sources/CodeEditorPlugin/LSP/LSPCompletionProvider.swift`
- Modify: `Sources/CodeEditorPlugin/LSP/LSPManager.swift`
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift`
- Modify: `Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift`

**Files (tests — 10 files):**
- Modify: `Tests/CodeEditorPluginTests/Completion/CodeEditorModifierCompletionIntegrationTests.swift`
- Modify: `Tests/CodeEditorPluginTests/Completion/CompletionEventStreamTests.swift`
- Modify: `Tests/CodeEditorPluginTests/Completion/CompletionManagerBuiltInProviderTests.swift`
- Modify: `Tests/CodeEditorPluginTests/Completion/CompletionManagerLearningTests.swift`
- Modify: `Tests/CodeEditorPluginTests/Completion/CompletionManagerRankingTests.swift`
- Modify: `Tests/CodeEditorPluginTests/Completion/CompletionViewControllerTests.swift`
- Modify: `Tests/CodeEditorPluginTests/Completion/CompletionViewWiringTests.swift`
- Modify: `Tests/CodeEditorPluginTests/Completion/LanguageKeywordCompletionProviderTests.swift`
- Modify: `Tests/CodeEditorPluginTests/Completion/SwiftUIClosureCompletionProviderTests.swift`
- Modify: `Tests/CodeEditorPluginTests/Completion/SwiftUIClosureLifecycleTests.swift`

- [ ] **Step 1: Add `import CodeEditorCompletion` to each umbrella file (8 files)**

For each of the 8 umbrella files listed above:

1. Read the file's import block (top of file).
2. Locate the alphabetical position for `import CodeEditorCompletion` — between `CodeEditorCommon` (if present) and `CodeEditorConfiguration` / `CodeEditorDesignTokens` / next-alphabetical-import.
3. Use `Edit` to insert the import line.

Example pattern — if the file imports `CodeEditorCommon` then `CodeEditorPlugin`, edit:

```swift
import CodeEditorCommon
import CodeEditorPlugin
```

to:

```swift
import CodeEditorCommon
import CodeEditorCompletion
import CodeEditorPlugin
```

If the file's imports are inside `#if canImport(AppKit)` / `#elseif canImport(UIKit)` blocks, add the import inside each block — or, if the import block precedes the `#if`, just add it once at the top. Follow the existing pattern of the file. SwiftLint will flag wrong placement during Task 6 Step 1.

- [ ] **Step 2: Add `import CodeEditorCompletion` to LSP + SwiftUI files (4 files)**

Same pattern as Step 1 for the 4 LSP / SwiftUI files. These are inside umbrella source tree today, so they're umbrella-internal imports.

- [ ] **Step 3: Build to confirm the umbrella + LSP + SwiftUI red wavefront is now green**

Run:
```bash
swift build --target CodeEditorPlugin 2>&1 | tail -20
```

Expected: `Build complete!`. If any errors remain in umbrella source files, the import is missing or in the wrong `#if` block. Diagnose by reading the error line.

- [ ] **Step 4: Add `import CodeEditorCompletion` to the 10 test files**

For each test file under `Tests/CodeEditorPluginTests/Completion/`:

1. Read the file's import block.
2. Insert `import CodeEditorCompletion` at the alphabetical position.
3. **Keep `@testable import CodeEditorPlugin` exactly as it was.** Per §6.2.8d lesson, do NOT blanket-drop it — internal umbrella symbols may still be required.

Common import-block shape in these tests:

```swift
import CodeEditorPlugin
@testable import CodeEditorPlugin
import Foundation
import Testing
```

becomes:

```swift
import CodeEditorCompletion
import CodeEditorPlugin
@testable import CodeEditorPlugin
import Foundation
import Testing
```

SwiftLint's `sorted_imports` will adjust placement if you guess wrong. Don't sweat the exact ordering — run lint in Task 6 Step 1.

- [ ] **Step 5: Full build green**

Run:
```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!`. No errors anywhere. If errors remain, capture the file path and re-do Step 1/2/4 for it.

If build is red on a non-test target, the umbrella import is misplaced — read the error, fix the import, rebuild.

---

### Task 6: Verification

**Files:** none modified (except SwiftLint may rearrange imports in Step 1).

- [ ] **Step 1: Run lint with autofix**

Run:
```bash
swiftlint --fix
swiftlint
```

Expected: zero violations. Strict mode is on (`.swiftlint.yml`), so warnings fail the lint.

`swiftlint --fix` may rearrange the imports added in Task 5 — that's expected and folds into Task 9's main commit. Do not commit separately.

If lint reports new violations unrelated to Completion (e.g., a `no_print_statements` flag in a moved file), apply memory `feedback_fix_pre_existing_failures.md` — fix them inline. They're either pre-existing latent issues now surfaced by file relocation, or genuine bugs introduced during this task. Either way, fix-don't-document.

- [ ] **Step 2: Run targeted Completion tests**

Run:
```bash
swift test --filter Completion 2>&1 | tail -20
```

Expected: pass count matches the baseline captured in Task 1 Step 7. No new failures, no test count regressions.

If any tests fail with `cannot find X in scope`, the test file needs `import CodeEditorCompletion` — return to Task 5 Step 4.

If any tests fail with access-level errors, the spec missed a member-level promotion — go back to Task 4 Step 6, find the symbol, promote it.

If any tests fail with logic errors (e.g., a snapshot mismatch), the extraction may have changed runtime behavior. Read carefully — most likely a snapshot baseline needs regen *because* the production code changed. If it doesn't, that's a real regression.

- [ ] **Step 3: Skip the full test suite per memory `feedback_test_confirmations.md`**

This is an additive-only restructure with the build green and targeted tests passing. Do NOT run `swift test --parallel` — it adds ~minutes without uncovering anything the targeted filter would miss.

If you have specific reason to suspect a regression (e.g., the umbrella build surfaced an unexpected error fixed in Task 4 or Task 5), run the full suite. Otherwise skip.

- [ ] **Step 4: Verify file layout**

Run:
```bash
ls -1 Sources/CodeEditorCompletion/ | wc -l
ls Sources/CodeEditorPlugin/Completion 2>&1 | head -3
find Sources/CodeEditorPlugin -name '*.swift' | wc -l
find Sources -name '*.swift' | wc -l
```

Expected:
- First command: `19` (all 19 files present, no `.gitkeep`).
- Second command: `ls: Sources/CodeEditorPlugin/Completion: No such file or directory` (directory removed in Task 3 Step 3).
- Third command: `283` (302 − 19).
- Fourth command: `592` (unchanged — files moved, not added).

If the count is not 283/592, the move was incomplete. Re-run Task 3 Step 2 with the missing files.

- [ ] **Step 5: Sanity check `Package.swift` shape**

Run:
```bash
grep -n "CodeEditorCompletion" Package.swift
```

Expected: 3 hits:
1. The `.target` stanza (`name: "CodeEditorCompletion",`)
2. `"CodeEditorCompletion"` in `CodeEditorPlugin` (umbrella) `dependencies:`
3. `"CodeEditorCompletion"` in `CodeEditorPluginTests` `dependencies:`

If you see 0 hits in the `products:` array, that's correct (umbrella-route only per spec §2.5). If a `.library(name: "CodeEditorCompletion", ...)` entry appears, remove it (Task 2 Step 6 was skipped or misapplied).

- [ ] **Step 6: Confirm no `Core/Completion/` bucket was accidentally created**

Run:
```bash
ls Sources/CodeEditorPlugin/Core/Completion 2>&1 | head -3
```

Expected: `ls: Sources/CodeEditorPlugin/Core/Completion: No such file or directory`. Per spec §3.1, this is a clean extraction with no umbrella relocation; the `Core/Completion/` semantic bucket should NOT exist.

If it does, the executing agent created it by mistake. Inspect the directory contents:
```bash
ls -la Sources/CodeEditorPlugin/Core/Completion/
```

Move any files back to the new target (`git mv <path> Sources/CodeEditorCompletion/`) and `rmdir` the directory.

---

### Task 7: Sample app smoke (manual)

**Files:** none modified. This is the only manual gate in the plan.

- [ ] **Step 1: Kill any stale sample-app processes per memory `feedback_process_hygiene.md`**

Run:
```bash
pkill -f CodeEditorSample 2>/dev/null
pkill -f "lldb.*CodeEditorSample" 2>/dev/null
sleep 1
```

These return exit code 1 if no processes match — that's fine. If a process was running, kill it before launching a fresh build.

- [ ] **Step 2: Launch the sample app**

Run:
```bash
swift run CodeEditorSample
```

The first run may take ~30s for SPM to compile the freshly-restructured package.

- [ ] **Step 3: Exercise the completion popup**

In the sample app:

1. Open a Swift source file (any `.swift` file from `Sources/` works).
2. Position the cursor at the end of an existing identifier.
3. Type `.` (period — the standard trigger character).
4. Verify: a completion popup appears within ~200ms (the debouncer interval).
5. Verify: the popup lists candidate methods/properties.
6. Press the down-arrow key — selection moves.
7. Press the up-arrow key — selection moves back.
8. Press Return — the selected item is inserted at the cursor.
9. Press Escape (with the popup open) — popup dismisses without insertion.

If any of these regress, the extraction broke the completion UI wiring. Likely causes:
- Missing `import CodeEditorCompletion` in `Core/CodeEditorView+CompletionExtensions.swift` — re-check Task 5 Step 1.
- Access-level error on a `CompletionViewController` member — return to Task 4 Step 6.
- Delegate forwarding broken — check `CodeEditorViewDelegate.swift` and `CodeEditorViewDelegateProxy.swift` imports.

- [ ] **Step 4: Exercise the SwiftUI `.codeCompletion(provider:)` modifier**

If the sample app has a panel demonstrating the SwiftUI completion modifier, exercise it: type into the editor, verify the closure-provided completions appear. If no demo panel exists, this step is skipped — the integration test in `CodeEditorModifierCompletionIntegrationTests` covers it.

- [ ] **Step 5: Quit cleanly**

Cmd-Q to quit. No console errors. If the app does not quit cleanly, kill stale processes:
```bash
pkill -f CodeEditorSample 2>/dev/null
```

If any step in Task 7 fails, do not proceed to Task 8 — investigate, fix, re-run Task 6, then retry.

---

### Task 8: Update CLAUDE.md and NEXT.md

**Files:**
- Modify: `CLAUDE.md`
- Modify: `NEXT.md`

The `(pending commit SHA)` placeholders added in this task get back-filled in Task 9 Step 3 after the extraction commit lands.

- [ ] **Step 1: Update `CLAUDE.md` — remove `Completion/` from the umbrella source tree**

Open `CLAUDE.md`. Locate the `## Source Tree` code block (currently around lines 51–61). Its line for Completion reads:

```
├── Completion/              # Code completion providers
```

Use `Edit` to remove this line. Replace `old_string`:

```
├── Completion/              # Code completion providers
├── Core/                    # Main APIs, services, event system (includes F3 sub-buckets: Annotations/, Configuration/, Documents/, Folding/, Platform/, Search/, Symbols/, SyntaxHighlighting/, Text/ — umbrella-coupled glue staged here pending §6.2.12 Core split)
```

with `new_string`:

```
├── Core/                    # Main APIs, services, event system (includes F3 sub-buckets: Annotations/, Configuration/, Documents/, Folding/, Platform/, Search/, Symbols/, SyntaxHighlighting/, Text/ — umbrella-coupled glue staged here pending §6.2.12 Core split)
```

- [ ] **Step 2: Update `CLAUDE.md` — append `Completion/` to the pre-extraction list**

In `CLAUDE.md`, locate the line that currently reads (around line 63):

```markdown
Pre-extraction directories (`Text/`, `SyntaxHighlighting/`, `Theming/`, `Configuration/`, `Documents/`, `Platform/`, `Extensions/`, `Models/`, `Utilities/`, `Resources/`, `Workspace/`, `Search/`, `Annotations/`) have been carved out into sibling SPM targets — see "Other source roots" below.
```

Use `Edit` to append `Completion/` at the end (the list is chronological-by-extraction, not alphabetical — `Annotations/` was the most recent §6.2.8 addition; `Completion/` follows it):

```markdown
Pre-extraction directories (`Text/`, `SyntaxHighlighting/`, `Theming/`, `Configuration/`, `Documents/`, `Platform/`, `Extensions/`, `Models/`, `Utilities/`, `Resources/`, `Workspace/`, `Search/`, `Annotations/`, `Completion/`) have been carved out into sibling SPM targets — see "Other source roots" below.
```

- [ ] **Step 3: Update `CLAUDE.md` — refresh umbrella file count + dir count**

In `CLAUDE.md`, locate the line that currently reads (around line 67):

```
7 top-level directories in the umbrella target, 302 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f), and 592 Swift source files under `Sources/`.
```

Re-count files after the move (verified in Task 6 Step 4):
```bash
find Sources/CodeEditorPlugin -name '*.swift' | wc -l
find Sources -name '*.swift' | wc -l
```

Expected: umbrella drops to `283` (302 − 19); total stays at `592`. Top-level dirs drop from 7 to 6 (Completion/ removed).

Use `Edit` to replace the line with:

```
6 top-level directories in the umbrella target, 283 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g), and 592 Swift source files under `Sources/`.
```

If the actual `find` counts differ from `283` / `592`, use the actual numbers. The `480` baseline is historical and does not change.

- [ ] **Step 4: Update `CLAUDE.md` — add `CodeEditorCompletion` to "Other source roots"**

In `CLAUDE.md`, locate the bullet list under "Other source roots (each is its own SPM target — see `Package.swift`):" (starts around line 70). The list is NOT alphabetical — it groups by extraction phase / chronology. The §6.2.8 entries (Folding, Symbols, Annotations, Search, Workspace) are clustered toward the end before `Sample` and `TreeSitterLanguages`. `Workspace` (line 84, the most recent §6.2.8 entry) is the right anchor — insert the new `Completion` bullet immediately after it and before `Sample`.

Use `Edit` to replace `old_string`:
```markdown
- `Sources/CodeEditorWorkspace/` — workspace file-tree protocols + macOS `MacOSWorkspaceFileManager` adapter (phase 4; new in §6.2.8f). Productized as an opt-in `.library` per NEXT.md §6.3; the umbrella `CodeEditorPlugin` does not depend on it. Foundation-only; AppKit-conditional manager. iOS adapter is a future session.
- `Sources/CodeEditorSample/` — executable demo app target.
```

with `new_string`:
```markdown
- `Sources/CodeEditorWorkspace/` — workspace file-tree protocols + macOS `MacOSWorkspaceFileManager` adapter (phase 4; new in §6.2.8f). Productized as an opt-in `.library` per NEXT.md §6.3; the umbrella `CodeEditorPlugin` does not depend on it. Foundation-only; AppKit-conditional manager. iOS adapter is a future session.
- `Sources/CodeEditorCompletion/` — completion subsystem: `CompletionManager`, ranking model, fuzzy matcher, built-in providers, view controllers + adapter, event broadcaster (phase 4; new in §6.2.8g). 19 files. Not productized — umbrella consumes Completion types from ~12 files (`Core/CodeEditorView+CompletionExtensions.swift`, `LSP/`, `SwiftUI/`, `Core/Symbols/SymbolNavigator.swift`), so the new target routes through the umbrella per Folding/Symbols/SH/Annotations precedent.
- `Sources/CodeEditorSample/` — executable demo app target.
```

- [ ] **Step 5: Update `NEXT.md` §6.0 — append the Completion row to the status table**

Open `NEXT.md`. Locate the §6.0 status table. The current closing row is the `CodeEditorAnnotations` entry (commit `9ce2934a`). Append a new row immediately after:

```markdown
| `CodeEditorCompletion` | `(pending commit SHA)` | 19 files moved from umbrella `Completion/` to new target. Clean full extraction — no carve-out (zero `CodeEditorView` structural coupling in moving set). Final feature engine in §6.2.8 modulo deferred SmartEditing. Routes through umbrella (umbrella depends; not productized) per Folding/Symbols/SH/Annotations precedent. 2 access-modifier promotions (`CompletionItemAdapter`, `SwiftUIClosureCompletionProvider`) — see §6.2.8g deviation block for member-level details. | Common, Diagnostics, Languages, Platform, TextModel |
```

- [ ] **Step 6: Update `NEXT.md` §6.0 — add deviations block**

In `NEXT.md` §6.0, immediately after the §6.2.8e deviations block ("Deviations during §6.2.8e `CodeEditorAnnotations` (commit `9ce2934a`):"), insert:

```markdown
**Deviations during §6.2.8g `CodeEditorCompletion` (commit `(pending)`):**

- **Clean full extraction — no carve-out.** Second since §6.2.5 `CodeEditorTheming` / §6.2.8f `CodeEditorWorkspace`. All 19 files moved; no `Core/Completion/` semantic bucket created. The audit's surface "carve-out" recommendation was driven by AppKit/UIKit imports in the view controllers, but `CodeEditorPlatform` already abstracts that boundary and none of the 19 files reference `CodeEditorView` structurally — all `CodeEditorView` / `EditorController` mentions are doc-comment-only.
- **NEXT.md §4.1's `Completion → Languages, TextModel` dep claim was wrong.** Actual deps: `Common, Diagnostics, Languages, Platform, TextModel`. `CrossPlatformLogger` (`Common`), `LRUCache` + `MemoryMonitor` (`Diagnostics`), `PlatformViewController` + `PlatformColors` + `PlatformFonts` (`Platform`) are all required. Joins the §6.2.5 / §6.2.8b / §6.2.8e / §6.2.8f / §6.2.10 pattern of §4.1 dep claims being speculative until grep proves them.
- **Promotion surface narrower than §6.2.7 SH but wider than zero.** 2 definite top-level promotions (`CompletionItemAdapter`, `SwiftUIClosureCompletionProvider`) plus 0–10 member-level promotions surfaced by compile-driven iteration. Final count documented post-execution. Far smaller than §6.2.7 SH (~107) — most of the moving set was already `public`.
- **No productization.** Umbrella consumes Completion types from ~12 files (`Core/CodeEditorView*`, `Core/MemoryManagementCoordinator`, `Core/Symbols/SymbolNavigator`, `LSP/`, `SwiftUI/`); umbrella-route only matches Folding/Symbols/SH/Annotations precedent. The `CodeEditorView+CompletionExtensions.swift` partial-file extension cannot migrate out of umbrella, so Search/Workspace/Diagnostics opt-in pattern is structurally impossible here.
- **`CodeEditorPluginTests` target gained `CodeEditorCompletion` as a direct dep.** Sample / UI required no new deps (verified in pre-flight Task 1 Step 5). 10 test files under `Tests/CodeEditorPluginTests/Completion/` gained `import CodeEditorCompletion` alongside their existing `@testable import CodeEditorPlugin` (kept defensively per §6.2.8d's plan-execution lesson).
- **Section letter `8g`, not `8c`.** §6.2.8c is reserved for deferred SmartEditing.
- **Closes §6.2.8 feature engines.** With Completion landed, the remaining §6.2.8 work is `SmartEditing` (deferred §6.2.12) and `Debugger` (pending confirm-or-delete decision — not yet a feature-engine carve-out).
- **Phase 4 semantic label vs build-graph reality.** Completion is labelled phase 4 (feature engine). With deps on `Common, Diagnostics, Languages, Platform, TextModel`, its build-graph slot is between phase 3 (Languages, SH) and phase 4 (Diagnostics). Label kept because it's a feature, not foundational infra.
```

- [ ] **Step 7: Update `NEXT.md` §6.2.8 — add Completion sub-bullet**

In `NEXT.md` step 8 of §6.2 ("Extract feature engines individually"), the §6.2.8c SmartEditing deferred sub-bullet currently closes the list (after Annotations). Immediately below it add:

```markdown
   - **[done — clean extraction, see §6.0]** **`CodeEditorCompletion`** (§6.2.8g) — 19 files moved cleanly from `Sources/CodeEditorPlugin/Completion/` to `Sources/CodeEditorCompletion/`. Zero `CodeEditorView` structural coupling in moving set; no `Core/Completion/` bucket. Routes through umbrella (umbrella depends; not productized) per Folding/Symbols/SH/Annotations precedent. (`(pending)`)
```

- [ ] **Step 8: Update `NEXT.md` §10 "Suggested next session" — strike Completion from remaining list**

In `NEXT.md` §10, the first bullet currently reads:

```markdown
- **6.2.8 feature engines** — `Completion`. `Folding` is done (§6.2.8a, carve-out — see §6.0); `Symbols` is done (§6.2.8b, carve-out — see §6.0); `Search` is done (§6.2.8d, carve-out — see §6.0); `Annotations` is done (§6.2.8e, carve-out — see §6.0); `Workspace` is done (§6.2.8f, clean extraction — see §6.0); `SmartEditing` is **deferred** (§6.2.8c — blocked on §6.2.12 Core split because all 5 SmartEditing files take `CodeEditorView` as a parameter on every public entry point). Completion last (most call sites). `Features/Debugger*` may be design-only — confirm-or-delete before promoting.
```

Replace with:

```markdown
- **6.2.8 feature engines complete (modulo deferrals).** `Folding` (§6.2.8a), `Symbols` (§6.2.8b), `Search` (§6.2.8d), `Annotations` (§6.2.8e), `Workspace` (§6.2.8f), `Completion` (§6.2.8g) all extracted. `SmartEditing` is **deferred** (§6.2.8c — blocked on §6.2.12 Core split because all 5 SmartEditing files take `CodeEditorView` as a parameter on every public entry point). `Features/Debugger*` confirm-or-delete decision still pending — gate for §6.2.9 LSP/Debugger extraction.
```

- [ ] **Step 9: Update `NEXT.md` §10 "Suggested next session" preamble**

Locate the preamble line at the top of §10:

```markdown
Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8d, 6.2.8e, 6.2.8f, and 6.2.10 are done (see §6.0). Remaining work:
```

Replace with:

```markdown
Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8d, 6.2.8e, 6.2.8f, 6.2.8g, and 6.2.10 are done (see §6.0). Remaining work:
```

- [ ] **Step 10: Verify build + lint after doc edits**

Run:
```bash
swift build 2>&1 | tail -5
swiftlint 2>&1 | tail -5
```

Expected: both clean. Markdown edits don't affect compilation, but verify anyway in case a doc-update step accidentally touched a `.swift` file.

---

### Task 9: Main extraction commit + SHA back-fill

**Files:** none modified in this task; commit + record SHA back into `NEXT.md`.

- [ ] **Step 1: Stage all changes from Tasks 2–8**

Run:
```bash
git add Sources/CodeEditorCompletion \
        Sources/CodeEditorPlugin \
        Tests/CodeEditorPluginTests \
        Package.swift \
        CLAUDE.md \
        NEXT.md
git status --short
```

Expected output:
- 19 renames: `Sources/CodeEditorPlugin/Completion/<file>.swift` → `Sources/CodeEditorCompletion/<file>.swift`
- Modifications to ~12 umbrella source files (the consumer files from Task 5)
- Modifications to up to 2 moved files for promotions (`CompletionItemAdapter.swift`, `SwiftUIClosureCompletionProvider.swift`, plus any member-level files from Task 4 Step 6)
- Modifications to 10 test files under `Tests/CodeEditorPluginTests/Completion/`
- Modifications to `Package.swift`, `CLAUDE.md`, `NEXT.md`

If any unexpected files appear (e.g., `.DS_Store`, snapshot regeneration), investigate before committing.

- [ ] **Step 2: Create the main extraction commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
Extract CodeEditorCompletion target (§6.2.8g)

Move 19 files from Sources/CodeEditorPlugin/Completion/ into a
new CodeEditorCompletion SPM target:
  - CodePatterns, CompletionContextExtractor, CompletionDebouncer
  - CompletionEvent, CompletionEventBroadcaster, CompletionItem
  - CompletionItemAdapter, CompletionManager, CompletionParsingHelpers
  - CompletionProviderUtilities, CompletionRankingModel
  - CompletionViewController + Base + Delegate + Representable
  - CompletionViewModels, LanguageKeywordCompletionProvider
  - OptimizedFuzzyMatcher, SwiftUIClosureCompletionProvider

Clean full extraction — no carve-out, no Core/Completion/ bucket.
Second clean extraction in the §6.2.8 series after Workspace.
Audit confirmed zero CodeEditorView structural coupling in the
moving set (only doc-comment mentions); the surface "UI-files-
feel-umbrella-ish" carve-out recommendation was data-incongruent.

Two top-level access-modifier promotions (CompletionItemAdapter,
SwiftUIClosureCompletionProvider) plus a compile-driven member-
level pass — far smaller than §6.2.7 SH's ~107 because most of
the moving surface was already public.

Not productized — umbrella consumes Completion types from ~12
files (Core/CodeEditorView+CompletionExtensions, LSP, SwiftUI,
Symbols/SymbolNavigator), so the new target routes through the
umbrella per Folding/Symbols/SH/Annotations precedent. The
CodeEditorView+CompletionExtensions partial-file extension
cannot migrate out of umbrella, so Search/Workspace/Diagnostics
opt-in pattern is structurally impossible here.

Closes the §6.2.8 feature engines modulo deferred SmartEditing
(§6.2.8c — re-spec after §6.2.12 Core split) and pending
Debugger confirm-or-delete decision (gates §6.2.9).

Direct deps: Common, Diagnostics, Languages, Platform, TextModel.
NEXT.md §4.1's "Completion → Languages, TextModel" claim was
speculative; the audit grounded the real set. Joins the §6.2.5 /
§6.2.8b / §6.2.8e / §6.2.8f / §6.2.10 pattern of §4.1 dep
corrections.

Spec: docs/superpowers/specs/2026-05-18-codeeditor-completion-extraction-design.md
Plan: docs/superpowers/plans/2026-05-18-codeeditor-completion-extraction-plan.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Capture the commit SHA and back-fill `NEXT.md` placeholders**

Run:
```bash
git log -1 --format=%h
```

Save the short SHA (e.g., `abc1234`).

Open `NEXT.md` and replace each `(pending commit SHA)` / `(pending)` placeholder added in Task 8 with the actual SHA. Specifically:

- **Task 8 Step 5:** the status-table cell `| \`(pending commit SHA)\` |` becomes `| \`<SHA>\` |`.
- **Task 8 Step 6:** the deviations-block header `Deviations during §6.2.8g \`CodeEditorCompletion\` (commit \`(pending)\`):` becomes `... (commit \`<SHA>\`):`.
- **Task 8 Step 7:** the §6.2.8 sub-bullet trailing `(\`(pending)\`)` becomes `(\`<SHA>\`)`.

- [ ] **Step 4: Create the SHA back-fill commit**

Run:
```bash
git add NEXT.md
git commit -m "$(cat <<'EOF'
Update NEXT.md SHA back-reference for §6.2.8g

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Matching the §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f precedent of a separate follow-up commit (rather than `git commit --amend`). Keeps history tidy and reviewable.

- [ ] **Step 5: Verify final git state**

Run:
```bash
git log -5 --oneline
git status --short
```

Expected:
- Two new commits on top of the spec commit `c1f415ad`: the extraction commit and the SHA back-fill commit.
- Working tree clean.

- [ ] **Step 6: Stop. Do not push.**

The user will review the local commits and push when ready.

---

## Final state checklist

After all 9 tasks complete, the repo should match this end-state:

- [ ] `Sources/CodeEditorCompletion/` contains exactly 19 `.swift` files, no `.gitkeep`.
- [ ] `Sources/CodeEditorPlugin/Completion/` directory does not exist.
- [ ] `Sources/CodeEditorPlugin/Core/Completion/` directory does not exist (clean extraction, no umbrella bucket).
- [ ] `Package.swift` has a new `.target(name: "CodeEditorCompletion", ...)` stanza, no new `.library` product, and `CodeEditorCompletion` appears in `CodeEditorPlugin` umbrella `dependencies:` and `CodeEditorPluginTests` `dependencies:`.
- [ ] `CompletionItemAdapter` and `SwiftUIClosureCompletionProvider` declared `package`; explicit `package init(...)` on both.
- [ ] 12 umbrella source files have `import CodeEditorCompletion` added.
- [ ] 10 test files have `import CodeEditorCompletion` added alongside `@testable import CodeEditorPlugin`.
- [ ] `swift build && swiftlint --fix && swiftlint && swift test --filter Completion` passes green.
- [ ] Sample app smoke test (Task 7) confirms completion popup still renders, navigates, and inserts.
- [ ] `CLAUDE.md` source-tree section drops `Completion/`, file count drops to 283, dir count drops to 6, new `Sources/CodeEditorCompletion/` bullet added under "Other source roots", `Completion/` added to the "pre-extraction directories" list.
- [ ] `NEXT.md` §6.0 status table has the Completion row, §6.0 deviations block has the §6.2.8g entry, §6.2.8 step list has the Completion sub-bullet marked done, §10 preamble references §6.2.8g.
- [ ] Two commits on top of `c1f415ad`: the extraction commit and the SHA back-fill commit. Working tree clean.
