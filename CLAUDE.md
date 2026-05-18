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

# Build/run the sample app (target, not a separate package)
swift build --target CodeEditorSample
swift run CodeEditorSample
./Scripts/run-sample.sh [debug|release]

# Build a single library target
swift build --target CodeEditorPlugin
swift build --target CodeEditorUI
swift build --target CodeEditorDesignTokens

# Run the package test helper
./Scripts/run-parallel-tests.sh
```

## Package Structure

**Swift 6.3** with `StrictConcurrency` enabled. 4 products defined in `Package.swift`:

| Product | Type | Purpose |
|---|---|---|
| `CodeEditorPlugin` | library | Main editor framework |
| `CodeEditorUI` | library | Optional SwiftUI components |
| `CodeEditorDesignTokens` | library | Design tokens (colors, spacing, typography) |
| `CodeEditorSample` | executable | Demo app |

Key dependencies: `swift-syntax`, `swift-dependencies`, `xctest-dynamic-overlay` (IssueReporting), `swift-snapshot-testing` (tests only), `swift-custom-dump` (tests only).

The snapshot-testing fork (`ajmcclary/swift-snapshot-testing@fix-swift-6.3-attachable`) exists because upstream 1.19.x doesn't build under Swift 6.3. Do not revert to upstream until a tagged release fixes that.

Tests mix both XCTest and Swift Testing frameworks across 4 test targets (`CodeEditorPluginTests`, `CodeEditorDesignTokensTests`, `CodeEditorUITests`, `CodeEditorSampleTests`).

Tree-sitter work is internal scaffolding only. There is no public configuration flag and no bundled C grammar libraries wired into `Package.swift`; normal syntax highlighting uses the descriptor-backed regex path.

## Source Tree

```
Sources/CodeEditorPlugin/
├── CodeEditorPlugin.swift   # Public-facing entry stub (becomes the @_exported import file in §6.2.14)
├── Languages/               # Language descriptors + folding/symbol/completion-model interfaces (compiled as CodeEditorLanguages target via `path:`)
├── Resources/               # Info.plist
└── SwiftUI/                 # SwiftUI wrappers and modifiers (extracts to CodeEditorSwiftUI in §6.2.13)
```

Pre-extraction directories (`Core/`, `Text/`, `SyntaxHighlighting/`, `Theming/`, `Configuration/`, `Documents/`, `Platform/`, `Extensions/`, `Models/`, `Utilities/`, `Resources/`, `Workspace/`, `Search/`, `Annotations/`, `Completion/`, `LSP/`, `Layout/`, `Features/`) have been carved out into sibling SPM targets — see "Other source roots" below.

Long-form prose docs live in `docs/` — see [`docs/README.md`](docs/README.md) for the topical index.

2 top-level directories in the umbrella target (`Languages/`, `SwiftUI/` — plus `Resources/` for `Info.plist`) and 18 Swift source files in the umbrella target (1 root `CodeEditorPlugin.swift` + 17 `SwiftUI/*`; `Languages/` is its own SPM target via `path:`). Down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8c / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.11 / §6.2.12a/b/c / §6.2.12. Total Swift source files under `Sources/`: ~586.

Other source roots (each is its own SPM target — see `Package.swift`):
- `Sources/CodeEditorCommon/` — utilities, models, extensions, errors, `RecoverableAsyncError`+`RecoveryStrategy`+`BackoffStrategy` infra (phase 0; expanded in §6.2.7); `SendablePerformanceMetric` + `FileChangeNotification` (added §6.2.12b); `SelectionState`, `EditorInteractionState` + `EditorCursorPosition`, `DirtyTracker`, `ErrorRecoveryCoordinator` (added §6.2.12c — `ErrorRecoveryCoordinator` is a rename of umbrella `Core/AsyncOperationErrors.swift`; the now-deleted `CompletionAsyncError` was dead code).
- `Sources/CodeEditorDesignTokens/` — standalone design-token library.
- `Sources/CodeEditorDiagnostics/` — performance instrumentation and memory monitoring (separate SPM product so consumers can omit it from release builds; phase 4).
- `Sources/CodeEditorFolding/` — fold-storage primitives (`FoldStoreElement`, `LineFoldStorage`, `FoldInfo`), `FoldRegionAdapter`, and `FoldingProviderRegistry` (phase 4; new in §6.2.8a). The umbrella-coupled fold engine, operations service, and presentation strategy live in `Sources/CodeEditorPlugin/Core/Folding/`.
- `Sources/CodeEditorSymbols/` — symbol-navigation surface: `BreadcrumbItem`, `SymbolNavigationConfiguration`, `SymbolProviderCatalog`, and generic `SymbolRangeIndex` storage (phase 4; new in §6.2.8b). The umbrella-coupled `SymbolNavigator` lives in `Sources/CodeEditorPlugin/Core/Symbols/`.
- `Sources/CodeEditorPlugin/Languages/` — language descriptors + folding/symbol/completion-model interfaces; `TabModel` + `LanguageDetectionService` (added §6.2.12b) (phase 3; physically inside the umbrella source tree but compiled as its own target via `path:`).
- `Sources/CodeEditorPlatform/` — cross-platform color/font/view abstractions (phase 0).
- `Sources/CodeEditorTextModel/` — TextKit2 primitives, `RangeStore`/`RangeStoreElement`/`RangeStoreRun`, geometry, location, parsing primitives (phase 1; RangeStore relocated from umbrella in §6.2.7).
- `Sources/CodeEditorConfiguration/` — settings, presets, validation (phase 1).
- `Sources/CodeEditorTheming/` — theme system, color tokens, appearance + bundled theme JSON (phase 2).
- `Sources/CodeEditorAnnotations/` — annotation data model + view chrome: `Annotation`, `AnnotationKind`, `AnnotationView`, `AnnotationsContentView`, `CodeEditorViewAnnotation`, `LineAnnotation`, `MessageLineAnnotation` (phase 4; new in §6.2.8e). The umbrella-coupled `AnnotationsDataSource` protocol stays in the umbrella at `Sources/CodeEditorPlugin/Core/Annotations/` (its required method takes `CodeEditorView`, awaiting §6.2.12). Not productized — umbrella consumes Annotation types via 6 files (Core/CodeEditorAPI, Core/CodeEditorView, Core/CodeEditorView+AnnotationsExtensions, Layout/ThemeableUIComponent+Conformances, SwiftUI/EditorController, Core/Annotations/AnnotationsDataSource), so it routes through the umbrella rather than as an opt-in `.library`.
- `Sources/CodeEditorSearch/` — project-wide file-search protocols + portable adapter (phase 4; new in §6.2.8d). Productized as opt-in `.library` per NEXT.md §6.3; the umbrella `CodeEditorPlugin` does not depend on it. Foundation-only; cross-platform (no `#if canImport`). The in-document `SearchReplaceEngine` stays in the umbrella at `Sources/CodeEditorPlugin/Core/Search/` (`CodeEditorView`-coupled, awaiting §6.2.12).
- `Sources/CodeEditorSmartEditing/` — smart-editing engines: `SmartEditingEngine` (top-level coordinator) + 4 strategy engines (`AutoBracketingEngine`, `MultiCursorEditor`, `SmartIndentationEngine`, `SmartSelectionExpander`). 5 files (phase 4; new in §6.2.8c — closes the §6.2.8 feature-engine extraction series). Not productized — umbrella `CodeEditorPlugin` depends on it directly (matches Folding/Symbols/Annotations/Completion precedent). Hosts attach via `engine.attach(to: codeEditorView)` — not wired into `EditorConfiguration`. Sub-folder `Features/SmartEditing/` flattened at destination per the target-name-is-the-namespace convention.
- `Sources/CodeEditorSyntaxHighlighting/` — syntax-highlighting engine: color schemes, tokenizers, regex/SwiftSyntax highlighters, parsing helpers, descriptor execution, performance instrumentation (phase 3.5).
- `Sources/CodeEditorUI/` — optional SwiftUI chrome/components.
- `Sources/CodeEditorWorkspace/` — workspace file-tree protocols + macOS `MacOSWorkspaceFileManager` adapter (phase 4; new in §6.2.8f). Productized as an opt-in `.library` per NEXT.md §6.3; the umbrella `CodeEditorPlugin` does not depend on it. Foundation-only; AppKit-conditional manager. iOS adapter is a future session.
- `Sources/CodeEditorCompletion/` — completion subsystem: `CompletionManager`, ranking model, fuzzy matcher, built-in providers, view controllers + adapter, event broadcaster, SwiftUI bridge types (phase 4; new in §6.2.8g). 20 files. Not productized — umbrella consumes Completion types from ~17 files (Core/CodeEditorView extensions + delegates + EditorEvent + UnifiedEventSystem, LSP, SwiftUI slice, Core/Symbols/SymbolNavigator), so the new target routes through the umbrella per Folding/Symbols/SH/Annotations precedent.
- `Sources/CodeEditorLSP/` — Language Server Protocol subsystem: `LSPClient`, `LSPManager`, transport (process + WebSocket with cert pinning), document/path/process/connection managers, message handler, wire types, completion + semantic-token storage, retry config (phase 5; new in §6.2.9). 22 files (18 top-level + 4 in `Transport/`). Productized as opt-in `.library` per NEXT.md §6.3; the umbrella `CodeEditorPlugin` depends on it (matches §6.2.10 Diagnostics precedent — productized + umbrella-coupled, not §6.2.8d Search-style umbrella-decoupled opt-out). The two `CodeEditorView`-coupled files (`LSPSemanticTokenProvider`, `LSPContentCoordinator`) stay in umbrella at `Sources/CodeEditorPlugin/Core/LSP/`.
- `Sources/CodeEditorLayout/` — presentation primitives: layout caches/coordinator/optimizer, fold chevrons, `_GlassSurface`, insertion-point/line-highlight views, layout providers, event bus, completion popover chrome, `ThemeableUIComponent` protocol + `LayoutConformances` half of the split, `MinimapStyleDataSource`, plus `EditorLayoutTypes.swift` (`ComponentFrames`, `EdgeInsets`, `LayoutOptimizations`, `LayoutConstraints` lifted from umbrella `EditorLayoutService`) (phase 7; new in §6.2.11). 22 files. Productized as `.library` per NEXT.md §6.3; umbrella DOES depend on it (matches §6.2.9 LSP / §6.2.10 Diagnostics pattern). Cross-target relocations during the extraction: `SourcePosition` → `CodeEditorCommon`, `EditorConfiguration: Hashable` conformance → `CodeEditorConfiguration`.
- `Sources/CodeEditorView/` — editor-surface target: 118 files moved from former umbrella `Core/` to new SPM target in §6.2.12. Contents: `CodeEditorView` class + 24 `CodeEditorView+*Extensions` slices + delegate companions (`CodeEditorViewDelegate`, `CodeEditorViewDelegateProxy`, `CodeEditorViewProtocol`) + `UnifiedTextView+Extensions` + 22 root-level standalone-service files (`ActorCoordinator`, `CodeEditorAPI`, `CodeEditorDependencies`, `CodeEditorRenderingDiagnostics`, `CodeFoldingCoordinatorService`, `EditorEvent`/`EditorEventHandler`/`EditorEventPublisher`/`EditorEventTypes`, `EditorLayoutService`, `EditorRuntime`, `EditorState`/`EditorStateBridge`, `GutterSizingService`, `IOSLargeFileOptimizer`, `LineNumberCalculationService`, `MemoryManagementCoordinator`, `SyntaxHighlightingService`, `TextEditingService`, `TextKitSetupHelper`, `TextViewDelegateMultiplexer`/`TextViewDelegateParticipant`, `UnifiedEventSystem`) + the previously stay-set carve-out residues from `Annotations/` (1), `Configuration/` (1), `Documents/` (2), `Folding/` (4), `Layout/` (21), `LSP/` (2), `Platform/` (11), `Search/` (1), `Symbols/` (1), `SyntaxHighlighting/` (9), `Text/` (7), `Actors/` (6) — all sub-directories preserved + `CodeEditorCoordinating.swift` (new package-visible marker protocol that breaks the would-be circular dep with umbrella SwiftUI/'s `CodeEditorBaseCoordinator`). Phase 8. Productized as `.library` per NEXT.md §6.3; umbrella `CodeEditorPlugin` DOES depend on it (matches §6.2.9 / §6.2.10 / §6.2.11 pattern — productized + umbrella-coupled).
- `Sources/CodeEditorSample/` — executable demo app target.
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

- **Catch-all type extensions** use the `+Extensions` suffix and live in `Sources/CodeEditorPlugin/Extensions/`: `String+Extensions.swift`, `NSParagraphStyle+Extensions.swift`, etc.
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
- These symbols are referenced in those archived diagrams (and in scripts / design docs) but do **not** exist in the framework: `depermaid`, `ConfigurationBatchUpdater`, `PluginManager`, `ServiceLifecycle`, `CodeEditorSwiftUITheme`, `EditorTheme`, `LanguageConfig`, `CodeEditorLayoutManager`, `ConfigurationValidator`, `EditorConfigurationBuilder`, `ConfigurationMigrator`, `ConfigurationHotReload`, `PluginAPI`, `PluginContext`, `MarkdownPlugin`. (`AppState` exists in the `CodeEditorSample` target, not in the framework — don't confuse the two.)

## What Will Go Wrong

- **Sample app is a target, not a directory**: `cd CodeEditorSample && swift build` will fail. Use `swift run CodeEditorSample` or `swift build --target CodeEditorSample`.

- **`CodeEditorSample` uses the native NSWindow chrome**: do NOT add `EditorTitleBar`, `EditorTrafficLights`, or `.windowStyle(.hiddenTitleBar)` to `RootWindow` / `CodeEditorSampleApp`. `.hiddenTitleBar` hides the title-bar background but leaves the OS traffic-light buttons drawn in the window's top-left corner, so embedding `EditorTitleBar` on top produces a visible "app inside an app." `EditorTitleBar` is a public `CodeEditorUI` component for hosts that genuinely own their chrome (and hide the standard NSWindow buttons themselves); it remains covered by `EditorTitleBarSnapshots` / `EditorTrafficLightsSnapshots` and the `ConformanceAuditTests` type audit — none of that requires the sample to embed it.

- **No DocC catalog**: this project ships plain Markdown in `docs/`, not a DocC bundle. Don't add `@Metadata`, `<doc:>`, `## Topics`, or `.tutorial` directives to files in `docs/` — they won't render and they re-introduce a toolchain dependency that was deliberately removed.

- **SwiftLint strict mode** is on (`strict: true` in `.swiftlint.yml`). Warnings are treated as errors. Always run `swiftlint --fix` before `swiftlint`.

- **Custom lint rule `no_print_statements`** matches `///` doc comment lines in source, but the regex exempts them. Edits to that regex must preserve the `///` exclusion.

- **`canImport` conventions are enforced across ~217 files**. Adding a new `#if os()` is a regression.

- **Test count varies**: the codebase uses both `@Suite` (Swift Testing) and `XCTestCase` (XCTest). Counting "tests" depends on framework — `swift test --parallel` runs all of them regardless.

- **Mac Catalyst and TextKit1 are retired**: don't reintroduce `.macCatalyst`, `targetEnvironment(macCatalyst)`, `EditorConfiguration.catalyst`, or TextKit1 fallback branches. The package supports native macOS and iOS/iPadOS only.

- **`MemoryMonitor` is final**: tests should use `MemoryMonitor.mock(...)` or registered cleanup handlers, not subclass overrides.

- **Scripts are intentionally narrow**: `Scripts/generate-dependency-diagrams.sh` uses `swift package describe`, and `Scripts/run-parallel-tests.sh` delegates to SwiftPM. Do not reintroduce stale plugin, Pandoc, or sample-directory assumptions.

- **`docs/superpowers/` is archived working notes**: don't link it as authoritative project documentation.

- **`TextSystem` protocol and its styler classes were deleted in §6.2.12c.** `TextSystem`, `TextSystemStyler<Interface>`, `ThreePhaseTextSystemStyler<Interface>`, and `TokenSystemValidator<Interface>` were earlier TextKit2 styling-experiment scaffolding with zero in-tree consumers — deleted, not extracted. External consumers depending on these need to remove the dependency.

- **`CompletionAsyncError` was deleted in §6.2.12c.** Public enum with zero in-tree callers. External consumers pattern-matching on `CompletionAsyncError.providerNotAvailable(_:)` (etc.) need to switch to whatever they ultimately mapped it to.

- **`ErrorRecoveryCoordinator` moved to `CodeEditorCommon` in §6.2.12c.** Previously umbrella-public (in `Core/AsyncOperationErrors.swift`), now lives in `Sources/CodeEditorCommon/ErrorRecoveryCoordinator.swift`. External consumers doing `import CodeEditorPlugin` continue to see it via the umbrella's transitive dep on `CodeEditorCommon`; consumers that need direct access should `import CodeEditorCommon`. The line-258 fallback error type changed from `SyntaxHighlightingError.cancelled` to `CancellationError()` (the path is practically-unreachable; callers should not depend on the specific error type).

- **`SelectionState`, `EditorInteractionState`, `EditorCursorPosition`, `DirtyTracker` moved to `CodeEditorCommon` in §6.2.12c.** Same soft-relocation pattern as `ErrorRecoveryCoordinator`. Test targets that previously reached these via `@testable import CodeEditorPlugin` need to add `import CodeEditorCommon`.

- **SwiftLint `missing_docs` is asymmetric between public struct and public actor inits.** As of §6.2.12c, an undocumented `public init()` on a `public struct` passes lint; the same `public init()` on a `public actor` fails with a `missing_docs` violation. Both `DirtyTracker.init` (struct) and `ErrorRecoveryCoordinator.init` (actor) were added by §6.2.12c; only the actor's needed a one-line `///` to compile. Empirical, not configured anywhere obvious — keep this in mind when adding explicit synth-init-replacement inits to cross-target moves.

- **`Sources/CodeEditorPlugin/Core/` is gone.** §6.2.12 moved all 118 files to `Sources/CodeEditorView/`. References to old paths in scripts / regression tests / documentation need updating. The new target preserves the same sub-directory structure (`Actors/`, `Annotations/`, `Configuration/`, `Documents/`, `Folding/`, `LSP/`, `Layout/`, `Platform/`, `Search/`, `Symbols/`, `SyntaxHighlighting/`, `Text/`).

- **`CodeEditorView` is now both a target name AND a class name.** Module and type live in separate Swift namespaces, so `import CodeEditorView` followed by `CodeEditorView()` is unambiguous — no rename needed. Do not refactor either to disambiguate; the collision is intentional and matches the `CodeEditor<Concept>` naming convention.

- **`CodeEditorCoordinating` protocol added in §6.2.12.** Package-visible (`package protocol`, MainActor), in `Sources/CodeEditorView/CodeEditorCoordinating.swift`. Exists solely to break the would-be circular dep between `CodeEditorView` target and the umbrella's SwiftUI/ slice. The umbrella's `CodeEditorBaseCoordinator` conforms. The protocol requires `func markClean(view: CodeEditorView)` — the single method `CodeEditorView.applyMarkClean()` calls on its `coordinator: CodeEditorCoordinating?` back-pointer. Do not type-cast back to `CodeEditorBaseCoordinator` from inside the `CodeEditorView` target (that would re-introduce the circular dep).

- **`@testable import CodeEditorPlugin` is still useful for the umbrella's residual SwiftUI/ slice.** Don't blanket-drop it from tests; keep alongside `@testable import CodeEditorView` per the §6.2.8d "don't blanket-drop @testable" lesson. After §6.2.12, 87 plugin-test files and 34 sample-test files gained `@testable import CodeEditorView` in addition to (not in place of) their existing umbrella import. (§6.2.8c closed the Features/SmartEditing residue — the umbrella now only retains SwiftUI/ on top of the root entry stub + Languages/ + Resources/.)

- **`CodeEditorView` has `@unchecked Sendable` conformance** (§6.2.12). Swift's cross-module strict-concurrency checking refuses to compile `[weak codeEditorView] _ in MainActor.assumeIsolated { ... }` patterns when `CodeEditorView` lives in a different module — same code was tolerated by same-module analysis. The marker is safe because `CodeEditorView` is @MainActor-isolated end-to-end. Don't remove the `@unchecked Sendable` unless you've replaced every cross-isolation capture pattern with something the compiler can prove safe (e.g., extracting from `Notification.object` inside the closure body).

- **`CodeEditorTextModel` declares `CodeEditorPlatform` as a dep** (added in §6.2.12 commit `d0324a9`). `Sources/CodeEditorTextModel/ParagraphStyleCache.swift` imports `CodeEditorPlatform` and has done so since §6.2.12a, but the Package.swift dep was missed; incremental builds masked it. If you remove the dep, `swift package clean && swift build` will fail.

- **§6.2.12 SwiftLint `forbidden_text_view_delegate_assignment` path update.** The rule's `excluded:` regex was updated from `Sources/CodeEditorPlugin/Core/TextKitSetupHelper\.swift` to `Sources/CodeEditorView/TextKitSetupHelper\.swift`. The sole legitimate `textView.delegate = …` install site is in the moved file; lint stays passing because the path matches.

- **`package extension Foo { ... }` form is rejected by SwiftLint's `no_extension_access_modifier` rule.** Use per-method `package func ...` instead. Bit during §6.2.12 when bulk-promoting `TextViewDelegateParticipant`'s 12 default-impl methods; the bulk modifier had to be moved to each method individually.
