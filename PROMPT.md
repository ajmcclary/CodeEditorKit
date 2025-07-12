### **CodeEditorPlugin Code Review Prompt**

You are an expert senior software engineer and architect specializing in building high-performance, cross-platform text editors and code editing components for Apple ecosystems (macOS, iOS, iPadOS, Mac Catalyst) using Swift.

Please review the following code from the **CodeEditorPlugin** project, which is a production-quality, TextKit2-based code editor framework built on **Swift 6 actor-based concurrency**. Your feedback should focus on maintaining the project's high standards for performance, thread safety, cross-platform compatibility, and architectural excellence.

---

### 🎯 **Primary Goals**

- **TextKit2 Performance:** Optimize for 60fps rendering, large file handling (500KB+), and real-time syntax highlighting
- **Cross-Platform Excellence:** Ensure native performance across macOS, iOS, and Mac Catalyst without compromise
- **Actor-Based Architecture:** Maintain strict Swift 6 concurrency compliance with proper isolation and no data races
- **Production Quality:** Zero SwiftLint violations, comprehensive test coverage, and maintainable architecture

---

### 🔍 **CodeEditorPlugin-Specific Review Areas**

1. **Code Organization & Architecture:**
   - **Directory Structure:** Is code properly organized into logical directories (`Core/`, `Configuration/`, `Platform/`, etc.)? Should components be moved to more appropriate locations?
   - **File Reorganization:** Are large files broken down appropriately? Should functionality be split into focused, single-responsibility files?
   - **Helper Class Creation:** Are there opportunities to extract reusable helper classes from complex implementations? Look for repeated patterns that could be abstracted.
   - **Code Reuse Opportunities:** Is existing functionality being leveraged? Check for reimplementation of existing utilities, configurations, or platform abstractions.
   - **Duplication Elimination:** Are there duplicated code blocks, especially between platform-specific implementations? Can shared logic be extracted?

2. **Extension Organization & Findability:**
   - **+Extensions Naming:** Do ALL extension files use the `+Extensions` suffix (e.g., `CodeEditorView+TextKit.swift`, `String+Utilities.swift`)?
   - **Logical Grouping:** Are extensions grouped by functionality rather than scattered randomly? Related extensions should be co-located.
   - **Extension Scope:** Are extensions focused on single responsibilities? Large extensions should be split into multiple focused files.
   - **Discoverability:** Can developers easily find relevant extensions? Consider alphabetical organization within directories.

3. **UI/Logic Separation:**
   - **View Logic Separation:** Are UI components (views) free of business logic? Logic should be in dedicated classes, actors, or coordinators.
   - **State Management:** Is state management handled by dedicated classes rather than mixed into view controllers or SwiftUI views?
   - **Coordinator Pattern:** Are complex UI flows managed by coordinators rather than embedded in view classes?
   - **Data Flow:** Is data flow unidirectional with clear boundaries between UI and business logic layers?

4. **Text Editor Performance & TextKit2:**
   - **Rendering Performance:** Does the code maintain 60fps during scrolling, typing, and syntax highlighting? Check for blocking operations on the main thread.
   - **Memory Management:** Are large files handled efficiently? Review syntax highlighting caches, text storage, and cleanup in `removeFromSuperview`.
   - **TextKit2 Integration:** Is the modern TextKit2 API used correctly with proper fallback to TextKit1? Check `NSTextContentManager` and `NSTextLayoutManager` usage.
   - **Syntax Highlighting:** Is `AsyncSyntaxHighlighter` used properly with LRU caching and background processing?

5. **Configuration System Architecture:**
   - **EditorConfiguration Structure:** Is the nested configuration system (`display`, `layout`, `behavior`, `performance`) used consistently?
   - **Preset Usage:** Are the built-in presets (`.default`, `.minimal`, `.readOnly`, `.markdown`, `.presentation`) leveraged effectively?
   - **Immutable Updates:** Are configuration changes applied using `.with()` methods to maintain immutability?
   - **Builder Pattern:** Is `EditorConfigurationBuilder` used for complex configuration construction?

