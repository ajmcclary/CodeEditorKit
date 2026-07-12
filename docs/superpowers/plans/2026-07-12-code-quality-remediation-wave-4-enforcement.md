# Architecture Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align package/import/test boundaries, remove speculative surface, repair lint/docs, normalize logging, and make all remediation claims mechanically verifiable for A6, P1, P5–P7, and D5.

**Architecture:** Exact-import verification prevents focused targets from depending on the umbrella. Tests are split by primary module. Small structural scripts validate forbidden APIs, current paths, audit evidence, and clone classification. Canonical logging constants make operational categories consistent.

**Tech Stack:** SwiftPM, Swift 6.3, Swift Testing, XCTest, SwiftLint 0.63.2, POSIX shell, Python 3 read-only verification scripts.

## Global Constraints

- Verifiers must fail with actionable file/line output.
- Generated or checked documentation derives from `swift package describe`.
- Archived documentation remains historical.
- Focused targets do not import `CodeEditorPlugin`.
- The umbrella test target is integration-only.
- No unclassified clone family may remain in completion evidence.

---

### Task 1: Enforce Exact Target Dependencies and Imports

**Files:**
- Create: `Scripts/verify-target-imports.py`
- Create: `Tests/CodeEditorSampleTests/Support/VerifierTestSupport.swift`
- Create: `Tests/CodeEditorSampleTests/TargetImportVerifierTests.swift`
- Modify: `Package.swift:307-348`
- Modify: all `Sources/CodeEditorUI/**/*.swift` files importing `CodeEditorPlugin`
- Modify: `Sources/CodeEditorPlugin/CodeEditorPlugin.swift`

**Interfaces:**
- Produces: `python3 Scripts/verify-target-imports.py` with exit 0 only when internal imports match declared dependencies and focused targets avoid the umbrella.

- [ ] **Step 1: Add failing verifier test**

```swift
import Foundation
import Testing

struct ProcessResult {
    let status: Int32
    let output: String
}

enum VerifierTestSupport {
    static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static func run(executable: String, arguments: [String]) throws -> ProcessResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return ProcessResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }
}

@Test("target import verifier accepts the package")
func targetImports() throws {
    let result = try VerifierTestSupport.run(
        executable: "/usr/bin/python3",
        arguments: [VerifierTestSupport.repositoryRoot.appending(path: "Scripts/verify-target-imports.py").path]
    )
    #expect(result.status == 0, Comment(rawValue: result.output))
}
```

- [ ] **Step 2: Implement the verifier and run RED**

The Python script parses target names/dependency string literals from `Package.swift`, reads `import CodeEditor*` lines per target, ignores Apple/external modules, and reports:

```text
Sources/CodeEditorUI/StatusBar/EditorStatusBar.swift:2: CodeEditorUI imports umbrella CodeEditorPlugin
CodeEditorUI: imported CodeEditorView but dependency is missing
CodeEditorPlugin: declared CodeEditorSmartEditing but no source imports it
```

Run: `swift test --filter TargetImportVerifierTests`

Expected: failure listing current `CodeEditorUI` umbrella imports and unused umbrella dependencies.

- [ ] **Step 3: Replace umbrella imports and trim dependencies**

Remove `CodeEditorPlugin` from `CodeEditorUI` dependencies. In each UI file, retain only exact imports required by referenced symbols. Trim `CodeEditorPlugin` target dependencies to the six re-exported modules unless the compiler proves another direct dependency is necessary.

- [ ] **Step 4: Run GREEN and target builds**

```bash
python3 Scripts/verify-target-imports.py
swift build --target CodeEditorPlugin
swift build --target CodeEditorUI
swift test --filter TargetImportVerifierTests
```

