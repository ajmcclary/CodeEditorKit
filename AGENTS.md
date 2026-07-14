# AGENTS.md

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

`swift-snapshot-testing` is consumed from upstream by version (`from: "1.19.3"`, tests only). The former `ajmcclary/swift-snapshot-testing@fix-swift-6.3-attachable` fork was only required on the open-source `swift-6.3-RELEASE` toolchain; upstream builds cleanly under the Apple Swift 6.4 / Xcode 27 toolchain this package targets. Keep it version-pinned so the package stays consumable by stable-version dependents.

Tests mix both XCTest and Swift Testing frameworks across 11 test targets (`CodeEditorCommonTests`, `CodeEditorCompletionTests`, `CodeEditorHighlightingCoreTests`, `CodeEditorHygieneTests`, `CodeEditorLSPIntegrationTests`, `CodeEditorLSPTests`, `CodeEditorPluginTests`, `CodeEditorSwiftUITests`, `CodeEditorTextModelTests`, `CodeEditorUITests`, `CodeEditorViewTests`).

Tree-sitter is not bundled: no C grammar libraries are wired into `Package.swift`, and the built-in path remains the descriptor-backed regex highlighter (plus SwiftSyntax for Swift). External tree-sitter highlighting plugs in through the public injection seam — `CodeEditorView.setExternalHighlightProvider(_:)` / `EditorController.setExternalHighlightProvider(_:)` / `.codeEditorHighlightProvider(_:)` — with the separate `CodeEditorTreeSitter` package's `TreeSitterHighlightProvider` as the reference conformer.

## Source Tree

```
Sources/CodeEditorPlugin/
├── CodeEditorPlugin.swift   # Public-facing entry stub (@_exported re-export hub)
└── Resources/               # Info.plist
```

Pre-extraction directories (`Core/`, `Text/`, `SyntaxHighlighting/`, `Theming/`, `Configuration/`, `Documents/`, `Platform/`, `Extensions/`, `Models/`, `Utilities/`, `Resources/`, `Workspace/`, `Search/`, `Annotations/`, `Completion/`, `LSP/`, `Layout/`, `Languages/`, `Features/`) have been carved out into sibling SPM targets — see "Other source roots" below.

Long-form prose docs live in `docs/` — see [`docs/README.md`](docs/README.md) for the topical index.

No top-level directories left in the umbrella target source tree (`Resources/` holds only `Info.plist`); 1 Swift source file in the umbrella (`CodeEditorPlugin.swift`). Total Swift source files under `Sources/`: ~589.

