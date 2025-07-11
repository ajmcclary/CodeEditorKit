# REVIEW 2

# Code Review Summary

## API Design & Ergonomics

### 1\. Public Gutter View Exposure

`CodeEditorView` exposes the gutter view directly:

    public var gutterView: GutterView? {
        gutterViewStorage
    }


    **Issue**
    Exposing GutterView leaks internal implementation details and couples clients to the underlying view hierarchy.

    **Recommendation**
    Make gutterView internal and provide higher‑level APIs (e.g. configuration options) to customize gutter behavior.

    Suggested taskHide `gutterView` from public API

    Start task

    ### 2. Default Event System Fallback

    EditorConfiguration injects an optional eventSystem but falls back to the deprecated UnifiedEventSystem.shared:


    public var eventSystem: UnifiedEventSystem?


    **Issue**
    Using a singleton as an implicit default hides dependencies and complicates testing.

    **Recommendation**
    Require explicit event system injection. If a default is needed, expose a factory method (e.g. EditorConfiguration.withDefaultEventSystem()).

    Suggested taskRemove implicit `UnifiedEventSystem.shared` fallback

    Start task

    ### 3. Builder Pattern Enhancements

    EditorConfigurationBuilder creates new builders via with { } but does not support mutation after build(). Rebuilding large configurations may incur unnecessary copying.

    **Suggestion**
    Add mutating builder functions to allow incremental updates before calling build(). This is optional but improves ergonomics.

    ### 4. SwiftUI Focus API

    The SwiftUI modifier for focusing uses a boolean environment key (codeEditorBecomeFirstResponder):


    public func becomeFirstResponder() -> some View {
        environment(\.codeEditorBecomeFirstResponder, true)
    }


    **Suggestion**
    Adopt FocusState directly in the public API for better integration with other SwiftUI components (e.g. expose .focused(_:) wrapper).

    ## Architecture & Scalability

    ### 5. Async Highlighting Cancellation

    AsyncSyntaxHighlighter uses withUnsafeContinuation inside a task cancellation handler:


    await withTaskCancellationHandler {
        await withUnsafeContinuation { continuation in
            ...
        }
    } onCancel: { ... }


    **Issue**
    withUnsafeContinuation risks resuming multiple times or leaking if a cancellation occurs before continuation.resume.

    **Recommendation**
    Use withCheckedContinuation or withCheckedThrowingContinuation to enforce single resume and handle cancellation explicitly.

    Suggested taskReplace unsafe continuations in `AsyncSyntaxHighlighter`

    Start task

    ### 6. Hot Reload History Size

    ConfigurationHotReload stores configuration history with a maxHistorySize:


    private let maxHistorySize: Int = PlatformConstants.maxConfigurationHistorySize


    **Issue**
    PlatformConstants.maxConfigurationHistorySize is not documented in this file, making maintainability harder.

    **Recommendation**
    Document the constant or provide a default value directly in ConfigurationHotReload so it is self‑contained.

    ## Code Quality & Best Practices

    ### 7. Debug Logging in Release Builds

    CodeEditorView logs setup details inside setupTextView guarded only by #if DEBUG:


    #if DEBUG
    Self.logger.debug("Setting up CodeEditorView with TextKit\(self.textLayoutManager != nil ? "2" : "1")")
    #endif


    **Suggestion**
    Ensure all diagnostic logging is wrapped in #if DEBUG or uses a logging level that can be disabled in release to avoid overhead.

    ### 8. Use of Deprecated API

    Several properties are kept for backward compatibility (e.g. showsLineNumbers):


    @available(*, deprecated, renamed: "isLineNumbersEnabled")
    public var showsLineNumbers: Bool { ... }


    **Recommendation**
    Plan a removal path for deprecated APIs in a future major release and document it in migration notes.

    ## Testing & Reliability

    ### 9. Under‑tested Scenarios

    Tests cover configuration and basic functionality extensively. Areas that appear under-tested:

      * Background syntax highlighting cancellation and recovery in AsyncSyntaxHighlighter.

      * Platform-specific behaviors in PlatformCapabilities (e.g. trackpad or pencil support).

      * Memory monitor cleanup paths.

    **Recommendation**
    Add integration tests to simulate large-file highlighting with cancellation, verify PlatformCapabilities feature checks on different simulated environments, and ensure MemoryMonitor triggers cleanup handlers.

    Suggested taskAdd integration tests for async highlighting and platform capabilities

    Start task

    ## Documentation & Clarity

    ### 10. Clarify Hot Reload Usage

    ConfigurationHotReload provides powerful features but lacks usage examples in DocC or README.

    **Recommendation**
    Add a short section in Documentation.docc or README.md illustrating how to enable hot reloading and register observers.

    ### 11. AI Assistant Files

    AGENTS.md, CLAUDE.md, and GEMINI.md are helpful but could reference where to find DocC articles for advanced topics.

    **Suggestion**
    Add a bullet in these guides directing the assistant to Documentation.docc/Articles for more details.

    * * *

    These refinements will tighten the public API, improve concurrency safety, and enhance documentation and test coverage, moving CodeEditorPlugin closer to an exceptional component.