Expected: all commands pass.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/CodeEditorUI Sources/CodeEditorPlugin Scripts/verify-target-imports.py Tests/CodeEditorSampleTests/TargetImportVerifierTests.swift
git commit -m "refactor(package): enforce exact target imports"
```

### Task 2: Split the Monolithic Test Target

**Files:**
- Modify: `Package.swift:378-462`
- Create: `Scripts/classify-test-targets.py`
- Create: `Scripts/test-target-manifest.json`
- Create directories: `Tests/CodeEditorCommonTests`, `Tests/CodeEditorTextModelTests`, `Tests/CodeEditorCompletionTests`, `Tests/CodeEditorLSPTests`, `Tests/CodeEditorViewTests`, `Tests/CodeEditorSwiftUITests`
- Move: every file assigned by `Scripts/test-target-manifest.json` from `Tests/CodeEditorPluginTests`

**Interfaces:**
- Produces: focused unit-test targets and integration-only `CodeEditorPluginTests`.

- [ ] **Step 1: Generate and review an exact per-file migration manifest**

`Scripts/classify-test-targets.py` must enumerate every Swift file currently under
`Tests/CodeEditorPluginTests`, record its imports, and assign exactly one destination
target in `Scripts/test-target-manifest.json`. Use these deterministic rules in order:

1. `UmbrellaReExportTests.swift` and any test that exercises two or more product-level
   entry points remain in `CodeEditorPluginTests`.
2. Files whose only `CodeEditor*` import is `CodeEditorCommon`, `CodeEditorTextModel`,
   `CodeEditorCompletion`, or `CodeEditorLSP` move to the matching focused target.
3. Files under `Completion/` move to `CodeEditorCompletionTests` unless they construct
   `CodeEditorView` or a SwiftUI `CodeEditor`; those move to `CodeEditorViewTests` or
   `CodeEditorSwiftUITests`, respectively.
4. Files under `LSP/` move to `CodeEditorLSPTests` unless they attach LSP state to an
   editor surface; those move to `CodeEditorViewTests`.
5. Tests that instantiate `CodeEditor`, a representable, a coordinator, an environment
   key, or a SwiftUI modifier move to `CodeEditorSwiftUITests`.
6. Tests that instantiate `CodeEditorView`, TextKit bridges, layout, folding, annotations,
   or editor feature controllers move to `CodeEditorViewTests`.
7. Shared helpers are copied into a target-local `Support/` directory only for the
   targets that import them; no test target may reach into another target's directory.

The script exits nonzero if a file is unclassified, assigned twice, missing from the
manifest, or if the manifest contains a stale path. The checked JSON is the exact move
list and makes later reviews reproducible.

Run:

```bash
python3 Scripts/classify-test-targets.py --generate
python3 Scripts/classify-test-targets.py --check
```

Expected: the manifest's `source_count` equals the live Swift-file count and every file
is classified once, with no unmatched or stale entries. (The current baseline is 181;
Waves 1-3 add tests before this task runs.)

- [ ] **Step 2: Add target declarations before moving tests and verify RED**

Add six `.testTarget` entries with only their module and test-library dependencies. Run `swift test`; expect empty-target or missing-path/package errors until files move.

- [ ] **Step 3: Apply the Common and TextModel manifest entries**

Run `python3 Scripts/classify-test-targets.py --apply CodeEditorCommonTests CodeEditorTextModelTests`.
For every moved file, remove umbrella/View/SwiftUI imports that the compiler reports as
unused, and add only dependencies actually imported by that focused target. Run:

```bash
swift test --filter CodeEditorCommonTests
swift test --filter CodeEditorTextModelTests
```

Expected: both targets pass independently.

- [ ] **Step 4: Apply the Completion and LSP manifest entries**

Run `python3 Scripts/classify-test-targets.py --apply CodeEditorCompletionTests CodeEditorLSPTests`.
Provider/ranking/cache/request tests must compile in `CodeEditorCompletionTests`;
transport/wire/client/manager tests must compile in `CodeEditorLSPTests`. Cross-editor
integration entries remain assigned to the umbrella target by the checked manifest.

Run:

```bash
swift test --filter CodeEditorCompletionTests
swift test --filter CodeEditorLSPTests
```

Expected: both targets pass independently.

- [ ] **Step 5: Apply the View and SwiftUI manifest entries**

Run `python3 Scripts/classify-test-targets.py --apply CodeEditorViewTests CodeEditorSwiftUITests`.
Use exact `@testable` imports and target-local copies of shared support identified by the
manifest.

Run:

```bash
swift test --filter CodeEditorViewTests
swift test --filter CodeEditorSwiftUITests
```

Expected: both targets pass independently.

- [ ] **Step 6: Prove umbrella target is integration-only**

Run:

```bash
rg -L "import CodeEditorPlugin" Tests/CodeEditorPluginTests -g '*.swift'
python3 - <<'PY'
from pathlib import Path
files=list(Path('Tests/CodeEditorPluginTests').rglob('*.swift'))
assert len(files) < 40, f'integration target still has {len(files)} files'
print(f'integration_test_files={len(files)}')
PY
python3 Scripts/classify-test-targets.py --check
swift test --parallel
```

Expected: every remaining test imports the public umbrella, the target has fewer than 40 integration files, and the full suite passes.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Scripts/classify-test-targets.py Scripts/test-target-manifest.json Tests
git commit -m "test: align test targets with package modules"
```

### Task 3: Repair Lint Paths and Product Documentation

