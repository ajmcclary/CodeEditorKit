# Tree-sitter Viability Decision

**Gate:** B
**Status:** `partial go` — keep the internal range-provider spike; defer real C grammar adoption and package extraction
**Date:** 2026-05-07

## Context

CodeEditSourceEditor uses ChimeHQ/SwiftTreeSitter (tag 0.4.x in their fork) as the primary parsing substrate. We evaluated whether to adopt Tree-sitter for CodeEditorPlugin.

## Evaluation

### SwiftTreeSitter Package Status

- **Repository:** ChimeHQ/SwiftTreeSitter (GitHub)
- **Latest tag:** 0.25.0
- **Activity:** Actively maintained with regular releases (0.6.x through 0.25.0)
- **Swift compatibility:** Recent versions target Swift 5.9+ but Swift 6.3 strict-concurrency compatibility is unconfirmed.
- **Dependencies:** Requires `tree-sitter` C library compiled per platform. Adds build complexity (C interop, per-platform library configuration).

### Platform Concerns

- **macOS:** Tree-sitter works reliably.
- **iOS:** Requires the C library to be compiled for ARM64. Possible but adds build complexity.
- **Cross-platform parity:** CodeEditorPlugin targets macOS and iOS. Tree-sitter would require per-platform build configuration.

### Parser Coverage

Tree-sitter has grammars for ~250 languages. CodeEditorPlugin currently supports 25 concrete languages plus plain text. Most have mature tree-sitter grammars (JavaScript, Python, JSON, HTML, CSS, etc.).

### Architectural Integration

CodeEditSourceEditor's `TreeSitterExecutor` pattern (priority queue with sync/async fallback) is well-designed. CodeEditorPlugin now has the intended integration surface: `RangeHighlightProviding`, `RangeBasedHighlightingController`, and an internal Tree-sitter-shaped provider.

### Risks

1. **Build complexity:** Adding a C library dependency to an SPM package creates platform-specific build headaches.
2. **Swift 6.3 compatibility:** The SwiftTreeSitter package may not compile under Swift 6.3's strict concurrency.
3. **Parser.reset() workaround:** CodeEditSourceEditor uses `Mirror` reflection to access `internalParser` for `ts_parser_reset()`. This is fragile and may not be needed if SwiftTreeSitter has since added a public `reset()` method.
4. **Maintainer bandwidth:** Adding a C dependency increases the maintenance surface.

## Decision

**Keep the internal spike; defer real C grammar adoption.**

Rationale:
1. The `RangeHighlightProviding` protocol and range-based highlighting infrastructure now exist.
2. `TreeSitterRangeHighlightProvider` remains internal scaffolding and is no longer wired to public configuration.
3. The current provider intentionally uses `RegexBackedTreeSitterParser`; it proves the range-provider architecture without adding C grammar binaries or consumer-facing Tree-sitter claims to the core package.
4. Real Tree-sitter adoption still carries the original build, binary-size, and maintenance risks.

## Required Actions (before real grammar adoption)

1. Verify SwiftTreeSitter 0.25.x compiles under Swift 6.3 with `StrictConcurrency`.
2. Test parser loading for JavaScript, Python, and JSON on macOS and iOS.
3. Measure parse time and memory for 10K-line and 100K-line files.
4. Confirm `ts_parser_reset()` is available as a public API (or the reflection workaround is still viable).
5. Verify highlight and injection queries exist for the 25 concrete supported languages.
6. Decide whether the real grammar implementation remains in this package or moves into the planned `CodeEditorTreeSitterLanguages` companion package.

## Rejected Alternatives

- **Immediate real C grammar adoption:** Premature. The architecture exists, but the binary-size and build-complexity tradeoffs still need a measured package extraction.
- **No-go (permanent):** Too early to rule out. Tree-sitter is the best available incremental parser for non-Swift languages.

## Follow-up

Use [Tree-sitter packaging](../TreeSitterPackaging.md) as the living extraction plan.
