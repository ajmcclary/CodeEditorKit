# Tree-sitter Viability Decision

**Gate:** B
**Status:** `defer` — evaluate after Phase 3 highlighting overlay is complete
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

Tree-sitter has grammars for ~250 languages. CodeEditorPlugin currently supports 20 languages. Most have mature tree-sitter grammars (JavaScript, Python, JSON, HTML, CSS, etc.).

### Architectural Integration

CodeEditSourceEditor's `TreeSitterExecutor` pattern (priority queue with sync/async fallback) is well-designed. Porting it would follow the same patterns as Phase 3's `RangeHighlightProviding` protocol.

### Risks

1. **Build complexity:** Adding a C library dependency to an SPM package creates platform-specific build headaches.
2. **Swift 6.3 compatibility:** The SwiftTreeSitter package may not compile under Swift 6.3's strict concurrency.
3. **Parser.reset() workaround:** CodeEditSourceEditor uses `Mirror` reflection to access `internalParser` for `ts_parser_reset()`. This is fragile and may not be needed if SwiftTreeSitter has since added a public `reset()` method.
4. **Maintainer bandwidth:** Adding a C dependency increases the maintenance surface.

## Decision

**Defer until after Phase 3 (Highlighting Provider Overlay).**

Rationale:
1. The `RangeHighlightProviding` protocol designed in Phase 3 is the integration surface for any parser, including Tree-sitter.
2. Once the protocol and range-based highlighting infrastructure exist, a Tree-sitter provider can be built behind a feature flag and evaluated against actual performance data.
3. Current SwiftSyntax-based highlighting is correct and performant for Swift. Non-Swift languages use regex/lightweight tokenizers that work for basic use cases.
4. The build complexity for Tree-sitter is not justified until the highlighting infrastructure is ready to receive it.

## Required Actions (when Gate B re-evaluated)

1. Verify SwiftTreeSitter 0.25.x compiles under Swift 6.3 with `StrictConcurrency`.
2. Test parser loading for JavaScript, Python, and JSON on macOS and iOS.
3. Measure parse time and memory for 10K-line and 100K-line files.
4. Confirm `ts_parser_reset()` is available as a public API (or the reflection workaround is still viable).
5. Verify highlight and injection queries exist for the 20 supported languages.

## Rejected Alternatives

- **Immediate adoption:** Premature. The highlighting infrastructure to receive Tree-sitter doesn't exist yet.
- **No-go (permanent):** Too early to rule out. Tree-sitter is the best available incremental parser for non-Swift languages.

## Follow-up

Re-evaluate this gate at the end of Phase 3. The evaluation should include a working spike with at least JavaScript highlighting behind a feature flag.
