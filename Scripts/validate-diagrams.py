#!/usr/bin/env python3
"""Validate current architecture diagrams against remediated ownership seams."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIAGRAMS = ROOT / "docs/Diagrams"
REQUIRED = {
    "02-core-components-class.md": (
        "EditorSession", "EditorCompletionController", "HighlightingController",
        "LSPDocumentController", "EditorEventBus",
    ),
    "04-service-architecture.md": (
        "EditorRuntimeDependencies", "MemoryManagementCoordinator", "setMemoryMonitor",
    ),
    "05-event-system-flow.md": (
        "EditorEventBus", "SequencedEditorEvent", "NotificationCenterEventAdapter",
    ),
    "07-completion-system-architecture.md": (
        "CompletionProviderRegistry", "CompletionRequestCoordinator", "CompletionLearningStore",
        "CompletionRanker",
    ),
    "12-lsp-system-architecture.md": (
        "JSONRPCSession", "LSPConnectionLifecycle", "LSPDocumentSession",
        "LSPLanguageFeatureClient",
    ),
    "19-swiftui-integration-ecosystem.md": (
        "EditorBindingSynchronizer", "EditorInteractionSynchronizer",
        "EditorRenderReconciler", "CompletionModifierRegistry", "EditorRuntimeSnapshot",
    ),
}
FORBIDDEN = ("TextProcessingActor", "TextKit2RenderingOptimizer", "CompletionSession", "CacheManager")


def main() -> int:
    failures: list[str] = []
    for name, tokens in REQUIRED.items():
        path = DIAGRAMS / name
        if not path.is_file():
            failures.append(f"missing diagram: docs/Diagrams/{name}")
            continue
        value = path.read_text()
        if value.count("```mermaid") != 1 or value.count("```") != 2:
            failures.append(f"docs/Diagrams/{name}: expected one balanced Mermaid fence")
        for token in tokens:
            if token not in value:
                failures.append(f"docs/Diagrams/{name}: missing current component {token}")
        for token in FORBIDDEN:
            if token in value:
                failures.append(f"docs/Diagrams/{name}: contains removed/stale component {token}")

    readme = (DIAGRAMS / "README.md").read_text()
    for link in re.findall(r"\]\(([^)]+\.md)\)", readme):
        if link.startswith("../"):
            continue
        if not (DIAGRAMS / link).is_file():
            failures.append(f"docs/Diagrams/README.md: broken diagram link {link}")
    for name in REQUIRED:
        if f"({name})" not in readme:
            failures.append(f"docs/Diagrams/README.md: {name} is not indexed")

    if failures:
        print("\n".join(failures))
        return 1
    print(f"diagram validation passed: {len(REQUIRED)} remediated diagrams")
    return 0


if __name__ == "__main__":
    sys.exit(main())
