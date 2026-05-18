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
├── Annotations/             # Data-source driven annotation badges
├── Completion/              # Code completion providers
├── Core/                    # Main APIs, services, event system (includes F3 sub-buckets: Configuration/, Documents/, Folding/, Platform/, Symbols/, SyntaxHighlighting/, Text/ — umbrella-coupled glue staged here pending §6.2.12 Core split)
├── Features/                # Optional features (folding, smart editing, search/replace, etc.)
├── LSP/                     # Language Server Protocol support
├── Languages/               # Language descriptors + folding/symbol/completion-model interfaces (compiled as CodeEditorLanguages target via `path:`)
├── Layout/                  # UI components + co-located ViewModels
├── Search/                  # Search result models and shared search support
├── SwiftUI/                 # SwiftUI wrappers and modifiers
└── Workspace/               # Workspace indexing/search types
```

Pre-extraction directories (`Text/`, `SyntaxHighlighting/`, `Theming/`, `Configuration/`, `Documents/`, `Platform/`, `Extensions/`, `Models/`, `Utilities/`, `Resources/`) have been carved out into sibling SPM targets — see "Other source roots" below.

Long-form prose docs live in `docs/` — see [`docs/README.md`](docs/README.md) for the topical index.

10 top-level directories in the umbrella target, 313 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b), and 592 Swift source files under `Sources/`.

Other source roots (each is its own SPM target — see `Package.swift`):
- `Sources/CodeEditorCommon/` — utilities, models, extensions, errors, `RecoverableAsyncError`+`RecoveryStrategy`+`BackoffStrategy` infra (phase 0; expanded in §6.2.7).
- `Sources/CodeEditorDesignTokens/` — standalone design-token library.
- `Sources/CodeEditorDiagnostics/` — performance instrumentation and memory monitoring (separate SPM product so consumers can omit it from release builds; phase 4).
- `Sources/CodeEditorFolding/` — fold-storage primitives (`FoldStoreElement`, `LineFoldStorage`, `FoldInfo`), `FoldRegionAdapter`, and `FoldingProviderRegistry` (phase 4; new in §6.2.8a). The umbrella-coupled fold engine, operations service, and presentation strategy live in `Sources/CodeEditorPlugin/Core/Folding/`.
- `Sources/CodeEditorSymbols/` — symbol-navigation surface: `BreadcrumbItem`, `SymbolNavigationConfiguration`, `SymbolProviderCatalog`, and generic `SymbolRangeIndex` storage (phase 4; new in §6.2.8b). The umbrella-coupled `SymbolNavigator` lives in `Sources/CodeEditorPlugin/Core/Symbols/`.
- `Sources/CodeEditorPlugin/Languages/` — language descriptors + folding/symbol/completion-model interfaces (phase 3; physically inside the umbrella source tree but compiled as its own target via `path:`).
- `Sources/CodeEditorPlatform/` — cross-platform color/font/view abstractions (phase 0).
- `Sources/CodeEditorTextModel/` — TextKit2 primitives, `RangeStore`/`RangeStoreElement`/`RangeStoreRun`, geometry, location, parsing primitives (phase 1; RangeStore relocated from umbrella in §6.2.7).
- `Sources/CodeEditorConfiguration/` — settings, presets, validation (phase 1).
- `Sources/CodeEditorTheming/` — theme system, color tokens, appearance + bundled theme JSON (phase 2).
- `Sources/CodeEditorSyntaxHighlighting/` — syntax-highlighting engine: color schemes, tokenizers, regex/SwiftSyntax highlighters, parsing helpers, descriptor execution, performance instrumentation (phase 3.5).
- `Sources/CodeEditorUI/` — optional SwiftUI chrome/components.
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
