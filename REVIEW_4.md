# Documentation.docc Review 4


**Key documentation issues**

  1. **Outdated SwiftUI modifiers in GettingStarted**

    * The quick example uses `showsLineNumbers(true)` and `enablesSyntaxHighlighting(true)`, but the actual modifiers are `lineNumbers(true)` and `enableSyntaxHighlighting(true)`.

    * Source lines: `GettingStarted.md` lines 52–58 show these incorrect calls

  2. **Placeholder tutorial code snippets**

    * Files such as `editor-01-import.swift`, `config-02-settings.swift`, and others contain only comments like “// Placeholder…”.

    * Example: `Resources/Code/config-02-settings.swift` contains a single placeholder line

  3. **Missing documentation for several implemented features**

    * No DocC pages mention key components like `SmartEditingEngine`, `SearchReplaceEngine`, `ActorCoordinator`, or debugger features.

    * Searches for these terms in `Documentation.docc` return zero results (e.g. SmartEditingEngine search count: 0)

**Recommended additions**

  * Create dedicated articles for **SmartEditingEngine** and **SearchReplaceEngine** describing their APIs and usage.

  * Provide documentation or an article for the **ActorCoordinator** concurrency helper.

  * Document the **DebuggerIntegration** functionality (currently only noted as removed in the architecture overview).

**Recommended updates**

  * Fix the modifiers in `GettingStarted.md` to use `.lineNumbers(true)` and `.enableSyntaxHighlighting(true)`.

  * Replace placeholder code files under `Documentation.docc/Resources/Code/` with real example snippets referenced by the tutorials.

  * Ensure Quick Start and other pages reference the correct APIs and provide complete examples.

**Recommended removals**

  * None identified; existing articles generally match the codebase, though some future-oriented sections (e.g. WebAssembly LSP) might be marked as planned features.
