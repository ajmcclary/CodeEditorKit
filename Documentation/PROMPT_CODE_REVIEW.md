### **Revised Code Review Prompt**

**Persona:** You are an expert Swift developer specializing in building cross-platform, multi-paradigm libraries that support both imperative (AppKit/UIKit) and declarative (SwiftUI) frameworks. You have a deep understanding of TextKit 2, performance optimization, and API design.

**Primary Goal:** Conduct a comprehensive code review of the `CodeEditorPlugin` codebase. The main objective is to ensure its architecture is robust, maintainable, and truly platform-agnostic, allowing it to function seamlessly across macOS (AppKit) and iOS/Mac Catalyst (UIKit). The `CodeEditorSample` application should also be reviewed to ensure it serves as a best-practice model for integrating the plugin.

**Scope:**
- **Primary Focus:** `Sources/CodeEditorPlugin/`
- **Secondary Focus:** `CodeEditorSample/` (as an integration reference)

**Key Areas for Analysis:**

1.  **Platform Abstraction & Separation of Concerns:**
    - **Evaluate Platform-Specific Code:** Scrutinize the use of `#if os(macOS)`, `#if os(iOS)`, and `TARGET_OS_MACCATALYST` directives. Are they properly isolated to the `Platform/` directory and view-level components, or are they leaking into core logic?
    - **Assess Abstraction Layer:** Review the type aliases and protocols in `Sources/CodeEditorPlugin/Platform/`. Is this layer used consistently? Identify any instances where AppKit or UIKit types (e.g., `NSView`, `UIView`, `NSColor`, `UIColor`) are used directly in shared core components instead of the provided platform-agnostic types.
    - **Identify Refactoring Opportunities:** Look for duplicated logic between AppKit and UIKit-specific files (e.g., `GutterView+AppKit.swift` and `GutterView+UIKit.swift`). Could this be consolidated by moving common functionality into a shared base class or protocol extension?

2.  **SwiftUI Integration:**
    - **Review `UIViewRepresentable` / `NSViewRepresentable`:** Analyze the SwiftUI wrappers. Do they correctly manage the view lifecycle, handle state updates efficiently, and use the `Coordinator` pattern properly?
    - **Check Data Flow:** Ensure that data flows correctly and efficiently between the SwiftUI layer and the underlying AppKit/UIKit views, particularly for editor configuration changes and text updates.

3.  **API Design & Usability:**
    - **Clarity and Consistency:** Is the public API of `CodeEditorView` and `EditorConfiguration` clear, consistent, and easy to use for a developer unfamiliar with the project?
    - **Protocol Adherence:** Does the implementation adhere strictly to the contracts defined by protocols like `CodeEditorViewProtocol`?

4.  **Architecture & Code Quality:**
    - **Concurrency:** Review the use of Swift actors. Are they used correctly to prevent data races and ensure thread safety, especially in background tasks like syntax highlighting and annotation processing?
    - **Adherence to Conventions:** Verify that the code follows the project's established conventions as outlined in `GEMINI.md` (e.g., feature-based organization, `+Extensions` suffix).

**Output Format:**

Please generate a comprehensive code review report in Markdown format. Structure your findings as follows:

---

### **Code Review Report: CodeEditorPlugin**

**1. Overall Assessment**
A high-level summary of the codebase's architectural strengths and areas for improvement regarding cross-platform support and overall quality.

**2. Critical Issues (If any)**
List any bugs, potential crashes, or significant architectural flaws that require immediate attention. For each, specify the file, line number, and a clear description of the problem.

**3. Architectural and Refactoring Recommendations**
Provide actionable suggestions for improving the codebase. For each recommendation:
- **File/Area:** The relevant file(s) or module.
- **Observation:** A clear description of the current implementation and the issue.
- **Suggestion:** A detailed explanation of the proposed change and why it's better.
- **Example (Optional but Preferred):** A code snippet demonstrating the "before" and "after."

**4. Platform-Specific Highlights**
- **Good:** Examples of well-implemented platform abstractions or clean separation of concerns.
- **To Improve:** Specific instances of platform-specific code that could be better abstracted.

**5. SwiftUI Integration Notes**
Comments on the quality and correctness of the SwiftUI wrapper implementation.

---