# §6.2.9 CodeEditorLSP extraction — design

**Status:** spec for the next session.

**Position in the restructure:** first non-`Features/` extraction since §6.2.7 SyntaxHighlighting. With §6.2.8 feature engines complete (modulo deferred SmartEditing §6.2.8c) and §6.2.9a Debugger deletion landed, LSP is the next item on NEXT.md §10's queue. After this, §6.2.11 Layout, §6.2.12 Core split, §6.2.13 SwiftUI, then umbrella shim + test split + workspace relocation finish the restructure.

**Precedents this builds on:**

- §6.2.7 `CodeEditorSyntaxHighlighting` (`f2798287`) — carve-out (36 moved, 9 stayed); ~107 access-modifier promotions. First time the pre-commit relocation pattern was used.
- §6.2.8a `CodeEditorFolding` (`76abf928`) — carve-out (4 moved, 4 stayed).
- §6.2.8b `CodeEditorSymbols` (`fefe8f93`) — carve-out (2 moved + 1 split-out, 1 stayed).
- §6.2.8d `CodeEditorSearch` (`18f9d43a`) — carve-out (1 moved, 1 stayed, 1 migrated to sample); productized opt-in.
- §6.2.8e `CodeEditorAnnotations` (`9ce2934a`) — carve-out (7 moved, 1 stayed); zero access-modifier promotions.
- §6.2.8g `CodeEditorCompletion` (`28b78b4f`) — clean extraction (19 moved, 0 stayed); umbrella depends; not productized.
- §6.2.10 `CodeEditorDiagnostics` (`e60f7857`) — productized opt-in; umbrella depends. **This is the closest precedent for LSP** — both are productized, both umbrella-depended.

**Why LSP is a carve-out, not a clean extraction:** unlike §6.2.8g Completion, LSP has structural `CodeEditorView` coupling in 2 of 24 files. `LSPSemanticTokenProvider` stores `CodeEditorView?` and takes `CodeEditorView` on 6 protocol-conformance entry points; `LSPContentCoordinator` stores `weak var textView: CodeEditorView?`. Both are forced to stay in the umbrella, relocated to a new `Core/LSP/` semantic bucket. The remaining 22 files have no structural `CodeEditorView` references and move cleanly.

---

## 1. Goal

Extract the 24-file `Sources/CodeEditorPlugin/LSP/` subsystem into a new SPM target `CodeEditorLSP`. **Carve-out shape** — 22 files move; 2 stay in umbrella under a new `Core/LSP/` bucket. Productized as a separate opt-in `.library` product per NEXT.md §6.3. The umbrella `CodeEditorPlugin` target gains `CodeEditorLSP` as a direct dependency (matches §6.2.10 Diagnostics precedent — productized but umbrella-coupled, not the §6.2.8d/§6.2.8f umbrella-decoupled opt-out pattern).

Net result: 22 files move to the new target; 2 files relocate inside the umbrella; ~6 umbrella files gain `import CodeEditorLSP`; 9 sample files (likely fewer after bare-word grep), 12 plugin-test files, and 6 sample-test files gain the import; ~5–15 access-modifier promotions on the moving set's surfaces touched by the 2 carve-out files.

---

## 2. Scope

### 2.1 Files that move to `Sources/CodeEditorLSP/`

22 of 24 files from `Sources/CodeEditorPlugin/LSP/` (including the 4 files under `Transport/`).

**Top-level (18 files):**

