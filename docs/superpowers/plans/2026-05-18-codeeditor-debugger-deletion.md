# CodeEditorDebugger Deletion (§6.2.9a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete the unreachable 7-file/1,410-LOC Debugger scaffold (`Sources/CodeEditorPlugin/Features/Debugger*.swift` + `DebugAdapter.swift`), reconcile 4 docs files (1 archive move + 3 surgical edits), and apply 14 NEXT.md edits + a new §6.2.9a deviations block. Strictly subtractive: zero functional code change outside the deleted files, zero new tests, zero access-modifier work, zero `Package.swift` change.

**Architecture:** Single main commit (the deletion + edits) plus a single-line follow-up commit that backfills the actual SHA into the new §6.2.9a deviations block. Matches the established pattern from §6.2.8g (`28b78b4f` + `7dfa081c`).

**Tech Stack:** Swift 6.3 SPM package with `StrictConcurrency`. The deletion does not touch the package manifest because the Debugger code never had its own target. SwiftLint strict mode is on; `swift build` is the load-bearing verification signal because zero tests reference Debugger types.

**Spec:** `docs/superpowers/specs/2026-05-18-codeeditor-debugger-deletion-design.md` (commit `91967bbe`).

---

### Task 1: Pre-flight audit

Verify nothing has changed since the spec was written. Capture baseline state. Read-only; no edits.

**Files:**
- Read-only audit; no edits in this task.

- [ ] **Step 1: Confirm the 7 deletion targets still exist**

Run:
```bash
ls -1 Sources/CodeEditorPlugin/Features/DebuggerIntegration*.swift Sources/CodeEditorPlugin/Features/DebuggerModels.swift Sources/CodeEditorPlugin/Features/DebugAdapter.swift
```

Expected output (exactly 7 lines, in any order):
```
Sources/CodeEditorPlugin/Features/DebuggerIntegration+Breakpoints.swift
Sources/CodeEditorPlugin/Features/DebuggerIntegration+Evaluation.swift
Sources/CodeEditorPlugin/Features/DebuggerIntegration+Execution.swift
Sources/CodeEditorPlugin/Features/DebuggerIntegration.swift
Sources/CodeEditorPlugin/Features/DebuggerIntegrationCore.swift
Sources/CodeEditorPlugin/Features/DebuggerModels.swift
Sources/CodeEditorPlugin/Features/DebugAdapter.swift
```

If any path is missing, stop and investigate — the audit underpinning this plan is no longer valid.

- [ ] **Step 2: Confirm zero in-tree consumers of framework Debugger types**

Run:
```bash
grep -rEn "DebuggerIntegrationCore|class DebugSession|struct LaunchConfiguration|struct StackFrame|struct DebugCapabilities|protocol DebugAdapter|class BaseDebugAdapter|class LLDBAdapter|class NodeDebugAdapter|class PythonDebugAdapter" Sources Tests --include='*.swift' 2>/dev/null | grep -vE "Sources/CodeEditorPlugin/Features/(Debugger|DebugAdapter)"
```

Expected output: **one line only** — a doc comment in `Sources/CodeEditorSample/EditorActions/AnnotationsHub.swift:16` that names `DebuggerIntegrationCore` in prose. Any other match means a real consumer has appeared since the audit; stop and consult §2.2 of the spec.

- [ ] **Step 3: Confirm zero `EditorConfiguration` debugger fields**

Run:
```bash
grep -nEi "debug|breakpoint" Sources/CodeEditorConfiguration/*.swift
```

Expected output: **no matches**. If anything prints, a new field was added since the audit; stop and re-audit.

- [ ] **Step 4: Confirm zero LSP wiring**

Run:
```bash
grep -nE "Debugger|DebugAdapter|DebugSession" Sources/CodeEditorPlugin/LSP/*.swift Sources/CodeEditorPlugin/LSP/Transport/*.swift 2>/dev/null
```

Expected output: **no matches**.

- [ ] **Step 5: Capture baseline build & test signal**

Run:
```bash
swift build 2>&1 | tail -5
```

Expected: ends with `Build complete!` (or equivalent success line). If the baseline build is red, stop — pre-existing breakage must be triaged before deletion. Capture the exact output for post-deletion comparison.

```bash
swift test --filter AnnotationsHubDiagnosticsTests 2>&1 | tail -5
```

