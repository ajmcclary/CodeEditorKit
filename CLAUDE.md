# CLAUDE.md

AI assistant guidance for CodeEditorPlugin — a TextKit2-based code editor framework for Apple platforms.

## Commands

```bash
# Build, lint, test (in order — lint catches issues tests may miss)
swift build && swiftlint --fix && swiftlint && swift test --parallel

# Fix auto-correctable lint violations
swiftlint --fix

# Run a single test (matches by name substring)
swift test --filter TestName

# Build a single library target
swift build --target CodeEditorPlugin
swift build --target CodeEditorUI

# Run the package test helper
./Scripts/run-parallel-tests.sh
```

## Package Structure

**Swift 6.3** with `StrictConcurrency` enabled. 19 products defined in `Package.swift`:

| Product | Type | Purpose |
|---|---|---|
| `CodeEditorAnnotations` | library | Opt-in annotation model + chrome (line badges) |
| `CodeEditorCommon` | library | Shared utilities, models, errors, recovery infra |
| `CodeEditorCompletion` | library | Completion subsystem (manager, ranking, providers) |
| `CodeEditorConfiguration` | library | Settings, presets, validation |
| `CodeEditorDiagnostics` | library | Opt-in performance and memory diagnostics |
| `CodeEditorHighlightingCore` | library | View-free value contracts for highlight providers |
| `CodeEditorInstrumentation` | library | Lightweight runtime instrumentation (memory monitor, perf counters) |
| `CodeEditorLSP` | library | Language Server Protocol client and transports |
| `CodeEditorLSPIntegration` | library | Opt-in LSP-to-editor bridge (semantic tokens, sync) |
| `CodeEditorLanguages` | library | Language descriptors and detection |
| `CodeEditorLayout` | library | Editor presentation and layout primitives |
| `CodeEditorPlatform` | library | Cross-platform color/font/view abstractions |
| `CodeEditorPlugin` | library | Umbrella editor framework |
| `CodeEditorSearch` | library | Opt-in project-wide search interfaces |
| `CodeEditorSwiftUI` | library | SwiftUI editor host and controller bridge |
| `CodeEditorTextModel` | library | TextKit2 text-model primitives |
| `CodeEditorUI` | library | Optional SwiftUI chrome and components |
| `CodeEditorView` | library | Native editor surface and runtime services |
| `CodeEditorWorkspace` | library | Opt-in workspace file-tree interfaces |

Key dependencies: `DesignKit` (shared design system: `DesignKitTokens` + `DesignKitThemes`), `swift-syntax`, `swift-dependencies`, `xctest-dynamic-overlay` (IssueReporting), `swift-snapshot-testing` (tests only), `swift-custom-dump` (tests only).

The snapshot-testing fork (`ajmcclary/swift-snapshot-testing@fix-swift-6.3-attachable`) exists because upstream 1.19.x doesn't build under Swift 6.3. Do not revert to upstream until a tagged release fixes that.

Tests mix both XCTest and Swift Testing frameworks across 11 test targets (`CodeEditorCommonTests`, `CodeEditorCompletionTests`, `CodeEditorHighlightingCoreTests`, `CodeEditorHygieneTests`, `CodeEditorLSPIntegrationTests`, `CodeEditorLSPTests`, `CodeEditorPluginTests`, `CodeEditorSwiftUITests`, `CodeEditorTextModelTests`, `CodeEditorUITests`, `CodeEditorViewTests`).

Tree-sitter work is internal scaffolding only. There is no public configuration flag and no bundled C grammar libraries wired into `Package.swift`; normal syntax highlighting uses the descriptor-backed regex path.

## Source Tree

```
Sources/CodeEditorPlugin/
├── CodeEditorPlugin.swift   # Public-facing entry stub (becomes the @_exported import file in §6.2.14)
└── Resources/               # Info.plist
```

Pre-extraction directories (`Core/`, `Text/`, `SyntaxHighlighting/`, `Theming/`, `Configuration/`, `Documents/`, `Platform/`, `Extensions/`, `Models/`, `Utilities/`, `Resources/`, `Workspace/`, `Search/`, `Annotations/`, `Completion/`, `LSP/`, `Layout/`, `Languages/`, `Features/`) have been carved out into sibling SPM targets — see "Other source roots" below.

