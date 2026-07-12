#!/usr/bin/env python3
"""Reject public abstractions removed by the structural remediation."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN = (
    "ConfigurableUIComponent",
    "ReusableUIComponent",
    "UISpacing",
    "UIMargins",
    "AnnotationViewProtocol",
    "AnnotationsContentViewProtocol",
    "GutterViewProtocol",
    "CompletionCellComponentProvider",
    "CompletionCellFactory",
)
DECLARATION = re.compile(
    r"\b(?:public\s+|open\s+|package\s+|internal\s+|private\s+)?"
    r"(?:protocol|struct|enum|class|actor|typealias)\s+(" + "|".join(FORBIDDEN) + r")\b"
)


def main() -> int:
    failures: list[str] = []
    for source in sorted((ROOT / "Sources").rglob("*.swift")):
        for line_number, line in enumerate(source.read_text().splitlines(), 1):
            match = DECLARATION.search(line)
            if match:
                failures.append(
                    f"{source.relative_to(ROOT)}:{line_number}: "
                    f"forbidden declaration {match.group(1)}"
                )
    if failures:
        print("\n".join(failures))
        return 1
    print(f"public abstraction verifier passed: {len(FORBIDDEN)} symbols absent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