**Files:**
- Create: `Scripts/verify-project-metadata.py`
- Create: `Tests/CodeEditorSampleTests/ProjectMetadataVerifierTests.swift`
- Modify: `.swiftlint.yml:293-303`
- Modify: `AGENTS.md:31-46,111`
- Modify: `CLAUDE.md` corresponding sections

**Interfaces:**
- Produces: current SwiftUI lint path and metadata verifier comparing documented products/paths with the package/source tree.

- [ ] **Step 1: Add failing metadata test**

Invoke `Scripts/verify-project-metadata.py` from a Swift test. The script runs `swift package describe --type json`, extracts product names, parses the AGENTS product table, and checks every live `Sources/...` path named in AGENTS/CLAUDE exists.

- [ ] **Step 2: Run RED**

Run: `swift test --filter ProjectMetadataVerifierTests`

Expected: failure showing the documented four-product list differs from the eleven package products and the lint include path is stale.

- [ ] **Step 3: Fix lint rule and docs**

Set:

```yaml
forbidden_swiftui_extension_codeeditor:
  included: 'Sources/CodeEditorSwiftUI/.*\.swift'
  excluded: 'Sources/CodeEditorSwiftUI/CodeEditor\+FactoryExtensions\.swift'
```

Update product tables from current `Package.swift`; replace live pre-extraction paths with current target paths.

- [ ] **Step 4: Add a lint fixture check**

The metadata script creates a temporary Swift file under `Sources/CodeEditorSwiftUI/` containing `extension CodeEditor {}`, runs `swiftlint lint --config .swiftlint.yml --path <file>`, verifies the custom rule appears, and removes the file in `finally`.

- [ ] **Step 5: Run GREEN and commit**

```bash
python3 Scripts/verify-project-metadata.py
swift test --filter ProjectMetadataVerifierTests
swiftlint
git add .swiftlint.yml AGENTS.md CLAUDE.md Scripts/verify-project-metadata.py Tests/CodeEditorSampleTests/ProjectMetadataVerifierTests.swift
git commit -m "chore: align lint and docs with package graph"
```

### Task 4: Remove Zero-Consumer Public Abstractions

**Files:**
- Modify: `Sources/CodeEditorLayout/BaseUIComponents.swift`
- Modify: `Sources/CodeEditorAnnotations/AnnotationView.swift`
- Modify: `Sources/CodeEditorAnnotations/AnnotationsContentView.swift`
- Modify: `Sources/CodeEditorView/Layout/GutterView.swift`
- Modify: `Sources/CodeEditorLayout/CompletionCellComponents.swift`
- Create: `Scripts/verify-public-abstractions.py`
- Create: `Tests/CodeEditorSampleTests/PublicAbstractionVerifierTests.swift`

**Interfaces:**
- Removes: `ConfigurableUIComponent`, `ReusableUIComponent`, `UISpacing`, `UIMargins`, `AnnotationViewProtocol`, `AnnotationsContentViewProtocol`, `GutterViewProtocol`, `CompletionCellComponentProvider`, unused `CompletionCellFactory`.

- [ ] **Step 1: Add failing symbol verifier**

The script scans live sources for the exact forbidden declarations above and fails with file/line matches. Invoke it from `PublicAbstractionVerifierTests`.

- [ ] **Step 2: Run RED**

Run: `swift test --filter PublicAbstractionVerifierTests`

Expected: failure listing every current declaration.

- [ ] **Step 3: Remove abstractions and use design tokens**

Remove protocol conformances and declarations. Replace any newly discovered spacing references with `CGFloat(Tokens.Spacing.*)`. Instantiate completion cells directly through their platform-native initializers.

- [ ] **Step 4: Run GREEN and API builds**

```bash
python3 Scripts/verify-public-abstractions.py
swift test --filter PublicAbstractionVerifierTests
swift build --target CodeEditorAnnotations
swift build --target CodeEditorLayout
swift build --target CodeEditorView
```

Expected: all commands pass.

- [ ] **Step 5: Commit**

```bash
git add Sources Scripts/verify-public-abstractions.py Tests/CodeEditorSampleTests/PublicAbstractionVerifierTests.swift
git commit -m "refactor(api): remove unused public abstractions"
```

### Task 5: Normalize Logging Identity

**Files:**
- Create: `Sources/CodeEditorCommon/Utilities/CodeEditorLog.swift`
- Create: `Scripts/verify-logger-usage.py`
- Create: `Tests/CodeEditorSampleTests/LoggerUsageVerifierTests.swift`
- Modify: production files calling `CrossPlatformLogger.logger()` without subsystem/category

