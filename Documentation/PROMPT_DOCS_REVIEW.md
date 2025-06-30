# Prompt for AI Assistant

## Role
You are an expert technical writer and developer advocate. Your task is to update the documentation for a Swift-based Code Editor component to reflect its latest features and architecture after a series of major refactoring sprints.

## Goal
Rewrite and enhance the two README.md files (`/README.md` and `/CodeEditorSample/README.md`) to be clear, compelling, and accurate. The new documentation should highlight the project's modern architecture, advanced features, and production-readiness.

## Primary Audience
Swift developers looking for a powerful, modern, and reliable code editor component for their macOS and iOS applications.

## Key Themes to Emphasize Across Both Files

1. **Modern Swift 6 Concurrency**: Stress the use of Swift 6 actors for a thread-safe, performant, and modern architecture. This is a key differentiator.

2. **Robust Cross-Platform Support**: Highlight the sophisticated platform abstraction layer that enables true cross-platform functionality for macOS, iOS, and Mac Catalyst. Mention that this isn't just a port, but a ground-up design for platform independence.

3. **Production-Ready & Tested**: Emphasize the project's maturity with over 170 tests, a clean build, and zero linting violations. This builds trust.

4. **Advanced, Extensible Architecture**: Showcase the new feature-based architecture, the upcoming plugin system, and the Language Server Protocol (LSP) integration as proof of the project's power and future-proof design.

5. **Comprehensive & Unified Configuration**: Detail the nested EditorConfiguration system, the builder pattern, and the available presets. This shows flexibility and ease of use.

---

## Task 1: Update the Main `README.md`

Analyze the provided README.md, CLAUDE.md, AGENTS.md, and GEMINI.md content and perform the following updates:

### 1. Refresh the Feature List
- Re-brand the list to be more benefit-oriented.
- Prominently add the new, high-impact features:
  - **"Modern Swift 6 Concurrency**: Built from the ground up with actors for rock-solid thread safety and performance."
  - **"True Cross-Platform Architecture**: A sophisticated abstraction layer ensures seamless, native performance on macOS, iOS, and Mac Catalyst."
  - **"Extensible & Future-Proof**: Features a forward-thinking plugin architecture and Language Server Protocol (LSP) integration for advanced language intelligence."
  - **"Production-Grade Quality**: Verified with over 170 tests, ensuring reliability for professional applications."

### 2. Enhance the Architecture Section
- Expand on the "Simplified Feature-Based Architecture" to explain why it's better (e.g., "This clean, modular design makes the codebase easier to understand, maintain, and extend.").
- Create a new sub-section for the Platform Abstraction System. Explain its role and why it's important for developers (e.g., "Write your UI code once. Our abstraction layer handles the platform-specific details, providing unified types like PlatformColor and PlatformView.").
- Briefly explain the role of the key components listed in CLAUDE.md, AGENTS.md, and GEMINI.md (CodeEditorView, EditorConfiguration, SyntaxHighlightingCoordinator, etc.) to give a clearer architectural overview.

### 3. Create a New "Advanced Features" Section
- Dedicate a new section to showcase the high-end capabilities that are currently bundled in the sample app but are part of the core offering.
- Mention the Interactive Showcase in the sample app where users can see these features in action.
- List features like: Performance Monitoring, Multi-Cursor Editing (if applicable), Search/Replace, the Plugin Architecture preview, and LSP integration.

### 4. Refine the "Testing & Quality" Section
- Update the test counts to be specific (e.g., "106 tests for the core plugin, 66 for the sample app, totaling 172 tests").
- State clearly that the project adheres to strict quality standards, with zero linting violations.

---

## Task 2: Update the `CodeEditorSample/README.md`

Analyze the provided CodeEditorSample/README.md and align it with the updates from the main README.md.

### 1. Clarify the Purpose
- In the introduction, explicitly state that this sample app is the primary way to evaluate the plugin's most advanced features.
- Position it not just as a demo, but as a "comprehensive reference implementation" and a "showcase of production-ready patterns."

### 2. Update Feature Demonstration List
- Ensure the list of demonstrated features in "What This Demonstrates" matches the main README.md.
- Add entries for the new key themes:
  - **"Modern Architecture in Practice**: See how Swift 6 actors and the feature-based structure are implemented."
  - **"Advanced Features Showcase**: An interactive view to explore performance monitoring, plugin architecture concepts, and LSP integration."

### 3. Restructure the "Project Architecture" Section
- Rename the "Key Integration Patterns" sub-section to something more descriptive like "How to Integrate the Plugin".
- Focus this section on providing clear, copy-paste-friendly examples for the most common integration tasks (SwiftUI, Configuration, etc.).

### 4. Align Test Counts and Quality Metrics
- Ensure the test counts (66 tests) and quality statements (e.g., "Only 1 minor file length warning") are consistent with the main README.md's quality message.

## Final Deliverable

Provide the complete, updated text for both README.md files. The tone should be professional, confident, and focused on developer benefits. Use Markdown for formatting, including code blocks for examples.