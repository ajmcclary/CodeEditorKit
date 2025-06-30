### **Rewritten Code Review Prompt**

**Prompt Title:** Comprehensive Code Review for Production-Ready Swift Code Editor Component

**Persona:** Act as a principal software engineer specializing in Apple platform development, with deep expertise in Swift, SwiftUI, AppKit, and modern concurrency. You are reviewing a new code editor component that is being prepared for its first major open-source release.

**Project Context:**
You will review a Swift Package containing two main targets:
1.  `CodeEditorPlugin`: A reusable, production-ready code editor component designed for macOS and iOS using Swift 6. It aims for high performance, extensibility, and ease of integration into any SwiftUI or AppKit application.
2.  `CodeEditorSample`: A sample application that demonstrates the `CodeEditorPlugin`'''s features and configurations.

The project'''s standards, architecture, and goals are documented in `GEMINI.md`. Your review must validate the claims made in this document, including "production-ready," "zero technical debt," and full cross-platform support.

**Review Objectives & Key Areas of Focus:**

Please perform a thorough code review, focusing on the following areas. Structure your feedback in a comprehensive report.

**1. Architecture and API Design:**
    *   **Modularity:** Is the `CodeEditorPlugin` fully self-contained and decoupled from the `CodeEditorSample` app?
    *   **API Intuitiveness:** Evaluate the public API of `CodeEditorPlugin`. Is it easy to understand and integrate for a developer new to the project? Pay close attention to the `CodeEditor` SwiftUI view and the `EditorConfiguration` system.
    *   **Extensibility:** Does the plugin architecture (`Sources/CodeEditorPlugin/Plugin/`) provide a clear path for developers to add new features or languages?

**2. Code Quality and Best Practices:**
    *   **Swift 6 Concurrency:** Scrutinize the use of Swift 6 Actors, `async/await`, and other concurrency patterns. Are there potential race conditions, deadlocks, or misuse of `MainActor`?
    *   **Platform Abstraction:** Review the code in `Sources/CodeEditorPlugin/Platform/`. Is the abstraction layer robust? Does the code correctly use `#if canImport()` for platform-specific implementations?
    *   **Adherence to Standards:** Verify that the codebase strictly follows the guidelines outlined in `GEMINI.md`, including naming conventions and the "zero SwiftLint violations" rule.

**3. Performance and Reliability:**
    *   **Efficiency:** Identify potential performance bottlenecks, especially in the syntax highlighting engine (`SyntaxHighlighting/`), text processing (`TextProcessing/`), and rendering logic (`Layout/`).
    *   **Memory Management:** Check for potential memory leaks or excessive memory consumption, particularly within the `CodeEditorView` and its underlying TextKit 2 components.
    *   **Error Handling:** Is error handling robust and user-friendly? Are custom errors (`CodeEditorError`) used effectively?

**4. Test Coverage:**
    *   **Test Quality:** The project claims 172 tests. Review the existing tests in `Tests/`. Are they meaningful? Do they cover critical paths, edge cases, and platform-specific logic?
    *   **Gaps in Coverage:** Identify any significant features or components that lack adequate testing.

**5. Sample Application (`CodeEditorSample`):**
    *   **Effectiveness:** Does the sample app serve as a clear and comprehensive guide for developers?
    *   **Best Practices:** Does the integration of `CodeEditorPlugin` within the sample app demonstrate best practices?

**Output Format:**
Please provide your findings in a structured report with the following sections:
*   **Executive Summary:** A high-level overview of the codebase'''s quality, readiness for release, and key findings.
*   **High-Priority Issues:** Critical bugs, architectural flaws, or performance problems that must be addressed.
*   **Suggestions & Best Practices:** Recommendations for improving code clarity, maintainability, and API design.
*   **Code Snippets:** Include specific, non-trivial code examples to illustrate your points.
*   **Conclusion:** A final assessment of whether the project meets its goal of being a production-ready component.