Long-form prose docs live in `docs/` — see [`docs/README.md`](docs/README.md) for the topical index.

No top-level directories left in the umbrella target source tree (`Resources/` holds only `Info.plist`); 1 Swift source file in the umbrella (`CodeEditorPlugin.swift`; the 17-file SwiftUI/ slice was extracted to `CodeEditorSwiftUI` in §6.2.13; the 74-file `Languages/` slice was relocated to `Sources/CodeEditorLanguages/` in §6.2.15). Down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8c / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.11 / §6.2.12a/b/c / §6.2.12 / §6.2.13 / §6.2.15. Total Swift source files under `Sources/`: ~589.

Other source roots (each is its own SPM target — see `Package.swift`):
- `Sources/CodeEditorCommon/` — utilities, models, extensions, errors, `RecoverableAsyncError`+`RecoveryStrategy`+`BackoffStrategy` infra (phase 0; expanded in §6.2.7); `SendablePerformanceMetric` + `FileChangeNotification` (added §6.2.12b); `SelectionState`, `EditorInteractionState` + `EditorCursorPosition`, `DirtyTracker`, `ErrorRecoveryCoordinator` (added §6.2.12c — `ErrorRecoveryCoordinator` is a rename of umbrella `Core/AsyncOperationErrors.swift`; the now-deleted `CompletionAsyncError` was dead code).
- `Sources/CodeEditorDiagnostics/` — the full diagnostics system (PerformanceInsights, PerformanceViews dashboards, PerformanceTypes, PerformanceObservation, FrameRateMonitor, PerformanceBudget, metric providers; phase 4). Depends on and `@_exported`-re-exports `CodeEditorInstrumentation`, so `import CodeEditorDiagnostics` still exposes `MemoryMonitor` and friends.
- `Sources/CodeEditorInstrumentation/` — lightweight runtime instrumentation consumed by the lean editor targets: `MemoryMonitor` (+`MemoryMonitorUsing`), `UnifiedPerformanceSystem`, `PerformanceMonitor`, `LRUCache`, `AdaptivePerformanceMode`, `HardwareAcceleration`, `ProductionPerformanceMetrics`, plus the `MemoryMonitoring` protocol and `NoOpMemoryMonitor`/`NoOpPerformanceTracker`. `CodeEditorView`/`Completion`/`SyntaxHighlighting`/`LSP` depend on this, NOT on `CodeEditorDiagnostics`.
- `Sources/CodeEditorHighlightingCore/` — view-free value contracts for highlight providers: `HighlightRange`, `HighlightToken`, `HighlightDocumentSnapshot`, `HighlightTextEdit`, `HighlightInvalidation`, and the `HighlightRangeProviding` protocol. Zero CodeEditor dependencies (Foundation only). The blocking external highlight seam that replaces the internal view-based `RangeHighlightProviding`; `CodeEditorView` bridges value providers via `SnapshotHighlightProviderBridge`.
- `Sources/CodeEditorLSPIntegration/` — opt-in LSP-to-editor bridge (depends on `CodeEditorView` + `CodeEditorLSP`): `LSPEditorBridge` (public entry, owns the `LSPManager`), `LSPDocumentController`, `LSPContentCoordinator`, and `LSPSemanticTokenProvider` (a value-oriented `HighlightRangeProviding`). `CodeEditorView` no longer depends on `CodeEditorLSP`; the LSP bridge was moved out here so LSP is genuinely optional.
- `Sources/CodeEditorFolding/` — fold-storage primitives (`FoldStoreElement`, `LineFoldStorage`, `FoldInfo`), `FoldRegionAdapter`, and `FoldingProviderRegistry` (phase 4; new in §6.2.8a). The view-coupled fold engine, operations service, and presentation strategy live in `Sources/CodeEditorView/Folding/` (moved with the rest of `Core/` in §6.2.12).
- `Sources/CodeEditorSymbols/` — symbol-navigation surface: `BreadcrumbItem`, `SymbolNavigationConfiguration`, `SymbolProviderCatalog`, and generic `SymbolRangeIndex` storage (phase 4; new in §6.2.8b). The view-coupled `SymbolNavigator` lives in `Sources/CodeEditorView/Symbols/` (moved with the rest of `Core/` in §6.2.12).
- `Sources/CodeEditorLanguages/` — language descriptors + folding/symbol/completion-model interfaces; `TabModel` + `LanguageDetectionService` (added §6.2.12b). Phase 3; relocated to its own source root in §6.2.15 (was at `Sources/CodeEditorPlugin/Languages/` with a `path:` override).
- `Sources/CodeEditorPlatform/` — cross-platform color/font/view abstractions (phase 0).
- `Sources/CodeEditorTextModel/` — TextKit2 primitives, `RangeStore`/`RangeStoreElement`/`RangeStoreRun`, geometry, location, parsing primitives (phase 1; RangeStore relocated from umbrella in §6.2.7).
- `Sources/CodeEditorConfiguration/` — settings, presets, validation (phase 1).
- `Sources/CodeEditorAnnotations/` — annotation data model + view chrome: `Annotation`, `AnnotationKind`, `AnnotationView`, `AnnotationsContentView`, `CodeEditorViewAnnotation`, `LineAnnotation`, `MessageLineAnnotation` (phase 4; new in §6.2.8e). The view-coupled `AnnotationsDataSource` protocol lives in `Sources/CodeEditorView/Annotations/` (its required method takes `CodeEditorView`). Productized as an opt-in `.library` (added for DiagramKit's editor migration — external hosts need to name `Annotation`/`AnnotationKind` to call `EditorController.addAnnotation`); `CodeEditorView` and `CodeEditorSwiftUI` still consume the types directly.
- `Sources/CodeEditorSearch/` — project-wide file-search protocols + portable adapter (phase 4; new in §6.2.8d). Productized as opt-in `.library` per NEXT.md §6.3; the umbrella `CodeEditorPlugin` does not depend on it. Foundation-only; cross-platform (no `#if canImport`). The in-document `SearchReplaceEngine` lives in `Sources/CodeEditorView/Search/` (CodeEditorView-coupled; moved with the rest of `Core/` in §6.2.12).
- `Sources/CodeEditorSmartEditing/` — smart-editing engines: `SmartEditingEngine` (top-level coordinator) + 4 strategy engines (`AutoBracketingEngine`, `MultiCursorEditor`, `SmartIndentationEngine`, `SmartSelectionExpander`). 5 files (phase 4; new in §6.2.8c — closes the §6.2.8 feature-engine extraction series). Not productized. NOTE: contrary to earlier docs, the umbrella `CodeEditorPlugin` target does **not** currently depend on it (verified via the product→target transitive closure); the only in-tree dependent is `CodeEditorViewTests`. Hosts attach via `engine.attach(to: codeEditorView)` — not wired into `EditorConfiguration`. Sub-folder `Features/SmartEditing/` flattened at destination per the target-name-is-the-namespace convention.
- `Sources/CodeEditorSwiftUI/` — SwiftUI host wrapper + Representable bridge: `CodeEditor` (SwiftUI view struct), `EditorController` (host controller class), `CodeEditorBaseCoordinator` (open class, conforms to `CodeEditorCoordinating` package protocol in `CodeEditorView`), `CodeEditorIntent`, `CodeEditorEnvironment+Extensions`, `CodeEditorPlatformAdapter`, `CodeEditorRepresentableHelper`, `CodeEditorTheme+Extensions`, `EditorState+Environment` reader, plus 7 `CodeEditor+*` and 2 `EditorController+*` slice extensions. 17 files (phase 9; new in §6.2.13). Productized as `.library` per NEXT.md §6.3; umbrella `CodeEditorPlugin` DOES depend on it (matches §6.2.9 LSP / §6.2.10 Diagnostics / §6.2.11 Layout / §6.2.12 View precedent — productized + umbrella-coupled).
- `Sources/CodeEditorSyntaxHighlighting/` — syntax-highlighting engine: color schemes, tokenizers, regex/SwiftSyntax highlighters, parsing helpers, descriptor execution, performance instrumentation (phase 3.5).
- `Sources/CodeEditorUI/` — optional SwiftUI chrome/components.
- `Sources/CodeEditorWorkspace/` — workspace file-tree protocols + macOS `MacOSWorkspaceFileManager` adapter (phase 4; new in §6.2.8f). Productized as an opt-in `.library` per NEXT.md §6.3; the umbrella `CodeEditorPlugin` does not depend on it. Foundation-only; AppKit-conditional manager. iOS adapter is a future session.
- `Sources/CodeEditorCompletion/` — completion subsystem: `CompletionManager`, ranking model, fuzzy matcher, built-in providers, view controllers + adapter, event broadcaster, SwiftUI bridge types (phase 4; new in §6.2.8g). 20 files. Not productized — umbrella consumes Completion types from ~17 files (Core/CodeEditorView extensions + delegates + EditorEvent + UnifiedEventSystem, LSP, SwiftUI slice, Core/Symbols/SymbolNavigator), so the new target routes through the umbrella per Folding/Symbols/SH/Annotations precedent.
- `Sources/CodeEditorLSP/` — Language Server Protocol subsystem: `LSPClient`, `LSPManager`, transport (process + WebSocket with cert pinning), document/path/process/connection managers, message handler, wire types, completion + semantic-token storage, retry config (phase 5; new in §6.2.9). 22 files (18 top-level + 4 in `Transport/`). Productized as opt-in `.library` per NEXT.md §6.3; the umbrella `CodeEditorPlugin` depends on it (matches §6.2.10 Diagnostics precedent — productized + umbrella-coupled, not §6.2.8d Search-style umbrella-decoupled opt-out). The editor-coupled bridge (`LSPSemanticTokenProvider`, `LSPContentCoordinator`, `LSPDocumentController`, `LSPEditorBridge`) now lives in `Sources/CodeEditorLSPIntegration/`, not `CodeEditorView` — `CodeEditorView` no longer depends on `CodeEditorLSP`.
- `Sources/CodeEditorLayout/` — presentation primitives: layout caches/coordinator/optimizer, fold chevrons, `_GlassSurface`, insertion-point/line-highlight views, layout providers, event bus, completion popover chrome, `ThemeableUIComponent` protocol + `LayoutConformances` half of the split, `MinimapStyleDataSource`, plus `EditorLayoutTypes.swift` (`ComponentFrames`, `EdgeInsets`, `LayoutOptimizations`, `LayoutConstraints` lifted from umbrella `EditorLayoutService`) (phase 7; new in §6.2.11). 22 files. Productized as `.library` per NEXT.md §6.3; umbrella DOES depend on it (matches §6.2.9 LSP / §6.2.10 Diagnostics pattern). Cross-target relocations during the extraction: `SourcePosition` → `CodeEditorCommon`, `EditorConfiguration: Hashable` conformance → `CodeEditorConfiguration`.
- `Sources/CodeEditorView/` — editor-surface target: 118 files moved from former umbrella `Core/` to new SPM target in §6.2.12. Contents: `CodeEditorView` class + 24 `CodeEditorView+*Extensions` slices + delegate companions (`CodeEditorViewDelegate`, `CodeEditorViewDelegateProxy`, `CodeEditorViewProtocol`) + `UnifiedTextView+Extensions` + 22 root-level standalone-service files (`ActorCoordinator`, `CodeEditorAPI`, `CodeEditorDependencies`, `CodeEditorRenderingDiagnostics`, `CodeFoldingCoordinatorService`, `EditorEvent`/`EditorEventHandler`/`EditorEventPublisher`/`EditorEventTypes`, `EditorLayoutService`, `EditorRuntime`, `EditorState`/`EditorStateBridge`, `GutterSizingService`, `IOSLargeFileOptimizer`, `LineNumberCalculationService`, `MemoryManagementCoordinator`, `SyntaxHighlightingService`, `TextEditingService`, `TextKitSetupHelper`, `TextViewDelegateMultiplexer`/`TextViewDelegateParticipant`, `UnifiedEventSystem`) + the previously stay-set carve-out residues from `Annotations/` (1), `Configuration/` (1), `Documents/` (2), `Folding/` (4), `Layout/` (21), `LSP/` (2), `Platform/` (11), `Search/` (1), `Symbols/` (1), `SyntaxHighlighting/` (9), `Text/` (7), `Actors/` (6) — all sub-directories preserved + `CodeEditorCoordinating.swift` (new package-visible marker protocol that breaks the would-be circular dep with umbrella SwiftUI/'s `CodeEditorBaseCoordinator`). Phase 8. Productized as `.library` per NEXT.md §6.3; umbrella `CodeEditorPlugin` DOES depend on it (matches §6.2.9 / §6.2.10 / §6.2.11 pattern — productized + umbrella-coupled).
- `Sources/CodeEditorTreeSitterLanguages/` — tree-sitter packaging/staging sources; it is not currently an SPM target.

## Conventions

### Platform Detection
```swift
// CORRECT
#if canImport(AppKit)
import AppKit
#endif

// WRONG
#if os(macOS)  // Don't do this
```

### Logging
Never use `print()`. Use `CrossPlatformLogger.logger()` instead. This is enforced by a custom SwiftLint rule.

### Force Unwraps
Never use `!`. Always safe-unwrap. Enforced by SwiftLint `force_unwrapping` rule.

### Extension Files
Two naming patterns are in active use; both are accepted:

- **Catch-all type extensions** use the `+Extensions` suffix and live in the owning module, commonly `Sources/CodeEditorCommon/Extensions/`: `String+Extensions.swift`, `NSParagraphStyle+Extensions.swift`, etc.
- **Domain-scoped extensions** use a `+<Topic>` suffix that names the slice they implement, and live in the domain's own directory: `CodeEditorView+Theme.swift`, `EditorController+Completion.swift`, `LSPClient+Transport.swift`, `CodeEditorContainerView+Minimap.swift`. These are partial-file extensions that decompose a single owning type's API surface by feature rather than acting as a generic type extension.

When in doubt, prefer the domain-scoped form for files that extend one specific framework type with a feature-scoped slice, and the `+Extensions` form for type extensions that don't belong to a single domain.

### Dependency Injection
No singletons. Pass dependencies through `EditorConfiguration` or service initializers:
- `ActorCoordinator`: `config.actorCoordinator = ActorCoordinator.create()`
- `MemoryMonitor`: `config.performance.memoryMonitor = MemoryMonitor()`, or use the SwiftUI `.memoryMonitor(_:)` modifier
- `UnifiedEventSystem`: `config.eventSystem = UnifiedEventSystem()`, or use `.eventSystem(_:)`

### Configuration
```swift
// Direct updates (preferred for SwiftUI bindings)
config.display.isLineNumbersEnabled = true
config.display.isCodeFoldingEnabled = true
config.behavior.isAutoIndentEnabled = true

// Presets
let config = EditorConfiguration.minimal

// Batch mutation (immutable chaining)
let updated = config
    .with(display: modifiedDisplay)
    .with(behavior: modifiedBehavior)
```

### Testing
Snapshot tests write to `__Snapshots__/` directories (excluded from git in `Package.swift` excludes). When adding snapshot tests, record with `isRecording: true`, then commit the generated images. Tests use a mix of `import XCTest` and `import Testing`.

## Diagrams

Architecture diagrams live in `docs/Diagrams/` (Mermaid). Keep them in sync with the codebase — when adding features or renaming classes, update the relevant diagram. The folder has its own [`README.md`](docs/Diagrams/README.md) indexing every diagram.

**Watch for stale claims in diagrams:**
- Language count is 30 concrete languages plus plain text (Swift, Python, JavaScript, TypeScript, Java, Go, Rust, C, C++, PHP, Ruby, JSON, YAML, XML, Markdown, CSS, HTML, SQL, Shell, Dockerfile, TOML, Lua, C#, Kotlin, Dart, Mermaid, D2, Graphviz DOT, Structurizr DSL, PlantUML, plus plain text). The five diagram DSLs were added for DiagramKit's editor migration.
- Historical snapshots and design-only diagrams (pre-0.2.0 platform abstraction, the extended debugging-integration design, the plugin system, and the planned enhanced-syntax-highlighting design) live in [`docs/archive/Diagrams/`](docs/archive/Diagrams/). Treat them as point-in-time references, not current truth.
- These symbols are referenced in those archived diagrams (and in scripts / design docs) but do **not** exist in the framework: `depermaid`, `ConfigurationBatchUpdater`, `PluginManager`, `ServiceLifecycle`, `CodeEditorSwiftUITheme`, `EditorTheme`, `LanguageConfig`, `CodeEditorLayoutManager`, `ConfigurationValidator`, `EditorConfigurationBuilder`, `ConfigurationMigrator`, `ConfigurationHotReload`, `PluginAPI`, `PluginContext`, `MarkdownPlugin`. (`AppState` exists in the workspace's `apps/CodeEditorDemo` demo app, not in the framework — don't confuse the two.)

## What Will Go Wrong

- **No DocC catalog**: this project ships plain Markdown in `docs/`, not a DocC bundle. Don't add `@Metadata`, `<doc:>`, `## Topics`, or `.tutorial` directives to files in `docs/` — they won't render and they re-introduce a toolchain dependency that was deliberately removed.

- **SwiftLint strict mode** is on (`strict: true` in `.swiftlint.yml`). Warnings are treated as errors. Always run `swiftlint --fix` before `swiftlint`.

- **Custom lint rule `no_print_statements`** matches `///` doc comment lines in source, but the regex exempts them. Edits to that regex must preserve the `///` exclusion.

- **`canImport` conventions are enforced across ~217 files**. Adding a new `#if os()` is a regression.

- **Test count varies**: the codebase uses both `@Suite` (Swift Testing) and `XCTestCase` (XCTest). Counting "tests" depends on framework — `swift test --parallel` runs all of them regardless.

- **Mac Catalyst and TextKit1 are retired**: don't reintroduce `.macCatalyst`, `targetEnvironment(macCatalyst)`, `EditorConfiguration.catalyst`, or TextKit1 fallback branches. The package supports native macOS and iOS/iPadOS only.

- **`MemoryMonitor` is final**: tests should use `MemoryMonitor.mock(...)` or registered cleanup handlers, not subclass overrides.

- **Scripts are intentionally narrow**: `Scripts/generate-dependency-diagrams.sh` uses `swift package describe`, and `Scripts/run-parallel-tests.sh` delegates to SwiftPM. Do not reintroduce stale plugin, Pandoc, or sample-directory assumptions.

- **Historical superpowers plans/specs were archived out of this repo**: they now live in the CodeEditor workspace superproject under `docs/archive/package/CodeEditorPlugin/superpowers/`. Don't recreate a local `docs/superpowers/`; don't link the archived notes as authoritative project documentation. Source comments and the `.swiftlint.yml` rule message that still cite `docs/superpowers/...` paths are historical breadcrumbs pointing at that archive.

- **`TextSystem` protocol and its styler classes were deleted in §6.2.12c.** `TextSystem`, `TextSystemStyler<Interface>`, `ThreePhaseTextSystemStyler<Interface>`, and `TokenSystemValidator<Interface>` were earlier TextKit2 styling-experiment scaffolding with zero in-tree consumers — deleted, not extracted. External consumers depending on these need to remove the dependency.

- **`CompletionAsyncError` was deleted in §6.2.12c.** Public enum with zero in-tree callers. External consumers pattern-matching on `CompletionAsyncError.providerNotAvailable(_:)` (etc.) need to switch to whatever they ultimately mapped it to.

- **`ErrorRecoveryCoordinator` moved to `CodeEditorCommon` in §6.2.12c.** Previously umbrella-public (in `Core/AsyncOperationErrors.swift`), now lives in `Sources/CodeEditorCommon/ErrorRecoveryCoordinator.swift`. External consumers doing `import CodeEditorPlugin` continue to see it via the umbrella's transitive dep on `CodeEditorCommon`; consumers that need direct access should `import CodeEditorCommon`. The line-258 fallback error type changed from `SyntaxHighlightingError.cancelled` to `CancellationError()` (the path is practically-unreachable; callers should not depend on the specific error type).

- **`SelectionState`, `EditorInteractionState`, `EditorCursorPosition`, `DirtyTracker` moved to `CodeEditorCommon` in §6.2.12c.** Same soft-relocation pattern as `ErrorRecoveryCoordinator`. Test targets that previously reached these via `@testable import CodeEditorPlugin` need to add `import CodeEditorCommon`.

- **SwiftLint `missing_docs` is asymmetric between public struct and public actor inits.** As of §6.2.12c, an undocumented `public init()` on a `public struct` passes lint; the same `public init()` on a `public actor` fails with a `missing_docs` violation. Both `DirtyTracker.init` (struct) and `ErrorRecoveryCoordinator.init` (actor) were added by §6.2.12c; only the actor's needed a one-line `///` to compile. Empirical, not configured anywhere obvious — keep this in mind when adding explicit synth-init-replacement inits to cross-target moves.

- **`Sources/CodeEditorPlugin/Core/` is gone.** §6.2.12 moved all 118 files to `Sources/CodeEditorView/`. References to old paths in scripts / regression tests / documentation need updating. The new target preserves the same sub-directory structure (`Actors/`, `Annotations/`, `Configuration/`, `Documents/`, `Folding/`, `LSP/`, `Layout/`, `Platform/`, `Search/`, `Symbols/`, `SyntaxHighlighting/`, `Text/`).

- **`CodeEditorView` is now both a target name AND a class name.** Module and type live in separate Swift namespaces, so `import CodeEditorView` followed by `CodeEditorView()` is unambiguous — no rename needed. Do not refactor either to disambiguate; the collision is intentional and matches the `CodeEditor<Concept>` naming convention.

- **`CodeEditorCoordinating` protocol added in §6.2.12.** Package-visible (`package protocol`, MainActor), in `Sources/CodeEditorView/CodeEditorCoordinating.swift`. Exists solely to break the would-be circular dep between `CodeEditorView` target and the SwiftUI/ slice. Post-§6.2.13, `CodeEditorBaseCoordinator` (the conformer) lives in `Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift` (open class, `package func markClean(view:)` impl at line 164). The protocol requires `func markClean(view: CodeEditorView)` — the single method `CodeEditorView.applyMarkClean()` calls on its `coordinator: CodeEditorCoordinating?` back-pointer. Do not type-cast back to `CodeEditorBaseCoordinator` from inside the `CodeEditorView` target (that would re-introduce the circular dep).

- **`@testable import CodeEditorPlugin` is rarely useful post-§6.2.13.** The umbrella now retains only `CodeEditorPlugin.swift` (root entry stub) + `Resources/Info.plist`. Tests reach internal symbols via `@testable import CodeEditorView` and `@testable import CodeEditorSwiftUI`; keep both alongside the existing umbrella `@testable` per the §6.2.8d "don't blanket-drop @testable" lesson, but new test code targeting umbrella-internal symbols will almost never need them. After §6.2.13, 176 plugin-test files, 38 sample-test files, and 15 UI-test files gained `@testable import CodeEditorSwiftUI` (alongside, not in place of, their existing imports).

- **`CodeEditorView` has `@unchecked Sendable` conformance** (§6.2.12). Swift's cross-module strict-concurrency checking refuses to compile `[weak codeEditorView] _ in MainActor.assumeIsolated { ... }` patterns when `CodeEditorView` lives in a different module — same code was tolerated by same-module analysis. The marker is safe because `CodeEditorView` is @MainActor-isolated end-to-end. Don't remove the `@unchecked Sendable` unless you've replaced every cross-isolation capture pattern with something the compiler can prove safe (e.g., extracting from `Notification.object` inside the closure body).

- **`CodeEditorTextModel` declares `CodeEditorPlatform` as a dep** (added in §6.2.12 commit `d0324a9`). `Sources/CodeEditorTextModel/ParagraphStyleCache.swift` imports `CodeEditorPlatform` and has done so since §6.2.12a, but the Package.swift dep was missed; incremental builds masked it. If you remove the dep, `swift package clean && swift build` will fail.

- **§6.2.12 SwiftLint `forbidden_text_view_delegate_assignment` path update.** The rule's `excluded:` regex was updated from `Sources/CodeEditorPlugin/Core/TextKitSetupHelper\.swift` to `Sources/CodeEditorView/TextKitSetupHelper\.swift`. The sole legitimate `textView.delegate = …` install site is in the moved file; lint stays passing because the path matches.

- **`package extension Foo { ... }` form is rejected by SwiftLint's `no_extension_access_modifier` rule.** Use per-method `package func ...` instead. Bit during §6.2.12 when bulk-promoting `TextViewDelegateParticipant`'s 12 default-impl methods; the bulk modifier had to be moved to each method individually.
