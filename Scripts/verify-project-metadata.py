#!/usr/bin/env python3
"""Verify package documentation and architecture lint metadata."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = (ROOT / "AGENTS.md", ROOT / "CLAUDE.md")
PRODUCT_ROW = re.compile(r"^\| `([^`]+)` \| (library|executable) \|")
SOURCE_ROOT = re.compile(r"^- `(?P<path>Sources/[^`]+/)`")
TEST_TARGETS = re.compile(r"across (\d+) test targets \(([^)]+)\)")
LINT_RULE = "forbidden_swiftui_extension_codeeditor"


def package_description() -> dict[str, object]:
    result = subprocess.run(
        [
            "swift", "package",
            "--scratch-path", str(Path(tempfile.gettempdir()) / "codeeditor-metadata-verifier"),
            "describe", "--type", "json",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return json.loads(result.stdout)


def documented_products(text: str) -> dict[str, str]:
    products: dict[str, str] = {}
    for line in text.splitlines():
        match = PRODUCT_ROW.match(line)
        if match:
            products[match.group(1)] = match.group(2)
    return products


def product_type(value: dict[str, object]) -> str:
    return "executable" if "executable" in value else "library"


def verify_lint_fixture(failures: list[str]) -> None:
    executable = shutil.which("swiftlint")
    if executable is None:
        failures.append("swiftlint is not installed; cannot verify the SwiftUI architecture rule")
        return
    fixture = ROOT / "Sources/CodeEditorSwiftUI/__ArchitectureLintFixture.swift"
    fixture.write_text("extension CodeEditor {}\n")
    try:
        result = subprocess.run(
            [executable, "lint", "--config", ".swiftlint.yml", str(fixture.relative_to(ROOT))],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
    finally:
        fixture.unlink(missing_ok=True)
    output = result.stdout + result.stderr
    if LINT_RULE not in output:
        failures.append(
            "SwiftUI lint fixture did not trigger forbidden_swiftui_extension_codeeditor: "
            + output.strip()
        )


def main() -> int:
    try:
        package = package_description()
    except RuntimeError as error:
        print(error, end="")
        return 1

    expected_products = {
        product["name"]: product_type(product["type"])
        for product in package["products"]
    }
    expected_tests = {
        target["name"] for target in package["targets"]
        if target["name"].endswith("Tests")
    }
    failures: list[str] = []

    for document in DOCS:
        text = document.read_text()
        actual_products = documented_products(text)
        if actual_products != expected_products:
            failures.append(
                f"{document.name}: documented products differ from Package.swift "
                f"(expected {sorted(expected_products)}, found {sorted(actual_products)})"
            )
        target_match = TEST_TARGETS.search(text)
        if target_match is None:
            failures.append(f"{document.name}: test-target inventory is missing")
        else:
            documented_count = int(target_match.group(1))
            documented_targets = {
                value.strip().strip("`") for value in target_match.group(2).split(",")
            }
            if documented_count != len(expected_tests) or documented_targets != expected_tests:
                failures.append(
                    f"{document.name}: documented test targets differ from Package.swift "
                    f"(expected {sorted(expected_tests)}, found {sorted(documented_targets)})"
                )
        for line_number, line in enumerate(text.splitlines(), 1):
            match = SOURCE_ROOT.match(line)
            if match and not (ROOT / match.group("path")).is_dir():
                failures.append(
                    f"{document.name}:{line_number}: missing documented source root "
                    f"{match.group('path')}"
                )

    lint = (ROOT / ".swiftlint.yml").read_text()
    expected_include = "included: 'Sources/CodeEditorSwiftUI/.*\\.swift'"
    expected_exclude = (
        "excluded: 'Sources/CodeEditorSwiftUI/"
        "CodeEditor\\+FactoryExtensions\\.swift'"
    )
    if expected_include not in lint:
        failures.append(".swiftlint.yml: SwiftUI architecture rule has a stale included path")
    if expected_exclude not in lint:
        failures.append(".swiftlint.yml: SwiftUI architecture rule has a stale excluded path")

    verify_lint_fixture(failures)
    if failures:
        print("\n".join(failures))
        return 1
    print(
        f"project metadata verified: {len(expected_products)} products, "
        f"{len(expected_tests)} test targets"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
