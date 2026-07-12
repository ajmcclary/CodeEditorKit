#!/usr/bin/env python3
"""Report maximal exact Swift clone pairs after conservative normalization."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class SignificantLine:
    text: str
    physical_line: int


def normalize_line(line: str, in_block_comment: bool) -> tuple[str | None, bool]:
    stripped = line.strip()
    if in_block_comment:
        if "*/" in stripped:
            stripped = stripped.split("*/", 1)[1].strip()
            in_block_comment = False
        else:
            return None, True
    if stripped.startswith("/*"):
        if "*/" in stripped[2:]:
            stripped = stripped.split("*/", 1)[1].strip()
        else:
            return None, True
    if not stripped or stripped.startswith(("//", "*", "import ", "@available", "@MainActor", "#")):
        return None, in_block_comment
    stripped = re.sub(r"\s+//.*$", "", stripped).strip()
    if not stripped:
        return None, in_block_comment
    return re.sub(r"\s+", " ", stripped), in_block_comment


def significant_lines(path: Path) -> list[SignificantLine]:
    result: list[SignificantLine] = []
    in_block_comment = False
    for number, line in enumerate(path.read_text().splitlines(), 1):
        normalized, in_block_comment = normalize_line(line, in_block_comment)
        if normalized is not None:
            result.append(SignificantLine(normalized, number))
    return result


def target_name(path: str) -> str:
    parts = Path(path).parts
    return parts[1] if len(parts) > 1 and parts[0] == "Sources" else "unknown"


def clone_report(root: Path, source: Path, excluded_targets: set[str], window: int) -> dict[str, object]:
    files: dict[str, list[SignificantLine]] = {}
    for path in sorted(source.rglob("*.swift")):
        relative = str(path.relative_to(root))
        if target_name(relative) in excluded_targets:
            continue
        files[relative] = significant_lines(path)

    windows: dict[tuple[str, ...], list[tuple[str, int]]] = defaultdict(list)
    for path, lines in files.items():
        for index in range(0, len(lines) - window + 1):
            windows[tuple(value.text for value in lines[index:index + window])].append((path, index))

    maximal: dict[tuple[str, int, int, str, int, int], dict[str, object]] = {}
    for occurrences in windows.values():
        if len(occurrences) < 2:
            continue
        for left_index in range(len(occurrences)):
            occurrence_left_path, occurrence_left_start = occurrences[left_index]
            for occurrence_right_path, occurrence_right_start in occurrences[left_index + 1:]:
                left_path, left_start = occurrence_left_path, occurrence_left_start
                right_path, right_start = occurrence_right_path, occurrence_right_start
                if left_path == right_path and abs(left_start - right_start) < window:
                    continue
                left_lines = files[left_path]
                right_lines = files[right_path]
                start_left, start_right = left_start, right_start
                while (
                    start_left > 0 and start_right > 0
                    and left_lines[start_left - 1].text == right_lines[start_right - 1].text
                ):
                    start_left -= 1
                    start_right -= 1
                end_left = left_start + window
                end_right = right_start + window
                while (
                    end_left < len(left_lines) and end_right < len(right_lines)
                    and left_lines[end_left].text == right_lines[end_right].text
                ):
                    end_left += 1
                    end_right += 1
                if left_path == right_path and not (end_left <= start_right or end_right <= start_left):
                    continue
                left_key = (left_path, start_left, end_left)
                right_key = (right_path, start_right, end_right)
                if right_key < left_key:
                    left_key, right_key = right_key, left_key
                    left_path, right_path = right_path, left_path
                    start_left, start_right = start_right, start_left
                    end_left, end_right = end_right, end_left
                    left_lines, right_lines = right_lines, left_lines
                key = left_key + right_key
                normalized = "\n".join(value.text for value in left_lines[start_left:end_left])
                digest = hashlib.sha256(normalized.encode()).hexdigest()[:16]
                maximal[key] = {
                    "hash": digest,
                    "significant_lines": end_left - start_left,
                    "left": {
                        "path": left_path,
                        "start": left_lines[start_left].physical_line,
                        "end": left_lines[end_left - 1].physical_line,
                    },
                    "right": {
                        "path": right_path,
                        "start": right_lines[start_right].physical_line,
                        "end": right_lines[end_right - 1].physical_line,
                    },
                    "target_pair": sorted({target_name(left_path), target_name(right_path)}),
                }

    clones = sorted(
        maximal.values(),
        key=lambda value: (
            -value["significant_lines"], value["hash"],
            value["left"]["path"], value["left"]["start"],
            value["right"]["path"], value["right"]["start"],
        ),
    )
    return {
        "source": str(source.relative_to(root)),
        "window": window,
        "excluded_targets": sorted(excluded_targets),
        "files": len(files),
        "significant_lines": sum(len(lines) for lines in files.values()),
        "clone_pairs": len(clones),
        "clone_families": len({clone["hash"] for clone in clones}),
        "clones": clones,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default="Sources")
    parser.add_argument("--exclude-target", action="append", default=[])
    parser.add_argument("--window", type=int, default=8)
    parser.add_argument("--output")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    report = clone_report(root, root / args.source, set(args.exclude_target), args.window)
    rendered = json.dumps(report, indent=2) + "\n"
    if args.output:
        (root / args.output).write_text(rendered)
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
