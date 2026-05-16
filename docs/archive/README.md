# Archived documentation

Point-in-time material kept for history. Nothing here is current truth — when a doc is moved here it is because the live documentation in [`../`](../) has superseded it, or because it describes a design that was never implemented and is preserved only as a record of the decision space.

If you reach a page in this folder from a link in the live docs, that's expected; the link is intentional and the live doc explains the relationship. If you reach one from a search and want the current state, follow the "Replaced by" pointer below.

## Contents

### `docs/archive/`

- [`Fixing-Editor-Text-Color.md`](Fixing-Editor-Text-Color.md) — Working notes captured 2026-05-15 while investigating an unresolved invisible-glyph regression in `CodeEditorSample`. Snapshot of the diagnostic state at that point; does not describe how the editor currently behaves.
- [`11-15-REVIEW-DONE.md`](11-15-REVIEW-DONE.md) — Multi-agent code-review summary from 2026-05-15 covering Core / Text / Highlighting / Layout / Theming / LSP / Sample / Tests. The "FIXED" entries record landed changes; the broader item list is a snapshot, not an open backlog.
- [`PerformanceScaffoldingAudit.md`](PerformanceScaffoldingAudit.md) — Phase-1.2 audit (2026-05-07) classifying four performance-critical methods as `keep` / `complete` / `remove`. The action items have been applied; preserved for traceability. The live ADR index is [`../Architecture/README.md`](../Architecture/README.md).

### `docs/archive/Diagrams/`

- [`08-platform-abstraction-layer.md`](Diagrams/08-platform-abstraction-layer.md) — Pre-0.2.0 snapshot from the Mac Catalyst / legacy TextKit era. Replaced by [`../Platform/platform-abstraction.md`](../Platform/platform-abstraction.md) and [`../FeatureMatrix.md`](../FeatureMatrix.md).
- [`20-debugging-integration-architecture.md`](Diagrams/20-debugging-integration-architecture.md) — Extended design document for a debugging-integration system. The currently implemented integration is [`../Diagrams/20-debugging-integration.md`](../Diagrams/20-debugging-integration.md).
- [`27-plugin-system-architecture.md`](Diagrams/27-plugin-system-architecture.md) — Design for a plugin system that has not been implemented. No `PluginManager`, `PluginAPI`, `PluginContext`, or `MarkdownPlugin` symbols currently exist in the codebase.
- [`29-enhanced-syntax-highlighting-architecture.md`](Diagrams/29-enhanced-syntax-highlighting-architecture.md) — Planned design for an enhanced syntax-highlighting architecture. The current implementation is [`../Diagrams/29-enhanced-syntax-highlighting-architecture.md`](../Diagrams/29-enhanced-syntax-highlighting-architecture.md) (same filename intentionally — the planned variant kept the original name while the implementation was tagged with an `-updated` suffix; the suffix has now been dropped on the live file).

## What goes here

Move a file into the archive when *all* of the following are true:

- The content describes a state that is no longer current (a retired platform, a removed code path, a finished investigation, a never-shipped design).
- A reader looking at the live docs index could reasonably mistake it for current truth.
- Deleting it would lose useful history — context, decisions, or working notes worth referring back to.

When unsure, prefer editing the live doc to reflect current reality over moving it here. The archive is for content whose value is *as a snapshot*, not content that just needs updating.