Other source roots (each is its own SPM target — see `Package.swift`):
- `Sources/CodeEditorCommon/` — utilities, models, extensions, errors, `RecoverableAsyncError`+`RecoveryStrategy`+`BackoffStrategy` infra, `SendablePerformanceMetric`, `FileChangeNotification`, `SelectionState`, `EditorInteractionState`+`EditorCursorPosition`, `DirtyTracker`, `ErrorRecoveryCoordinator`.
- `Sources/CodeEditorDiagnostics/` — the full diagnostics system (PerformanceInsights, PerformanceViews dashboards, PerformanceTypes, PerformanceObservation, FrameRateMonitor, PerformanceBudget, metric providers). Depends on and `@_exported`-re-exports `CodeEditorInstrumentation`, so `import CodeEditorDiagnostics` still exposes `MemoryMonitor` and friends.
- `Sources/CodeEditorInstrumentation/` — lightweight runtime instrumentation consumed by the lean editor targets: `MemoryMonitor` (+`MemoryMonitorUsing`), `UnifiedPerformanceSystem`, `PerformanceMonitor`, `LRUCache`, `AdaptivePerformanceMode`, `HardwareAcceleration`, `ProductionPerformanceMetrics`, plus the `MemoryMonitoring` protocol and `NoOpMemoryMonitor`/`NoOpPerformanceTracker`. `CodeEditorView`/`Completion`/`SyntaxHighlighting`/`LSP` depend on this, NOT on `CodeEditorDiagnostics`.
- `Sources/CodeEditorHighlightingCore/` — view-free value contracts for highlight providers: `HighlightRange`, `HighlightToken`, `HighlightDocumentSnapshot`, `HighlightTextEdit`, `HighlightInvalidation`, and the `HighlightRangeProviding` protocol. Zero CodeEditor dependencies (Foundation only) so an external adapter can conform without the editor. **Public injection seam:** a host installs a value provider as the editor's *primary* highlight source (replacing the built-in regex/SwiftSyntax highlighter) via `CodeEditorView.setExternalHighlightProvider(_:)`, `EditorController.setExternalHighlightProvider(_:)`, or the `.codeEditorHighlightProvider(_:)` SwiftUI modifier; all three reach `RangeBasedHighlightingController`'s `externalProvider` through `SnapshotHighlightProviderBridge`. Distinct from the LSP path, which layers a *supplemental* provider on top while the built-in highlighter keeps running. Requires `performance.usesRangeBasedHighlighting` + `display.useRangeStoreHighlighting`. The `CodeEditorTreeSitter` package's `TreeSitterHighlightProvider` is the reference conformer.
- `Sources/CodeEditorFolding/` — fold-storage primitives (`FoldStoreElement`, `LineFoldStorage`, `FoldInfo`), `FoldRegionAdapter`, and `FoldingProviderRegistry`. The umbrella-coupled fold engine, operations service, and presentation strategy live in `Sources/CodeEditorView/Folding/`.
- `Sources/CodeEditorSymbols/` — symbol-navigation surface: `BreadcrumbItem`, `SymbolNavigationConfiguration`, `SymbolProviderCatalog`, and generic `SymbolRangeIndex` storage. The view-coupled `SymbolNavigator` lives in `Sources/CodeEditorView/Symbols/`.
- `Sources/CodeEditorLanguages/` — language descriptors + folding/symbol/completion-model interfaces; `TabModel` + `LanguageDetectionService`.
- `Sources/CodeEditorPlatform/` — cross-platform color/font/view abstractions.
- `Sources/CodeEditorTextModel/` — TextKit2 primitives, `RangeStore`/`RangeStoreElement`/`RangeStoreRun`, geometry, location, parsing primitives.
- `Sources/CodeEditorConfiguration/` — settings, presets, validation.
- `Sources/CodeEditorAnnotations/` — annotation data model + view chrome: `Annotation`, `AnnotationKind`, `AnnotationView`, `AnnotationsContentView`, `CodeEditorViewAnnotation`, `LineAnnotation`, `MessageLineAnnotation`. The `AnnotationsDataSource` protocol stays in `CodeEditorView` (its required method takes `CodeEditorView`).
- `Sources/CodeEditorSearch/` — project-wide file-search protocols + portable adapter. Productized as an opt-in `.library`; the umbrella `CodeEditorPlugin` does not depend on it. Foundation-only; cross-platform (no `#if canImport`). The in-document `SearchReplaceEngine` lives in `Sources/CodeEditorView/Search/`.
- `Sources/CodeEditorSmartEditing/` — smart-editing engines: `SmartEditingEngine` (coordinator) + 4 strategy engines (`AutoBracketingEngine`, `MultiCursorEditor`, `SmartIndentationEngine`, `SmartSelectionExpander`). Hosts attach via `engine.attach(to: codeEditorView)`.
- `Sources/CodeEditorSwiftUI/` — SwiftUI host wrapper + Representable bridge: `CodeEditor` (SwiftUI view), `EditorController`, `CodeEditorBaseCoordinator` (conforms to `CodeEditorCoordinating` package protocol in `CodeEditorView`), `CodeEditorIntent`, plus SwiftUI environment and platform adapter glue.
- `Sources/CodeEditorSyntaxHighlighting/` — syntax-highlighting engine: color schemes, tokenizers, regex/SwiftSyntax highlighters, parsing helpers, descriptor execution, performance instrumentation.
- `Sources/CodeEditorUI/` — optional SwiftUI chrome/components.
- `Sources/CodeEditorWorkspace/` — workspace file-tree protocols + macOS `MacOSWorkspaceFileManager` adapter. Productized as an opt-in `.library`; the umbrella `CodeEditorPlugin` does not depend on it. Foundation-only; AppKit-conditional manager.
- `Sources/CodeEditorCompletion/` — completion subsystem: `CompletionManager`, ranking model, fuzzy matcher, built-in providers, view controllers + adapter, event broadcaster, SwiftUI bridge types.
- `Sources/CodeEditorLSP/` — Language Server Protocol subsystem: `LSPClient`, `LSPManager`, transport (process + WebSocket with cert pinning), document/path/process/connection managers, message handler, wire types, completion + semantic-token storage, retry config. Productized as an opt-in `.library`; the umbrella `CodeEditorPlugin` depends on it. The editor-coupled bridge lives in `Sources/CodeEditorLSPIntegration/`, not `CodeEditorView` (see next entry).
- `Sources/CodeEditorLSPIntegration/` — opt-in LSP-to-editor bridge (depends on `CodeEditorView` + `CodeEditorLSP`): `LSPEditorBridge` (public entry, owns the `LSPManager`), `LSPDocumentController`, `LSPContentCoordinator`, and `LSPSemanticTokenProvider` (a value-oriented `HighlightRangeProviding`). `CodeEditorView` no longer depends on `CodeEditorLSP`; LSP hosts consume this product.
- `Sources/CodeEditorLayout/` — presentation primitives: layout caches/coordinator/optimizer, fold chevrons, `_GlassSurface`, insertion-point/line-highlight views, layout providers, event bus, completion popover chrome, `ThemeableUIComponent` protocol + `LayoutConformances`, `MinimapStyleDataSource`. Productized as a `.library`; umbrella depends on it.
- `Sources/CodeEditorView/` — editor-surface target: `CodeEditorView` class + 24 `CodeEditorView+*Extensions` slices + delegate companions (`CodeEditorViewDelegate`, `CodeEditorViewDelegateProxy`, `CodeEditorViewProtocol`) + standalone services (`ActorCoordinator`, `CodeEditorAPI`, `EditorEvent`/`EditorEventHandler`/`EditorEventPublisher`, `EditorLayoutService`, `EditorRuntime`, `EditorState`/`EditorStateBridge`, `MemoryManagementCoordinator`, `SyntaxHighlightingService`, `TextEditingService`, `TextKitSetupHelper`, `UnifiedEventSystem`, etc.) + carve-out residues from `Annotations/`, `Configuration/`, `Documents/`, `Folding/`, `Layout/`, `LSP/`, `Platform/`, `Search/`, `Symbols/`, `SyntaxHighlighting/`, `Text/`, `Actors/` + `CodeEditorCoordinating.swift` (package-visible marker protocol that breaks the would-be circular dep with `CodeEditorSwiftUI`). Productized as a `.library`; umbrella depends on it.
- `Sources/CodeEditorTreeSitterLanguages/` — tree-sitter packaging/staging sources; not currently an SPM target.

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
- Language count is 25 concrete languages plus plain text (Swift, Python, JavaScript, TypeScript, Java, Go, Rust, C, C++, PHP, Ruby, JSON, YAML, XML, Markdown, CSS, HTML, SQL, Shell, Dockerfile, TOML, Lua, C#, Kotlin, Dart, plus plain text).
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

- **`Sources/CodeEditorPlugin/Core/` is gone.** All 118 files moved to `Sources/CodeEditorView/`. References to old paths in scripts / regression tests / documentation need updating. The new target preserves the same sub-directory structure (`Actors/`, `Annotations/`, `Configuration/`, `Documents/`, `Folding/`, `LSP/`, `Layout/`, `Platform/`, `Search/`, `Symbols/`, `SyntaxHighlighting/`, `Text/`).

- **`CodeEditorView` is now both a target name AND a class name.** Module and type live in separate Swift namespaces, so `import CodeEditorView` followed by `CodeEditorView()` is unambiguous — no rename needed. The collision is intentional and matches the `CodeEditor<Concept>` naming convention.

- **`CodeEditorCoordinating` protocol** (package-visible, MainActor, in `Sources/CodeEditorView/CodeEditorCoordinating.swift`) exists solely to break the would-be circular dep between `CodeEditorView` and `CodeEditorSwiftUI`. `CodeEditorBaseCoordinator` (the conformer) lives in `Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift`. Do not type-cast back to `CodeEditorBaseCoordinator` from inside `CodeEditorView` (that re-introduces the circular dep).

- **`@testable import CodeEditorPlugin` is rarely useful.** The umbrella retains only `CodeEditorPlugin.swift` + `Resources/Info.plist`. Tests reach internal symbols via `@testable import CodeEditorView` and `@testable import CodeEditorSwiftUI`; keep both alongside the existing umbrella `@testable`, but new test code targeting umbrella-internal symbols will almost never need them.

- **`CodeEditorView` has `@unchecked Sendable` conformance.** Swift's cross-module strict-concurrency checking refuses to compile `[weak codeEditorView] _ in MainActor.assumeIsolated { ... }` patterns when `CodeEditorView` lives in a different module. The marker is safe because `CodeEditorView` is @MainActor-isolated end-to-end. Don't remove it without replacing every cross-isolation capture pattern with something the compiler can prove safe.

- **SwiftLint `missing_docs` is asymmetric between public struct and public actor inits.** An undocumented `public init()` on a `public struct` passes lint; the same `public init()` on a `public actor` fails with a `missing_docs` violation. Empirical, not configured anywhere obvious — keep this in mind when adding explicit synth-init-replacement inits to cross-target moves.

- **`package extension Foo { ... }` form is rejected by SwiftLint's `no_extension_access_modifier` rule.** Use per-method `package func ...` instead.

- **`TextSystem` protocol and its styler classes are deleted.** `TextSystem`, `TextSystemStyler<Interface>`, `ThreePhaseTextSystemStyler<Interface>`, and `TokenSystemValidator<Interface>` were earlier TextKit2 styling-experiment scaffolding with zero in-tree consumers. External consumers depending on these need to remove the dependency.

- **`CompletionAsyncError` is deleted.** Public enum with zero in-tree callers. External consumers pattern-matching on `CompletionAsyncError.providerNotAvailable(_:)` need to switch to whatever they ultimately mapped it to.

- **`ErrorRecoveryCoordinator`, `SelectionState`, `EditorInteractionState`, `EditorCursorPosition`, `DirtyTracker` live in `CodeEditorCommon`.** Previously umbrella-public. External consumers doing `import CodeEditorPlugin` still see them transitively; consumers that need direct access should `import CodeEditorCommon`. Test targets that previously reached these via `@testable import CodeEditorPlugin` need `import CodeEditorCommon`.
