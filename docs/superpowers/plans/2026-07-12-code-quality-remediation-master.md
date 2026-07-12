# Code Quality Remediation Master Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fully remediate all 19 findings in `CODE_QUALITY_AUDIT.md` and prove the resulting architecture with behavior, structural, build, lint, and test evidence.

**Architecture:** Execute four independently buildable waves. Wave 1 fixes state loss and removes dishonest API; Wave 2 moves runtime ownership into focused components; Wave 3 consolidates duplicate algorithms and UI state; Wave 4 aligns package, test, lint, documentation, and logging boundaries. Stable editor-facing façades remain while placeholder or zero-consumer APIs may be removed.

**Tech Stack:** Swift 6.3, Swift Package Manager, Swift Testing, XCTest, TextKit 2, AppKit, UIKit, SwiftUI, Point-Free Dependencies, SwiftLint 0.63.2.

## Global Constraints

- Support native macOS 26.3+ and iOS/iPadOS 26.3+ only.
- Use `#if canImport(AppKit)` / `#if canImport(UIKit)`; never add `#if os(...)`.
- Never use force unwraps or production `print()`.
- Preserve stable public editor-facing APIs; remove placeholder and zero-consumer APIs instead of preserving simulated behavior.
- Keep TextKit 2 access through `TextKitBridge`; do not read `CodeEditorView.textStorage` or `layoutManager` directly.
- Preserve exclusive delegate ownership by `TextViewDelegateMultiplexer`.
- Write and run a failing test before each production behavior change.
- Run `swiftlint --fix` before `swiftlint`.
- Update relevant Mermaid diagrams when ownership or type names change.

---

## Wave Plans

1. [Wave 1: Runtime Correctness and API Truth](2026-07-12-code-quality-remediation-wave-1-runtime.md)
2. [Wave 2: Ownership Boundaries and Events](2026-07-12-code-quality-remediation-wave-2-ownership.md)
3. [Wave 3: Reuse Kernels and Platform State](2026-07-12-code-quality-remediation-wave-3-reuse.md)
4. [Wave 4: Architecture Enforcement](2026-07-12-code-quality-remediation-wave-4-enforcement.md)

Execute them in order. Each wave ends with a green build/lint/test checkpoint and a commit. Do not begin the next wave with failing scoped verification.

## Finding Coverage Matrix

| Finding | Primary plan/task | Required evidence |
|---|---|---|
| A1 | Wave 2 Tasks 1–3 | `EditorSession` owns feature lifecycle; view teardown delegates once. |
| A2 | Wave 2 Tasks 4–7 | Four SwiftUI collaborators have focused tests. |
| A3 | Wave 2 Tasks 8–13 | Completion/LSP façades delegate to focused components. |
| A4 | Wave 1 Tasks 1–4 | Runtime/monitor updates preserve injected and live state. |
| A5 | Wave 1 Tasks 5–7 | Placeholder processors/optimizers/fixed metrics are absent. |
| A6 | Wave 4 Task 4 | Zero-consumer protocols/factories/scales are absent. |
| A7 | Wave 1 Task 3 | No production process-level test detection controls lifecycle. |
| P1 | Wave 4 Task 1 | Imports equal declared target dependencies; UI avoids umbrella. |
| P2 | Wave 1 Task 2 | Runtime-only SwiftUI update changes live editor state. |
| P3 | Wave 2 Tasks 14–16 | One ordered event bus feeds all compatibility adapters. |
| P4 | Wave 3 Tasks 5–7 | Responsibility files and shared platform helpers replace near-clones. |
| P5 | Wave 4 Task 2 | Focused test targets own module tests. |
| P6 | Wave 4 Task 3 | Current lint paths and generated/verified product docs. |
| P7 | Wave 4 Task 5 | No uncategorized production logger calls. |
| D1 | Wave 3 Task 1 | One linked-list LRU node implementation. |
| D2 | Wave 3 Task 2 | One keyed debounce state machine. |
| D3 | Wave 3 Tasks 3–4 | Shared LSP union codec and JS/TS map. |
| D4 | Wave 3 Tasks 5–7 | Shared completion state, toolbar catalog, and scroll helper. |
| D5 | Wave 4 Task 6 | Clone report classifies retained semantic/platform repetition. |

## Master Completion Audit

- [ ] **Step 1: Create the remediation evidence appendix**

Append a table to `CODE_QUALITY_AUDIT.md` with columns `Finding`, `Implementation`, `Tests`, `Structural proof`, and `Status`. Populate every A1–A7, P1–P7, and D1–D5 row with current paths and commands.

- [ ] **Step 2: Run structural verifiers**

Run:

```bash
python3 Scripts/verify-target-imports.py
python3 Scripts/verify-architecture-remediation.py
python3 Scripts/validate-diagrams.py
```

Expected: all commands exit 0 and explicitly report all 19 finding identifiers.

- [ ] **Step 3: Reproduce the clone audit**

Run:

```bash
python3 Scripts/audit-swift-clones.py --source Sources --exclude-target CodeEditorSample --window 8
```

Expected: no clone family classified as algorithmic/policy duplication remains; retained families are listed as semantic schema or platform contract repetition.

- [ ] **Step 4: Run full verification**

Run:

```bash
swift build
swift build --target CodeEditorSample
swiftlint --fix
swiftlint
swift test --parallel
```

Expected: every command exits 0 with no warnings treated as errors and all tests passing.

- [ ] **Step 5: Verify the audit appendix and working tree**

Run:

```bash
python3 Scripts/verify-code-quality-audit.py CODE_QUALITY_AUDIT.md
git diff --check
git status --short
```

Expected: 19 resolved rows, all referenced paths/lines resolve, no placeholder status remains, `git diff --check` is silent, and the working tree contains only intentional remediation files.

- [ ] **Step 6: Commit completion evidence**

```bash
git add CODE_QUALITY_AUDIT.md docs/Diagrams docs/README.md AGENTS.md Scripts Package.swift Sources Tests
git commit -m "docs: record completed code quality remediation"
```

Expected: commit succeeds after all previous gates pass.
