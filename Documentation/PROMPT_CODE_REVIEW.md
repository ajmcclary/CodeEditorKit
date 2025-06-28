### Prompt for Code Review

**Role:** You are a senior software engineer specializing in cross-platform Apple development (iOS/macOS).

**Objective:** Conduct a thorough code review of the `CodeEditorPlugin` and `CodeEditorSample` codebase. The primary goal is to ensure robust cross-platform compatibility, verifying that platform-specific code for AppKit and UIKit is correctly abstracted and implemented.

**Project Context:**
*   `CodeEditorPlugin` is a Swift package designed for use in any AppKit or SwiftUI application to provide code editing capabilities.
*   `CodeEditorSample` is a sample application that demonstrates the plugin's features.
*   The project has a dedicated **Platform Abstraction System** located in `Sources/CodeEditorPlugin/Platform/` which should be the single source of truth for platform-agnostic types and capabilities. Refer to `GEMINI.md` for its architecture.

**Key Areas for Review:**

1.  **Adherence to Platform Abstraction Layer:**
    *   Scan the codebase for any direct use of platform-specific types (e.g., `NSColor`, `UIColor`, `NSView`, `UIView`, `NSFont`, `UIFont`).
    *   Verify that these are replaced by the appropriate platform-agnostic types defined in `PlatformImports.swift` (e.g., `PlatformColor`, `PlatformView`, `PlatformFont`).
    *   Ensure platform-specific API usage is guarded by checks against `PlatformCapabilities.swift`.

2.  **Conditional Compilation (`#if`):**
    *   Analyze all uses of `#if os(macOS)`, `#if os(iOS)`, `#if canImport(AppKit)`, and `#if canImport(UIKit)`.
    *   Confirm that these directives are not used where the platform abstraction layer already provides a solution.
    *   Ensure that for every `#if`, there is a corresponding and correct implementation for the `else` condition to prevent functionality gaps on the other platform.

3.  **UI and Layout Consistency:**
    *   Inspect files in `Sources/CodeEditorPlugin/Layout/` and `CodeEditorSample/Sources/Views/`.
    *   Identify potential layout issues, such as hardcoded values or assumptions that might not hold true across different screen sizes and platforms.
    *   Pay special attention to `GutterView` and `CodeEditorContainerView` to ensure the fixes for text rendering and clipping are correctly implemented.

**Output Requirements:**

Please generate a comprehensive report in Markdown format. For each issue identified, structure your feedback as follows:

---

**File:** `[Absolute Path to the File]`
**Line:** `[Line Number]`

**Issue:**
A brief, clear description of the cross-platform problem or potential risk.

**Problematic Code:**
```swift
// Snippet of the code that needs correction.
```

**Suggested Improvement:**
A detailed explanation of how to fix the issue, referencing the project's own conventions (e.g., "Replace `NSColor.textColor` with `PlatformColors.label` to leverage the semantic, adaptive color system.").

**Corrected Code:**
```swift
// Snippet of the corrected, platform-agnostic code.
```

---

If no critical issues are found, please provide a summary confirming that the platform abstractions are well-implemented and the codebase appears robust for cross-platform support.