#!/bin/bash

# Generate package dependency diagrams from SwiftPM's built-in package
# description. This intentionally avoids third-party package plugins so the
# script works in a fresh checkout.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIAGRAM_DIR="$ROOT_DIR/docs/Diagrams"
PACKAGE_JSON="$(mktemp)"

cleanup() {
    rm -f "$PACKAGE_JSON"
}
trap cleanup EXIT

cd "$ROOT_DIR"
mkdir -p "$DIAGRAM_DIR"

swift package describe --type json > "$PACKAGE_JSON"

/usr/bin/python3 - "$PACKAGE_JSON" "$DIAGRAM_DIR" <<'PY'
import json
import pathlib
import sys

package_path = pathlib.Path(sys.argv[1])
diagram_dir = pathlib.Path(sys.argv[2])
data = json.loads(package_path.read_text())

targets = {target["name"]: target for target in data.get("targets", [])}
products = data.get("products", [])


def dependency_name(dependency):
    if isinstance(dependency, str):
        return dependency
    if isinstance(dependency, dict):
        return (
            dependency.get("name")
            or dependency.get("target")
            or dependency.get("product")
            or dependency.get("byName")
        )
    return None


def node_id(name):
    return "".join(character if character.isalnum() else "_" for character in name)


def write_diagram(path, title, product_filter):
    lines = [
        f"# {title}",
        "",
        "Generated from `swift package describe --type json`.",
        "",
        "```mermaid",
        "graph TD",
    ]

    included_targets = set()
    for product in products:
        product_name = product["name"]
        product_targets = product.get("targets", [])
        if not product_filter(product_name, product_targets):
            continue
        product_node = f"product_{node_id(product_name)}"
        lines.append(f'    {product_node}["{product_name}"]')
        for target_name in product_targets:
            included_targets.add(target_name)
            lines.append(f'    {product_node} --> target_{node_id(target_name)}["{target_name}"]')

    queue = list(included_targets)
    while queue:
        target_name = queue.pop(0)
        target = targets.get(target_name)
        if target is None:
            continue
        for dependency in target.get("dependencies", []):
            dep_name = dependency_name(dependency)
            if dep_name is None:
                continue
            dep_node = node_id(dep_name)
            lines.append(f'    target_{node_id(target_name)} --> target_{dep_node}["{dep_name}"]')
            if dep_name in targets and dep_name not in included_targets:
                included_targets.add(dep_name)
                queue.append(dep_name)

    lines.extend(["```", ""])
    path.write_text("\n".join(lines))


write_diagram(
    diagram_dir / "25-package-dependencies.md",
    "Package Dependencies - CodeEditorPlugin",
    lambda product_name, _: product_name != "CodeEditorSample",
)
write_diagram(
    diagram_dir / "26-sample-dependencies.md",
    "Package Dependencies - CodeEditorSample",
    lambda product_name, targets: product_name == "CodeEditorSample" or "CodeEditorSample" in targets,
)
PY

echo "Dependency diagrams generated in $DIAGRAM_DIR"
