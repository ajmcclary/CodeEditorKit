# Documentation.docc Review 2

**Documentation Gaps & Inaccuracies**

  1. **Outdated project statistics.**  
`CLAUDE.md` and `README.md` state “333 source files” and “53 Test Files,” but the repository currently contains 401 Swift files and 66 test files.  


  2. **Unused properties referenced.**  
`Performance-Monitoring.md` describes a `showPerformanceOverlay` property and performance overlay customization that does not exist in the codebase.  


  3. **Profiling APIs missing in the code.**  
Sections on `TimeProfiler` and `MemoryProfiler` in `Performance-Monitoring.md` reference types not present in the repository.  


  4. **Deprecated property names still documented.**  
Several docs continue to use `.maxHighlightingLength` rather than the current `.maxSyntaxHighlightingLength`.  


  5. **Features lacking documentation.**  
The codebase includes significant components without any documentation:

    * `SearchReplaceEngine.swift`

    * `SmartEditingEngine.swift`

    * `DebuggerIntegration.swift` and related debug adapters

    * `OptimizedLineIndexCache.swift`

    * `UnifiedDrawingCoordinator.swift`

  6. **Outdated counts in GettingStarted guide.**  
The “Getting Started” article mentions 53 test files.  


**Recommended Updates**

Suggested task: Update project statistics
Suggested task: Remove undocumented performance overlay sections
Suggested task: Replace deprecated property names in docs
Suggested task: Document SearchReplaceEngine and SmartEditingEngine
Suggested task: Add documentation for debugger integration
Suggested task: Document OptimizedLineIndexCache and UnifiedDrawingCoordinator
Suggested task: Update Getting Started test count

These updates will synchronize the documentation with the current codebase and remove references to nonexistent features.
