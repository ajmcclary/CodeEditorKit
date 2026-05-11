# LineGeometryStore — Phase 0 Baseline

**Date**: 2026-05-10  
**Source**: `Tests/CodeEditorPluginTests/LineGeometryStoreBenchmarkTests.swift`  
**Tests**: 31 tests, 0 failures  
**Reference**: `NSString.getLineStart(_:end:contentsEnd:for:)` — UTF-16 correct ground truth

## Reference Implementation

The test file contains two oracle helpers that the `LineGeometryStore` must match exactly:

- `referenceLineOffsets(for:)` — line-start offsets using `NSString.getLineStart` with `contentsEnd` detection to distinguish trailing-empty-line from no-trailing-newline
- `referenceLineCount(for:)` — delegates to `referenceLineOffsets(for:).count`

These use `contentsEnd < lineEnd` to determine whether a line ends with a terminator (producing a conceptual empty trailing line), avoiding the ambiguity of `lineRange(for:)` at document-end.

## Performance Baseline (NSString, arm64 macOS)

| Operation | Scale | Time |
|---|---|---|
| Build offsets | 10k lines (avg 30 chars/line) | 2.5 ms |
| Build offsets | 100k lines (avg 4 chars/line) | 16.4 ms |
| Line count | 1M lines ("x\n") | 163 ms |
| Offset→line lookup | 100 queries across 10k lines | 28 µs total |

## Correctness Coverage

### ASCII
- Single line, multi-line (LF), empty text
- Offset→line round-trip (every offset maps to a line containing it)
- Line→offset round-trip (line starts match expected positions)
- Line-number-at-offset for known positions

### Emoji & Composed Characters
- Single-scalar emoji: 😀 = 2 UTF-16 code units, 1 Swift Character
- ZWJ sequence: 👨‍👩‍👧‍👦 = 11 UTF-16 code units, 1 Swift Character
- Composed é: precomposed (U+00E9, 1 unit) vs decomposed (e + U+0301, 2 units)
- Emoji in multi-line text with round-trip verification
- **Character-vs-UTF16 divergence proof**: for `"a😀b\nc👨‍👩‍👧‍👦d"`, Swift Character iteration produces `[0, 4]` while NSString UTF-16 produces `[0, 5]` — confirming the ANALYSIS.md §5.1.1 bug

### Line Endings
- LF (`\n`)
- CRLF (`\r\n`)
- CR (`\r`)
- Mixed (all three in one document)
- Trailing newline present → produces trailing empty line
- Trailing newline absent → no trailing empty line
- Multiple consecutive blank lines

### NSRange Round-Trips
- Every offset in a Swift file round-trips to its containing line
- Line-start offsets are consistent across document walk
- Known-offset verification (100 lines of `"line\n"`)

### Edge Cases
- Single newline only (`"\n"`)
- Only newlines (`"\n\n\n"`)
- Very long line (100,000 chars + newline)
- Very many short lines (50,000 lines of `"x\n"`)
- Empty text

### Fuzz Testing
- 200-iteration random edit correctness: after each edit, full rebuild validates all offsets are strictly increasing, first offset is 0, every offset maps to a valid line
- 100-iteration random edit line count: offsets form valid line ranges for all positions

## Key Requirement for Phase 1

The `LineGeometryStore` must be UTF-16–based from day one. Use `NSString.getLineStart(_:end:contentsEnd:for:)` for initial build, not `for char in text` iteration. The existing `LineIndexCache.buildCache(for:)` at line 139 uses character iteration and produces incorrect offsets for documents containing emoji, composed characters, or surrogate pairs.
