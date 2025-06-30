# Review 2

# Code Review

## Overall Health Summary

The project provides a well-structured cross-platform code editor. Platform abstractions are centralized in `Sources/CodeEditorPlugin/Platform/`, offering type aliases and capability detection. SwiftUI wrappers exist for macOS (`NSViewRepresentable`) and iOS (`UIViewRepresentable`). The sample app demonstrates integration on both platforms. Most conditional compilation relies on `#if canImport(AppKit)` and `#if canImport(UIKit)` per the project's guidelines.

## Critical Issues

No immediate crash-level defects were found in a static review. However, large mixed `#if` blocks and duplication may increase maintenance risk, and some areas still reference AppKit/UIKit types directly.

## Improvement Suggestions

### 1. Platform Abstraction Layer

**Issue:** Several components still depend directly on AppKit or UIKit types rather than using `Platform*` aliases.

**Example:** `InsertionPointView` defines an AppKit class when AppKit is available, and a different UIKit class otherwise

**Recommendation:** Move these platform-specific views into separate files (`InsertionPointView+AppKit.swift`, `InsertionPointView+iOS.swift`) and expose them via a single `InsertionPointView` typealias or factory. This keeps the core API surface independent of AppKit/UIKit.

**Issue:** `CompletionViewController` provides distinct controllers for AppKit and UIKit within one file, leading to a long conditional section.

**Example:** lines defining `CompletionViewController` for macOS and `BasicCompletionViewController` for iOS share no code

**Recommendation:** Extract each platform's implementation into separate files, limiting the main file to a small factory method returning the appropriate controller.

### 2. Conditional Compilation (`#if` blocks)

**Issue:** Some large files include extensive conditional code, making them hard to read (`CodeEditorContainerView.swift`, `CrossPlatformCoordinator.swift`).

**Example:** platform-specific layout logic stretches across hundreds of lines

**Recommendation:** Split platform-specific logic into dedicated extensions or files. Keep the common interface minimal in the main type.

**Issue:** In the sample app, AppKit-only logic uses only `#if canImport(AppKit)` without excluding Catalyst explicitly.

**Example:** `AnnotationManager`'s AppKit branch begins at line 137 and doesn't check for `!targetEnvironment(macCatalyst)`

**Recommendation:** Follow the project's guideline from `Platform/README.md` to include `!targetEnvironment(macCatalyst)` for macOS-specific code so Catalyst builds don't accidentally enter AppKit paths.

### 3. SwiftUI Integration

**Issue:** Both `CodeEditorRepresentable` implementations keep block-based notification observers without explicit removal, which may lead to leaked references.

**Example:** observers stored in an array but only removed in deinit for each coordinator

**Recommendation:** Ensure observers are removed when views disappear (e.g., in `updateNSView`/`updateUIView` or via `onDisappear`).

**Issue:** The deprecated `CodeEditorSwiftUIView` wrapper is still used in the sample app for some platforms.

**Example:** `SampleCodeEditorView` conditionally uses `CodeEditorViewWrapper` with the deprecated view on iOS lines 34–39

**Recommendation:** Update the sample app to use the modern `CodeEditor` API consistently.

### 4. Code Duplication and Consistency

**Issue:** Many platform-specific features repeat similar logic (e.g., annotation scanning and view creation) across `#if` blocks.

**Recommendation:** Factor duplicated algorithms into shared helpers or protocols implemented by AppKit/UIView subclasses.

### 5. CodeEditorSample as a Reference

**Issue:** The sample's configuration export/import service duplicates AppKit and UIKit logic within one file, leading to long conditional sections.

**Recommendation:** Split these functions into platform-specific extensions so the common API surface remains concise.

## Action Plan

1. Refactor large conditional files (`CodeEditorContainerView`, `CrossPlatformCoordinator`, `CompletionViewController`) into separate platform-specific files.

2. Replace remaining direct AppKit/UIKit class declarations with `Platform*` abstractions or platform-specific extensions.

3. Review all `#if` conditions to ensure macOS-only blocks include `!targetEnvironment(macCatalyst)` when required.

4. Enhance observer management in SwiftUI coordinators to avoid potential leaks.

5. Update the sample app to rely on the modern `CodeEditor` wrapper and split its platform-specific utilities into dedicated files for clarity.

6. Add tests verifying that each platform builds and that basic editor actions work on macOS, iOS, and Catalyst.

These steps will simplify maintenance and strengthen cross-platform support.