| File | Top-level type / modifier | Notes |
|---|---|---|
| `LSPClient.swift` | `public final class LSPClient` (actor-ish) | Connection orchestration |
| `LSPClient+Transport.swift` | extensions on `LSPClient` | Transport-specific wiring; imports `Foundation` only |
| `LSPClientRegistry.swift` | `public final class LSPClientRegistry` | Multi-client coordination |
| `LSPCompletionProvider.swift` | `public final class LSPCompletionProvider` | LSP-backed `CompletionProvider`. Only doc-comment mention of `CodeEditorView`; no structural coupling |
| `LSPConnectionManager.swift` | (internal types) | Transport lifecycle / shutdown |
| `LSPDocumentManager.swift` | (internal types) | Document state tracking |
| `LSPLanguageFeatures.swift` | `public enum LSPLanguageFeatures` | Feature-flag namespace |
| `LSPManager.swift` | `public final class LSPManager: ObservableObject` | The public entry point. Re-exported in umbrella via `MemoryManagementCoordinator.createLSPManager(...)` |
| `LSPManagerTypes.swift` | `public struct LSPManagerCompletionItem: CompletionItemView` + other public types | Bridges LSP types to `CodeEditorCompletion`'s `CompletionItemView` |
| `LSPMessageHandler.swift` | (internal types) | Notification/response routing |
| `LSPPathResolver.swift` | `public struct LSPPathResolver: Sendable` | Path resolution |
| `LSPProcessManager.swift` | (internal types) | Process lifecycle |
| `LSPProtocol.swift` | (internal protocol types) | Wire-protocol primitives |
| `LSPRetryConfiguration.swift` | public types | Retry/back-off |
| `LSPSemanticTokenStorage.swift` | `final class LSPSemanticTokenStorage` (internal) | **Consumed by carve-out `LSPSemanticTokenProvider` — promote to `package`** |
| `LSPTypeAliases.swift` | public typealiases | Re-exports of LSP types |
| `LSPTypes.swift` | many `public struct/enum` (request/response payloads) | `LSPRange`, `InitializeParams`, `Hover`, `CompletionList`, etc. All `Sendable + Codable` |
| `RemoteLSPConfiguration.swift` | public configuration types | Imports `Security`/`CryptoKit`-adjacent |

**Transport (`Sources/CodeEditorLSP/Transport/`, 4 files):**

| File | Notes |
|---|---|
| `LSPTransport.swift` | Transport protocol |
| `ProcessTransport.swift` | Process-based transport |
| `WebSocketTransport.swift` | WebSocket transport |
| `WebSocketPinningDelegate.swift` | Certificate pinning helper; imports `CryptoKit`, `Security` |

### 2.2 Files that stay in umbrella, relocated to `Sources/CodeEditorPlugin/Core/LSP/`

2 files with structural `CodeEditorView` coupling:

| File | Coupling reason |
|---|---|
| `LSPSemanticTokenProvider.swift` | Stores `private var textView: CodeEditorView?` (line 63); 6 protocol-conformance entry points take `CodeEditorView`: `setUp(textView:language:)`, `willApplyEdit(textView:range:)` (2 overloads), `applyEdit(textView:range:delta:)`, `queryHighlights(textView:range:)`, `refreshAfterBatch(textView:)`. References `documentString` on `textView`. |
| `LSPContentCoordinator.swift` | Stores `private weak var textView: CodeEditorView?` (line 39); `init` takes `textView: CodeEditorView` (line 66). |

The relocation is `git mv LSP/<file>.swift Core/LSP/<file>.swift` for each. The new `Core/LSP/` directory is created during the relocation; no other content is added.

