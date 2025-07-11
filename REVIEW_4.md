# REVIEW 4

### API Design & Ergonomics

1. **Redundant Builder Methods**  
   The display builder exposes both `showLineNumbers(_:)` and `isLineNumbersEnabled(_:)`which write to the same property. This duplication increases API surface without adding functionality.  
   File reference: `EditorConfigurationBuilder+Display.swift` lines 55‑81 show both methods mapping to `display.isLineNumbersEnabled`.

Suggested taskRemove redundant `showLineNumbers` builder method

Start task

2. **Unused Public Protocol**  
   `ContextMenuProvider` is declared `public` but has no references outside `ContextMenuAction.swift`, so exposing it adds maintenance burden.  
   File reference: `ContextMenuAction.swift` lines 188‑196.

Suggested taskRestrict `ContextMenuProvider` visibility

Start task

3. **Event System Singleton**  
   `UnifiedEventSystem` still provides a deprecated singleton (`shared`). Keeping a global instance risks unintended cross‑editor interactions.  
   File reference: `UnifiedEventSystem.swift` lines 8‑13 show the deprecated singleton declaration.

Suggested taskRemove deprecated `UnifiedEventSystem.shared`

Start task

4. **Memory Monitor Initialization**  
   `MemoryMonitor` starts monitoring in its initializer unless tests are running. This is convenient but couples object creation with side effects.  
   File reference: `MemoryMonitor.swift` lines 95‑104.

Suggested taskProvide explicit `startMonitoring()` API

Start task

5. **AsyncSyntaxHighlighter Metrics**  
   The highlighter exposes background statistics but lacks integration tests verifying cache optimization or visible‑range updates.  
   File reference: `AsyncSyntaxHighlighter.swift` lines 96‑110.

Suggested taskAdd tests for `AsyncSyntaxHighlighter` cache metrics

Start task

### Architecture & Scalability

6. **Platform Configuration Defaults**  
   `PlatformConfigurations` falls back to `.default` when device type is `.unknown`, but does not log or document this fallback.  
   File reference: `PlatformConfigurations.swift` lines 234‑272 show device-type selection with a silent default case.

Suggested taskLog fallback when device type is unknown

Start task

7. **Event History Buffer**  
   `CircularBuffer` inside `UnifiedEventSystem` is internal but not marked `Sendable`. This may hinder future concurrency changes.  
   File reference: `UnifiedEventSystem.swift` lines 320‑356 define the buffer without `Sendable`conformance.

Suggested taskConform `CircularBuffer` to `Sendable`

Start task

### Testing & Reliability

8. **Memory Monitor Scenarios**  
   Tests cover basic monitoring but not cleanup handler execution under memory pressure.  
   File reference: the public cleanup API around lines 132‑170 of `MemoryMonitor.swift` handles cleanup operations but lacks tests.

Suggested taskTest `MemoryMonitor` cleanup handlers

Start task

9. **Large File Performance**  
   There are performance benchmarks, yet no regression tests verifying highlight throughput for files around the `backgroundHighlightingThreshold` (10 000 characters).  
   File reference: threshold declared at line 28 in `AsyncSyntaxHighlighter.swift`.

Suggested taskAdd large-file highlighting benchmark

Start task

### Documentation & Clarity

10. **DocC Coverage for Event System**  
    DocC articles mention advanced features but the unified event system lacks a dedicated guide. Developers may miss how to subscribe or inject their own event handlers.

Suggested taskAdd DocC article for `UnifiedEventSystem`

Start task

These targeted improvements address API cleanliness, encapsulation, and test coverage while enhancing documentation and platform diagnostics. Implementing them should further elevate CodeEditorPlugin’s quality and usability.
