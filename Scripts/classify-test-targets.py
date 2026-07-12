#!/usr/bin/env python3
"""Generate, validate, and apply the checked test-target move manifest."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Tests/CodeEditorPluginTests"
MANIFEST = ROOT / "Scripts/test-target-manifest.json"
IMPORT = re.compile(r"(?:@testable\s+)?import\s+(CodeEditor\w+)")
TARGET_PATHS = {
    "CodeEditorCommonTests": ROOT / "Tests/CodeEditorCommonTests",
    "CodeEditorTextModelTests": ROOT / "Tests/CodeEditorTextModelTests",
    "CodeEditorCompletionTests": ROOT / "Tests/CodeEditorCompletionTests",
    "CodeEditorLSPTests": ROOT / "Tests/CodeEditorLSPTests",
    "CodeEditorViewTests": ROOT / "Tests/CodeEditorViewTests",
    "CodeEditorSwiftUITests": ROOT / "Tests/CodeEditorSwiftUITests",
}


def classify(path: Path, imports: set[str], text: str) -> str:
    name = path.name
    relative = path.relative_to(SOURCE)
    if name == "UmbrellaReExportTests.swift" or "Snapshot" in name or imports == {"CodeEditorPlugin"}:
        return "CodeEditorPluginTests"
    if str(relative) in {"Text/RangeStoreTests.swift", "TextRangeUtilitiesRegressionTests.swift"}:
        return "CodeEditorTextModelTests"
    if relative.parts[0] == "Completion":
        if "CodeEditorView(" in text:
            return "CodeEditorViewTests"
        if "CodeEditor(" in text or "Modifier" in name or "Lifecycle" in name:
            return "CodeEditorSwiftUITests"
        return "CodeEditorCompletionTests"
    if relative.parts[0] == "LSP":
        return "CodeEditorViewTests" if "CodeEditorView(" in text else "CodeEditorLSPTests"
    if relative.parts[0] == "SwiftUI":
        return "CodeEditorSwiftUITests"
    swiftui_markers = ("CodeEditor(", "EditorController", "Coordinator", "Environment", "Modifier")
    if "CodeEditorSwiftUI" in imports and any(marker in text for marker in swiftui_markers):
        return "CodeEditorSwiftUITests"
    if "CodeEditorCompletion" in imports and "CodeEditorView(" not in text:
        return "CodeEditorCompletionTests"
    if "CodeEditorLSP" in imports and "CodeEditorView(" not in text:
        return "CodeEditorLSPTests"
    if imports and imports <= {"CodeEditorCommon", "CodeEditorDiagnostics"}:
        return "CodeEditorCommonTests"
    if "CodeEditorTextModel" in imports and imports <= {
        "CodeEditorCommon", "CodeEditorLanguages", "CodeEditorTextModel"
    }:
        return "CodeEditorTextModelTests"
    return "CodeEditorViewTests"


def live_entries() -> list[dict[str, object]]:
    entries = []
    for path in sorted(SOURCE.rglob("*.swift")):
        text = path.read_text()
        imports = set(IMPORT.findall(text))
        entries.append({
            "source": str(path.relative_to(ROOT)),
            "target": classify(path, imports, text),
            "imports": sorted(imports),
        })
    return entries


def generate() -> int:
    entries = live_entries()
    MANIFEST.write_text(json.dumps({"source_count": len(entries), "entries": entries}, indent=2) + "\n")
    print(f"classified {len(entries)} test files")
    return 0


def check() -> int:
    data = json.loads(MANIFEST.read_text())
    entries = data["entries"]
    sources = [entry["source"] for entry in entries]
    failures = []
    if len(sources) != len(set(sources)):
        failures.append("manifest assigns at least one source more than once")
    if data["source_count"] != len(entries):
        failures.append("source_count does not match manifest entries")
    for entry in entries:
        source = ROOT / entry["source"]
        destination = TARGET_PATHS.get(entry["target"])
        if not source.exists() and destination is not None:
            candidate = destination / source.relative_to(SOURCE)
            if not candidate.exists():
                failures.append(f"stale source: {entry['source']}")
        if entry["target"] != "CodeEditorPluginTests" and destination is None:
            failures.append(f"unknown target: {entry['target']}")
    for name, path in TARGET_PATHS.items():
        for source in path.rglob("*.swift"):
            if "CodeEditorPlugin" in set(IMPORT.findall(source.read_text())):
                failures.append(
                    f"focused target imports umbrella: {source.relative_to(ROOT)} ({name})"
                )
    integration_files = sorted(SOURCE.rglob("*.swift"))
    if len(integration_files) >= 40:
        failures.append(
            f"integration target contains {len(integration_files)} Swift files; expected fewer than 40"
        )
    for source in integration_files:
        if "CodeEditorPlugin" not in set(IMPORT.findall(source.read_text())):
            failures.append(f"integration test omits umbrella import: {source.relative_to(ROOT)}")
    if failures:
        print("\n".join(failures))
        return 1
    print(f"test target manifest verified: {len(entries)} files")
    return 0


def apply(targets: set[str]) -> int:
    data = json.loads(MANIFEST.read_text())
    moved = 0
    for entry in data["entries"]:
        target = entry["target"]
        if target not in targets:
            continue
        source = ROOT / entry["source"]
        if not source.exists():
            continue
        destination = TARGET_PATHS[target] / source.relative_to(SOURCE)
        destination.parent.mkdir(parents=True, exist_ok=True)
        text = source.read_text()
        if len(entry["imports"]) > 1:
            text = re.sub(r"^@testable import CodeEditorPlugin\n", "", text, flags=re.MULTILINE)
            text = re.sub(r"^import CodeEditorPlugin\n", "", text, flags=re.MULTILINE)
        if target in {
            "CodeEditorCommonTests",
            "CodeEditorTextModelTests",
            "CodeEditorCompletionTests",
            "CodeEditorLSPTests",
        }:
            text = re.sub(r"^@testable import CodeEditorSwiftUI\n", "", text, flags=re.MULTILINE)
            text = re.sub(r"^import CodeEditorSwiftUI\n", "", text, flags=re.MULTILINE)
            text = re.sub(r"^@testable import CodeEditorView\n", "", text, flags=re.MULTILINE)
            text = re.sub(r"^import CodeEditorView\n", "", text, flags=re.MULTILINE)
        destination.write_text(text)
        source.unlink()
        moved += 1
    print(f"moved {moved} files")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--generate", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--apply", nargs="*")
    args = parser.parse_args()
    if args.generate:
        return generate()
    if args.check:
        return check()
    if args.apply is not None:
        return apply(set(args.apply))
    parser.error("choose --generate, --check, or --apply")


if __name__ == "__main__":
    sys.exit(main())
