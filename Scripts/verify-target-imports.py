#!/usr/bin/env python3
"""Verify internal module imports match SwiftPM target dependencies."""

from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IMPORT = re.compile(r"^\s*(?:@_exported\s+)?import\s+(CodeEditor\w+)", re.MULTILINE)


def main() -> int:
    process = subprocess.run(
        [
            "swift",
            "package",
            "--scratch-path",
            str(Path(tempfile.gettempdir()) / "codeeditor-target-import-verifier"),
            "describe",
            "--type",
            "json",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if process.returncode:
        print(process.stdout + process.stderr, end="")
        return process.returncode
    description = json.loads(process.stdout)
    failures: list[str] = []

    for target in description["targets"]:
        name = target["name"]
        path = ROOT / target["path"]
        if not name.startswith("CodeEditor") or not path.is_dir() or target["path"].startswith("Tests/"):
            continue
        dependencies = {value for value in target.get("target_dependencies", []) if value.startswith("CodeEditor")}
        imports: set[str] = set()
        for source in path.rglob("*.swift"):
            modules = set(IMPORT.findall(source.read_text()))
            imports.update(modules)
            if name not in {"CodeEditorPlugin", "CodeEditorSample"} and "CodeEditorPlugin" in modules:
                line = next(
                    index for index, value in enumerate(source.read_text().splitlines(), 1)
                    if "import CodeEditorPlugin" in value
                )
                failures.append(f"{source.relative_to(ROOT)}:{line}: {name} imports umbrella CodeEditorPlugin")
        for module in sorted(imports - dependencies - {name}):
            failures.append(f"{name}: imported {module} but dependency is missing")
        if name in {"CodeEditorPlugin", "CodeEditorUI"}:
            for module in sorted(dependencies - imports):
                failures.append(f"{name}: declared {module} but no source imports it")

    if failures:
        print("\n".join(failures))
        return 1
    print("target imports verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
