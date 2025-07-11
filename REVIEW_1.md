# REVIEW 1

## Code Review

### API Design & Ergonomics

1. **Expose memory monitor injection on `CodeEditorView`**

   - _File_: `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`
   - _Lines_: [187‑191] show `memoryMonitor` as an internal property with update hooks.
   - **Issue**: Users working directly with `CodeEditorView` cannot inject a custom `MemoryMonitor`. The SwiftUI view exposes a `.memoryMonitor` modifier, but the AppKit/UIKit API does not.
   - **Recommendation**: Make `memoryMonitor` a public property or provide a dedicated setter so platform clients can supply a monitor directly.
   - **Example:**
     ```swift
     public var memoryMonitor: MemoryMonitor = MemoryMonitor() {
         didSet { updateMemoryMonitorReferences() }
     }
     ```
   - **Category**: Suggestion
     - Suggested task: Allow direct memory monitor injection in CodeEditorView
     - Start task

2. **Clarify builder method return types**

   - _File_: `Sources/CodeEditorPlugin/Configuration/EditorConfigurationBuilder.swift`
   - _Lines_: [131‑135]
   - **Issue**: The `with(_:)` helper returns `Self` by value, creating a copy. Some method chains may inadvertently work on outdated copies if a developer stores intermediate results.
   - **Recommendation**: Document this explicitly or refactor the builder to mutate `self` (`inout`) with `@discardableResult` to reduce confusion.
   - **Category**: Suggestion
     - Suggested task: Document builder-copy semantics
     - Start task

3. **Improve environment customization ergonomics**

   - _File_: `Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment.swift`
   - _Lines_: [29‑65] define `CodeEditorEnvironment` with `with` methods.
   - **Issue**: Callers must pass `.unchanged` for properties they don’t modify, which is verbose.
   - **Recommendation**: Overload `codeEditorEnvironment` modifier to accept optional parameters directly, e.g.:
     ```swift
     public func codeEditorEnvironment(
         language: Language? = nil,
         theme: CodeEditorSwiftUITheme? = nil,
         configuration: EditorConfiguration? = nil,
         becomeFirstResponder: Bool? = nil,
         memoryMonitor: MemoryMonitor? = nil,
         eventSystem: UnifiedEventSystem? = nil
     ) -> some View
     ```
     This avoids the `BecomeFirstResponderOption` when not needed.
   - **Category**: Suggestion
     - Suggested task: Simplify SwiftUI environment modifier
     - Start task

4. **Limit access to LSP components on non‑macOS platforms**
   - _Files_: `Sources/CodeEditorPlugin/LSP/*`
   - **Issue**: LSP functionality only works on macOS (see lines [15‑23] in `LSPClient.swift`), but the module builds these files for all platforms. iOS or Catalyst projects compile unused code.
   - **Recommendation**: Wrap the entire LSP target in `#if canImport(AppKit) && !targetEnvironment(macCatalyst)` to avoid compiling un‑usable code and reduce binary size.
   - **Category**: Suggestion
     - Suggested task: Conditional compilation for LSP subsystem
     - Start task

### Architecture & Scalability

5. **Actor reentrancy during cache cleanup**
   - _File_: `Sources/CodeEditorPlugin/TextProcessing/AsyncTextProcessor.swift`
   - _Lines_: [159‑205] show `cleanup()` awaiting all active tasks while holding actor isolation.
   - **Issue**: Awaiting tasks inside the actor can lead to reentrancy and long actor blocking if tasks never finish.
   - **Recommendation**: Capture tasks, exit the actor, and await them outside to avoid blocking.
   - **Example:**
     ```swift
     func cleanup() async {
         let tasks = activeTasks.values
         activeTasks.removeAll()
         processingQueue.clear()
         await withTaskGroup(of: Void.self) { group in
             for task in tasks { group.addTask { _ = try? await task.value } }
         }
         resultCache = nil
     }
     ```
   - **Category**: Critical
     - Suggested task: Avoid actor reentrancy in AsyncTextProcessor.cleanup
     - Start task

### Code Quality & Best Practices

6. **Reduce duplicated color mapping logic**

   - _File_: `Sources/CodeEditorPlugin/Annotations/AnnotationView.swift`
   - _Lines_: [202‑235] contain a switch computing annotation colors; similar logic exists earlier for icon names.
   - **Recommendation**: Extract common mapping into a single enum (e.g., `AnnotationKind`) with associated color and icon.
   - **Category**: Suggestion
     - Suggested task: Centralize annotation kind metadata
     - Start task

7. **Document builder preset coverage**
   - _File_: `Sources/CodeEditorPlugin/Configuration/EditorConfigurationBuilder+Convenience.swift`
   - _Lines_: [88‑128] define quick configurations such as `.swift()` and `.web()`.
   - **Issue**: These methods return a fully built configuration without clarifying which preset they derive from. Users may not realize they override existing presets.
   - **Recommendation**: Document the underlying preset (e.g., `.minimal`) and mention that `.build()` is called internally.
   - **Category**: Suggestion
     - Suggested task: Clarify preset origins in convenience builders
     - Start task

### Testing & Reliability

8. **Expand performance regression tests**
   - _Observation_: While `SyntaxHighlightingPerformanceTests.swift` covers highlighting speed, there are no explicit tests for the new `MemoryMonitor` integration.
   - **Recommendation**: Add performance tests verifying that cache cleanup triggered by `MemoryMonitor` keeps memory under a target threshold when editing large files.
   - **Category**: Suggestion
     - Suggested task: Add memory-pressure performance tests
     - Start task

### Documentation & Clarity

9. **Clarify AI assistant guidance**
   - _Files_: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`
   - **Issue**: The guides mention 533 tests in some places and 604 in others (e.g., `CLAUDE.md` lines [56‑59]). Consistent numbers help automation.
   - **Recommendation**: Reconcile the test count across these documents to avoid confusion for future assistants.
   - **Category**: Suggestion
     - Suggested task: Sync test count across AI assistant guides
     - Start task

---

These adjustments aim to further polish the already solid architecture and make the API even more approachable for developers on all platforms. They also improve actor safety and clarify documentation for both users and automated tools.
