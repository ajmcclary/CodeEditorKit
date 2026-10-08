# Changelog

All notable changes to CodeEditorKit are documented in this file.

Entries dated before the 2026-07-25 rename deliberately keep the package's
former name, `CodeEditorPlugin` — they record what shipped at the time.

## [Unreleased]

### Fixed (tests only)

- The full test suite passes again (1057 XCTest + 368 Swift Testing), and CI
  runs all of it instead of a hand-picked subset.
  - 16 crashes (signal 11) in the TextKit 2 ruler, gutter, text-visibility and
    event fan-out tests: their programmatic `NSWindow`s defaulted to
    `isReleasedWhenClosed = true`, so `close()` over-released them.
  - Image snapshots no longer depend on the display scale of the machine that
    runs them (`NativeImageSnapshotting.swift`: fixed 2x rendering, ImageIO
    comparison with SnapshotTesting's precision semantics), and 48 references
    were re-recorded under macOS 27. They predated the 2026-07-12 DesignKit
    migration, whose theme values changed the title bar, tab strip, glass
    surfaces and other chrome colours.

## [0.1.0-beta.8] - 2026-10-08

### Changed

- `swift-syntax` requirement widened from `from: "602.0.0"` (i.e.
  `602.x` only) to `"602.0.0"..<"605.0.0"`, so dependents on the Swift 6.4
  toolchain resolve the matching `604.0.0`. Only `SwiftParser`/`SwiftSyntax`
  are used (runtime highlighting); no source change.
- Package lockfile refreshed to the newest in-range Point-Free stack and
  `swift-snapshot-testing` 1.19.6 (tests only). No public API change.

## [0.1.0-beta.7] - 2026-07-25

### Changed

- Every target declares Swift 6 language mode per target (it already
  compiled cleanly under Swift 6 with strict concurrency; no source change).
- **Platform floor raised to macOS 27.0, and the iOS 26 claim is removed.**
  `CodeEditorWorkspace` re-exports WorkspaceKit, whose `WorkspaceFileSystem`
  uses FSEvents unguarded, so an iOS build fails; the claim had most likely
  been unbacked since 0.1.0-beta.5. Restoring iOS needs WorkspaceKit's
  FSEvents target platform-gated.
- Dependency floors: LanguageKit `.upToNextMinor(from: "0.2.0")`, DesignKit
  `from: "2.0.0"`.

## [0.1.0-beta.6] - 2026-07-25

### Changed

- **BREAKING: the package is renamed `CodeEditorPlugin` → `CodeEditorKit`.**
  The SwiftPM package identity, the umbrella library product, the umbrella
  target and Swift module, its source directory
  (`Sources/CodeEditorPlugin/` → `Sources/CodeEditorKit/`), its entry stub
  (`CodeEditorPlugin.swift` → `CodeEditorKit.swift`), its test target
  (`CodeEditorPluginTests` → `CodeEditorKitTests`) and the repository URL
  (`https://github.com/ajmcclary/CodeEditorKit.git`) all change together.
  No compatibility alias is provided: `import CodeEditorPlugin` becomes
  `import CodeEditorKit`, and dependents must update both the
  `.package(url:)`/`.package(path:)` entry and every
  `.product(name:package: "CodeEditorKit")` label. Every other product,
  target and public symbol is unchanged — this is a naming migration only.
- `ProcessTransport` reads pipes through ProcessKit's shared
  `ProcessPipeReader` (`installChunkReader` is removed).

## [0.1.0-beta.5] - 2026-07-15

### Changed

- `CodeEditorWorkspace` is now an `@_exported` re-export shim over the new
  top-level WorkspaceKit package (0.1.0-beta.1), which received the
  workspace file-tree contracts and `MacOSWorkspaceFileManager` verbatim.
  Existing `import CodeEditorWorkspace` code is unaffected. (Released as
  `CodeEditorPlugin`.)

## [0.1.0-beta.4] - 2026-07-14

### Changed

- **`ProcessTransport` runs on ProcessKit** (the promoted neutral process
  package — the "proof-of-two" with RepoPrompt). `ProcessLauncher` owns
  spawning (posix_spawnp), `FileHandleChunkChannel` preserves stdout/stderr
  byte-arrival order (the previous per-chunk `Task` dispatch never
  guaranteed start order), `ProcessTermination` owns SIGTERM→SIGKILL
  escalation and single reaping (replacing the 5-second
  `waitUntilExit`/`interrupt()` race), and `FDWriteSupport` handles framed
  stdin writes (EPIPE-safe). `LSPFrameCodec` still owns framing; the actor
  keeps only LSP orchestration. Public API and `LSPTransport` conformance
  are unchanged; new lifecycle tests cover EOF, broken stdin, and
  child-exit-before-disconnect.

- **`LSPClient` is transport-only.** Content-Length framing is owned by a
  single internal `LSPFrameCodec` (both `ProcessTransport` and
  `WebSocketTransport` encode through it; `LSPMessageHandler` decodes
  through it, keeping the malformed-framing recovery semantics pinned by
  `LSPMessageHandlerRecoveryTests`). The legacy
  `connect(configuration: ServerConfiguration)` overload no longer falls
  back to spawning a server process when no transport is configured — it
  throws `LSPError.transportNotConfigured` (previously it spawned the
  executable and then hung awaiting an initialize response). Local servers
  are reached via `ProcessTransport`, installed by
  `connect(configuration:languageId:)` or `init(transport:)`; no in-package
  or demo caller used the fallback. The internal `LSPProcessManager` was
  deleted; `ProcessTransport` gained a direct end-to-end framing test.
  (ProcessKit proof-of-two, steps 1–4.)

## [0.1.0-beta.3] - 2026-07-14

### Added

- **Public injection seam for external highlight providers.** A host can now
  install a value-oriented `HighlightRangeProviding` (from the view-free
  `CodeEditorHighlightingCore` contract) as the editor's primary syntax-highlight
  source through three parallel APIs:
  - `CodeEditorView.setExternalHighlightProvider(_:)` (view level, plus a
    matching `externalHighlightProvider` read accessor).
  - `EditorController.setExternalHighlightProvider(_:)` (SwiftUI host façade);
    the controller remembers the provider and re-applies it on every (re)attach,
    so it works even when set before the underlying view exists.
  - `.codeEditorHighlightProvider(_:)` SwiftUI view modifier.

  Injecting a provider *replaces* the built-in regex / SwiftSyntax highlighter as
  the primary source (it does not augment it — that remains the LSP
  supplemental-provider path). Passing `nil` restores the built-in highlighter.
  The provider paints once `performance.usesRangeBasedHighlighting` and
  `display.useRangeStoreHighlighting` are enabled. This exposes the previously
  internal `RangeBasedHighlightingController(externalProvider:)` seam that the
  `CodeEditorTreeSitter` package's `TreeSitterHighlightProvider` was written for.

### Changed

- **Platform floor lowered from macOS 26.3 / iOS 26.3 to macOS 26.0 / iOS 26.0.**
  The 26.3 floor was never a real API requirement: the package contains no
  26.3-gated declarations and the full package builds with availability
  checking at 26.0. Lowering the floor aligns CodeEditorPlugin with DesignKit
  (26.0) and RepoPrompt (26.0), removing the deployment-target obstacle to
  embedding the editor in RepoPrompt. Toolchain requirements are unchanged
  (Swift 6.3+, Xcode 26.3+).

## [0.1.0-beta.2] - 2026-07-13

Dependency hygiene and a target-graph split since beta.1.

- **Dependency hygiene:** the test-only `swift-snapshot-testing` dependency now
  points at upstream by version (`from: "1.19.3"`) instead of the branch-pinned
  `ajmcclary/swift-snapshot-testing@fix-swift-6.3-attachable` fork. Upstream
  1.19.3 builds cleanly under the Apple Swift 6.4 / Xcode 27 toolchain; the fork
  was only needed on the open-source `swift-6.3-RELEASE` toolchain. Removing the
  branch pin makes the package consumable by stable-version dependents (LanguageKit
  was already pinned by version in beta.1).
- **Target split (Task 6):** lightweight runtime instrumentation was split out of
  `CodeEditorDiagnostics` into a new `CodeEditorInstrumentation` product; the LSP
  editor bridge was extracted into `CodeEditorLSPIntegration`, dropping the
  `CodeEditorView → CodeEditorLSP` edge so LSP is genuinely optional; and a
  view-free `CodeEditorHighlightingCore` value contract was introduced as the
  external highlight seam. Product count grew accordingly (see the target table
  in `CLAUDE.md`).

## [0.1.0-beta.1] - 2026-07-13

First documented prerelease.

- TextKit2-based code editor framework for macOS and iOS/iPadOS, built with
  Swift 6.3 and Swift 6 strict concurrency; 16 SwiftPM library products
  (umbrella `CodeEditorPlugin` plus opt-in modules for annotations,
  completion, diagnostics, LSP, search, and workspace file-tree UI).
- Syntax highlighting for 30 concrete languages plus plain text (including
  five diagram DSLs — Mermaid, D2, Graphviz DOT, Structurizr DSL, PlantUML —
  added for DiagramKit's editor migration); language
  identity (display names, LSP identifiers, parser names, file extensions)
  is sourced from LanguageKit's `LanguageCatalog`, with two documented,
  intentional divergences (`tsx` mapped to TypeScript, Swift's grammar
  identifier suppressed) preserved via characterization tests.
- Theming via the shared DesignKit design system (`DesignKitThemes`:
  12 theme families, each with a light and a dark variant, default
  `.lcarsDark`); SwiftUI-native integration via `CodeEditor` with
  environment-based configuration.
- Language Server Protocol client support, with local server management on
  macOS and remote WebSocket clients on all supported platforms.
