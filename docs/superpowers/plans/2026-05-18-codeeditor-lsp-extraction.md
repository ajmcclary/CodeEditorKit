# CodeEditorLSP Extraction (§6.2.9) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract a new `CodeEditorLSP` SPM target containing 22 of the 24 `Sources/CodeEditorPlugin/LSP/` files. Productized as an opt-in `.library` per NEXT.md §6.3. Carve-out shape — 2 `CodeEditorView`-coupled files (`LSPSemanticTokenProvider.swift`, `LSPContentCoordinator.swift`) relocate to a new umbrella `Core/LSP/` bucket via a pre-commit. The umbrella `CodeEditorPlugin` depends on the new target (matches §6.2.10 Diagnostics precedent — productized but umbrella-coupled).

**Architecture:** Three commits. (1) Pre-commit relocation of the 2 carve-out files into umbrella `Core/LSP/` (matches §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e pre-commit cadence). (2) Main extraction commit — scaffold target, `Package.swift` edits (target + `.library` product + dep additions), `git mv` 22 files, access-modifier promotions, import additions across umbrella + sample + tests, `CLAUDE.md` updates. (3) `NEXT.md` SHA back-fill commit. Closes §6.2.9 of the restructure; next is §6.2.11 Layout.

**Tech Stack:** Swift 6.3 SPM package, `StrictConcurrency` enabled. New target dependencies: `CodeEditorCommon`, `CodeEditorCompletion`, `CodeEditorDiagnostics`, `CodeEditorLanguages`, `CodeEditorPlatform`, `CodeEditorTextModel` (6 deps — verified by per-file `import` survey; corrects NEXT.md §4.1's speculative `Languages, Diagnostics, TextModel, Completion` claim by adding `Common` and `Platform`). No new third-party deps. Apple SDKs `Combine`, `CryptoKit`, `Security` already available.

**Spec:** `docs/superpowers/specs/2026-05-18-codeeditor-lsp-extraction-design.md` (commit `29b09c0`).

**Lessons baked in:**

- §6.2.7 SH: pre-commit relocation pattern for carve-out files; compile-driven access-modifier promotions; WIP checkpoint if promotion count exceeds ~30.
- §6.2.8b Symbols: synthesized `init`s on `public` structs default to `internal` — add explicit `package init(...)` when promoting cross-target access.
- §6.2.8d Search: do NOT blanket-drop `@testable import CodeEditorPlugin` from tests; internal umbrella symbols may still be required.
- §6.2.8e Annotations: bare-word grep (`\bLSP\b`) catches consumers that compound-name grep misses; run the bare-word follow-up before declaring the consumer inventory final. Sample-test target dep may need adding if bare-word grep surfaces a new path.
- §6.2.8f Workspace: SwiftPM resolution between scaffold and `git mv` needs a `.gitkeep` placeholder; with a `.library` product entry, the target also needs at least one `.swift` placeholder to compile (we create both during scaffold; both are removed in Task 4 once real files arrive).
- §6.2.10 Diagnostics: productized opt-in pattern with the umbrella depending on the new target — `.library` entry exposes a standalone product for external consumers without removing the umbrella's dep.

---

### Task 1: Pre-flight audit

**Files:** read-only.

- [ ] **Step 1: Confirm carry-set (24 files in `LSP/`) is unchanged since spec**

Run:
```bash
find Sources/CodeEditorPlugin/LSP -name '*.swift' | sort
```

Expected: exactly these 24 paths (alphabetical):
```
Sources/CodeEditorPlugin/LSP/LSPClient+Transport.swift
Sources/CodeEditorPlugin/LSP/LSPClient.swift
Sources/CodeEditorPlugin/LSP/LSPClientRegistry.swift
Sources/CodeEditorPlugin/LSP/LSPCompletionProvider.swift
Sources/CodeEditorPlugin/LSP/LSPConnectionManager.swift
Sources/CodeEditorPlugin/LSP/LSPContentCoordinator.swift
Sources/CodeEditorPlugin/LSP/LSPDocumentManager.swift
Sources/CodeEditorPlugin/LSP/LSPLanguageFeatures.swift
Sources/CodeEditorPlugin/LSP/LSPManager.swift
Sources/CodeEditorPlugin/LSP/LSPManagerTypes.swift
Sources/CodeEditorPlugin/LSP/LSPMessageHandler.swift
Sources/CodeEditorPlugin/LSP/LSPPathResolver.swift
Sources/CodeEditorPlugin/LSP/LSPProcessManager.swift
Sources/CodeEditorPlugin/LSP/LSPProtocol.swift
Sources/CodeEditorPlugin/LSP/LSPRetryConfiguration.swift
Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift
Sources/CodeEditorPlugin/LSP/LSPSemanticTokenStorage.swift
Sources/CodeEditorPlugin/LSP/LSPTypeAliases.swift
Sources/CodeEditorPlugin/LSP/LSPTypes.swift
Sources/CodeEditorPlugin/LSP/RemoteLSPConfiguration.swift
Sources/CodeEditorPlugin/LSP/Transport/LSPTransport.swift
Sources/CodeEditorPlugin/LSP/Transport/ProcessTransport.swift
Sources/CodeEditorPlugin/LSP/Transport/WebSocketPinningDelegate.swift
Sources/CodeEditorPlugin/LSP/Transport/WebSocketTransport.swift
```

If any file is missing or extras appear, stop and consult the user — the spec is stale.

- [ ] **Step 2: Re-verify the audit's `CodeEditorView` structural-coupling finding**

Run:
```bash
grep -nE "\bCodeEditorView\b" Sources/CodeEditorPlugin/LSP/*.swift Sources/CodeEditorPlugin/LSP/Transport/*.swift
```

Expected: exactly these 10 hits, only on `LSPSemanticTokenProvider.swift`, `LSPContentCoordinator.swift`, and one doc-comment hit on `LSPCompletionProvider.swift`:

```
Sources/CodeEditorPlugin/LSP/LSPCompletionProvider.swift:7:/// LSP-based completion provider that integrates with the CodeEditorView completion system
Sources/CodeEditorPlugin/LSP/LSPContentCoordinator.swift:39:    private weak var textView: CodeEditorView?
Sources/CodeEditorPlugin/LSP/LSPContentCoordinator.swift:66:        textView: CodeEditorView,
Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift:63:    private var textView: CodeEditorView?
Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift:79:    func setUp(textView: CodeEditorView, language: Language) {
Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift:107:    func willApplyEdit(textView _: CodeEditorView, range _: NSRange) {
Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift:111:    func willApplyEdit(textView _: CodeEditorView, source _: String, range _: NSRange) {
Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift:115:    func applyEdit(textView: CodeEditorView, range _: NSRange, delta _: Int) async -> IndexSet {
Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift:124:    func queryHighlights(textView: CodeEditorView, range: NSRange) async throws -> [HighlightedToken] {
Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift:180:    func refreshAfterBatch(textView _: CodeEditorView) {
```

`LSPCompletionProvider.swift:7` is doc-comment only — confirmed by line content beginning with `///`. The 9 hits on the other two files are structural. If structural references appear on any third file, the carve-out shape is invalidated and the spec needs revisiting before proceeding.

- [ ] **Step 3: Confirm umbrella consumer-ripple inventory matches the spec**

Run:
```bash
grep -rlnE "\bLSP[A-Z]" Sources/CodeEditorPlugin --include='*.swift' 2>/dev/null | grep -v "Sources/CodeEditorPlugin/LSP/" | sort -u
```

Expected: exactly these 4 paths (sorted):
```
Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift
Sources/CodeEditorPlugin/Core/CodeEditorView.swift
Sources/CodeEditorPlugin/Core/MemoryManagementCoordinator.swift
Sources/CodeEditorPlugin/SwiftUI/EditorController.swift
```

If extras appear, capture the new paths — Task 6 needs to add them to the umbrella import list. If any expected path is missing, the file may have been deleted between spec and execution — stop and re-read.

- [ ] **Step 4: Run the §6.2.8e bare-word grep follow-up**

Run:
```bash
grep -rln "\bLSP\b" Sources/CodeEditorPlugin --include='*.swift' 2>/dev/null | grep -v "Sources/CodeEditorPlugin/LSP/" | sort -u
```

Expected: the same 4 paths from Step 3, possibly plus paths whose only reference is in doc comments or non-type identifiers (e.g., `setupLSPIntegration`). For each new path, open the file and verify whether it actually uses an LSP-target type or only references LSP in a comment/method name. Only LSP-target type usages need the new import. Add any newly-confirmed consumers to Task 6's list.

- [ ] **Step 5: Confirm sample consumer-ripple inventory**

Run:
```bash
grep -rlnE "\bLSP[A-Z]" Sources/CodeEditorSample --include='*.swift' 2>/dev/null | sort -u
```

Expected: exactly these 9 paths (sorted):
```
Sources/CodeEditorSample/App/AppState.swift
Sources/CodeEditorSample/App/LSP/DiagnosticsBridge.swift
Sources/CodeEditorSample/App/LSP/HoverSession.swift
Sources/CodeEditorSample/App/LSP/LSPHoverPopover.swift
Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift
Sources/CodeEditorSample/App/LSP/ServerCapabilitiesSummary.swift
Sources/CodeEditorSample/App/WindowBody.swift
Sources/CodeEditorSample/Sidebars/InspectorPanelStack.swift
Sources/CodeEditorSample/Sidebars/LSPInspectorPanel.swift
```

Caveat (§6.2.8d / §6.2.8e / §6.2.8f lesson): some sample files may only reference LSP types in doc comments. Verify each with a quick read in Task 6; doc-comment-only references do NOT need the new import.

- [ ] **Step 6: Verify UI target needs no new dep**

Run:
```bash
grep -rlnE "\bLSP[A-Z]" Sources/CodeEditorUI --include='*.swift' 2>/dev/null
```

Expected: **no output**. If any path prints, that target needs `CodeEditorLSP` added to its `dependencies:` in Task 3 — capture the paths and amend the plan.

- [ ] **Step 7: Confirm test consumer-ripple inventory**

Run:
```bash
grep -rlnE "\bLSP[A-Z]" Tests --include='*.swift' 2>/dev/null | sort -u
```

Expected: exactly these 18 paths (sorted):
```
Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift
Tests/CodeEditorPluginTests/LSP/LSPClientRegistryRemoteFlowTests.swift
Tests/CodeEditorPluginTests/LSP/LSPCompletionRangeConversionTests.swift
Tests/CodeEditorPluginTests/LSP/LSPConnectionManagerShutdownTests.swift
Tests/CodeEditorPluginTests/LSP/LSPManagerIOSCoverageTests.swift
Tests/CodeEditorPluginTests/LSP/LSPProcessManagerReaderTests.swift
Tests/CodeEditorPluginTests/LSP/LanguageServerConfigFactoryTests.swift
Tests/CodeEditorPluginTests/LSP/WebSocketTransportSecurityTests.swift
Tests/CodeEditorPluginTests/LSPIntegrationTests.swift
Tests/CodeEditorPluginTests/LSPRetryTests.swift
Tests/CodeEditorPluginTests/LSPSemanticTokenStorageTests.swift
Tests/CodeEditorPluginTests/LSPTestHelpers.swift
Tests/CodeEditorSampleTests/DiagnosticsBridgeTests.swift
Tests/CodeEditorSampleTests/LSPInspectorPanelTests.swift
Tests/CodeEditorSampleTests/LSPLiveIntegrationTests.swift
Tests/CodeEditorSampleTests/LSPSampleCoordinatorDefinitionTests.swift
Tests/CodeEditorSampleTests/LSPSampleCoordinatorStateTests.swift
Tests/CodeEditorSampleTests/Support/StubProcessResolver.swift
```

That's **12 plugin-tests + 6 sample-tests = 18**. Note `SecurityOptionsTLSVersionTests.swift` is inside `Tests/CodeEditorPluginTests/LSP/` but does not match `\bLSP[A-Z]`. Open it and verify with a bare-word `grep "\bLSP\b" Tests/CodeEditorPluginTests/LSP/SecurityOptionsTLSVersionTests.swift`. If it has zero LSP references, no import is needed; if it does, add it to the Task 6 list.

- [ ] **Step 8: Capture baseline test pass count**

Run:
```bash
swift test --filter LSP 2>&1 | tail -10
```

Expected: a pass count for the LSP tests. Note the number — Task 7 Step 2 verifies the same count after extraction. If any test is failing on baseline, do NOT proceed — apply memory `feedback_fix_pre_existing_failures.md` and fix the failure(s) first, then re-baseline.

- [ ] **Step 9: Verify clean working tree**

Run:
```bash
git status --short
```

Expected: no output (clean tree). If there are uncommitted changes, stop and ask the user.

- [ ] **Step 10: Capture starting SHA for the NEXT.md back-reference (Task 9 + Task 10)**

Run:
```bash
git log -1 --format=%h
```

Expected: a 7+ char short SHA (currently `29b09c0` from the spec commit, or a follow-up if work has landed since). Save it.

---

### Task 2: Pre-commit — relocate the 2 carve-out files to `Core/LSP/`

This is its own commit so the carve-out relocation is reviewable in isolation, matching the §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e pre-commit cadence.

**Files:**
- Create: `Sources/CodeEditorPlugin/Core/LSP/` (new directory)
- Move (git mv): `Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift` → `Sources/CodeEditorPlugin/Core/LSP/LSPSemanticTokenProvider.swift`
- Move (git mv): `Sources/CodeEditorPlugin/LSP/LSPContentCoordinator.swift` → `Sources/CodeEditorPlugin/Core/LSP/LSPContentCoordinator.swift`

- [ ] **Step 1: Create the destination directory**

Run:
```bash
mkdir -p Sources/CodeEditorPlugin/Core/LSP
```

- [ ] **Step 2: `git mv` the two carve-out files**

Run as a single chained command so any individual `mv` failure halts the rest:

```bash
git mv Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift Sources/CodeEditorPlugin/Core/LSP/LSPSemanticTokenProvider.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPContentCoordinator.swift Sources/CodeEditorPlugin/Core/LSP/LSPContentCoordinator.swift
```

Verify both files moved:
```bash
ls Sources/CodeEditorPlugin/Core/LSP/
```

Expected output (2 files):
```
LSPContentCoordinator.swift
LSPSemanticTokenProvider.swift
```

And the source dir still has the other 22:
```bash
find Sources/CodeEditorPlugin/LSP -name '*.swift' | wc -l
```

Expected: `22`.

- [ ] **Step 3: Verify build is green**

Run:
```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!` with no errors. The relocated files compile from their new umbrella location; nothing changed in terms of module membership (both files are still in the umbrella `CodeEditorPlugin` target).

If the build fails, the most likely cause is that the two files referenced each other via internal access and now SwiftPM is unhappy about the path change — but the underlying access didn't change. If errors appear, read the message carefully — it's almost always something the relocation surfaced, not introduced.

- [ ] **Step 4: Run targeted LSP tests to confirm no behavioral regression**

Run:
```bash
swift test --filter LSP 2>&1 | tail -10
```

Expected: same pass count as Task 1 Step 8 baseline.

- [ ] **Step 5: Commit the pre-commit relocation**

Run:
```bash
git add Sources/CodeEditorPlugin/Core/LSP Sources/CodeEditorPlugin/LSP
git status --short
```

Expected: exactly 2 renames (the 2 carve-out files), no other changes.

Then:
```bash
git commit -m "$(cat <<'EOF'
Relocate LSP carve-out files to Core/LSP/ (pre-commit for §6.2.9)

Move LSPSemanticTokenProvider.swift and LSPContentCoordinator.swift
from Sources/CodeEditorPlugin/LSP/ to Sources/CodeEditorPlugin/Core/LSP/.
Both files reference CodeEditorView structurally (stored properties +
init parameters + protocol-conformance method signatures), so they
must stay in the umbrella when the CodeEditorLSP target extracts.
This pre-commit isolates the relocation from the main extraction.

Matches the §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e
pre-commit cadence.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: Capture the pre-commit SHA**

Run:
```bash
git log -1 --format=%h
```

Save the SHA. It gets referenced in NEXT.md §6.0 in Task 9.

---

### Task 3: Scaffold the `CodeEditorLSP` target in `Package.swift`

**Files:**
- Create: `Sources/CodeEditorLSP/` (directory)
- Create: `Sources/CodeEditorLSP/Transport/` (directory)
- Create: `Sources/CodeEditorLSP/.gitkeep`
- Create: `Sources/CodeEditorLSP/_ScaffoldPlaceholder.swift` (Swift file required because the target has a `.library` product per spec §6.1 / §6.2.8f lesson)
- Modify: `Package.swift`

- [ ] **Step 1: Create the new source roots with placeholders**

Run:
```bash
mkdir -p Sources/CodeEditorLSP/Transport
touch Sources/CodeEditorLSP/.gitkeep
```

Then create the placeholder Swift file (needed because the new target has a `.library` product; SwiftPM requires at least one `.swift` file to compile the module):

Create `Sources/CodeEditorLSP/_ScaffoldPlaceholder.swift` with content:

```swift
// Placeholder for scaffold; replaced by real sources in Task 4.
// See docs/superpowers/plans/2026-05-18-codeeditor-lsp-extraction.md Task 3 / Task 4.
```

Both files get deleted in Task 4 Step 1 once the 22 real `.swift` files arrive.

- [ ] **Step 2: Add the `.library` product entry to `Package.swift`**

In `Package.swift`, locate the `products:` array (lines 55–84). The current closing entry before `executable` is `CodeEditorWorkspace` (lines 76–79). Insert the new `CodeEditorLSP` product entry alphabetically — it slots between `CodeEditorDiagnostics` (lines 60–63) and `CodeEditorPlugin` (lines 64–67).

Use `Edit` with `old_string`:

```swift
        .library(
            name: "CodeEditorDiagnostics",
            targets: ["CodeEditorDiagnostics"]
        ),
        .library(
            name: "CodeEditorPlugin",
            targets: ["CodeEditorPlugin"]
        ),
```

and `new_string`:

```swift
        .library(
            name: "CodeEditorDiagnostics",
            targets: ["CodeEditorDiagnostics"]
        ),
        .library(
            name: "CodeEditorLSP",
            targets: ["CodeEditorLSP"]
        ),
        .library(
            name: "CodeEditorPlugin",
            targets: ["CodeEditorPlugin"]
        ),
```

- [ ] **Step 3: Add the `.target` stanza to `Package.swift`**

In `Package.swift`, locate the `CodeEditorFolding` target stanza (currently at lines 190–199). The `CodeEditorLSP` target slots alphabetically after `CodeEditorFolding` and before `CodeEditorSearch` (lines 200–203).

Use `Edit` with `old_string`:

```swift
        .target(
            name: "CodeEditorFolding",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorLanguages",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorSearch",
```

and `new_string`:

```swift
        .target(
            name: "CodeEditorFolding",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorLanguages",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorLSP",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorSearch",
```

Note: no `path:` override (default `Sources/CodeEditorLSP/` is correct). No `exclude:` or `resources:` (the `Transport/` subdir is normal source, not a resource).

- [ ] **Step 4: Add `"CodeEditorLSP"` to the umbrella `CodeEditorPlugin` target's `dependencies:`**

In `Package.swift`, locate the `CodeEditorPlugin` umbrella target stanza (currently at lines 216–240). Its `dependencies:` array reads:

```swift
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorCompletion",
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

Use `Edit` to insert `"CodeEditorLSP"` alphabetically (between `"CodeEditorLanguages"` and `"CodeEditorPlatform"`). Replace `old_string`:

```swift
                "CodeEditorFolding",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
```

with `new_string`:

```swift
                "CodeEditorFolding",
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
```

Note SwiftLint's `sorted_imports` rule applies to import statements, not Swift array literals — `Package.swift` deps follow alphabetical order by convention. `CodeEditorLSP` sorts before `CodeEditorLanguages` because uppercase `L` < lowercase `a` in ASCII. Verify with `git diff Package.swift` after the edit.

- [ ] **Step 5: Add `"CodeEditorLSP"` to `CodeEditorSample` target's `dependencies:`**

In `Package.swift`, locate the `CodeEditorSample` executable target stanza (currently at lines 251–276). Its `dependencies:` array reads:

```swift
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
                "CodeEditorSearch",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                "CodeEditorUI",
                "CodeEditorWorkspace"
            ],
```

Use `Edit` to insert `"CodeEditorLSP"` alphabetically (between `"CodeEditorLanguages"` and `"CodeEditorPlatform"`). Replace `old_string`:

```swift
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
```

with `new_string`:

```swift
                "CodeEditorDiagnostics",
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
```

- [ ] **Step 6: Add `"CodeEditorLSP"` to `CodeEditorPluginTests` target's `dependencies:`**

In `Package.swift`, locate the `CodeEditorPluginTests` test target stanza (currently at lines 277–303). Its `dependencies:` array reads:

```swift
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorCompletion",
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

Use `Edit` to insert `"CodeEditorLSP"` alphabetically. Replace `old_string`:

```swift
                "CodeEditorFolding",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
```

with `new_string`:

```swift
                "CodeEditorFolding",
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
```

- [ ] **Step 7: Add `"CodeEditorLSP"` to `CodeEditorSampleTests` target's `dependencies:`**

In `Package.swift`, locate the `CodeEditorSampleTests` test target stanza (currently at lines 329–348). Its `dependencies:` array reads:

```swift
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorSample",
                "CodeEditorSearch",
                "CodeEditorWorkspace",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
```

Use `Edit` to insert `"CodeEditorLSP"` alphabetically. Replace `old_string`:

```swift
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorSample",
```

with `new_string`:

```swift
                "CodeEditorDiagnostics",
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorSample",
```

- [ ] **Step 8: Do NOT touch `CodeEditorUI` or `CodeEditorUITests` or `CodeEditorDesignTokensTests`**

Task 1 Step 6 confirmed `CodeEditorUI` has no LSP consumers; the test counterparts inherit accordingly. Skip those edits. If Task 1 Step 6 surfaced unexpected consumers, add the dep here using the same alphabetical-insert pattern.

- [ ] **Step 9: Verify build is green with the placeholder target**

Run:
```bash
swift build 2>&1 | tail -20
```

Expected: `Build complete!` with no errors. The new `CodeEditorLSP` target compiles as a single-file module (just `_ScaffoldPlaceholder.swift`); the umbrella build still resolves all LSP types through `Sources/CodeEditorPlugin/LSP/` because the 22 files haven't moved yet.

If the build fails with `the source files for target 'CodeEditorLSP' should be located under 'Sources/CodeEditorLSP'`, the directory wasn't created — re-run Step 1.

If the build fails with `target 'CodeEditorLSP' contains no source files`, the placeholder Swift file is missing — re-run Step 1 and create `_ScaffoldPlaceholder.swift`.

- [ ] **Step 10: No commit yet**

This task bundles with Tasks 4–9 into the single extraction commit (Task 10). Do not commit here.

---

### Task 4: Move the 22 files into `Sources/CodeEditorLSP/`

After this task, `Sources/CodeEditorPlugin/LSP/` is empty and gets removed. The 22 files compile inside the new target. The build is RED in umbrella + sample + tests because consumer files still resolve LSP types via the old umbrella surface — Tasks 5 and 6 fix the access-modifier issues and add imports.

**Files:**
- Delete: `Sources/CodeEditorLSP/.gitkeep`
- Delete: `Sources/CodeEditorLSP/_ScaffoldPlaceholder.swift`
- Move (git mv): 18 top-level files from `Sources/CodeEditorPlugin/LSP/` → `Sources/CodeEditorLSP/`
- Move (git mv): 4 `Transport/` files from `Sources/CodeEditorPlugin/LSP/Transport/` → `Sources/CodeEditorLSP/Transport/`
- Delete (after move): `Sources/CodeEditorPlugin/LSP/Transport/` directory
- Delete (after move): `Sources/CodeEditorPlugin/LSP/` directory

- [ ] **Step 1: Delete the scaffold placeholders**

Run:
```bash
rm Sources/CodeEditorLSP/.gitkeep
rm Sources/CodeEditorLSP/_ScaffoldPlaceholder.swift
```

- [ ] **Step 2: `git mv` all 18 top-level files**

Run as a single chained command:

```bash
git mv Sources/CodeEditorPlugin/LSP/LSPClient.swift Sources/CodeEditorLSP/LSPClient.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPClient+Transport.swift Sources/CodeEditorLSP/LSPClient+Transport.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPClientRegistry.swift Sources/CodeEditorLSP/LSPClientRegistry.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPCompletionProvider.swift Sources/CodeEditorLSP/LSPCompletionProvider.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPConnectionManager.swift Sources/CodeEditorLSP/LSPConnectionManager.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPDocumentManager.swift Sources/CodeEditorLSP/LSPDocumentManager.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPLanguageFeatures.swift Sources/CodeEditorLSP/LSPLanguageFeatures.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPManager.swift Sources/CodeEditorLSP/LSPManager.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPManagerTypes.swift Sources/CodeEditorLSP/LSPManagerTypes.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPMessageHandler.swift Sources/CodeEditorLSP/LSPMessageHandler.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPPathResolver.swift Sources/CodeEditorLSP/LSPPathResolver.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPProcessManager.swift Sources/CodeEditorLSP/LSPProcessManager.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPProtocol.swift Sources/CodeEditorLSP/LSPProtocol.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPRetryConfiguration.swift Sources/CodeEditorLSP/LSPRetryConfiguration.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPSemanticTokenStorage.swift Sources/CodeEditorLSP/LSPSemanticTokenStorage.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPTypeAliases.swift Sources/CodeEditorLSP/LSPTypeAliases.swift && \
git mv Sources/CodeEditorPlugin/LSP/LSPTypes.swift Sources/CodeEditorLSP/LSPTypes.swift && \
git mv Sources/CodeEditorPlugin/LSP/RemoteLSPConfiguration.swift Sources/CodeEditorLSP/RemoteLSPConfiguration.swift
```

Verify count:
```bash
ls -1 Sources/CodeEditorLSP/*.swift | wc -l
```

Expected: `18`.

- [ ] **Step 3: `git mv` all 4 Transport files**

Run:

```bash
git mv Sources/CodeEditorPlugin/LSP/Transport/LSPTransport.swift Sources/CodeEditorLSP/Transport/LSPTransport.swift && \
git mv Sources/CodeEditorPlugin/LSP/Transport/ProcessTransport.swift Sources/CodeEditorLSP/Transport/ProcessTransport.swift && \
git mv Sources/CodeEditorPlugin/LSP/Transport/WebSocketPinningDelegate.swift Sources/CodeEditorLSP/Transport/WebSocketPinningDelegate.swift && \
git mv Sources/CodeEditorPlugin/LSP/Transport/WebSocketTransport.swift Sources/CodeEditorLSP/Transport/WebSocketTransport.swift
```

Verify:
```bash
ls -1 Sources/CodeEditorLSP/Transport/ | wc -l
```

Expected: `4`.

- [ ] **Step 4: Remove the now-empty source directories**

Run:
```bash
rmdir Sources/CodeEditorPlugin/LSP/Transport
rmdir Sources/CodeEditorPlugin/LSP
```

If `rmdir` fails with "Directory not empty", inspect:
```bash
ls -la Sources/CodeEditorPlugin/LSP/Transport/
ls -la Sources/CodeEditorPlugin/LSP/
```

The likely culprit is a `.DS_Store`. Remove it (`rm Sources/CodeEditorPlugin/LSP/.DS_Store`) and retry `rmdir`. `.DS_Store` files are not tracked by git.

- [ ] **Step 5: Verify the new target compiles in isolation**

Run:
```bash
swift build --target CodeEditorLSP 2>&1 | tail -40
```

Expected: `Build complete!` with the 22 files compiled. If errors appear, they're internal to the new target — e.g., one moved file references a symbol from another moved file that's `internal` and lives in a different file (still fine inside a target). Most likely outcome: clean build.

If errors mention "cannot find type 'LSPSemanticTokenProvider'" or "cannot find type 'LSPContentCoordinator'", a moved file references one of the 2 carve-out types that now live in the umbrella. The new target should not depend on those types — if it does, the carve-out boundary is wrong and the spec needs revisiting. Stop and consult.

- [ ] **Step 6: Build the full package to expose the consumer red wavefront**

Run:
```bash
swift build 2>&1 | tail -80
```

Expected: build FAILS in umbrella + sample + tests. The error pattern across these files:

- `cannot find 'LSPManager' in scope` (umbrella `Core/CodeEditorView.swift`, `Core/MemoryManagementCoordinator.swift`)
- `cannot find 'LSPRange' in scope` (umbrella `SwiftUI/EditorController.swift`)
- `cannot find 'LSPSemanticTokenStorage' in scope` (umbrella `Core/LSP/LSPSemanticTokenProvider.swift` — this one will also fail with access-level error after import is added because `LSPSemanticTokenStorage` is `internal`; promotion happens in Task 5)
- Plus all sample + test file equivalents

Capture the list of failing files. It should match the 4-file umbrella list from Task 1 Step 3, plus the 2 relocated carve-out files in `Core/LSP/`, plus the 9 sample files from Task 1 Step 5, plus the 18 test files from Task 1 Step 7. Surprise additional failures → stop, re-survey, amend Task 6.

---

### Task 5: Cross-target access-modifier promotions

Per spec §4: one confirmed top-level promotion (`LSPSemanticTokenStorage`) plus a compile-driven member-level pass. Expected range 5–15 total. Per §6.2.7 lesson, if member count exceeds 30, halt at WIP checkpoint and re-evaluate.

**Files:**
- Modify: `Sources/CodeEditorLSP/LSPSemanticTokenStorage.swift`
- Modify (probable): zero to a handful of other moved files for member-level promotions surfaced by compile errors

- [ ] **Step 1: Read `LSPSemanticTokenStorage.swift` to identify its surface**

Read `Sources/CodeEditorLSP/LSPSemanticTokenStorage.swift` in full. Identify:
- The top-level class declaration (`final class LSPSemanticTokenStorage` — verified by spec audit).
- Whether the file declares an explicit `init` or relies on the synthesized init.
- Every stored property and whether it has an explicit access modifier.
- Every method and whether it has an explicit access modifier.

Note the exact line numbers — Step 2 needs them for `Edit` calls.

- [ ] **Step 2: Promote `LSPSemanticTokenStorage` from `internal` to `package`**

Use `Edit` to change:

```swift
final class LSPSemanticTokenStorage
```

to:

```swift
package final class LSPSemanticTokenStorage
```

(The exact `internal` keyword may be absent — Swift's default access is internal. If the declaration reads `final class LSPSemanticTokenStorage` with no modifier, replace it with `package final class LSPSemanticTokenStorage`.)

If the file lacks an explicit `init`, the synthesized init defaults to `internal`. Add an explicit `package init(...)` mirroring the stored-property signature. Example shape (substitute the actual properties read in Step 1):

```swift
package init(
    /* exact stored properties in declaration order */
) {
    /* exact self.X = X assignments */
}
```

- [ ] **Step 3: Build to surface remaining `LSPSemanticTokenStorage`-related promotion needs**

Run:
```bash
swift build 2>&1 | grep -E "(LSPSemanticTokenStorage|inaccessible)" | head -20
```

If the umbrella build errors mention specific `LSPSemanticTokenStorage` properties or methods as "inaccessible" or "not visible to module 'CodeEditorPlugin'", promote each from default-internal to `package`. Example shapes:

```swift
// before
func insert(_ token: SemanticToken, at range: NSRange) { ... }
// after
package func insert(_ token: SemanticToken, at range: NSRange) { ... }

// before
let cachedTokens: [SemanticToken]
// after
package let cachedTokens: [SemanticToken]
```

Don't promote symbols not named in compile errors — they remain internal.

If the build now passes for `LSPSemanticTokenStorage`-related errors, proceed to Step 4.

- [ ] **Step 4: Compile-driven iteration for any remaining cross-target access errors**

Run:
```bash
swift build 2>&1 | tee /tmp/codeditor-lsp-build.log | tail -40
```

Inspect `/tmp/codeditor-lsp-build.log` for remaining "inaccessible" / "not visible" errors. For each:

1. Open the moved file with the error.
2. Promote the named symbol (type, init, property, method) from default-internal to `package`.
3. Save and re-run `swift build`.

Iterate until no access-level errors remain. (Other error types — "cannot find X in scope" — are addressed by adding imports in Task 6; do NOT add imports during this task.)

Expected iteration count: 0–3 rounds, surfacing 0–10 additional member promotions. Likely candidates per the carve-out files' usage:

- Methods on `LSPManager` called from `Core/LSP/LSPSemanticTokenProvider.swift` or `Core/LSP/LSPContentCoordinator.swift` that are currently `internal`.
- Synthesized inits on public structs that need explicit `public init(...)` declarations (§6.2.8b lesson).

- [ ] **Step 5: WIP-checkpoint trigger if promotion count exceeds 30**

If the compile-driven iteration in Step 4 reveals >30 member promotions, halt:

```bash
git add -A
git status --short
echo "WIP: §6.2.9 promotion-count exceeds 30 — stopping for re-evaluation" > /tmp/wip-marker.txt
```

Do NOT commit. Re-read the spec §4 and §5 with the discovered scope and consult the user before proceeding. The §6.2.7 SH precedent (107 promotions) has a successful playbook (bulk script + manual revisions for duplicate-modifier artifacts), so 30+ is not a blocker — just worth a checkpoint to confirm the work is in scope.

If iterations complete with ≤30 promotions, no checkpoint needed; proceed to Step 6.

- [ ] **Step 6: Verify build state post-promotions**

Run:
```bash
swift build 2>&1 | tail -20
```

Expected: the build remains red, but only on `cannot find 'X' in scope` errors — never on access-level errors anymore. If access-level errors persist, return to Step 4.

---

### Task 6: Add `import CodeEditorLSP` to consumer files

This task adds the new import to the umbrella consumers, the 2 relocated carve-out files, sample sources, and test files identified by Tasks 1 Steps 3 / 4 / 5 / 7. Each file keeps its existing imports (notably `import CodeEditorPlugin` and `@testable import CodeEditorPlugin` in tests — untouched per §6.2.8d lesson).

SwiftLint's `sorted_imports` rule enforces alphabetical order. `CodeEditorLSP` slots between `CodeEditorLanguages` and `CodeEditorPlatform` because uppercase `L` < lowercase `a`.

**Files (umbrella — 6 files):**
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift`
- Modify: `Sources/CodeEditorPlugin/Core/MemoryManagementCoordinator.swift`
- Modify: `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`
- Modify: `Sources/CodeEditorPlugin/Core/LSP/LSPContentCoordinator.swift`
- Modify: `Sources/CodeEditorPlugin/Core/LSP/LSPSemanticTokenProvider.swift`

**Files (sample — up to 9; bare-word grep at plan time may eliminate doc-comment-only refs):**
- Verify and modify (skip if doc-comment-only):
  - `Sources/CodeEditorSample/App/AppState.swift`
  - `Sources/CodeEditorSample/App/LSP/DiagnosticsBridge.swift`
  - `Sources/CodeEditorSample/App/LSP/HoverSession.swift`
  - `Sources/CodeEditorSample/App/LSP/LSPHoverPopover.swift`
  - `Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift`
  - `Sources/CodeEditorSample/App/LSP/ServerCapabilitiesSummary.swift`
  - `Sources/CodeEditorSample/App/WindowBody.swift`
  - `Sources/CodeEditorSample/Sidebars/InspectorPanelStack.swift`
  - `Sources/CodeEditorSample/Sidebars/LSPInspectorPanel.swift`

**Files (tests — up to 18):**
- Plugin-tests (12 confirmed by Task 1 Step 7):
  - `Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift`
  - `Tests/CodeEditorPluginTests/LSPIntegrationTests.swift`
  - `Tests/CodeEditorPluginTests/LSPRetryTests.swift`
  - `Tests/CodeEditorPluginTests/LSPSemanticTokenStorageTests.swift`
  - `Tests/CodeEditorPluginTests/LSPTestHelpers.swift`
  - `Tests/CodeEditorPluginTests/LSP/LSPClientRegistryRemoteFlowTests.swift`
  - `Tests/CodeEditorPluginTests/LSP/LSPCompletionRangeConversionTests.swift`
  - `Tests/CodeEditorPluginTests/LSP/LSPConnectionManagerShutdownTests.swift`
  - `Tests/CodeEditorPluginTests/LSP/LSPManagerIOSCoverageTests.swift`
  - `Tests/CodeEditorPluginTests/LSP/LSPProcessManagerReaderTests.swift`
  - `Tests/CodeEditorPluginTests/LSP/LanguageServerConfigFactoryTests.swift`
  - `Tests/CodeEditorPluginTests/LSP/WebSocketTransportSecurityTests.swift`
- Plus verify (likely no LSP type ref — confirm with bare-word grep at Step 0): `Tests/CodeEditorPluginTests/LSP/SecurityOptionsTLSVersionTests.swift`
- Sample-tests (6 confirmed):
  - `Tests/CodeEditorSampleTests/DiagnosticsBridgeTests.swift`
  - `Tests/CodeEditorSampleTests/LSPInspectorPanelTests.swift`
  - `Tests/CodeEditorSampleTests/LSPLiveIntegrationTests.swift`
  - `Tests/CodeEditorSampleTests/LSPSampleCoordinatorDefinitionTests.swift`
  - `Tests/CodeEditorSampleTests/LSPSampleCoordinatorStateTests.swift`
  - `Tests/CodeEditorSampleTests/Support/StubProcessResolver.swift`

- [ ] **Step 1: Add `import CodeEditorLSP` to each umbrella file (6 files)**

For each of the 6 umbrella files listed above:

1. Read the file's import block (top of file).
2. Locate the alphabetical position for `import CodeEditorLSP` — after `CodeEditorLanguages` (if present), before `CodeEditorPlatform` (if present) or any non-CodeEditor import.
3. Use `Edit` to insert the import line.

Example pattern — if the file imports `CodeEditorCommon`, `CodeEditorLanguages`, then `Foundation`, edit:

```swift
import CodeEditorCommon
import CodeEditorLanguages
import Foundation
```

to:

```swift
import CodeEditorCommon
import CodeEditorLSP
import CodeEditorLanguages
import Foundation
```

If a file has imports inside `#if canImport(AppKit)` / `#elseif canImport(UIKit)` blocks, add the import outside the block at top-level (LSP doesn't have AppKit/UIKit conditionals at the type level). Follow the existing pattern of the file. SwiftLint will flag wrong placement during Task 7 Step 1.

**Special case — `Core/LSP/LSPSemanticTokenProvider.swift`:** This file imports `CodeEditorSyntaxHighlighting` (verified by survey). After adding `import CodeEditorLSP`, the alphabetical block should read:

```swift
import CodeEditorCommon
import CodeEditorLSP
import CodeEditorLanguages
import CodeEditorPlatform
import CodeEditorSyntaxHighlighting
import Foundation
```

**Special case — `Core/LSP/LSPContentCoordinator.swift`:** Existing imports `CodeEditorCommon`, `CodeEditorTextModel`. After adding:

```swift
import CodeEditorCommon
import CodeEditorLSP
import CodeEditorTextModel
import Foundation
```

- [ ] **Step 2: Build to confirm the umbrella red wavefront is now green**

Run:
```bash
swift build --target CodeEditorPlugin 2>&1 | tail -20
```

Expected: `Build complete!`. If any errors remain in umbrella source files, the import is missing or misplaced. Diagnose by reading the error line.

- [ ] **Step 3: Verify sample consumers via bare-word grep**

For each of the 9 sample files listed in the Files section, run a quick bare-word check before adding the import. Example for `AppState.swift`:

```bash
grep -nE "\bLSP[A-Z]" Sources/CodeEditorSample/App/AppState.swift
```

If hits are all in doc comments (lines starting with `///` or inside `/** ... */`), skip the file — no import needed. If hits include code (type names in declarations, parameters, return types), add `import CodeEditorLSP` to the import block.

§6.2.8d / §6.2.8e / §6.2.8f lesson: sample files often have doc-comment-only references that don't require the import. Expect at least 1–2 of the 9 to fall in this category.

- [ ] **Step 4: Add `import CodeEditorLSP` to confirmed sample consumers**

For each sample file that Step 3 confirmed needs the import, use `Edit` to insert `import CodeEditorLSP` at the alphabetical position. Same pattern as Step 1.

- [ ] **Step 5: Build to confirm the sample target is green**

Run:
```bash
swift build --target CodeEditorSample 2>&1 | tail -20
```

Expected: `Build complete!`. If errors remain, the import is missing from a sample file that has a non-doc-comment LSP reference — re-run Step 3's grep with output enabled and add the import to whichever file has code-level usage.

- [ ] **Step 6: Add `import CodeEditorLSP` to plugin-test files (12 files)**

For each plugin-test file listed in the Files section:

1. Read the file's import block.
2. Insert `import CodeEditorLSP` at the alphabetical position.
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
import CodeEditorLSP
import CodeEditorPlugin
@testable import CodeEditorPlugin
import Foundation
import Testing
```

If the file has additional `CodeEditor*` imports, slot `CodeEditorLSP` alphabetically. SwiftLint's `sorted_imports` will adjust placement if you guess wrong. Don't sweat the exact ordering — run lint in Task 7 Step 1.

- [ ] **Step 7: Verify `SecurityOptionsTLSVersionTests.swift`**

Run:
```bash
grep -nE "\bLSP" Tests/CodeEditorPluginTests/LSP/SecurityOptionsTLSVersionTests.swift
```

If the grep returns any hits beyond comments — including non-prefix usage like `LSPSecurityOptions` — add `import CodeEditorLSP` to this file too. If no LSP type is used, leave it.

- [ ] **Step 8: Add `import CodeEditorLSP` to sample-test files (6 files)**

Same pattern as Step 6 for the 6 sample-test files listed in the Files section. These keep their existing `@testable import CodeEditorSample` (if present) — do not drop.

- [ ] **Step 9: Full build green**

Run:
```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!`. No errors anywhere. If errors remain, capture the file path and re-do Step 1/4/6/8 for it.

If build is red on a non-test target, the umbrella import is misplaced — read the error, fix the import, rebuild.

---

### Task 7: Verification

**Files:** none modified (except SwiftLint may rearrange imports in Step 1).

- [ ] **Step 1: Run lint with autofix**

Run:
```bash
swiftlint --fix
swiftlint
```

Expected: zero violations. Strict mode is on (`.swiftlint.yml`), so warnings fail the lint.

`swiftlint --fix` may rearrange the imports added in Task 6 — that's expected and folds into Task 10's main commit. Do not commit separately.

If lint reports new violations unrelated to LSP (e.g., a `no_print_statements` flag in a moved file), apply memory `feedback_fix_pre_existing_failures.md` — fix them inline. They're either pre-existing latent issues now surfaced by file relocation, or genuine bugs introduced during this task. Either way, fix-don't-document.

- [ ] **Step 2: Run targeted LSP tests**

Run:
```bash
swift test --filter LSP 2>&1 | tail -20
```

Expected: pass count matches the baseline captured in Task 1 Step 8. No new failures, no test count regressions.

If any tests fail with `cannot find X in scope`, the test file needs `import CodeEditorLSP` — return to Task 6 Step 6 or Step 8.

If any tests fail with access-level errors, the spec missed a member-level promotion — go back to Task 5 Step 4, find the symbol, promote it.

If any tests fail with logic errors (e.g., a snapshot mismatch), the extraction may have changed runtime behavior. Read carefully — most likely a snapshot baseline needs regen *because* the production code changed. If it doesn't, that's a real regression.

- [ ] **Step 3: Skip the full test suite per memory `feedback_test_confirmations.md`**

This is an additive-only restructure with the build green and targeted tests passing. Do NOT run `swift test --parallel` — it adds ~minutes without uncovering anything the targeted filter would miss.

If you have specific reason to suspect a regression (e.g., the umbrella build surfaced an unexpected error fixed in Task 5 or Task 6), run the full suite. Otherwise skip.

- [ ] **Step 4: Verify file layout**

Run:
```bash
ls -1 Sources/CodeEditorLSP/*.swift | wc -l
ls -1 Sources/CodeEditorLSP/Transport/*.swift | wc -l
ls Sources/CodeEditorPlugin/LSP 2>&1 | head -3
ls Sources/CodeEditorPlugin/Core/LSP/
find Sources/CodeEditorPlugin -name '*.swift' | wc -l
find Sources -name '*.swift' | wc -l
```

Expected:
- First command: `18` (top-level moved files).
- Second command: `4` (Transport/ files).
- Third command: `ls: Sources/CodeEditorPlugin/LSP: No such file or directory` (umbrella `LSP/` removed in Task 4 Step 4).
- Fourth command: `LSPContentCoordinator.swift` and `LSPSemanticTokenProvider.swift` (2 carve-out files in new home).
- Fifth command: `253` (275 − 22).
- Sixth command: `586` (unchanged — files moved, not added/deleted).

If the count is not 253/586, the move was incomplete. Re-run Task 4 Step 2 / Step 3 with the missing files.

- [ ] **Step 5: Sanity check `Package.swift` shape**

Run:
```bash
grep -n "CodeEditorLSP" Package.swift
```

Expected: 5 hits:
1. `.library(name: "CodeEditorLSP", ...)` product entry
2. The `.target` stanza (`name: "CodeEditorLSP",`)
3. `"CodeEditorLSP"` in `CodeEditorPlugin` (umbrella) `dependencies:`
4. `"CodeEditorLSP"` in `CodeEditorSample` `dependencies:`
5. `"CodeEditorLSP"` in `CodeEditorPluginTests` `dependencies:`
6. `"CodeEditorLSP"` in `CodeEditorSampleTests` `dependencies:`

(That's 6 — adjust count if any of the per-task verifications surfaced extra targets.)

If any are missing, return to Task 3 and add the missing entry.

- [ ] **Step 6: Confirm `Core/LSP/` bucket has exactly 2 files**

Run:
```bash
ls Sources/CodeEditorPlugin/Core/LSP/
```

Expected (alphabetical):
```
LSPContentCoordinator.swift
LSPSemanticTokenProvider.swift
```

If any extra file appears, the executing agent moved a file in the wrong direction. Inspect:
```bash
ls -la Sources/CodeEditorPlugin/Core/LSP/
```

Move the unexpected file back to the new target (`git mv <path> Sources/CodeEditorLSP/`) and verify build again.

---

### Task 8: Sample app smoke (manual)

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

- [ ] **Step 3: Exercise LSP-backed features (if available in the sample)**

In the sample app:

1. Open a Swift source file (any `.swift` file from `Sources/` works) — assuming the sample's `LSPSampleCoordinator` is configured for Swift via `sourcekit-lsp`. If the sample requires explicit setup, this step may be skipped per the sample's README/help text.
2. Open the LSP Inspector panel (sidebar). Verify the panel renders and shows server status.
3. Hover over an identifier (e.g., a function call) — a hover popover should appear within ~500ms if the LSP server is connected and supports `textDocument/hover`. If no server is connected (offline / dev environment), the popover won't appear — that's fine.
4. Open Definition — Cmd-Click an identifier or use the keyboard shortcut. If the LSP server supports `textDocument/definition` and the file resolves, the editor should jump to the definition. Verify the editor jump triggers and the cursor lands at the right line.
5. Diagnostics — if the LSP server publishes diagnostics, they should appear as annotations (line gutter markers / inline error squiggles). Verify diagnostics render in the gutter.

LSP setup is optional for the sample — if no language server is configured / available, steps 3–5 are skipped. The structural goal is: **the editor surface still renders, the LSP inspector panel doesn't crash, no exceptions are logged about missing types.**

If any of these regress (renders broken, panel crashes, console errors mentioning LSP types), the extraction broke an LSP wiring. Likely causes:
- Missing `import CodeEditorLSP` in `Core/LSP/LSPSemanticTokenProvider.swift` or `Core/LSP/LSPContentCoordinator.swift` — re-check Task 6 Step 1.
- Access-level error on an `LSPSemanticTokenStorage` member — return to Task 5 Step 4.
- Sample-side import missing on a coordinator file — re-check Task 6 Step 4.

- [ ] **Step 4: Quit cleanly**

Cmd-Q to quit. No console errors. If the app does not quit cleanly, kill stale processes:
```bash
pkill -f CodeEditorSample 2>/dev/null
```

If any step in Task 8 fails, do not proceed to Task 9 — investigate, fix, re-run Task 7, then retry.

---

### Task 9: Update CLAUDE.md and NEXT.md

**Files:**
- Modify: `CLAUDE.md`
- Modify: `NEXT.md`

The `(pending commit SHA)` placeholders added in this task get back-filled in Task 10 Step 3 after the extraction commit lands.

- [ ] **Step 1: Update `CLAUDE.md` — remove `LSP/` from the umbrella source tree**

Open `CLAUDE.md`. Locate the `## Source Tree` code block (currently around lines 51–61). Its line for LSP reads:

```
├── LSP/                     # Language Server Protocol support
```

Use `Edit` to remove this line. Replace `old_string`:

```
├── LSP/                     # Language Server Protocol support
├── Languages/               # Language descriptors + folding/symbol/completion-model interfaces (compiled as CodeEditorLanguages target via `path:`)
```

with `new_string`:

```
├── Languages/               # Language descriptors + folding/symbol/completion-model interfaces (compiled as CodeEditorLanguages target via `path:`)
```

- [ ] **Step 2: Update `CLAUDE.md` — append `LSP/` to the pre-extraction list**

In `CLAUDE.md`, locate the line that currently reads (around line 63):

```markdown
Pre-extraction directories (`Text/`, `SyntaxHighlighting/`, `Theming/`, `Configuration/`, `Documents/`, `Platform/`, `Extensions/`, `Models/`, `Utilities/`, `Resources/`, `Workspace/`, `Search/`, `Annotations/`, `Completion/`) have been carved out into sibling SPM targets — see "Other source roots" below.
```

Use `Edit` to append `LSP/` at the end (the list is chronological-by-extraction):

```markdown
Pre-extraction directories (`Text/`, `SyntaxHighlighting/`, `Theming/`, `Configuration/`, `Documents/`, `Platform/`, `Extensions/`, `Models/`, `Utilities/`, `Resources/`, `Workspace/`, `Search/`, `Annotations/`, `Completion/`, `LSP/`) have been carved out into sibling SPM targets — see "Other source roots" below.
```

- [ ] **Step 3: Update `CLAUDE.md` — refresh umbrella file count + dir count**

In `CLAUDE.md`, locate the line that currently reads (around line 67):

```
6 top-level directories in the umbrella target, 282 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g), and 593 Swift source files under `Sources/`.
```

(Note: the actual line may use slightly different numbers — Task 1 Step 4 of `Sources/CodeEditorPlugin` count was `275` not `282`; baseline counts may have drifted. Re-run counts after the move:)

```bash
find Sources/CodeEditorPlugin -name '*.swift' | wc -l
find Sources -name '*.swift' | wc -l
ls -d Sources/CodeEditorPlugin/*/ | wc -l
```

Expected: umbrella drops to `253` (275 − 22); total stays at `586`; top-level dirs drop from `6` to `5` (LSP/ removed; remaining: Core/, Features/, Languages/, Layout/, SwiftUI/). The Core/LSP/ subdir is inside Core/, not a new top-level dir.

Use `Edit` to replace the file-count line with the actual new numbers, adjusting the version-history annotation to include `§6.2.9`:

```
5 top-level directories in the umbrella target, 253 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9), and 586 Swift source files under `Sources/`.
```

If the actual `find` counts differ from `253` / `586` / `5`, use the actual numbers. The `480` baseline is historical and does not change.

- [ ] **Step 4: Update `CLAUDE.md` — add `CodeEditorLSP` to "Other source roots"**

In `CLAUDE.md`, locate the bullet list under "Other source roots (each is its own SPM target — see `Package.swift`):". The list is roughly chronological-by-extraction. `CodeEditorCompletion` (the §6.2.8g entry) is the most recent neighbor — insert the new `CodeEditorLSP` bullet immediately after it and before `Sources/CodeEditorSample/` / `Sources/CodeEditorTreeSitterLanguages/`.

Use `Edit` to replace `old_string`:
```markdown
- `Sources/CodeEditorCompletion/` — completion subsystem: `CompletionManager`, ranking model, fuzzy matcher, built-in providers, view controllers + adapter, event broadcaster, SwiftUI bridge types (phase 4; new in §6.2.8g). 20 files. Not productized — umbrella consumes Completion types from ~17 files (Core/CodeEditorView extensions + delegates + EditorEvent + UnifiedEventSystem, LSP, SwiftUI slice, Core/Symbols/SymbolNavigator), so the new target routes through the umbrella per Folding/Symbols/SH/Annotations precedent.
- `Sources/CodeEditorSample/` — executable demo app target.
```

with `new_string`:
```markdown
- `Sources/CodeEditorCompletion/` — completion subsystem: `CompletionManager`, ranking model, fuzzy matcher, built-in providers, view controllers + adapter, event broadcaster, SwiftUI bridge types (phase 4; new in §6.2.8g). 20 files. Not productized — umbrella consumes Completion types from ~17 files (Core/CodeEditorView extensions + delegates + EditorEvent + UnifiedEventSystem, LSP, SwiftUI slice, Core/Symbols/SymbolNavigator), so the new target routes through the umbrella per Folding/Symbols/SH/Annotations precedent.
- `Sources/CodeEditorLSP/` — Language Server Protocol subsystem: `LSPClient`, `LSPManager`, transport (process + WebSocket with cert pinning), document/path/process/connection managers, message handler, wire types, completion + semantic-token storage, retry config (phase 5; new in §6.2.9). 22 files (18 top-level + 4 in `Transport/`). Productized as opt-in `.library` per NEXT.md §6.3; the umbrella `CodeEditorPlugin` depends on it (matches §6.2.10 Diagnostics precedent — productized + umbrella-coupled, not §6.2.8d Search-style umbrella-decoupled opt-out). The two `CodeEditorView`-coupled files (`LSPSemanticTokenProvider`, `LSPContentCoordinator`) stay in umbrella at `Sources/CodeEditorPlugin/Core/LSP/`.
- `Sources/CodeEditorSample/` — executable demo app target.
```

- [ ] **Step 5: Update `NEXT.md` §6.0 — append the LSP row to the status table**

Open `NEXT.md`. Locate the §6.0 status table. The current closing row is the `CodeEditorCompletion` entry (commit `28b78b4f`). Append a new row immediately after:

```markdown
| `CodeEditorLSP` | `(pending commit SHA)` | 22 files moved from umbrella `LSP/` to new target (18 top-level + 4 Transport/). 2 `CodeEditorView`-coupled files (`LSPSemanticTokenProvider`, `LSPContentCoordinator`) relocated to umbrella `Core/LSP/` in pre-commit `(pending pre-commit SHA)`. Productized as opt-in `.library` per §6.3; umbrella DOES depend on it (matches §6.2.10 Diagnostics precedent). See §6.2.9 deviation block for promotion details. | Common, Completion, Diagnostics, Languages, Platform, TextModel |
```

- [ ] **Step 6: Update `NEXT.md` §6.0 — add deviations block**

In `NEXT.md` §6.0, immediately after the §6.2.9a Debugger deletion deviations block ("Deviations during §6.2.9a `CodeEditorDebugger` confirm-or-delete (commit `bf27ea2e`):"), insert:

```markdown
**Deviations during §6.2.9 `CodeEditorLSP` (commit `(pending)`, pre-commit `(pending pre-commit)`):**

- **Carve-out shape, matching §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e precedent.** 22 of 24 LSP files moved cleanly; 2 files (`LSPSemanticTokenProvider`, `LSPContentCoordinator`) stay in umbrella because both hold `CodeEditorView?` references and take `CodeEditorView` on init / protocol-conformance entry points. Relocated to `Sources/CodeEditorPlugin/Core/LSP/` in pre-commit `(pending pre-commit)`.
- **NEXT.md §4.1's dep claim was incomplete.** §4.1 listed `Languages, Diagnostics, TextModel, Completion`. Actual deps add `Common` and `Platform` (final set: `Common, Completion, Diagnostics, Languages, Platform, TextModel`). Joins the §6.2.5 / §6.2.8b / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.10 pattern of §4.1 dep-claim corrections.
- **Productized opt-in, umbrella DOES depend** — matches §6.2.10 Diagnostics precedent, not §6.2.8d Search / §6.2.8f Workspace umbrella-decoupled pattern. Reason: the umbrella's `MemoryManagementCoordinator.createLSPManager(...)` and `EditorController.nsRange(forLSPRange:)` are public API touching LSP types, and `CodeEditorView` stores `LSPContentCoordinator?` / `LSPSemanticTokenProvider?` (the 2 carve-out types). External consumers can opt out by depending on a sub-product (e.g. `CodeEditorTextModel` only) rather than the umbrella.
- **Access-modifier promotions:** 1 confirmed top-level (`LSPSemanticTokenStorage` class) + N member promotions (TBD at completion). `LSPManager` and `LSPRange` were already `public`, so no umbrella public-API signature changes. Total surface much smaller than §6.2.7 SH (~107) — comparable to §6.2.8b Symbols (~7).
- **No public-API removals from umbrella.** `MemoryManagementCoordinator.createLSPManager(...)` and `EditorController.nsRange(forLSPRange:)` stay in umbrella. The umbrella simply gains `import CodeEditorLSP` to keep their signatures compiling.
- **`CodeEditorPluginTests`, `CodeEditorSample`, `CodeEditorSampleTests` targets gained `CodeEditorLSP` as a direct dep.** `CodeEditorUI` and `CodeEditorUITests` and `CodeEditorDesignTokensTests` required no new deps (verified pre-flight Task 1 Step 6). 12 plugin-test files + 6 sample-test files gained `import CodeEditorLSP` alongside their existing `@testable import CodeEditorPlugin` (kept defensively per §6.2.8d's plan-execution lesson).
- **First post-Debugger-deletion target.** `LSP/` no longer has Debugger neighbors to disentangle — that scaffold was deleted in §6.2.9a (`bf27ea2e`). Clean carry-set.
- **Phase 5 build-graph slot.** With 6 deps spanning phase 0 (Common) through phase 4 (Diagnostics, Completion), LSP sits at build-graph phase 5. Matches §4.1's semantic label.
```

(Adjust `N` and `(pending)` values when Task 10 Step 3 back-fills the SHA.)

- [ ] **Step 7: Update `NEXT.md` §6.2 — mark §6.2.9 done**

In `NEXT.md` step 9 of §6.2 ("Extract `CodeEditorLSP`"), the current line reads:

```markdown
9. **Extract `CodeEditorLSP`** — depends on engines from step 8. Make it a separate **product**, not just a target, so consumers can opt out. (Debugger deleted in §6.2.9a — no sibling target; see deviations block.)
```

Replace with:

```markdown
9. **[done — carve-out, see §6.0]** **Extract `CodeEditorLSP`** (§6.2.9) — 22 of 24 LSP files moved to `Sources/CodeEditorLSP/` (18 top-level + 4 `Transport/`). 2 `CodeEditorView`-coupled files (`LSPSemanticTokenProvider`, `LSPContentCoordinator`) relocated to umbrella `Core/LSP/`. Productized as opt-in `.library`; umbrella DOES depend on it (matches §6.2.10 Diagnostics precedent). Final deps: `Common, Completion, Diagnostics, Languages, Platform, TextModel`. (`(pending)` + pre-commit `(pending pre-commit)`)
```

- [ ] **Step 8: Update `NEXT.md` §10 "Suggested next session" — drop §6.2.9 from remaining list**

Locate §10's bullet for §6.2.9 (currently):

```markdown
- **6.2.9 `CodeEditorLSP`** — own session. Expose as a separate product. (Debugger deleted in §6.2.9a — no sibling extraction.)
```

Delete this entire line. §10 should no longer list §6.2.9 in remaining work.

- [ ] **Step 9: Update `NEXT.md` §10 "Suggested next session" preamble**

Locate the preamble line at the top of §10:

```markdown
Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8d, 6.2.8e, 6.2.8f, 6.2.8g, and 6.2.10 are done (see §6.0). Remaining work:
```

Replace with:

```markdown
Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8d, 6.2.8e, 6.2.8f, 6.2.8g, 6.2.9, and 6.2.10 are done (see §6.0). Remaining work:
```

- [ ] **Step 10: Update NEXT.md §4.1 LSP row dep claim**

Locate §4.1's row for LSP (around lines 81–82 or wherever the phase 5/6 table is). The current text claims deps "Languages, Diagnostics, TextModel, Completion" (or similar).

Use `Edit` to update the deps cell to the actual surveyed set: `Common, Completion, Diagnostics, Languages, Platform, TextModel`. Exact text depends on the table's row format — preserve the row structure.

- [ ] **Step 11: Verify build + lint after doc edits**

Run:
```bash
swift build 2>&1 | tail -5
swiftlint 2>&1 | tail -5
```

Expected: both clean. Markdown edits don't affect compilation, but verify anyway in case a doc-update step accidentally touched a `.swift` file.

---

### Task 10: Main extraction commit + SHA back-fill

**Files:** none modified in this task; commit + record SHAs back into `NEXT.md`.

- [ ] **Step 1: Stage all changes from Tasks 3–9**

Run:
```bash
git add Sources/CodeEditorLSP \
        Sources/CodeEditorPlugin \
        Tests/CodeEditorPluginTests \
        Tests/CodeEditorSampleTests \
        Sources/CodeEditorSample \
        Package.swift \
        CLAUDE.md \
        NEXT.md
git status --short
```

Expected output:
- 22 renames: `Sources/CodeEditorPlugin/LSP/<file>.swift` → `Sources/CodeEditorLSP/<file>.swift` (including 4 under `Transport/`)
- Modifications to 6 umbrella source files (the 4 from Task 1 Step 3 + 2 relocated carve-out files from Task 6 Step 1)
- Modifications to up to 9 sample source files (Task 6 Step 4)
- Modifications to 12+ plugin-test files (Task 6 Step 6) plus possibly `SecurityOptionsTLSVersionTests.swift` (Step 7)
- Modifications to 6 sample-test files (Task 6 Step 8)
- Modifications to the moved `LSPSemanticTokenStorage.swift` (and any other promotion-targeted moved files from Task 5)
- Modifications to `Package.swift`, `CLAUDE.md`, `NEXT.md`

If any unexpected files appear (e.g., `.DS_Store`, snapshot regeneration), investigate before committing.

- [ ] **Step 2: Create the main extraction commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
Extract CodeEditorLSP target (§6.2.9)

Move 22 of 24 files from Sources/CodeEditorPlugin/LSP/ into a new
CodeEditorLSP SPM target. Two CodeEditorView-coupled files
(LSPSemanticTokenProvider, LSPContentCoordinator) stay in umbrella
at Sources/CodeEditorPlugin/Core/LSP/, relocated in pre-commit
(see §6.2.9 deviation block in NEXT.md).

Carve-out shape, matching the §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d
/ §6.2.8e precedent. Files moving to the new target include the
full LSP wire-protocol surface (LSPClient, LSPManager,
LSPDocumentManager, LSPMessageHandler, LSPProcessManager,
LSPConnectionManager, LSPRetryConfiguration, LSPLanguageFeatures,
LSPCompletionProvider, LSPManagerTypes, LSPSemanticTokenStorage,
LSPProtocol, LSPTypes, LSPTypeAliases, LSPPathResolver,
RemoteLSPConfiguration, LSPClientRegistry, LSPClient+Transport)
and the entire Transport/ subdirectory (LSPTransport,
ProcessTransport, WebSocketTransport, WebSocketPinningDelegate).

Productized as opt-in .library per NEXT.md §6.3. Umbrella
CodeEditorPlugin DOES depend on the new target — matches
§6.2.10 Diagnostics precedent (productized + umbrella-coupled),
not §6.2.8d Search / §6.2.8f Workspace umbrella-decoupled pattern.
Reason: MemoryManagementCoordinator.createLSPManager and
EditorController.nsRange(forLSPRange:) are public API touching
LSP types, and CodeEditorView stores LSP coordinator/provider
references — pulling those out is a §6.2.12 Core-split job.

Direct deps: Common, Completion, Diagnostics, Languages, Platform,
TextModel. NEXT.md §4.1's "Languages, Diagnostics, TextModel,
Completion" claim was incomplete; the audit grounded the real set.
Joins the §6.2.5 / §6.2.8b / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.10
pattern of §4.1 dep corrections.

Access-modifier promotions: LSPSemanticTokenStorage class + members
promoted internal → package to support cross-target consumption by
the relocated carve-out file. See §6.2.9 deviation block for full
count.

First post-Debugger-deletion target — the §6.2.9a deletion in
bf27ea2e cleared the LSP/ source dir's last design-only neighbor.

Spec: docs/superpowers/specs/2026-05-18-codeeditor-lsp-extraction-design.md
Plan: docs/superpowers/plans/2026-05-18-codeeditor-lsp-extraction.md

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

Also get the pre-commit SHA from Task 2 Step 6 (also saved as the second SHA).

Open `NEXT.md` and replace each `(pending commit SHA)`, `(pending)`, and `(pending pre-commit SHA)` / `(pending pre-commit)` placeholder added in Task 9 with the actual SHAs. Specifically:

- **Task 9 Step 5:** the status-table cell `| \`(pending commit SHA)\` |` becomes `| \`<main-SHA>\` |`; the `(pending pre-commit SHA)` reference inside the description becomes `\`<pre-commit-SHA>\``.
- **Task 9 Step 6:** the deviations-block header `Deviations during §6.2.9 \`CodeEditorLSP\` (commit \`(pending)\`, pre-commit \`(pending pre-commit)\`):` becomes `... (commit \`<main-SHA>\`, pre-commit \`<pre-commit-SHA>\`):`. The "Relocated to ... in pre-commit `(pending pre-commit)`" reference inside the block also gets `<pre-commit-SHA>`.
- **Task 9 Step 7:** the §6.2.9 sub-bullet trailing `(\`(pending)\` + pre-commit \`(pending pre-commit)\`)` becomes `(\`<main-SHA>\` + pre-commit \`<pre-commit-SHA>\`)`.

Replace the placeholder `N` for promotion count (Task 9 Step 6 deviations bullet 4) with the actual count.

- [ ] **Step 4: Create the SHA back-fill commit**

Run:
```bash
git add NEXT.md
git commit -m "$(cat <<'EOF'
Update NEXT.md SHA back-reference for §6.2.9

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Matching the §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g precedent of a separate follow-up commit (rather than `git commit --amend`). Keeps history tidy and reviewable.

- [ ] **Step 5: Verify final git state**

Run:
```bash
git log -5 --oneline
git status --short
```

Expected:
- Three new commits on top of the spec commit `29b09c0`: the pre-commit relocation, the main extraction commit, the SHA back-fill commit.
- Working tree clean.

- [ ] **Step 6: Stop. Do not push.**

The user will review the local commits and push when ready.

---

## Final state checklist

After all 10 tasks complete, the repo should match this end-state:

- [ ] `Sources/CodeEditorLSP/` contains exactly 18 top-level `.swift` files and a `Transport/` subdir with 4 files. No `.gitkeep`, no `_ScaffoldPlaceholder.swift`.
- [ ] `Sources/CodeEditorPlugin/LSP/` directory does not exist.
- [ ] `Sources/CodeEditorPlugin/Core/LSP/` contains exactly 2 files: `LSPSemanticTokenProvider.swift` and `LSPContentCoordinator.swift`.
- [ ] `Package.swift` has a new `.target(name: "CodeEditorLSP", ...)` stanza, a new `.library(name: "CodeEditorLSP", ...)` product entry, and `CodeEditorLSP` appears in `CodeEditorPlugin` umbrella + `CodeEditorSample` + `CodeEditorPluginTests` + `CodeEditorSampleTests` `dependencies:`.
- [ ] `LSPSemanticTokenStorage` declared `package`; explicit `package init(...)` where needed.
- [ ] 6 umbrella source files have `import CodeEditorLSP` added (4 pre-existing consumers + 2 relocated carve-out files).
- [ ] Confirmed sample source files have `import CodeEditorLSP` added (likely 6–9; doc-comment-only refs skipped).
- [ ] 12+ plugin-test files have `import CodeEditorLSP` added alongside `@testable import CodeEditorPlugin`.
- [ ] 6 sample-test files have `import CodeEditorLSP` added.
- [ ] `swift build && swiftlint --fix && swiftlint && swift test --filter LSP` passes green.
- [ ] Sample app smoke test (Task 8) confirms editor surface still renders, LSP inspector panel doesn't crash.
- [ ] `CLAUDE.md` source-tree section drops `LSP/`, file count drops to 253, dir count drops to 5, new `Sources/CodeEditorLSP/` bullet added under "Other source roots", `LSP/` added to the "pre-extraction directories" list.
- [ ] `NEXT.md` §6.0 status table has the LSP row, §6.0 deviations block has the §6.2.9 entry, §6.2 step 9 marked done, §10 preamble references §6.2.9, §4.1's LSP row deps corrected.
- [ ] Three commits on top of `29b09c0`: pre-commit relocation, main extraction, SHA back-fill. Working tree clean.
