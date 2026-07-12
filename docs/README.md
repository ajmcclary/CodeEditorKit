# CodeEditorPlugin Documentation

A modern code editor framework for Apple platforms — TextKit2, Swift 6 strict concurrency, SwiftSyntax for Swift highlighting, and a modular feature-target source tree. This folder is the canonical documentation for the framework. Every page is plain Markdown and renders directly on GitHub or in any Markdown viewer.

## Start here

→ **[Getting Started](GettingStarted.md)** — install, integrate, and configure in five minutes.
→ **[Feature Matrix](FeatureMatrix.md)** — what works on the declared macOS / iOS package platforms.

## Platform Requirements

This package targets the current Apple OS family deliberately:

| Platform | Minimum |
|---|---|
| macOS | 26.3 |
| iOS / iPadOS | 26.3 |
| Swift toolchain | 6.3 |

The floor is intentional, not aspirational — the editor uses APIs introduced in this release window and exercising them on older OSes would require deprecation paths the project explicitly rejected during the most recent remediation pass. If you need broader OS coverage, pin a future LTS tag rather than building from `main`.

**Mac Catalyst is not supported** as of 0.2.0. The framework is pure SwiftUI plus native AppKit (macOS) / UIKit (iOS) — Catalyst's UIKit-on-Mac hosting layer added compilation and maintenance complexity without any feature the native paths don't already provide.

## Distribution

The package is MIT-licensed (`LICENSE` at repo root) and distributed from `https://github.com/ajmcclary/CodeEditorPlugin.git`. Release tags are not published yet, so SwiftPM consumers should use the `main` branch until tags exist.

`CodeEditorPlugin` is now a small umbrella library over extracted sibling targets. `import CodeEditorPlugin` gives host apps the normal editor entry points, while focused products are available for direct use when you only need a subsystem: `CodeEditorDesignTokens`, `CodeEditorDiagnostics`, `CodeEditorLSP`, `CodeEditorLayout`, `CodeEditorSearch`, `CodeEditorSwiftUI`, `CodeEditorUI`, `CodeEditorView`, and `CodeEditorWorkspace`.

## By topic

### Configuration

- [Configuration system](Configuration/system.md) — schema and per-section settings.
- [Presets](Configuration/presets.md) — what each built-in preset turns on.

### Features

- [Syntax highlighting](Features/syntax-highlighting.md)
- [Theme system](Features/theme-system.md)
- [Smart editing](Features/smart-editing.md)
- [Search & replace](Features/search-replace.md)
- [Annotations](Features/annotations.md) (TODO, FIXME, etc.)
- [Code folding](Features/code-folding.md)

### SwiftUI integration

- [SwiftUI integration](SwiftUI/integration.md)
- [Environment keys](SwiftUI/environment-keys.md)

### Platform integration

- [iOS](Platform/ios.md) — touch, keyboard, large-file handling
- [macOS](Platform/macos.md)
- [UIKit ↔ AppKit](Platform/uikit-appkit.md)
- [Platform abstraction](Platform/platform-abstraction.md)

### Language Server Protocol

- [LSP integration](LSP/integration.md)
- [Path resolution](LSP/path-resolution.md)
- [Retry configuration](LSP/retry-configuration.md)

### Performance

- [Monitoring](Performance/monitoring.md) — runtime instrumentation
- [Optimizations](Performance/optimizations.md) — incremental highlighting, optimized helpers, advanced techniques
- [Memory monitor](Performance/memory-monitor.md) — pressure handling and cleanup ([examples](Performance/memory-monitor-examples.swift))
- [Production reliability](Performance/reliability.md)
- [Test performance configuration](Performance/test-config.md)

### Concurrency

- [Swift 6 concurrency](Concurrency/swift6.md)
- [Sendable callbacks](Concurrency/sendable-callbacks.md)
- [Unified event system](Concurrency/unified-events.md)

### Internals

- [Architecture overview](Internals/architecture-overview.md)
- [Actor coordinator](Internals/actor-coordinator.md) — cache, file-system, metrics, and document actors; attach concrete text behavior through [Smart editing](Features/smart-editing.md).
- [Unified drawing coordinator](Internals/unified-drawing.md)
- [Optimized line index cache](Internals/line-index-cache.md)
- [Advanced patterns](Internals/advanced-patterns.md)

### Reference

- [Troubleshooting](Reference/troubleshooting.md)
- [Duration API migration](Reference/duration-api-migration.md)
- [Tree-sitter packaging](TreeSitterPackaging.md) — current compile flag, package shape, and extraction plan.

## Architecture & visuals

- **[Architecture decision records](Architecture/README.md)** — the short-form ADRs capturing structural choices (range store, tree-sitter, folding presentation, event hub).
- **[Text pipeline performance baselines](Architecture/TextPipelinePerformanceBaselines.md)** — consolidated phase audit notes for edit events, line geometry, Tree-sitter staging, and the renderer no-go.
- **[Diagrams](Diagrams/README.md)** — Mermaid diagrams of every major subsystem, indexed and grouped.

## Working notes

- `superpowers/` holds historical implementation plans and specs. Treat it as working-note archive, not as the public documentation surface or a source of current package truth.

## Contributing to these docs

- One topic per file. Use Markdown. Keep DocC syntax (`@Metadata`, `<doc:>`, `@Tutorial`) out — this folder is a plain-Markdown documentation tree.
- Add new pages under the appropriate topic folder and link them from this index.
- Significant architectural decisions belong in [Architecture/](Architecture/) as a new ADR.
- Diagram changes go through [Diagrams/](Diagrams/) using the existing Mermaid templates.

The framework's developer-facing source guidance for AI assistants lives in the repository's [CLAUDE.md](../CLAUDE.md) / [AGENTS.md](../AGENTS.md).
