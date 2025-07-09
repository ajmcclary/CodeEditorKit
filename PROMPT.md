**Project:** CodeEditorPlugin - A Swift 6, cross-platform code editor component for macOS, iOS, and Mac Catalyst.

**Persona:** You are a senior Swift engineer and an expert in API design, specializing in building and maintaining high-quality, reusable software components. You have a keen eye for modern Swift practices, including actor-based concurrency, platform abstraction, and API ergonomics. You value clean architecture, comprehensive testing, and clear documentation.

**Context:** I have developed a production-ready code editor component called `CodeEditorPlugin`. It's built with Swift 6 and supports macOS, iOS, and Mac Catalyst. The project prioritizes a clean, feature-based architecture, extensive test coverage (425 tests), and zero SwiftLint violations. It uses `SwiftSyntax` for AST-based Swift highlighting and performant regex for 16 other languages. A key feature is its sophisticated platform abstraction layer that uses `#if canImport()` for true cross-platform support, avoiding simple `#if os()` checks.

**Request:** Please conduct a thorough code review of the `CodeEditorPlugin` project. I am looking for actionable feedback to elevate it from a great component to an exceptional one.

**Areas of Focus:**

1.  **API Design & Ergonomics:**
    *   Review the main `CodeEditor` (SwiftUI) and `CodeEditorView` (AppKit/UIKit) APIs. Are they intuitive and easy to use?
    *   Examine the `EditorConfiguration` system. Is the builder pattern (`with()` methods) effective? Are the presets logical? Is it flexible enough for advanced use cases?
    *   Assess the public API surface. Is it minimal yet complete? Are there any internal details that are unnecessarily exposed?

2.  **Architecture & Scalability:**
    *   Evaluate the feature-based directory structure. Does it promote modularity and maintainability?
    *   Analyze the Swift 6 actor implementation. Are there opportunities to improve concurrency patterns or data flow? Are there any potential race conditions or deadlocks?
    *   Inspect the platform abstraction layer (`Platform/`). Is it robust? Does it effectively isolate platform-specific code? Are there any abstractions that feel leaky or incomplete?

3.  **Code Quality & Best Practices:**
    *   While the project adheres to SwiftLint, are there any "code smells" or anti-patterns that could be improved?
    *   Review the use of `SwiftSyntax`. Is it being used efficiently for highlighting?
    *   Check for potential performance bottlenecks, especially in the rendering pipeline (`Core/`), text processing (`TextProcessing/`), and syntax highlighting (`SyntaxHighlighting/`).

4.  **Testing & Reliability:**
    *   Given the existing 425 tests, what critical areas might be under-tested?
    *   Suggest specific scenarios for new integration, performance, or UI tests that would increase confidence in the component's reliability.

5.  **Documentation & Clarity:**
    *   Review the inline code comments and the DocC documentation. Is it clear, concise, and helpful for developers who want to integrate or contribute to the plugin?
    *   Do the `CLAUDE.md`, `GEMINI.md`, and `AGENTS.md` files provide enough context for an AI assistant to work effectively with the codebase?

**How to Present Your Feedback:**

Please structure your review with clear, actionable recommendations. For each point, please:
*   **Identify** the specific file and line number(s) where relevant.
*   **Explain** the issue or opportunity for improvement.
*   **Provide** a concrete code example or suggestion for the change.
*   **Categorize** the feedback (e.g., Critical, Suggestion, Question).

My goal is to ensure this component is not only powerful and feature-rich but also a pleasure for other developers to use and build upon. Thank you for your expertise!
