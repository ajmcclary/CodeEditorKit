#!/usr/bin/env python3
"""Validate the structural audit's findings and remediation evidence."""

from __future__ import annotations

import re
import sys
from pathlib import Path

EXPECTED = (
    "A1", "A2", "A3", "A4", "A5", "A6", "A7",
    "P1", "P2", "P3", "P4", "P5", "P6", "P7",
    "D1", "D2", "D3", "D4", "D5",
)
SECTIONS = (
    "## Executive Summary",
    "## Abstraction Analysis",
    "## Pattern Consistency Review",
    "## Duplication and Reuse Audit",
    "## Prioritized Refactoring Roadmap",
    "## Remediation Verification (2026-07-12)",
)


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    argument = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("CODE_QUALITY_AUDIT.md")
    path = argument if argument.is_absolute() else root / argument
    value = path.read_text()
    failures: list[str] = []

    for section in SECTIONS:
        if section not in value:
            failures.append(f"missing audit section: {section}")

    headings = re.findall(r"^### ([APD]\d+)\.", value, re.MULTILINE)
    if tuple(headings) != EXPECTED:
        failures.append(f"finding headings differ: expected {EXPECTED}, found {tuple(headings)}")

    rows: dict[str, str] = {}
    for line in value.splitlines():
        match = re.match(r"^\| ([APD]\d+) \|", line)
        if match:
            identifier = match.group(1)
            if identifier in rows:
                failures.append(f"duplicate remediation row: {identifier}")
            rows[identifier] = line
    if set(rows) != set(EXPECTED):
        failures.append(
            f"remediation rows differ: missing={sorted(set(EXPECTED) - set(rows))} "
            f"extra={sorted(set(rows) - set(EXPECTED))}"
        )
    for identifier, row in rows.items():
        if not row.endswith("| Resolved |"):
            failures.append(f"{identifier}: status is not Resolved")
        if f"predicate `{identifier}`" not in row:
            failures.append(f"{identifier}: verifier predicate is not cited")

    if failures:
        print("\n".join(failures))
        return 1
    print(f"code quality audit verified: {len(EXPECTED)} resolved findings")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
