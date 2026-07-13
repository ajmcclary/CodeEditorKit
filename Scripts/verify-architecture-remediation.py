#!/usr/bin/env python3
"""Verify structural evidence for every CODE_QUALITY_AUDIT finding."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]


def text(path: str) -> str:
    return (ROOT / path).read_text()


def exists(*paths: str) -> bool:
    return all((ROOT / path).exists() for path in paths)


def absent(needle: str, *paths: str) -> bool:
    return all(needle not in text(path) for path in paths)


def clone_classifications_complete() -> bool:
    module_path = ROOT / "Scripts/audit-swift-clones.py"
    spec = importlib.util.spec_from_file_location("clone_audit", module_path)
    if spec is None or spec.loader is None:
        return False
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    report = module.clone_report(ROOT, ROOT / "Sources", set(), 8)
    expected = {entry["hash"] for entry in report["clones"]}
    classifications = json.loads(
        (ROOT / "Scripts/clone-classifications.json").read_text()
    )["families"]
    allowed = {"semantic-schema", "platform-contract"}
    return (
        set(classifications) == expected
        and all(value.get("classification") in allowed for value in classifications.values())
        and all(len(value.get("rationale", "")) >= 40 for value in classifications.values())
    )


def main() -> int:
    source_files = list((ROOT / "Sources").rglob("*.swift"))
    source_text = "\n".join(path.read_text() for path in source_files)
    predicates = {
        "A1": exists("Sources/CodeEditorView/EditorSession.swift", "Sources/CodeEditorView/EditorFeatureController.swift"),
        "A2": exists(
            "Sources/CodeEditorSwiftUI/EditorBindingSynchronizer.swift",
            "Sources/CodeEditorSwiftUI/EditorInteractionSynchronizer.swift",
            "Sources/CodeEditorSwiftUI/EditorRenderReconciler.swift",
            "Sources/CodeEditorSwiftUI/CompletionModifierRegistry.swift",
        ),
        "A3": exists(
            "Sources/CodeEditorCompletion/CompletionProviderRegistry.swift",
            "Sources/CodeEditorCompletion/CompletionRequestCoordinator.swift",
            "Sources/CodeEditorCompletion/CompletionResponseCache.swift",
            "Sources/CodeEditorLSP/JSONRPCSession.swift",
            "Sources/CodeEditorLSP/LSPDocumentSession.swift",
            "Sources/CodeEditorLSP/LSPLanguageFeatureClient.swift",
        ),
        "A4": "featureDependencies = EditorFeatureRuntimeDependencies()" in text("Sources/CodeEditorView/EditorRuntime.swift") and "replace(featureDependencies:" in text("Sources/CodeEditorView/EditorRuntime.swift"),
        "A5": all(name not in source_text for name in ("TextProcessingActor", "TextKit2RenderingOptimizer", "simulateOptimization")),
        "A6": all(name not in source_text for name in ("ConfigurableUIComponent", "ReusableUIComponent", "AnnotationViewProtocol", "GutterViewProtocol", "CompletionCellFactory")),
        "A7": "isRunningTests" not in source_text and "XCTestConfigurationFilePath" not in source_text,
        "P1": "CodeEditorPlugin\"" not in text("Package.swift").split('name: "CodeEditorUI"', 1)[1].split("swiftSettings:", 1)[0] and not list((ROOT / "Sources/CodeEditorUI").rglob("*.swift")) == [],
        "P2": exists("Sources/CodeEditorSwiftUI/EditorRenderReconciler.swift") and "runtimeSnapshot" in text("Sources/CodeEditorSwiftUI/EditorRenderReconciler.swift"),
        "P3": exists("Sources/CodeEditorView/EditorEventBus.swift", "Sources/CodeEditorView/NotificationCenterEventAdapter.swift") and "eventBus.publish(event)" in text("Sources/CodeEditorView/UnifiedEventSystem.swift"),
        "P4": exists(
            "Sources/CodeEditorLayout/CompletionCellThemeState.swift",
            "Sources/CodeEditorView/Platform/ToolbarCatalog.swift",
            "Sources/CodeEditorView/CodeEditorView+SelectionScrolling.swift",
        ),
        "P5": all((ROOT / f"Tests/{name}").is_dir() for name in ("CodeEditorCommonTests", "CodeEditorTextModelTests", "CodeEditorCompletionTests", "CodeEditorLSPTests", "CodeEditorViewTests", "CodeEditorSwiftUITests")) and len(list((ROOT / "Tests/CodeEditorPluginTests").rglob("*.swift"))) < 40,
        "P6": "Sources/CodeEditorSwiftUI/.*\\.swift" in text(".swiftlint.yml") and exists("Scripts/verify-project-metadata.py"),
        "P7": exists("Sources/CodeEditorCommon/Utilities/CodeEditorLog.swift", "Scripts/verify-logger-usage.py") and "CrossPlatformLogger.logger()" not in source_text,
        "D1": sum(value.count("private final class Node") for value in (text("Sources/CodeEditorCommon/LinkedLRU.swift"), text("Sources/CodeEditorInstrumentation/LRUCache.swift"))) == 1,
        "D2": exists("Sources/CodeEditorCommon/Utilities/KeyedDebouncer.swift") and "debounceResults" not in source_text and "debounceErrors" not in source_text,
        "D3": exists("Sources/CodeEditorLSP/StringOrInteger.swift") and "typescript = javascript.merging" in text("Sources/CodeEditorSyntaxHighlighting/RegexQuery/QueryCaptureMap.swift"),
        "D4": exists("Sources/CodeEditorLayout/CompletionCellThemeState.swift", "Sources/CodeEditorView/Platform/ToolbarCatalog.swift") and "preservingScrollPosition" in text("Sources/CodeEditorView/CodeEditorView+SelectionScrolling.swift"),
        "D5": clone_classifications_complete(),
    }
    print(json.dumps({"findings": predicates, "resolved": sum(predicates.values()), "total": len(predicates)}, indent=2))
    return 0 if len(predicates) == 19 and all(predicates.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