The umbrella's `LSP/` source directory becomes empty post-extraction. Add `"LSP"` to the umbrella target's `exclude:` list (defensive — matches §6.2.7's defensive exclude of `"SyntaxHighlighting"`).

### 2.3 Directory layout

```
Sources/CodeEditorLSP/                       # new target root
├── LSPClient.swift
├── LSPClient+Transport.swift
├── LSPClientRegistry.swift
├── LSPCompletionProvider.swift
├── LSPConnectionManager.swift
├── LSPDocumentManager.swift
├── LSPLanguageFeatures.swift
├── LSPManager.swift
├── LSPManagerTypes.swift
├── LSPMessageHandler.swift
├── LSPPathResolver.swift
├── LSPProcessManager.swift
├── LSPProtocol.swift
├── LSPRetryConfiguration.swift
├── LSPSemanticTokenStorage.swift
├── LSPTypeAliases.swift
├── LSPTypes.swift
├── RemoteLSPConfiguration.swift
└── Transport/
    ├── LSPTransport.swift
    ├── ProcessTransport.swift
    ├── WebSocketPinningDelegate.swift
    └── WebSocketTransport.swift

Sources/CodeEditorPlugin/Core/LSP/           # new umbrella bucket
├── LSPContentCoordinator.swift
└── LSPSemanticTokenProvider.swift
```

---

## 3. Target dependencies

Based on the per-file import survey of the 22 moving files:

| Dep | Required by (representative) |
|---|---|
| `CodeEditorCommon` | `LSPClient`, `LSPClientRegistry`, `LSPCompletionProvider`, `LSPDocumentManager`, `LSPMessageHandler`, `LSPProcessManager`, `ProcessTransport`, `WebSocketPinningDelegate`, `WebSocketTransport` |
| `CodeEditorCompletion` | `LSPCompletionProvider`, `LSPManager`, `LSPManagerTypes` |
| `CodeEditorDiagnostics` | `LSPManager` (memory monitoring) |
| `CodeEditorLanguages` | `LSPClient`, `LSPClientRegistry`, `LSPCompletionProvider`, `LSPDocumentManager`, `LSPLanguageFeatures`, `LSPManager`, `LSPPathResolver`, `RemoteLSPConfiguration`, `LSPTransport` |
| `CodeEditorPlatform` | `LSPManagerTypes` |
| `CodeEditorTextModel` | `LSPCompletionProvider`, `LSPContentCoordinator` (stays in umbrella but transitively confirms TextModel need elsewhere if applicable) — verified via direct import in `LSPCompletionProvider` |

**Total deps: 6.** Notably absent:

- **No `CodeEditorSyntaxHighlighting`.** The only file in `LSP/` that imports SH is `LSPSemanticTokenProvider`, which stays in the umbrella. The new target does not need SH.
- **No `CodeEditorTheming` / `CodeEditorDesignTokens`.** Not referenced by any moving file.
- **No `CodeEditorAnnotations` / `CodeEditorFolding` / `CodeEditorSymbols` / `CodeEditorWorkspace` / `CodeEditorSearch`.** LSP does not consume those targets.

**External SDKs (Apple-provided, no SPM-side dep):** `Combine` (used by `LSPManager`, `LSPManagerTypes`), `CryptoKit` (`WebSocketPinningDelegate`), `Security` (`RemoteLSPConfiguration`, `WebSocketPinningDelegate`).

**NEXT.md §4.1 dep-claim audit:** §4.1 lists LSP under phase 5/6 with deps `Languages, Diagnostics, TextModel, Completion`. The actual surveyed deps are wider: `Common, Completion, Diagnostics, Languages, Platform, TextModel`. Joins the established §4.1-correction pattern (§6.2.5 Theming, §6.2.8b Symbols, §6.2.8e Annotations, §6.2.8f Workspace, §6.2.8g Completion). Update §4.1 to add `Common` and `Platform`.

---

## 4. Access-modifier promotions (anticipated)

The carve-out boundary forces `internal → package` promotions wherever the 2 stayed-in-umbrella files reach types or members that move to the new target.

**Confirmed-needed from the audit:**

| Symbol | Current | After | Reason |
|---|---|---|---|
| `LSPSemanticTokenStorage` (class) | `final class` (internal) | `package final class` | Used by `LSPSemanticTokenProvider` (carve-out → umbrella) |
| `LSPSemanticTokenStorage.init` and all members touched | (internal) | `package` | Same |

**`LSPManager` and `LSPRange` are already `public`** — no promotion needed. The umbrella's public surface (`MemoryManagementCoordinator.createLSPManager(...) -> LSPManager`, `EditorController.nsRange(forLSPRange: LSPRange) -> NSRange?`) keeps working without any signature changes.

**Anticipated additional promotions (TBD at compile time):**

- Any `internal` method on `LSPManager`, `LSPClient`, or `LSPDocumentManager` that `LSPSemanticTokenProvider` or `LSPContentCoordinator` call. The 2 carve-out files reach `LSPManager`, `LSPSemanticTokenStorage`, `LSPRange`, and `LSPContentCoordinator` (self-reference, irrelevant). Each member access on `LSPManager` and `LSPSemanticTokenStorage` from the carve-out side must be `package` or `public`.
- Possibly some synthesized-init promotions on `public struct`s in `LSPTypes.swift` (§6.2.8b lesson — synthesized inits on public structs are internal-visibility by default). Surveys at compile time.

**Estimated total: 5–15 promotions** — far below §6.2.7 SH's ~107, comparable to §6.2.8b Symbols's 7. The moving set is large (22 files) but the bridging surface is small (2 carve-out files). The exact count will be recorded in the §6.0 deviations block at completion.

---

## 5. Consumer ripple

### 5.1 Umbrella sources gaining `import CodeEditorLSP`

| File | Reason |
|---|---|
| `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` | References `LSPManager` (via `editorView.lspManager` indirectly) and stores `lspContentCoordinator: LSPContentCoordinator?`, `lspSemanticTokenProvider: LSPSemanticTokenProvider?` (carve-out types, but the file separately references `LSPManager` indirectly via wiring) |
| `Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift` | Constructs `LSPContentCoordinator` and `LSPSemanticTokenProvider` (umbrella now) — those types in turn reference `LSPManager`, which moves. Plan-time grep should verify whether this file directly names `LSPManager` outside the carve-out types; if not, the import may not be needed |
| `Sources/CodeEditorPlugin/Core/MemoryManagementCoordinator.swift` | Public `createLSPManager(workspaceRoot:) -> LSPManager`; constructs `LSPManager` |
| `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift` | Public `nsRange(forLSPRange lspRange: LSPRange) -> NSRange?` |
| `Sources/CodeEditorPlugin/Core/LSP/LSPSemanticTokenProvider.swift` | Now-relocated carve-out; references `LSPManager`, `LSPSemanticTokenStorage` (moved to new target) |
| `Sources/CodeEditorPlugin/Core/LSP/LSPContentCoordinator.swift` | Now-relocated carve-out; references `LSPManager`, `LSPRange` (moved to new target) |

**Estimate: 6 umbrella files** gain the import (4 pre-existing consumers + 2 relocated carve-out files). Plan-execution may surface 1–2 more via bare-word grep (`\bLSP[A-Z]` plus `\bLSP\b`).

### 5.2 Sample sources

9 files reference LSP types (`grep -lrE "\bLSP[A-Z]"`):

- `Sources/CodeEditorSample/App/AppState.swift`
- `Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift`
- `Sources/CodeEditorSample/App/WindowBody.swift`
- `Sources/CodeEditorSample/App/LSP/ServerCapabilitiesSummary.swift`
- `Sources/CodeEditorSample/App/LSP/HoverSession.swift`
- `Sources/CodeEditorSample/App/LSP/LSPHoverPopover.swift`
- `Sources/CodeEditorSample/App/LSP/DiagnosticsBridge.swift`
- `Sources/CodeEditorSample/Sidebars/LSPInspectorPanel.swift`
- `Sources/CodeEditorSample/Sidebars/InspectorPanelStack.swift`

**Caveat (§6.2.8d / §6.2.8e / §6.2.8f lesson):** verify each via grep at plan time. Files that only reference LSP types in doc comments do not need the import. Same correction landed for §6.2.8d (4 → 3) and §6.2.8f (6 → 5).

### 5.3 Tests

**`Tests/CodeEditorPluginTests/`** — 12 files (per `grep -lrE "\bLSP[A-Z]"`):

Subdirectory `LSP/` (7 files matching the LSP grep): `LSPClientRegistryRemoteFlowTests.swift`, `LSPCompletionRangeConversionTests.swift`, `LSPConnectionManagerShutdownTests.swift`, `LSPManagerIOSCoverageTests.swift`, `LSPProcessManagerReaderTests.swift`, `LanguageServerConfigFactoryTests.swift`, `WebSocketTransportSecurityTests.swift`. (The 8th file in the `LSP/` subdir, `SecurityOptionsTLSVersionTests.swift`, did not match the LSP-prefix grep — verify at plan time whether it needs the new import or only uses Foundation/Security symbols.)

Top-level (5 files): `ComprehensivePerformanceTests.swift`, `LSPIntegrationTests.swift`, `LSPRetryTests.swift`, `LSPSemanticTokenStorageTests.swift`, `LSPTestHelpers.swift`.

All gain `import CodeEditorLSP`, retaining their existing `@testable import CodeEditorPlugin` per §6.2.8d lesson (don't blanket-drop `@testable`; some internal-only umbrella helpers still require it). Bare-word grep (`\bLSP\b`) at plan time may surface 1–2 more files (§6.2.8e lesson).

**`Tests/CodeEditorSampleTests/`** — 6 files:

`DiagnosticsBridgeTests.swift`, `LSPInspectorPanelTests.swift`, `LSPLiveIntegrationTests.swift`, `LSPSampleCoordinatorDefinitionTests.swift`, `LSPSampleCoordinatorStateTests.swift`, `Support/StubProcessResolver.swift`. All gain `import CodeEditorLSP`.

**Test placement:** All test files stay in their existing target. No new `CodeEditorLSPTests` target. Matches §6.2.7/§6.2.8a/§6.2.8b/§6.2.8d/§6.2.8e/§6.2.8g precedent. Per-target test split deferred to §6.2.15.

---

## 6. Package.swift edits

### 6.1 New product entry

```swift
.library(name: "CodeEditorLSP", targets: ["CodeEditorLSP"]),
```

Slots into the `products:` list per NEXT.md §6.3 "Optional / opt-in" listing.

### 6.2 New target entry

```swift
.target(
    name: "CodeEditorLSP",
    dependencies: [
        "CodeEditorCommon",
        "CodeEditorCompletion",
        "CodeEditorDiagnostics",
        "CodeEditorLanguages",
        "CodeEditorPlatform",
        "CodeEditorTextModel",
    ],
    path: "Sources/CodeEditorLSP"
),
```

### 6.3 Umbrella `CodeEditorPlugin` target updates

- `dependencies:` gains `"CodeEditorLSP"` (preserving alphabetical order)
- `exclude:` list grows from `["Info.plist", "Languages", "Performance", "SyntaxHighlighting"]` to `["Info.plist", "Languages", "LSP", "Performance", "SyntaxHighlighting"]` (defensive — the source dir is empty post-extraction)

### 6.4 Sample / test target updates

- `CodeEditorSample` target: `dependencies:` gains `"CodeEditorLSP"`
- `CodeEditorPluginTests` target: `dependencies:` gains `"CodeEditorLSP"`
- `CodeEditorSampleTests` target: `dependencies:` gains `"CodeEditorLSP"`

`CodeEditorUI` and `CodeEditorUITests` do not gain the dep (no LSP references — verified by grep).

---

## 7. Execution order

Three commits, matching the §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e cadence:

1. **Pre-commit — relocate the carve-out.**
   - `git mv Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift Sources/CodeEditorPlugin/Core/LSP/LSPSemanticTokenProvider.swift`
   - `git mv Sources/CodeEditorPlugin/LSP/LSPContentCoordinator.swift Sources/CodeEditorPlugin/Core/LSP/LSPContentCoordinator.swift`
   - Run `swift build && swift test --filter LSP` to confirm green.
   - Commit with message describing the relocation only.

2. **Main commit — extract `CodeEditorLSP`.**
   - Create `Sources/CodeEditorLSP/` + `Sources/CodeEditorLSP/Transport/`.
   - Edit `Package.swift`: add product, add target, update umbrella `dependencies:` + `exclude:`, update Sample / PluginTests / SampleTests deps.
   - `git mv` each of the 22 moving files into `Sources/CodeEditorLSP/` (preserving the `Transport/` subdir layout).
   - Apply access-modifier promotions surfaced by the build.
   - Add `import CodeEditorLSP` to umbrella + sample + test consumers (alphabetically sorted by SwiftLint).
   - `swift build && swiftlint --fix && swiftlint && swift test --parallel`.
   - Commit.

3. **Docs commit — update NEXT.md.**
   - Add §6.0 deviations block (file list, target deps, promotion count, deviations encountered).
   - Update §6.2.9 status line.
   - Update §10 "Suggested next session" to drop §6.2.9 and surface §6.2.11.
   - Update §4.1's LSP row to reflect actual deps (likely needs `Common` and `Platform` added).
   - Update §6.0 status paragraph (count of targets, file counts).
   - Separate commit per series cadence.

---

## 8. Tests

`swift test --filter LSP` should match all 18 plugin-tests + 5 sample-tests LSP files. Snapshot tests are not expected (this is engine code, not rendered surface). Targeted post-step verification commands:

```bash
swift build && \
swift test --filter LSP && \
swiftlint --fix && swiftlint
```

Full `swift test --parallel` is run once at the end of the main commit. Per the memory `feedback_test_confirmations.md`, no full re-run after additive-only edits — trust the build and the targeted filter.

---

## 9. Expected deviations

These will be confirmed and recorded in NEXT.md §6.0 at completion. Listing here so the plan accommodates them:

1. **§4.1 dep claim is wrong** — actual deps add `Common` and `Platform`. Pattern established across §6.2.5 / §6.2.8b / §6.2.8e / §6.2.8f / §6.2.8g.
2. **Sample import count likely lower than 9.** Same correction landed for §6.2.8d (4 → 3) and §6.2.8f (6 → 5). Bare-word grep at plan time will surface doc-comment-only references.
3. **Test file count may rise.** `grep -lrE "\bLSP[A-Z]"` showed 12 plugin-tests + 6 sample-tests; bare-word `\bLSP\b` may surface 1–2 more (§6.2.8e lesson — bare-word grep catches what compound-name grep misses).
4. **Access-modifier promotion count** estimated 5–15; record actual.
5. **`SwiftLint sorted_imports`** will reorder new imports. `CodeEditorLSP` slots between `CodeEditorLanguages` and `CodeEditorPlatform`. Plan-written order should account for this (§6.2.8f lesson — don't hand-write order, let SwiftLint fix it).
6. **First post-Debugger-deletion target.** `LSP/` no longer has any Debugger neighbors to disentangle from. `LSPManager` previously held a (now-deleted) reference to the Debugger; that wiring is gone per §6.2.9a commit `bf27ea2e`.
7. **Phase 5/6 semantic label vs build-graph reality.** §4.1 labels LSP phase 5 or 6. With 6 deps spanning phase 0 (Common) through phase 4 (Diagnostics, Completion), build-graph sits at phase 5. Label kept.

---

## 10. Risks

1. **`LSPSemanticTokenProvider` cross-references `LSPSemanticTokenStorage` extensively.** The storage class is internal today. Most of its surface (init + insert/query/clear/replace methods + any properties touched) needs `package` promotion. Survey thoroughly during the main commit.
2. **`LSPManager` is the umbrella's public re-export point for LSP.** Its public surface stays untouched; consumers see no API break. But the methods called by the umbrella's `Core/LSP/` provider files (after relocation) must each be `package` or `public`. Survey at compile time.
3. **`@testable import CodeEditorPlugin` is load-bearing on several LSP tests** (§6.2.8d lesson). Don't blanket-drop the `@testable` qualifier; keep both `@testable import CodeEditorPlugin` and `import CodeEditorLSP`.
4. **The `Transport/` subdir contains `WebSocketPinningDelegate.swift` which uses `CryptoKit` + `Security`.** Verify the new target builds on iOS — `Security`/`CryptoKit` are cross-platform Apple SDKs but specific symbol availability may differ. The current umbrella target builds on both platforms, so this should not be a new problem, but watch for `#if canImport` regressions.

---

## 11. Out of scope

- **No LSP-feature work.** Hover popover, completion ranking, semantic-token rendering — none change.
- **No transport protocol changes.** `LSPTransport`, `ProcessTransport`, `WebSocketTransport` move as-is.
- **No public-API removals from the umbrella.** Unlike §6.2.8d Search (`EditorController.selectMatch` migrated to sample), LSP's public surface (`createLSPManager`, `nsRange(forLSPRange:)`) stays in the umbrella because the user chose the productized-but-umbrella-depended pattern.
- **No `@_exported import` umbrella shim.** Deferred to §6.2.14.
- **No per-target test split.** Deferred to §6.2.15.
- **No move to `~/Workspace/packages/`.** Deferred to the final restructure session.
- **SmartEditing extraction (§6.2.8c) remains deferred** to §6.2.12 Core split.

---

## 12. Definition of done

- All 22 moving files compile in the new `CodeEditorLSP` target.
- The 2 carve-out files compile in their new `Core/LSP/` home with `import CodeEditorLSP`.
- `swift build && swiftlint --fix && swiftlint && swift test --parallel` is green.
- Umbrella public API surface unchanged (`MemoryManagementCoordinator.createLSPManager`, `EditorController.nsRange(forLSPRange:)` and any other LSP-typed public methods compile and behave identically).
- `CodeEditorLSP` product is importable standalone (verified by a `swift build --target CodeEditorLSP` and a brief grep for accidental umbrella imports inside the new target's sources).
- NEXT.md §6.0 has a deviations block recording: final file move counts, final target deps, final access-modifier promotion count, any §4.1 corrections, sample / test import counts, and any unexpected sub-steps that surfaced during execution.
- §6.2.9 status line in NEXT.md updated to "done — carve-out, see §6.0".
- §10 "Suggested next session" updated to drop §6.2.9 and surface §6.2.11 as the next item.
