# REVIEW 1

# Code Review

## 1\. API Design & Ergonomics

### 1.1. Configuration Builder Duplication

`EditorConfigurationBuilder+Display.swift` offers both `showLineNumbers(_:)` and `isLineNumbersEnabled(_:)` methods that change the same setting. They differ only in parameter naming but encourage two separate APIs for the same feature.

    32 public func fontSize(_ size: CGFloat) -> Self { ... }
    55 public func showLineNumbers(_ show: Bool) -> Self { ... }
    59 ...
    70 /// let config = EditorConfigurationBuilder()


    _Suggestion:_ Deprecate one of the two lineNumbers methods to keep the fluent API minimal.

    Suggested taskRemove duplicate builder modifier

    Start task

    ### 1.2. Deprecated Property Exposure

    CodeEditorView+Core.swift exposes deprecated aliases (showsLineNumbers, showsSyntaxHighlighting, etc.) alongside the preferred properties.


    64 @available(*, deprecated, renamed: "isSyntaxHighlightingEnabled", ...)
    70 public var isLineNumbersEnabled: Bool { ... }
    81 @available(*, deprecated, renamed: "isLineNumbersEnabled", ...)


    _Suggestion:_ Consider marking deprecated properties as obsoleted in the next major release or move them to an extension specifically for backward compatibility.

    ### 1.3. Public API Surface

    CodeEditorPlugin.swift exports CodeEditorTextView and CodeEditorDelegate as typealiases.


    public typealias CodeEditorTextView = CodeEditorView
    public typealias CodeEditorDelegate = CodeEditorViewDelegate


    While convenient, these aliases may leak internal naming to end users. Evaluate whether they are still needed given the modern API.

    ## 2. Architecture & Scalability

    ### 2.1. Platform Capability Detection

    PlatformCapabilities.supportsCADisplayLink omits Mac Catalyst, returning false even though Catalyst should follow macOS behavior.


    174 public var supportsCADisplayLink: Bool {
    175     #if canImport(UIKit) && !targetEnvironment(macCatalyst)
    176     return true
    177     #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
    178     return systemVersionComponents.major >= 14
    179     #else
    180     return false
    181     #endif
    182 }


    _Suggestion:_ Add a targetEnvironment(macCatalyst) branch so Catalyst devices report proper support.

    Suggested taskHandle Mac Catalyst in CADisplayLink detection

    Start task

    ### 2.2. AsyncTextProcessor Cleanup

    AsyncTextProcessor.processNextTaskIfPossible() schedules a nested Task just to call taskCompleted:


    296 Task { [weak self] in
    297     defer {
    298         Task { [weak self] in
    299             await self?.taskCompleted(taskId)
    300         }
    301     }


    Creating a second task increases complexity and risks missing cleanup if the actor is deallocated. The completion handler can directly await taskCompleted after processingTask.value.

    Suggested taskSimplify task completion cleanup

    Start task

    ## 3. Code Quality & Best Practices

    ### 3.1. Inconsistent Test Counts

    The project documentation cites different numbers of tests. README.md and some docs mention **657**tests, while AGENTS.md and GEMINI.md mention **533**.


    README.md: Verified with **657 automated tests**
    AGENTS.md: **533 Comprehensive Tests**
    GEMINI.md: **533 Tests**
    Documentation.docc/Production-Reliability.md: "657 total tests"


    _Suggestion:_ Decide on the correct test count and update all references for consistency.

    Suggested taskSynchronize documented test count

    Start task

    ## 4. Testing & Reliability

    ### 4.1. Mac Catalyst Feature Validation

    Platform-dependent code (e.g., supportsCADisplayLink, input coordinators) has no dedicated test coverage. Adding tests to verify Catalyst behavior would strengthen confidence in cross‑platform support.

    Suggested taskAdd Mac Catalyst capability tests

    Start task

    ### 4.2. Memory Monitor Integration

    EditorConfiguration.Performance.memoryMonitor allows custom monitors but there are no unit tests ensuring the injected monitor receives cleanup callbacks.

    Suggested taskTest custom MemoryMonitor injection

    Start task

    ## 5. Documentation & Clarity

    ### 5.1. Clarify Deprecated APIs

    While many deprecated properties exist for backwards compatibility, the documentation does not specify removal timelines. Consider noting planned deprecation in DocC pages or changelogs to guide adopters.

    ### 5.2. Improve Getting Started Example

    The README Mac Catalyst section demonstrates wrapping SwiftUI content in a UIHostingController, but does not show configuring the environment. Including the .environment(\.codeEditorConfiguration, ...) line would better mirror earlier examples.

    ## Network access

    Some HTTPS requests were blocked during inspection, which may affect fetching remote dependencies or CI runs.

      * github.com: via git operations

      * nytimes.com: via curl (example)

    Consider enabling network access in CI for any tools that require external downloads.

    * * *

    These changes should improve API clarity, platform consistency, and test coverage while maintaining the component’s clean architecture.
