#!/usr/bin/env python3
"""Verify production logger calls use explicit canonical identities."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ALLOWED = {
    "com.codeeditor.plugin",
    "com.codeeditor.lsp",
    "com.codeeditor.search",
    "com.codeeditor.sample",
}
CALL = re.compile(r"CrossPlatformLogger\s*\.\s*logger\s*\((.*?)\)", re.DOTALL)
SUBSYSTEM = re.compile(r"\bsubsystem\s*:\s*\"([^\"]+)\"")


def without_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", lambda match: "\n" * match.group(0).count("\n"), text, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", text)


def main() -> int:
    failures: list[str] = []
    for source in sorted((ROOT / "Sources").rglob("*.swift")):
        if source.name in {"CrossPlatformLogger.swift", "CodeEditorLog.swift"}:
            continue
        text = without_comments(source.read_text())
        for match in CALL.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            arguments = match.group(1).strip()
            if not arguments:
                failures.append(
                    f"{source.relative_to(ROOT)}:{line}: uncategorized CrossPlatformLogger.logger()"
                )
                continue
            subsystem = SUBSYSTEM.search(arguments)
            if subsystem and subsystem.group(1) not in ALLOWED:
                failures.append(
                    f"{source.relative_to(ROOT)}:{line}: noncanonical logger subsystem "
                    f"{subsystem.group(1)!r}"
                )
    if failures:
        print("\n".join(failures))
        return 1
    print("logger usage verified: all production calls are categorized and canonical")
    return 0


if __name__ == "__main__":
    sys.exit(main())
