# CLAUDE.md

AI assistant guidance for CodeEditorPlugin — a TextKit2-based code editor framework for Apple platforms.

## Commands

```bash
# Build, lint, test (in order — lint catches issues tests may miss)
swift build && swiftlint && swift test --parallel

# Fix auto-correctable lint violations
swiftlint --fix

# Run a single test (matches by name substring)
swift test --filter TestName

# Build/run the sample app (target, not a separate package)
swift build --target CodeEditorSample
swift run CodeEditorSample

# Build a single target
swift build --target CodeEditorPlugin
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

Tests mix both XCTest and Swift Testing frameworks across 3 test targets (`CodeEditorPluginTests`, `CodeEditorDesignTokensTests`, `CodeEditorUITests`).

## Source Tree

```
Sources/CodeEditorPlugin/
├── Core/                    # Main APIs, services, event system
├── Text/                    # TextKit2 handling, layout, processing
├── Layout/                  # UI components + co-located ViewModels
├── Configuration/           # Settings, presets, validation
├── SyntaxHighlighting/      # Language highlighting engine
├── Languages/               # Language-specific providers (18 languages)
├── Theming/                 # Theme system, color tokens, appearance
├── Completion/              # Code completion providers
├── Features/                # Optional features (folding, annotations, etc.)
├── SwiftUI/                 # SwiftUI wrappers and modifiers
├── Platform/                # Cross-platform color/font/view abstractions
├── Extensions/              # Type extensions (all use +Extensions suffix)
├── Performance/             # Monitoring, profiling, memory tracking
├── LSP/                     # Language Server Protocol support
├── Annotations/             # Code annotation detection (TODO, FIXME, etc.)
├── Models/                  # Shared data models
├── Utilities/               # Shared helpers
└── Resources/               # Bundled theme JSON (processed via `resources:`)
```

Long-form prose docs live in `docs/` — see [`docs/README.md`](docs/README.md) for the topical index.

18 directories, ~438 Swift source files in the main target.

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
All extension files use the `+Extensions` suffix: `String+Extensions.swift`, `NSParagraphStyle+Extensions.swift`, etc. When an extension is specific to a domain (e.g., text layout helpers), co-locate it in that domain's directory rather than the global `Extensions/` folder.

### Dependency Injection
No singletons. Pass dependencies through `EditorConfiguration` or service initializers:
- `ActorCoordinator`: `config.actorCoordinator = ActorCoordinator.create()`
- `MemoryMonitor`: inject through configuration or environment

### Configuration
```swift
// Direct updates (preferred for SwiftUI bindings)
config.display.isLineNumbersEnabled = true

// Presets
let config = EditorConfiguration.minimal

// Batch mutation (immutable chaining)
let updated = config
    .with(display: modifiedDisplay)
    .with(behavior: modifiedBehavior)
```

### Testing
Snapshot tests write to `__Snapshots__/` directories (excluded from git in `Package.swift` excludes). When adding snapshot tests, record with `isRecording: true`, then commit the generated images. Tests use a mix of `import XCTest` and `import Testing`.

## What Will Go Wrong

- **Sample app is a target, not a directory**: `cd CodeEditorSample && swift build` will fail. Use `swift run CodeEditorSample` or `swift build --target CodeEditorSample`.

- **No DocC catalog**: this project ships plain Markdown in `docs/`, not a DocC bundle. Don't add `@Metadata`, `<doc:>`, `## Topics`, or `.tutorial` directives to files in `docs/` — they won't render and they re-introduce a toolchain dependency that was deliberately removed.

- **SwiftLint strict mode** is on (`strict: true` in `.swiftlint.yml`). Warnings are treated as errors. Always run `swiftlint --fix` before `swiftlint`.

- **Custom lint rule `no_print_statements`** matches `///` doc comment lines in source, but the regex exempts them. Edits to that regex must preserve the `///` exclusion.

- **`canImport` conventions are enforced across ~275 files**. Adding a new `#if os()` is a regression.

- **Test count varies**: the codebase uses both `@Suite` (Swift Testing) and `XCTestCase` (XCTest). Counting "tests" depends on framework — `swift test --parallel` runs all of them regardless.
