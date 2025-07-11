# REVIEW 2

**Key Findings**

**1\. API Design & Ergonomics**

- The convenience properties in `CodeEditorView+Core.swift` mirror the configuration structure. While helpful, they introduce duplication and expose configuration details directly. Consider using property wrappers or computed properties referencing `configuration` to avoid divergence and reduce maintenance cost.

- `EditorConfigurationBuilder` offers extensive `.with()` methods, but custom language settings are internal. Exposing a public `LanguageSettings` type (or allowing callers to supply overrides) could make the builder more flexible for new languages or special formatting needs.

- `eventPublisher` is a public property on `CodeEditorView` and part of `CodeEditorAPI`. Unless external subscribers are required, consider exposing only `subscribe`/`unsubscribe` to keep the event system internal and allow future changes without breaking API.

**2\. Architecture & Scalability**

- Methods manipulating views (e.g., annotation updates) are not annotated with `@MainActor`. To guarantee UI access on the correct actor, mark these functions explicitly. Example in `CodeEditorView+Annotations.swift` where `addAnnotation` or `removeAnnotation` modify subviews without actor isolation.

- The cross-platform checks repeat lengthy `#if canImport(AppKit) && !targetEnvironment(macCatalyst)` conditions. Creating helper compile-time flags (e.g., `#if CODEEDITOR_APPKIT`) would improve readability and reduce duplication across the codebase.

- `eventPublisher.publish` launches a separate `Task` per handler, potentially spawning many asynchronous tasks on heavy event traffic. Consider `MainActor.run` with a single loop or other batching to avoid unbounded task creation.

**3\. Code Quality & Best Practices**

- The fallback implementation of `SwiftSyntaxHighlighter` for Mac Catalyst duplicates substantial logic. Extract shared functionality or use a lightweight parser to avoid maintaining two highlighters. The split begins at line 317 and the alternate version starts at line 337.

- Several UI-focused methods in `CodeEditorView+Layout.swift` schedule async main‑thread work if called off-main, which might recurse if the caller already dispatched. Review these calls to ensure no potential layout loops occur.

**4\. Testing & Reliability**

- The repository includes ~622 individual tests, but platform‑specific behavior (e.g., code folding UI interactions and `CrossPlatformCoordinator` features) could benefit from additional UI or integration tests. Consider tests covering:

  - Folding control visibility across platforms.

  - `PlatformCapabilities` recommended configuration on each platform.

  - SwiftUI modifier chains applying environment changes correctly.

**5\. Documentation & Clarity**

- DocC documentation is extensive; however, the advertised test counts in README and guides differ (e.g., README cites 657 tests while the DocC article references 319). Align these numbers to avoid confusion.

- `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` effectively summarize commands and architecture. Including a short section explaining why tests cannot run on non-Apple platforms (due to Combine and TextKit2 dependencies) would help future contributors using Linux-based CI.

---

### Suggested Task Stubs

Suggested taskAnnotate annotation APIs with @MainActor

Start task

Suggested taskReplace repeated #if blocks with helper macros

Start task

Suggested taskStreamline SwiftSyntaxHighlighter Catalyst fallback

Start task

Suggested taskLimit task creation in eventPublisher.publish

Start task

Suggested taskClarify test counts in documentation

Start task

**Testing**

- ❌ `swift build && swiftlint && swift test` (failed: `no such module 'Combine'`)

Codex couldn't run certain commands due to environment limitations. Consider configuring a setup script or internet access in your Codex environment to install dependencies.
