# Changelog

All notable changes to CodeEditorPlugin are documented in this file.

## [Unreleased]

### Changed

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
