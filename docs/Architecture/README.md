# Architecture Decision Records

Short ADRs capturing structural decisions made for CodeEditorPlugin. Each one records the gate, the call (`go` / `defer` / `no-go`), and the reasoning so future contributors can re-evaluate the trade-offs.

| Gate | Decision | Status | Date |
|---|---|---|---|
| A | [RangeStore backend](RangeStoreDecision.md) — use `ArrayRunStore` with a backend-abstraction layer instead of `_RopeModule` | go | 2026-05-07 |
| B | [Tree-sitter viability](TreeSitterDecision.md) — defer adoption until after the Phase 3 highlighting overlay is complete | defer | 2026-05-07 |
| C | [Folding presentation strategy](FoldingPresentationDecision.md) — keep `attributeHidden` for now; overlay placeholders as the preferred future direction | go | 2026-05-07 |
| D | [Text edit event hub](TextEditEventHubDecision.md) — `CodeEditorView` owns a single `TextEditEventHub`; one canonical `TextEditEvent` struct for all consumers | go | 2026-05-07 |
| — | [Performance scaffolding audit](PerformanceScaffoldingAudit.md) — phase-1.2 audit of performance-critical methods | reference | 2026-05-07 |

## When to add a new ADR

Add an entry whenever you make a decision that is hard or expensive to reverse — choosing between libraries, picking a data structure for a hot path, locking in an event-distribution shape, etc. Keep the file short: context, options considered, the call, and consequences. Skip implementation detail; that belongs in the code.

## See also

- [Architecture overview](../Internals/architecture-overview.md) — the feature-based source tree the ADRs operate within.
- [Diagrams](../Diagrams/README.md) — visual references for the systems the ADRs touch.