**Interfaces:**
- Produces: canonical subsystems/categories and zero uncategorized production calls.

- [ ] **Step 1: Add failing logger verifier**

The script parses non-comment Swift lines under `Sources`, excludes the `CrossPlatformLogger` implementation, and fails on `CrossPlatformLogger.logger()` or a subsystem literal not in the allowed set:

```python
ALLOWED = {
    "com.codeeditor.plugin",
    "com.codeeditor.lsp",
    "com.codeeditor.search",
    "com.codeeditor.sample",
}
```

- [ ] **Step 2: Run RED**

Run: `swift test --filter LoggerUsageVerifierTests`

Expected: failure listing current uncategorized calls and noncanonical subsystem strings.

- [ ] **Step 3: Add canonical logger construction**

```swift
public enum CodeEditorLog {
    public static let subsystem = "com.codeeditor.plugin"

    public static func logger(category: String) -> CrossPlatformLogger.Logger {
        CrossPlatformLogger.logger(subsystem: subsystem, category: category)
    }
}
```

Use one static logger per long-lived type/feature. Replace interaction-path emoji messages with category-prefixed plain messages and route high-volume selection logs through `CodeEditorRenderingDiagnostics` gating.

- [ ] **Step 4: Run GREEN and commit**

```bash
python3 Scripts/verify-logger-usage.py
swift test --filter LoggerUsageVerifierTests
swiftlint
git add Sources Scripts/verify-logger-usage.py Tests/CodeEditorSampleTests/LoggerUsageVerifierTests.swift
git commit -m "refactor(logging): canonicalize logger identity"
```

### Task 6: Automate Clone Classification and Remediation Evidence

**Files:**
- Create: `Scripts/audit-swift-clones.py`
- Create: `Scripts/clone-classifications.json`
- Create: `Scripts/verify-architecture-remediation.py`
- Create: `Scripts/verify-code-quality-audit.py`
- Create: `Scripts/validate-diagrams.py`
- Create: `Tests/CodeEditorSampleTests/ArchitectureRemediationVerifierTests.swift`
- Modify: `CODE_QUALITY_AUDIT.md`
- Modify: relevant files in `docs/Diagrams/`

**Interfaces:**
- Produces: reproducible normalized clone report, explicit retained-clone classification, 19-finding structural verifier, and final evidence appendix.

- [ ] **Step 1: Add failing architecture verifier test**

Invoke `verify-architecture-remediation.py`. It must check each finding identifier through a named predicate and print a JSON summary. Before the evidence appendix and diagram updates, expect failures for unresolved evidence.

- [ ] **Step 2: Implement clone audit exactly as documented**

The script:

- reads `Sources/**/*.swift` excluding `CodeEditorSample`;
- removes blank/comment/import/preprocessor/availability/actor-only lines;
- normalizes whitespace;
- finds maximal exact clones of eight or more significant lines;
- emits JSON with paths, physical ranges, significant-line length, and target pair.

`clone-classifications.json` keys each retained clone family by stable normalized hash and allows only `semantic-schema` or `platform-contract`, with a written rationale. Unknown hashes fail verification.

- [ ] **Step 3: Update diagrams and audit evidence**

Update diagrams that name `CodeEditorView`, completion, LSP, SwiftUI coordinator, events, and runtime ownership. Append the 19-row remediation evidence table to the audit with implementation paths, test names, verifier predicates, and `Resolved` status.

- [ ] **Step 4: Run all structural verifiers**

```bash
python3 Scripts/audit-swift-clones.py --source Sources --exclude-target CodeEditorSample --window 8
python3 Scripts/verify-architecture-remediation.py
python3 Scripts/verify-code-quality-audit.py CODE_QUALITY_AUDIT.md
python3 Scripts/verify-target-imports.py
python3 Scripts/verify-project-metadata.py
python3 Scripts/verify-public-abstractions.py
python3 Scripts/verify-logger-usage.py
python3 Scripts/validate-diagrams.py
swift test --filter ArchitectureRemediationVerifierTests
```

Expected: every command passes; no unknown clone hash or unresolved finding remains.

- [ ] **Step 5: Run final full gate**

```bash
swift build
swift build --target CodeEditorSample
swiftlint --fix
swiftlint
swift test --parallel
git diff --check
```

Expected: every command exits 0, all tests pass, and `git diff --check` is silent.

- [ ] **Step 6: Commit Wave 4**

```bash
git add CODE_QUALITY_AUDIT.md Package.swift Sources Tests Scripts docs/Diagrams docs/README.md AGENTS.md CLAUDE.md .swiftlint.yml
git commit -m "refactor: complete structural code quality remediation"
```
