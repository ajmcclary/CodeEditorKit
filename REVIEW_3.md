# Review 3

## Summary

- **Documentation** still demonstrates `#if os(macOS)` rather than the preferred `#if canImport(AppKit)` example, which may confuse developers about the cross‑platform guidance

- **AsyncSyntaxHighlighter.swift** is very large (~738 lines), containing caching, background tasks and performance monitoring logic in one file

- **SmartCompletionEngine.swift** directly imports `Combine` without availability checks, causing build failures on non‑Apple platforms (e.g. Linux)

## Proposed Issues & Tasks

### 1\. Clarify platform detection in documentation

The documentation snippet uses `#if os(macOS)` even though the project standard is `#if canImport(AppKit)`.

Suggested task: Update platform detection examples in documentation

### 2\. Split large syntax highlighting implementation

`AsyncSyntaxHighlighter.swift` mixes token caching, highlighting logic, and performance monitoring in a single 738‑line file.

Suggested task: Refactor AsyncSyntaxHighlighter into smaller components

### 3\. Guard Combine imports for non‑Apple builds

Building on Linux fails because several files unconditionally import `Combine`.

Suggested task: Add conditional Combine imports

These changes will improve clarity, maintainability, and cross‑platform robustness.
