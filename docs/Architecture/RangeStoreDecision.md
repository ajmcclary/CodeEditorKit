# RangeStore Backend Decision

**Gate:** A
**Status:** `go` — ArrayRunStore with backend-abstraction layer
**Date:** 2026-05-07

## Context

CodeEditSourceEditor uses `_RopeModule` from apple/swift-collections for O(log n) interval operations in `RangeStore`. We evaluated whether to use the same underscored API or a safer alternative.

## Evaluation

### Option 1: `_RopeModule` (swift-collections)

- **Package:** apple/swift-collections, latest tag 1.4.1
- **Module:** `_RopeModule` is underscored (internal) API
- **Risk:** Underscored APIs are subject to breaking changes without notice. The module may not be importable from external packages depending on access control settings at any given version.
- **Swift 6.3 compatibility:** Unknown — the symbol is not part of the public API surface and may be affected by strict concurrency changes.

### Option 2: Interval Tree (custom)

- **Complexity:** Moderate. Red-black tree or AVL tree backed by `[StoredRun]`.
- **Performance:** O(log n) for queries, O(log n + k) for edits (k = affected runs).
- **Risk:** Low. We own the implementation, no external dependency changes. More code to maintain.
- **Notes:** `OptimizedLineIndexCache` already uses a red-black tree internally, demonstrating the pattern works in this codebase.

### Option 3: ArrayRunStore (baseline)

- **Complexity:** Low. Simple sorted array of `(offset, value)` pairs with binary search.
- **Performance:** O(n) worst-case for edits (array shift), O(log n) for queries. Acceptable for documents under 100K lines. The number of runs is typically small (one per syntactic element visible in the viewport).
- **Risk:** Minimal. Trivial to implement and reason about.

## Decision

**Chosen: ArrayRunStore as initial backend.**

Rationale:
1. `_RopeModule` is underscored API — too fragile for a production library.
2. The number of runs in practice is bounded by the visible viewport (typically < 500 runs), making O(n) operations negligible.
3. The `RangeStore` public API is designed to abstract the backend, allowing a swap to interval-tree or rope later without consumer changes.
4. An interval-tree backend (like the red-black tree already in `OptimizedLineIndexCache`) can be substituted if profiling shows the array shift is a bottleneck on 100K+ line documents with many style runs.

## Required Implementation

The `RangeStore` API (defined in Phase 2.1) will be backed by a simple sorted array of `[StoredRun<Element>]` where each run has an offset and value. Edits shift subsequent offsets. See `Documentation/Architecture/RangeStore.md` for the API specification.

## Rejected Alternatives

- **Direct `_RopeModule` dependency:** Too fragile. Would break silently on swift-collections updates.
- **Full red-black tree initially:** Premature optimization. Start simple, optimize when data demands it.

## Follow-up

When Phase 3 highlighting runs consume `RangeStore` with actual style data, benchmark with a 100K-line file to determine if ArrayRunStore needs replacement. The swap point is well-defined: if `runs(in:)` takes > 1ms with > 1000 stored runs, switch to interval-tree.
