# Changelog

All notable changes to CodeEditorPlugin are documented in this file.

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