Expected: ends with a passing summary (this test uses the sample's annotation-based breakpoint stand-in, which must keep working after the deletion).

- [ ] **Step 6: Confirm doc-edit targets are at the expected line numbers**

Run:
```bash
grep -n "class DebuggerIntegrationCore {" docs/Diagrams/11-advanced-features-integration.md
grep -n "class DebuggerIntegrationCore debugger" docs/Diagrams/11-advanced-features-integration.md
grep -n "classDef debugger" docs/Diagrams/11-advanced-features-integration.md
grep -n "Debugger<br/>Integration" docs/Diagrams/01-high-level-architecture.md
grep -n "class DIC advanced" docs/Diagrams/01-high-level-architecture.md
grep -n "20-debugging-integration.md" docs/Diagrams/README.md
```

Expected line numbers (per audit on commit `91967bbe`):
- `class DebuggerIntegrationCore {` → 228
- `class DebuggerIntegrationCore debugger` → 444
- `classDef debugger` → 422
- `Debugger<br/>Integration` → 43
- `class DIC advanced` → 226
- `20-debugging-integration.md` → 67 (one match)

If any line number is off by ≥3, the file has drifted since the spec; cross-check the edit instructions in Tasks 4–7 before proceeding (they use the surrounding text as anchors, not raw line numbers, so a small shift is recoverable).

---

### Task 2: Delete the 7 Debugger source files

The audit (§2 of the spec) confirmed zero consumers. This task removes the files in one batch.

**Files:**
- Delete: `Sources/CodeEditorPlugin/Features/DebuggerIntegration.swift`
- Delete: `Sources/CodeEditorPlugin/Features/DebuggerIntegrationCore.swift`
- Delete: `Sources/CodeEditorPlugin/Features/DebuggerIntegration+Breakpoints.swift`
- Delete: `Sources/CodeEditorPlugin/Features/DebuggerIntegration+Evaluation.swift`
- Delete: `Sources/CodeEditorPlugin/Features/DebuggerIntegration+Execution.swift`
- Delete: `Sources/CodeEditorPlugin/Features/DebuggerModels.swift`
- Delete: `Sources/CodeEditorPlugin/Features/DebugAdapter.swift`

- [ ] **Step 1: Remove all seven files via `git rm`**

Run:
```bash
git rm Sources/CodeEditorPlugin/Features/DebuggerIntegration.swift \
       Sources/CodeEditorPlugin/Features/DebuggerIntegrationCore.swift \
       Sources/CodeEditorPlugin/Features/DebuggerIntegration+Breakpoints.swift \
       Sources/CodeEditorPlugin/Features/DebuggerIntegration+Evaluation.swift \
       Sources/CodeEditorPlugin/Features/DebuggerIntegration+Execution.swift \
       Sources/CodeEditorPlugin/Features/DebuggerModels.swift \
       Sources/CodeEditorPlugin/Features/DebugAdapter.swift
```

Expected output: `rm 'Sources/CodeEditorPlugin/Features/...'` × 7. No errors.

- [ ] **Step 2: Verify the directory now has only the remaining 5 files**

Run:
```bash
find Sources/CodeEditorPlugin/Features -type f -name '*.swift' | sort
```

Expected output (exactly 5 paths):
```
Sources/CodeEditorPlugin/Features/SmartEditing/AutoBracketingEngine.swift
Sources/CodeEditorPlugin/Features/SmartEditing/MultiCursorEditor.swift
Sources/CodeEditorPlugin/Features/SmartEditing/SmartIndentationEngine.swift
Sources/CodeEditorPlugin/Features/SmartEditing/SmartSelectionExpander.swift
Sources/CodeEditorPlugin/Features/SmartEditingEngine.swift
```

- [ ] **Step 3: Smoke-test the build**

Run:
```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!`. If anything outside the deleted files cited a Debugger type, the build will now fail. If it does:
1. Capture the error message and the offending file.
2. Run `git restore --staged Sources/CodeEditorPlugin/Features/` and `git checkout -- Sources/CodeEditorPlugin/Features/` to undo.
3. Stop and consult §9 of the spec (Rollback).

Do **not** run the full test suite here — it's redundant with the build (zero tests reference the deleted types) and slow. The smoke test in Step 3 is the load-bearing check.

---

### Task 3: Archive the design-only diagram

Move `docs/Diagrams/20-debugging-integration.md` into `docs/archive/Diagrams/`. The archive already has a sibling `20-debugging-integration-architecture.md` (the older extended design); the moved file uses its current name and does not collide.

**Files:**
- Move: `docs/Diagrams/20-debugging-integration.md` → `docs/archive/Diagrams/20-debugging-integration.md`

- [ ] **Step 1: Confirm the archive destination is free**

Run:
```bash
ls docs/archive/Diagrams/20-debugging-integration.md 2>&1
```

Expected output: `ls: docs/archive/Diagrams/20-debugging-integration.md: No such file or directory`. If the file already exists in the archive (collision), stop — the spec's "no collision" claim is wrong; consult the user.

- [ ] **Step 2: Move the file**

Run:
```bash
git mv docs/Diagrams/20-debugging-integration.md docs/archive/Diagrams/20-debugging-integration.md
```

Expected: no output, exit code 0.

- [ ] **Step 3: Verify the move**

Run:
```bash
ls docs/Diagrams/20-debugging-integration.md 2>&1 ; ls docs/archive/Diagrams/20-debugging-integration.md
```

Expected:
- First command: `ls: docs/Diagrams/20-debugging-integration.md: No such file or directory`
- Second command: `docs/archive/Diagrams/20-debugging-integration.md`

---

### Task 4: Edit `docs/Diagrams/11-advanced-features-integration.md`

Remove the Debugger class block, the two cross-component edges, the LSP-section header rename + 3 edges, the classDef style, and the prose subsection. Five distinct edits to one file.

**Files:**
- Modify: `docs/Diagrams/11-advanced-features-integration.md`

- [ ] **Step 1: Remove the `DebuggerIntegrationCore` class block + section comment (Mermaid)**

Use Edit tool. Find this exact block (lines 227–245 in the audited file, anchored by the `%% Sixth Row` comment):

`old_string`:
```
    %% Sixth Row - Enhanced Debugger Integration with LSP
    class DebuggerIntegrationCore {
        <<debugger core>>
        +debugSessions [String: DebugSession]
        +activeSession DebugSession
        +breakpoints [Breakpoint]
        +currentFrame StackFrame
        +variables [Variable]
        +isDebugging Bool
        +debugAdapters [String: DebugAdapter]
        +configuration Configuration
        +startSession(configuration, textView)
        +stopSession(sessionId)
        +registerAdapter(adapter, language)
        +syncBreakpoints()
        +getStackTrace()
        +selectFrame(frame)
    }

    class LSPManager {
```

`new_string`:
```
    class LSPManager {
```

Result: the section comment + class block (19 lines) are removed; the file continues with `class LSPManager {` directly.

- [ ] **Step 2: Remove the `PerformanceInsights --> DebuggerIntegrationCore` edge**

Use Edit tool.

`old_string`:
```
    PerformanceInsights --> CodeFoldingEngine : monitors
    PerformanceInsights --> DebuggerIntegrationCore : monitors
    PerformanceInsights --> LSPManager : monitors
```

`new_string`:
```
    PerformanceInsights --> CodeFoldingEngine : monitors
    PerformanceInsights --> LSPManager : monitors
```

- [ ] **Step 3: Remove the `AsyncOperationManager --> DebuggerIntegrationCore` edge**

Use Edit tool.

`old_string`:
```
    AsyncOperationManager --> CodeFoldingEngine : schedules folding operations
    AsyncOperationManager --> DebuggerIntegrationCore : manages debug operations
```

`new_string`:
```
    AsyncOperationManager --> CodeFoldingEngine : schedules folding operations
```

- [ ] **Step 4: Rewrite the "Debugger and LSP Integration" Mermaid sub-section as LSP-only**

Use Edit tool.

`old_string`:
```
    %% Debugger and LSP Integration
    DebuggerIntegrationCore --> LSPManager : collaborates for debug info
    DebuggerIntegrationCore --> DocumentStateActor : manages debug documents
    DebuggerIntegrationCore --> FileSystemActor : accesses debug files

    LSPManager --> DocumentStateActor : synchronizes documents
```

`new_string`:
```
    %% LSP Integration
    LSPManager --> DocumentStateActor : synchronizes documents
```

Result: the 3 Debugger edges + the old "Debugger and LSP" comment are gone; the new "%% LSP Integration" comment heads the next 3 LSP-only edges (which are untouched).

- [ ] **Step 5: Remove the `class DebuggerIntegrationCore debugger` style assignment and the orphan `classDef debugger`**

Use Edit tool for the assignment.

`old_string`:
```
    class FileSystemActor actor
    class DebuggerIntegrationCore debugger
    class LSPManager lsp
```

`new_string`:
```
    class FileSystemActor actor
    class LSPManager lsp
```

Then use Edit tool for the orphan `classDef`:

`old_string`:
```
    classDef debugger fill:#FF375F20,stroke:#FF375F,stroke-width:2px,color:#1D1D1F
```

`new_string` (empty — delete the line entirely; the file's other `classDef` lines have no trailing dependency on this one):
```

```

Wait — Edit with an empty new_string is risky if the surrounding whitespace is ambiguous. Instead, use this version which anchors with the preceding line.

`old_string`:
```
    classDef folding fill:#5856D620,stroke:#5856D6,stroke-width:2px,color:#FFFFFF
    classDef debugger fill:#FF375F20,stroke:#FF375F,stroke-width:2px,color:#1D1D1F
```

`new_string`:
```
    classDef folding fill:#5856D620,stroke:#5856D6,stroke-width:2px,color:#FFFFFF
```

(If the line above `classDef debugger` is something other than `classDef folding`, find the actual preceding `classDef` line at runtime and use it as the anchor.)

- [ ] **Step 6: Rewrite the §6 prose subsection as LSP-only**

Use Edit tool.

`old_string`:
```
### 6. Production-Ready Debugger & LSP Integration
- **DebuggerIntegrationCore**: Multi-session debugging with adapter management and event handling
- **LSPManager**: Full Language Server Protocol support with document synchronization and workspace management
- **Cross-Component Collaboration**: Debugger and LSP integration with document and file system actors
- **Memory-Aware Operations**: All debugging and LSP operations integrated with memory monitoring
```

`new_string`:
```
### 6. Production-Ready LSP Integration
- **LSPManager**: Full Language Server Protocol support with document synchronization and workspace management
- **Cross-Component Collaboration**: LSP integration with document and file system actors
- **Memory-Aware Operations**: All LSP operations integrated with memory monitoring
```

- [ ] **Step 7: Verify no Debugger references remain in this file**

Run:
```bash
grep -nE "Debugger|DebugAdapter|DebugSession|class.*debugger" docs/Diagrams/11-advanced-features-integration.md
```

Expected output: **no matches**.

---

### Task 5: Edit `docs/Diagrams/01-high-level-architecture.md`

Remove the DIC (Debugger Integration) node and its class-assignment line. The diagram has no edges incident on DIC (verified in pre-flight Step 6), so this is two single-line removals.

**Files:**
- Modify: `docs/Diagrams/01-high-level-architecture.md`

- [ ] **Step 1: Remove the DIC node from the Advanced Features subgraph**

Use Edit tool.

`old_string`:
```
        SEE["Smart Editing<br/>Engine"]
        DIC["Debugger<br/>Integration"]
        OSN["Symbol<br/>Navigator"]
```

`new_string`:
```
        SEE["Smart Editing<br/>Engine"]
        OSN["Symbol<br/>Navigator"]
```

- [ ] **Step 2: Remove the `class DIC advanced` style assignment**

Use Edit tool. The line is preceded by other `class X advanced` lines; anchor with the immediate neighbor.

First, find the immediate predecessor of `class DIC advanced`:
```bash
grep -B1 "class DIC advanced" docs/Diagrams/01-high-level-architecture.md
```

Then apply the Edit with the predecessor + DIC line as `old_string` and just the predecessor as `new_string`. Example (if predecessor is `class SEE advanced`):

`old_string`:
```
    class SEE advanced
    class DIC advanced
```

`new_string`:
```
    class SEE advanced
```

(The actual predecessor may differ; use the grep output to confirm before editing.)

- [ ] **Step 3: Verify no Debugger / DIC references remain**

Run:
```bash
grep -nE "DIC|Debugger" docs/Diagrams/01-high-level-architecture.md
```

Expected output: **no matches**.

---

### Task 6: Edit `docs/Diagrams/README.md`

Remove the index entry §20 for the (now-archived) debugging diagram, and trim "debugging integration" from the §11 description. Leave lines 9 and 77 as-is.

**Files:**
- Modify: `docs/Diagrams/README.md`

- [ ] **Step 1: Remove the §20 index entry**

Use Edit tool.

`old_string`:
```
### 20. [Debugging Integration](20-debugging-integration.md)
Currently implemented debugging integration. The earlier extended design document is preserved in [`../archive/Diagrams/20-debugging-integration-architecture.md`](../archive/Diagrams/20-debugging-integration-architecture.md).

### 21. [Utility Systems & Extensions Network](21-utility-systems-extensions.md)
```

`new_string`:
```
### 21. [Utility Systems & Extensions Network](21-utility-systems-extensions.md)
```

- [ ] **Step 2: Trim "debugging integration" from the §11 description**

Use Edit tool.

`old_string`:
```
### 11. [Advanced Features Integration Architecture](11-advanced-features-integration.md)
Comprehensive architecture for advanced features including debugging integration, search functionality, smart editing, and code folding. Shows feature coordination, state management, and UI integration.
```

`new_string`:
```
### 11. [Advanced Features Integration Architecture](11-advanced-features-integration.md)
Comprehensive architecture for advanced features including search functionality, smart editing, and code folding. Shows feature coordination, state management, and UI integration.
```

- [ ] **Step 3: Verify line 9 and line 77 are unchanged (intentional)**

Run:
```bash
grep -n "debug" docs/Diagrams/README.md
```

Expected output (exactly 2 matches):
```
9:Design-only diagrams covering features that are not yet implemented (the plugin system, the extended debugging-integration design, and the planned enhanced syntax-highlighting design) live in [`../archive/Diagrams/`](../archive/Diagrams/).
77:Matrix view of language support capabilities across 25 concrete supported languages plus plain text. Shows feature comparison, performance characteristics, LSP integrations, and debugging support for each language.
```

Per §3.4 of the spec, both lines stay as-is. Line 9 still describes the situation correctly (the design-only design lives in archive). Line 77 describes per-language debug *metadata*, unrelated to the deleted framework code.

---

### Task 7: Apply NEXT.md edits

Fourteen row-level edits plus a new §6.2.9a deviations block. Each edit shown with `old_string` / `new_string` pairs. Apply them in the order listed; each is independent.

**Files:**
- Modify: `NEXT.md`

- [ ] **Step 1: §1.4 — drop "Debugger" from opt-in goals (line ~12)**

`old_string`:
```
4. **Make optional subsystems actually optional.** LSP, Debugger, SwiftUI chrome, and Performance instrumentation should be opt-in libraries, not unconditional payload in the umbrella product.
```

`new_string`:
```
4. **Make optional subsystems actually optional.** LSP, SwiftUI chrome, and Performance instrumentation should be opt-in libraries, not unconditional payload in the umbrella product.
```

- [ ] **Step 2: §3 file-count table — drop "debugger integration" from Features/ description, leave the stale "23" count alone**

`old_string`:
```
| Features/ | 23 | Folding, smart editing, search/replace, symbol nav, debugger integration |
```

`new_string`:
```
| Features/ | 23 | Folding, smart editing, search/replace, symbol nav |
```

Note: per §4 row 2 of the spec, the count baseline is intentionally not refreshed in this step — refreshing every §3 row to current reality is its own session.

- [ ] **Step 3: §4.1 phase table — delete the CodeEditorDebugger row**

`old_string`:
```
| 5 | `CodeEditorDebugger` | `Features/Debugger*`, `Features/DebugAdapter*` | TextModel, Annotations |
```

`new_string` (empty — remove the row line entirely):

Actually use this safer form anchored to the preceding row:

`old_string`:
```
| **5 — External services** | `CodeEditorLSP` | `LSP/` | TextModel, Completion, Languages, Symbols |
| 5 | `CodeEditorDebugger` | `Features/Debugger*`, `Features/DebugAdapter*` | TextModel, Annotations |
| **6 — Diagnostics** | `CodeEditorDiagnostics` | `Performance/` | Common |
```

`new_string`:
```
| **5 — External services** | `CodeEditorLSP` | `LSP/` | TextModel, Completion, Languages, Symbols |
| **6 — Diagnostics** | `CodeEditorDiagnostics` | `Performance/` | Common |
```

- [ ] **Step 4: §4.2 Mermaid — delete the `Debugger[CodeEditorDebugger]` subgraph node**

`old_string`:
```
    subgraph P5[Phase 5 — External services]
        LSP[CodeEditorLSP]
        Debugger[CodeEditorDebugger]
    end
```

`new_string`:
```
    subgraph P5[Phase 5 — External services]
        LSP[CodeEditorLSP]
    end
```

- [ ] **Step 5: §4.2 Mermaid — delete the `TextModel --> Debugger` edge**

`old_string`:
```
    Symbols --> LSP
    TextModel --> Debugger
    Annotations --> Debugger
```

`new_string`:
```
    Symbols --> LSP
```

(This step combines two edge removals — both `TextModel --> Debugger` and `Annotations --> Debugger`, which are adjacent — into one Edit. Counted as two row-level edits in the spec.)

- [ ] **Step 6: §4.3 — rewrite the opt-in bullet without Debugger**

`old_string`:
```
- **`CodeEditorLSP` and `CodeEditorDebugger` are opt-in libraries.** A consumer that doesn't want LSP simply doesn't link it; the umbrella can `@_exported import` them only when the consumer also links them, or expose them as separate products. (See §6.3.)
```

`new_string`:
```
- **`CodeEditorLSP` is an opt-in library.** A consumer that doesn't want LSP simply doesn't link it; the umbrella can `@_exported import` it only when the consumer also links it, or expose it as a separate product. (See §6.3.)
```

- [ ] **Step 7: §6.0 deviations (line ~366) — change "LSP / Debugger" to "LSP"**

`old_string`:
```
- **First cross-restructure public-API removal.** `EditorController.selectMatch(_ result: ProjectSearchResult)` is gone from the umbrella's public API. External consumers reimplement via the still-public `EditorController.nsLocation(forLSPLine:character:)` + `EditorController.selectRange(_:scroll:)` primitives. Sets precedent for §6.2.9 LSP / Debugger extractions where the umbrella's public surface may also thin.
```

`new_string`:
```
- **First cross-restructure public-API removal.** `EditorController.selectMatch(_ result: ProjectSearchResult)` is gone from the umbrella's public API. External consumers reimplement via the still-public `EditorController.nsLocation(forLSPLine:character:)` + `EditorController.selectRange(_:scroll:)` primitives. Sets precedent for §6.2.9 LSP extraction where the umbrella's public surface may also thin.
```

- [ ] **Step 8: §6.0 deviations (line ~402) — update the "remaining work" statement**

`old_string`:
```
- **Closes §6.2.8 feature engines.** With Completion landed, remaining §6.2.8 work is `SmartEditing` (deferred §6.2.12) and `Debugger` (pending confirm-or-delete decision — not yet a feature-engine carve-out).
```

`new_string`:
```
- **Closes §6.2.8 feature engines.** With Completion landed, remaining §6.2.8 work is `SmartEditing` (deferred §6.2.12). `Debugger` was deleted in §6.2.9a (see deviations block below) — never extracted.
```

- [ ] **Step 9: §6.2 step 9 — rewrite as single-target LSP step**

`old_string`:
```
9. **Extract `CodeEditorLSP` and `CodeEditorDebugger`** — both depend on engines from step 8. Make them separate **products**, not just targets, so consumers can opt out. (Debugger may already be design-only per `CLAUDE.md`'s note about archived design — confirm whether to keep, gate behind a product, or delete.)
```

`new_string`:
```
9. **Extract `CodeEditorLSP`** — depends on engines from step 8. Make it a separate **product**, not just a target, so consumers can opt out. (Debugger deleted in §6.2.9a — no sibling target; see deviations block.)
```

- [ ] **Step 10: §6.3 — drop `CodeEditorDebugger` from the opt-in list**

`old_string`:
```
- Optional / opt-in: `CodeEditorLSP`, `CodeEditorDebugger`, `CodeEditorDiagnostics`, `CodeEditorSearch`, `CodeEditorWorkspace`
```

`new_string`:
```
- Optional / opt-in: `CodeEditorLSP`, `CodeEditorDiagnostics`, `CodeEditorSearch`, `CodeEditorWorkspace`
```

- [ ] **Step 11: §8.2 risk #2 — rewrite as past tense (decision landed)**

`old_string`:
```
2. **`Features/` mixes shipped and not-yet-shipped subsystems.** `DebuggerIntegration*` may be design-only — confirm before promoting it to its own target. If it's not shipping, delete it instead of splitting it (matches `CLAUDE.md`'s "don't ship half-finished" stance).
```

`new_string`:
```
2. **`Features/` mixes shipped and not-yet-shipped subsystems.** `DebuggerIntegration*` was design-only — deleted in §6.2.9a (2026-05-18). Future debugger work, if any, starts green-field; the archived diagram in `docs/archive/Diagrams/` is the design starting point. The only remaining `Features/` resident is `SmartEditing`, deferred to §6.2.12 (Core split unblocks it).
```

- [ ] **Step 12: §9 non-goals — drop "debugger completion"**

`old_string`:
```
- **Not rewriting any code paths.** This restructure is import-graph surgery, not feature work. Don't combine it with debugger completion, tree-sitter expansion, or LSP changes.
```

`new_string`:
```
- **Not rewriting any code paths.** This restructure is import-graph surgery, not feature work. Don't combine it with tree-sitter expansion or LSP changes.
```

- [ ] **Step 13: §10 — drop the Debugger confirm-or-delete reminder**

`old_string`:
```
- **6.2.8 feature engines complete (modulo deferrals).** `Folding` (§6.2.8a), `Symbols` (§6.2.8b), `Search` (§6.2.8d), `Annotations` (§6.2.8e), `Workspace` (§6.2.8f), `Completion` (§6.2.8g) all extracted. `SmartEditing` is **deferred** (§6.2.8c — blocked on §6.2.12 Core split because all 5 SmartEditing files take `CodeEditorView` as a parameter on every public entry point). `Features/Debugger*` confirm-or-delete decision still pending — gate for §6.2.9 LSP/Debugger extraction.
```

`new_string`:
```
- **6.2.8 feature engines complete (modulo deferrals).** `Folding` (§6.2.8a), `Symbols` (§6.2.8b), `Search` (§6.2.8d), `Annotations` (§6.2.8e), `Workspace` (§6.2.8f), `Completion` (§6.2.8g) all extracted. `SmartEditing` is **deferred** (§6.2.8c — blocked on §6.2.12 Core split because all 5 SmartEditing files take `CodeEditorView` as a parameter on every public entry point). `Features/Debugger*` was deleted in §6.2.9a (2026-05-18) — never extracted; see deviations block.
```

- [ ] **Step 14: §10 — drop "+ CodeEditorDebugger" from the §6.2.9 mention**

`old_string`:
```
- **6.2.9 `CodeEditorLSP` + `CodeEditorDebugger`** — own session each. Expose as separate products.
```

`new_string`:
```
- **6.2.9 `CodeEditorLSP`** — own session. Expose as a separate product. (Debugger deleted in §6.2.9a — no sibling extraction.)
```

- [ ] **Step 15: Add the new §6.2.9a deviations block under §6.0**

This is the 15th NEXT.md site (one new block, not a row-level edit). Insert it after the existing §6.2.8g deviations block.

Find the §6.2.8g block's closing paragraph:
```bash
grep -n "Phase 4 semantic label vs build-graph reality.\*\* Completion is labelled phase 4" NEXT.md
```

That match locates the *last* bullet of the §6.2.8g block. The next section header is `### 6.1 Pre-work` (around line 405). Insert the new block between them.

Use Edit tool. Anchor with the last §6.2.8g bullet + the §6.1 header.

`old_string`:
```
- **Phase 4 semantic label vs build-graph reality.** Completion is labelled phase 4 (feature engine). With deps on `Common, Diagnostics, Languages, Platform, TextModel`, its build-graph slot is between phase 3 (Languages, SH) and phase 4 (Diagnostics). Label kept because it's a feature, not foundational infra.

### 6.1 Pre-work (do before any target split)
```

`new_string` — adds the new block while preserving the §6.2.8g closing bullet and §6.1 header:
```
- **Phase 4 semantic label vs build-graph reality.** Completion is labelled phase 4 (feature engine). With deps on `Common, Diagnostics, Languages, Platform, TextModel`, its build-graph slot is between phase 3 (Languages, SH) and phase 4 (Diagnostics). Label kept because it's a feature, not foundational infra.

**Deviations during §6.2.9a `CodeEditorDebugger` confirm-or-delete (commit `<TBD>`):**

- **Outcome: delete.** Audit (zero `public`, zero in-tree consumers, zero tests, zero Configuration wiring, zero LSP wiring, 10-month dormancy, self-admitted design-only diagram) plus user confirmation (no roadmap in 6–12 months) made deletion the right call. Spec at `docs/superpowers/specs/2026-05-18-codeeditor-debugger-deletion-design.md` (commit `91967bbe`).
- **Files deleted (7, 1,410 LOC):** `DebuggerIntegration.swift`, `DebuggerIntegrationCore.swift`, `DebuggerIntegration+Breakpoints.swift`, `DebuggerIntegration+Evaluation.swift`, `DebuggerIntegration+Execution.swift`, `DebuggerModels.swift`, `DebugAdapter.swift` — all under `Sources/CodeEditorPlugin/Features/`.
- **Diagrams reconciled.** `docs/Diagrams/20-debugging-integration.md` moved to `docs/archive/Diagrams/` (siblings the pre-existing `20-debugging-integration-architecture.md` extended design). Debugger sub-sections removed from `docs/Diagrams/11-advanced-features-integration.md` (class block, 2 cross-component edges, 3 LSP-integration edges + comment rewrite, classDef + class-assignment, prose subsection) and `docs/Diagrams/01-high-level-architecture.md` (node + class assignment). `docs/Diagrams/README.md` index entry §20 removed; entry §11 description trimmed.
- **Zero functional code change outside the deletions.** No file outside `Features/Debugger*` was edited for code reasons. No tests added or removed. No `EditorConfiguration` changes. No `Package.swift` changes (Debugger never had its own target). Public API surface of `CodeEditorPlugin` unchanged because every deleted symbol was `internal`.
- **NEXT.md edits.** 14 row-level edits across §1.4 / §3 / §4.1 / §4.2 (3 mermaid items) / §4.3 / §6.0 (2 deviations updates) / §6.2 / §6.3 / §8.2 / §9 / §10 (2 lines), plus this new deviations block. Removes the Debugger target row, the two Mermaid edges, the opt-in list mention, the deviations references, and the confirm-or-delete pending status.
- **No precedent for "delete a target before extraction".** First restructure step that *removes* a candidate target rather than carving one out. Sets a precedent for future audits: if a carve-out target's symbols are all `internal` and have zero in-tree consumers, deletion is the answer, not extraction.
- **Closes the §6.2.9 prerequisite.** §6.2.9b LSP extraction can now proceed as a single-target session without an accompanying Debugger target.

### 6.1 Pre-work (do before any target split)
```

- [ ] **Step 16: Verify all 14 row-level edits + new block landed**

Run:
```bash
grep -nE "CodeEditorDebugger|TextModel --> Debugger|Annotations --> Debugger|Debugger\[CodeEditorDebugger\]" NEXT.md
```

Expected output: **no matches** (every `CodeEditorDebugger` mention from the original NEXT.md should be gone). The new §6.2.9a block does reference "Debugger" in prose; that's intentional and the grep should not pattern-match it.

Run:
```bash
grep -n "§6.2.9a" NEXT.md
```

Expected output: multiple lines including the new deviations block header and the various back-references added in Steps 8/9/11/13. At least 5 matches.

---

### Task 8: Full verification

Run the full verification suite from §6 of the spec.

**Files:**
- Read-only.

- [ ] **Step 1: Clean build**

Run:
```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!`. If the smoke build in Task 2 Step 3 passed, this should too — there's no intermediate code change between them. If this fails but Task 2 Step 3 succeeded, the doc edits introduced a problem (unlikely — they're prose); inspect the build output carefully.

- [ ] **Step 2: SwiftLint pass (auto-fix then check)**

Run:
```bash
swiftlint --fix 2>&1 | tail -5
swiftlint 2>&1 | tail -10
```

Expected: both commands succeed with no violations. SwiftLint strict mode is on (`strict: true` in `.swiftlint.yml`); warnings are errors. The deletion does not introduce code; auto-fix should be a no-op.

- [ ] **Step 3: Sample-app build**

Run:
```bash
swift build --target CodeEditorSample 2>&1 | tail -5
```

Expected: `Build complete!`.

- [ ] **Step 4: Targeted test — sample's annotation-based breakpoint flow**

Run:
```bash
swift test --filter AnnotationsHubDiagnosticsTests 2>&1 | tail -10
```

Expected: pass. This test exercises the sample's `AnnotationsHub.toggleBreakpoint` path — the stand-in for the deleted framework code. If it fails, something is wrong with the sample side that the audit missed.

- [ ] **Step 5 (optional): Full parallel test run**

Per the spec §6 step 3 and the user's documented heuristic, this is optional. Run it only if you want the extra confidence:

```bash
swift test --parallel 2>&1 | tail -20
```

Expected: full green.

- [ ] **Step 6: Source-tree re-grep**

Run:
```bash
grep -rEn "DebuggerIntegrationCore|class DebugSession|class BaseDebugAdapter|class LLDBAdapter" Sources --include='*.swift'
```

Expected output: **one line only** — the doc comment in `Sources/CodeEditorSample/EditorActions/AnnotationsHub.swift:16` that retains the `DebuggerIntegrationCore` name in prose (intentional per spec §2.2).

- [ ] **Step 7: Doc-tree re-grep**

Run:
```bash
grep -rEn "DebuggerIntegration|DebugAdapter|class DebugSession" docs --include='*.md' | grep -v "docs/archive" | grep -v "docs/superpowers"
```

Expected output: **no matches**. (The two intentionally-untouched docs — `docs/Internals/architecture-overview.md` and the spec/plan files under `docs/superpowers/` — are filtered out.)

If `docs/Internals/architecture-overview.md` still shows for some reason despite the grep filter, that's fine — line 58 is a historical note about a prior removal and explicitly stays per spec §2.2 / §3.5.

- [ ] **Step 8: Diagram render sanity check**

Open the two edited diagrams in a Mermaid-aware viewer (VS Code preview, GitHub web view, or `mmdc` CLI). Both must render without syntax errors:

- `docs/Diagrams/11-advanced-features-integration.md`
- `docs/Diagrams/01-high-level-architecture.md`

If either fails to render, the most likely cause is an orphan `classDef` or a dangling edge; re-read the file end-to-end and fix.

- [ ] **Step 9: `git diff --stat` review**

Run:
```bash
git diff --cached --stat
```

Expected approximate shape:
```
 Sources/CodeEditorPlugin/Features/DebugAdapter.swift               | 502 -----
 Sources/CodeEditorPlugin/Features/DebuggerIntegration+Breakpoints.swift |  97 ----
 Sources/CodeEditorPlugin/Features/DebuggerIntegration+Evaluation.swift  | 106 ----
 Sources/CodeEditorPlugin/Features/DebuggerIntegration+Execution.swift   |  63 ----
 Sources/CodeEditorPlugin/Features/DebuggerIntegration.swift             |   9 -
 Sources/CodeEditorPlugin/Features/DebuggerIntegrationCore.swift         | 327 ----
 Sources/CodeEditorPlugin/Features/DebuggerModels.swift                  | 306 ----
 docs/Diagrams/01-high-level-architecture.md                              |   2 -
 docs/Diagrams/11-advanced-features-integration.md                        |  ~28 -
 docs/Diagrams/README.md                                                  |   3 -
 docs/Diagrams/20-debugging-integration.md => docs/archive/Diagrams/20-debugging-integration.md | 0
 NEXT.md                                                                  |  ~30 +/-
 12 files changed, ...
```

Total deletions: ≈1,410 source LOC + ≈60 doc LOC (rough). Total additions: the new §6.2.9a deviations block in NEXT.md (≈8 lines net). If the totals are off by an order of magnitude (e.g. NEXT.md shows +200 lines), something went wrong.

If the diff looks anomalous, stop and inspect before commit.

---

### Task 9: Commit the main change

Single commit per spec §5. Use a HEREDOC commit message.

**Files:**
- Commit: all staged changes.

- [ ] **Step 1: Stage any new untracked files**

Run:
```bash
git status
```

The archived diagram (moved with `git mv`) and all edited files should already be staged. The new spec/plan files under `docs/superpowers/` are already in their own prior commits and should not appear here. If anything unexpected is unstaged, investigate before continuing.

- [ ] **Step 2: Create the main commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
Delete unreachable Debugger scaffold (§6.2.9a)

7 files / 1,410 LOC under Sources/CodeEditorPlugin/Features/
were dead: zero public symbols, zero in-tree consumers, zero
tests, zero Configuration wiring, zero LSP wiring, ~10 months
of dormancy, and the only diagram describing them admitted
in its own preamble that the concrete adapters were planned
but not shipped.

Reconciliation:
- Files deleted: DebuggerIntegration.swift, DebuggerIntegrationCore.swift,
  DebuggerIntegration+Breakpoints.swift, +Evaluation.swift, +Execution.swift,
  DebuggerModels.swift, DebugAdapter.swift.
- docs/Diagrams/20-debugging-integration.md moved to archive (sits beside
  the pre-existing 20-debugging-integration-architecture.md).
- docs/Diagrams/11-advanced-features-integration.md: removed Debugger
  class block, 2 cross-component edges, 3 LSP-integration edges (LSP
  ones kept under a renamed comment), classDef + class assignment,
  prose subsection #6 rewritten as LSP-only.
- docs/Diagrams/01-high-level-architecture.md: DIC node + class
  assignment removed.
- docs/Diagrams/README.md: index entry §20 removed; §11 description
  trimmed.
- NEXT.md: 14 row-level edits across §1.4 / §3 / §4.1 / §4.2 / §4.3 /
  §6.0 / §6.2 / §6.3 / §8.2 / §9 / §10, plus a new §6.2.9a deviations
  block. Commit SHA back-reference will be filled in a follow-up commit.

Zero functional code change outside the deleted files. No new tests.
No Package.swift change (Debugger never had its own target). Public
API surface of CodeEditorPlugin unchanged because every deleted
symbol was internal.

Spec: docs/superpowers/specs/2026-05-18-codeeditor-debugger-deletion-design.md
Plan: docs/superpowers/plans/2026-05-18-codeeditor-debugger-deletion.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds, prints the new SHA. Capture that SHA — Task 10 needs it.

- [ ] **Step 3: Verify the commit landed cleanly**

Run:
```bash
git log --oneline -5
git status
```

Expected:
- First command: the new commit appears at top with the title `Delete unreachable Debugger scaffold (§6.2.9a)`.
- Second command: `nothing to commit, working tree clean`.

---

### Task 10: SHA back-reference follow-up commit

Mirrors the §6.2.8g pattern (commit `7dfa081c`): a one-line update that replaces the `<TBD>` placeholder in the new §6.2.9a deviations block with the actual commit SHA from Task 9.

**Files:**
- Modify: `NEXT.md`

- [ ] **Step 1: Capture the main commit SHA**

Run:
```bash
git rev-parse --short=8 HEAD
```

Expected: an 8-character SHA (e.g. `abc12345`). Call this `<MAIN_SHA>` below.

- [ ] **Step 2: Replace `<TBD>` with the SHA**

Use Edit tool.

`old_string`:
```
**Deviations during §6.2.9a `CodeEditorDebugger` confirm-or-delete (commit `<TBD>`):**
```

`new_string` (substitute the actual SHA from Step 1):
```
**Deviations during §6.2.9a `CodeEditorDebugger` confirm-or-delete (commit `<MAIN_SHA>`):**
```

- [ ] **Step 3: Verify the placeholder is gone**

Run:
```bash
grep -n "<TBD>" NEXT.md
```

Expected: **no matches**.

- [ ] **Step 4: Commit the SHA back-reference**

Run:
```bash
git add NEXT.md
git commit -m "$(cat <<'EOF'
Update NEXT.md SHA back-reference for §6.2.9a

Fills in the commit SHA placeholder in the §6.2.9a Debugger
confirm-or-delete deviations block now that the main commit
has landed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds.

- [ ] **Step 5: Final state check**

Run:
```bash
git log --oneline -5
git status
```

Expected log top-three:
```
<new> Update NEXT.md SHA back-reference for §6.2.9a
<MAIN_SHA> Delete unreachable Debugger scaffold (§6.2.9a)
91967bbe Add §6.2.9a Debugger confirm-or-delete design (delete)
```

Working tree clean.

---

## Self-review notes

**Spec coverage:** every spec section is covered by a task:
- §1 (Goal) → Tasks 2–7 collectively
- §2.1 (Files deleted) → Task 2
- §2.2 (Files NOT touched) → Task 1 Step 2 grep verifies; Task 8 Step 6 re-verifies
- §2.3 (Non-goals) → enforced by the plan's complete absence of changes outside the listed files
- §3.1 (Diagram move) → Task 3
- §3.2 (Diagram 11 edits) → Task 4 Steps 1–6
- §3.3 (Diagram 01 edits) → Task 5
- §3.4 (README edits) → Task 6
- §3.5 (Docs NOT edited) → Task 8 Step 7 grep filters them out
- §4 (NEXT.md edits, 14 rows) → Task 7 Steps 1–14
- §4.1 (New §6.2.9a block) → Task 7 Step 15
- §5 (Execution order) → Task order matches §5 steps 1–7
- §6 (Verification) → Task 8 + the smoke check in Task 2 Step 3
- §7 (Risks) → mitigated by the audit (Task 1) and the rollback path (referenced in Task 2 Step 3)
- §9 (Rollback) → Task 2 Step 3 carries the rollback instructions

**Type / signature consistency:** the plan does not introduce code, so there are no type-consistency hazards.

**Placeholder scan:** the only `<TBD>` in the plan is the `<TBD>` placeholder in NEXT.md (Task 7 Step 15) which is intentional and resolved in Task 10. No "implement later", "TODO", "fill in", or vague "handle edge cases" anywhere. Every step shows the exact text it expects to add/remove or the exact command it expects to run with expected output.