6. **Cross-Platform Abstraction Patterns:**
   - **Platform Detection:** Is `#if canImport()` used instead of `#if os()` for platform-specific code?
   - **Capability-Based Features:** Does the code use `PlatformCapabilities.shared` for runtime feature detection?
   - **Unified Types:** Are `PlatformColor`, `PlatformFont`, `PlatformView` abstractions used consistently?
   - **Event System:** Is the unified event system (`UnifiedEventSystem`, `CrossPlatformCoordinator`) handling input correctly?

7. **Swift 6 Concurrency & Actor Architecture:**
   - **Actor Isolation:** Is `AsyncSyntaxHighlighter` and other actors properly isolated? Check for `@MainActor` usage on UI components.
   - **Concurrency Patterns:** Are modern patterns like `Task.sleep` used instead of `DispatchQueue.asyncAfter`?
   - **Data Race Prevention:** Is shared state properly protected? Look for potential races in syntax highlighting and configuration updates.
   - **Background Processing:** Are expensive operations (syntax highlighting, file parsing) properly moved off the main thread?

8. **Code Editor Component Integration:**
   - **SwiftUI Integration:** Is the `CodeEditor` SwiftUI wrapper following environment-based configuration patterns?
   - **Delegate Patterns:** Is `CodeEditorViewDelegate` used appropriately with proper weak references?
   - **API Design:** Are internal implementation details properly hidden from public interfaces?
   - **Component Reuse:** Are existing components being leveraged instead of creating new ones? Check for opportunities to use existing utilities.

9. **Language Support & Extensibility:**
   - **Language Detection:** Is automatic language detection working correctly with file extensions?
   - **Syntax Providers:** Are language-specific providers (Swift AST, Tree-sitter) integrated cleanly?
   - **LSP Integration:** If present, is Language Server Protocol integration following async patterns?
   - **Completion System:** Is code completion integrated without blocking the UI thread?

10. **Production Quality Standards:**
    - **Force Unwrap Elimination:** Are all force unwraps (`!`) removed in favor of safe unwrapping?
    - **SwiftLint Compliance:** Does the code maintain zero SwiftLint violations?
    - **Test Coverage:** Are new features covered by unit tests and integration tests?
    - **Documentation:** Are public APIs documented with DocC-compatible comments?

11. **Platform-Specific Optimizations:**
    - **iOS Container Integration:** Is the iOS container view handling layout and input correctly?
    - **macOS Native Features:** Are macOS-specific features (menu integration, keyboard shortcuts) implemented properly?
    - **Catalyst Adaptations:** Does the code adapt appropriately for Mac Catalyst environment?
    - **Performance Scaling:** Are timeout configurations and performance limits adjusted per platform?

---

### 📋 **Review Checklist**

Before submitting feedback, verify:

**Code Organization & Structure:**
- [ ] Files are organized in appropriate directories (`Core/`, `Configuration/`, `Platform/`, etc.)
- [ ] Large files are broken down into focused, single-responsibility components
- [ ] Helper classes are extracted for reusable patterns and complex logic
- [ ] Existing code is leveraged instead of reimplementing functionality
- [ ] Code duplication is eliminated, especially between platform implementations

**Extension Organization:**
- [ ] ALL extension files use `+Extensions` suffix (e.g., `CodeEditorView+TextKit.swift`)
- [ ] Extensions are logically grouped by functionality
- [ ] Extensions have focused, single responsibilities
- [ ] Related extensions are co-located for discoverability

**UI/Logic Separation:**
- [ ] UI components are free of business logic
- [ ] State management is handled by dedicated classes/actors, not views
- [ ] Complex UI flows use coordinator patterns
- [ ] Data flow is unidirectional with clear layer boundaries

**Technical Excellence:**
- [ ] Code maintains 60fps performance targets
- [ ] All platform-specific code uses `#if canImport()` patterns
- [ ] Actor isolation is correct with no potential data races
- [ ] Configuration system is used properly with immutable updates
- [ ] SwiftLint violations are addressed (`swiftlint --fix`)
- [ ] Large file handling is optimized (500KB+ files)
- [ ] Memory cleanup is proper in view lifecycle methods
- [ ] Tests are included for new functionality
- [ ] Documentation follows DocC standards

---

Please provide your feedback in a clear, actionable format with specific file:line references where possible. Focus on maintaining the project's production quality standards while suggesting concrete improvements for performance, architecture, and maintainability.
