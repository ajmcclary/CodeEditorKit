### **CodeEditorPlugin Code Review Prompt**

You are an expert senior software engineer and architect specializing in building high-performance, cross-platform text editors and code editing components for Apple ecosystems (macOS, iOS, iPadOS, Mac Catalyst) using Swift.

Please review the following code from the **CodeEditorPlugin** project, which is a production-quality, TextKit2-based code editor framework built on **Swift 6 actor-based concurrency**. This framework contains **400+ source files** organized across **17 feature directories** with comprehensive test coverage (53+ test files, 624+ tests) and zero SwiftLint violations.

Your feedback should focus on maintaining the project's high standards for performance, thread safety, cross-platform compatibility, and architectural excellence.

---

### 🎯 **Primary Goals**

- **TextKit2 Performance:** Optimize for 60fps rendering, large file handling (500KB+), and real-time syntax highlighting
- **Cross-Platform Excellence:** Ensure native performance across macOS, iOS, and Mac Catalyst without compromise
- **Actor-Based Architecture:** Maintain strict Swift 6 concurrency compliance with proper isolation and no data races
- **Production Quality:** Zero SwiftLint violations, comprehensive test coverage, and maintainable architecture
- **Test Performance:** Ensure all performance tests complete in reasonable time (<30s per test suite)

---

### 🔍 **CodeEditorPlugin-Specific Review Areas**

1. **Code Organization & Architecture:**
   - **Directory Structure:** Is code properly organized into the 17 core directories (`Core/`, `Text/`, `Layout/`, `Configuration/`, `Platform/`, `SyntaxHighlighting/`, `Languages/`, `Completion/`, `Features/`, `SwiftUI/`, `Extensions/`, `Performance/`, `LSP/`, `Annotations/`, `Models/`, `Utilities/`, `Documentation.docc/`)? Should components be moved to more appropriate locations?
   - **File Size Limits:** Are files kept under 600 lines? Large files should be refactored into focused services and helpers (e.g., CodeFoldingEngine → FoldingProviderRegistry, FoldingOperationsService)
   - **Service Layer Usage:** Are business logic services (`TextEditingService`, `LanguageDetectionService`, `SyntaxHighlightingService`) being used instead of implementing logic directly in views?
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
   - **SwiftUI Integration:** Is the `CodeEditor` SwiftUI wrapper following modern patterns? Check for:
     - Direct property binding: `$configuration.display.fontSize`
     - Environment configuration: `.environment(\.codeEditorConfiguration, config)`
     - Consolidated environment: `.codeEditorEnvironment(language:theme:configuration:)`
     - Proper use of modifiers: `.codeLanguage(.swift)`, `.lineNumbers(true)`
   - **Deprecated API Avoidance:** Is `ConfigurationBindingBuilder` avoided (deprecated as of 2025)?
   - **Delegate Patterns:** Is `CodeEditorViewDelegate` used appropriately with proper weak references?
   - **API Design:** Are internal implementation details properly hidden from public interfaces? Check `CodeEditorAPI` protocol compliance.
   - **Component Reuse:** Are existing components being leveraged instead of creating new ones? Check for opportunities to use existing utilities.

9. **Language Support & Extensibility:**
   - **Language Detection:** Is automatic language detection working correctly with file extensions via `LanguageDetectionService`?
   - **Syntax Providers:** Are language-specific providers (Swift AST, Tree-sitter) integrated cleanly?
   - **Completion Provider Factory:** Is `UniversalCompletionProvider` factory pattern used for language-specific completion?
   - **LSP Integration:** If present, is Language Server Protocol integration following async patterns?
   - **Completion System:** Is code completion integrated without blocking the UI thread? Check async implementation in `Completion/` directory.
   - **Supported Languages:** Are all 17+ supported languages properly configured (Swift, Python, JavaScript, TypeScript, Rust, C/C++, HTML, CSS, JSON, YAML, Markdown, Go, Java, Ruby, PHP, SQL, XML, Shell)?

10. **Production Quality Standards:**
    - **Force Unwrap Elimination:** Are all force unwraps (`!`) removed in favor of safe unwrapping?
    - **SwiftLint Compliance:** Does the code maintain zero SwiftLint violations? Run `swiftlint --fix` before review.
    - **Test Coverage:** Are new features covered by unit tests and integration tests? Project has 53+ test files with 624+ tests.
    - **Test Performance:** Do performance tests complete quickly? Avoid generating massive test data (e.g., 50,000 line files for tests).
    - **Documentation:** Are public APIs documented with DocC-compatible comments?
    - **Memory Management:** Is proper cleanup performed in `removeFromSuperview` and deinit?
    - **Sendable Compliance:** Are all shared types properly marked as Sendable for Swift 6?
    - **Protocol Naming:** Avoid naming conflicts between protocols and types (e.g., CompletionItem protocol vs struct)

11. **Platform-Specific Optimizations:**
    - **iOS Container Integration:** Is the iOS container view (`CodeEditorContainerView`) handling layout and input correctly?
    - **macOS Native Features:** Are macOS-specific features (menu integration, keyboard shortcuts) implemented properly?
    - **Catalyst Adaptations:** Does the code adapt appropriately for Mac Catalyst environment? Check text storage handling.
    - **Performance Scaling:** Are timeout configurations and performance limits adjusted per platform?
    - **CrossPlatformCoordinator:** Is unified input handling properly delegated through the coordinator?

12. **Recent Architecture Improvements (2024-2025):**
    - **Directory Consolidation:** Has functionality been properly organized after the reduction from 22 to 17 directories?
    - **Text Directory Unification:** Is all text handling properly consolidated in the `Text/` directory?
    - **ViewModel Distribution:** Are ViewModels co-located with their features rather than in a separate directory?
    - **Service Layer Adoption:** Are new features using the service layer pattern for business logic?
    - **Dependency Injection:** Has singleton usage been replaced with proper dependency injection (e.g., MemoryMonitor)?
    - **Large File Refactoring:** Have monolithic files been broken down (CodeFoldingEngine 690→199 lines, CompletionViewModel 686→378 lines)?
    - **Cache Key Generation:** Are cache keys properly generated for cross-platform compatibility (e.g., relative vs absolute hit counts)?

---

### 📋 **Review Checklist**

Before submitting feedback, verify:

**Code Organization & Structure:**
- [ ] Files are organized in the 17 appropriate directories (Core, Text, Layout, Configuration, Platform, etc.)
- [ ] Files are kept under 600 lines (refactor large files into services and helpers)
- [ ] Business logic uses service layer (TextEditingService, LanguageDetectionService, etc.)
- [ ] Helper classes are extracted for reusable patterns and complex logic
- [ ] Existing code is leveraged instead of reimplementing functionality
- [ ] Code duplication is eliminated, especially between platform implementations
- [ ] ViewModels are co-located with their features (e.g., GutterViewModel in Layout/)
- [ ] Service extraction pattern is followed (e.g., FoldingProviderRegistry, CompletionCacheManager)

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
- [ ] All platform-specific code uses `#if canImport()` patterns (NOT `#if os()`)
- [ ] Actor isolation is correct with no potential data races
- [ ] Configuration system is used properly with immutable updates
- [ ] Direct SwiftUI bindings are used (ConfigurationBindingBuilder is deprecated)
- [ ] SwiftLint violations are addressed (`swiftlint --fix`)
- [ ] Large file handling is optimized (500KB+ files)
- [ ] Memory cleanup is proper in view lifecycle methods
- [ ] Tests are included for new functionality (project has 53+ test files, 624+ tests)
- [ ] Performance tests complete quickly (avoid 50K+ line test files)
- [ ] Documentation follows DocC standards
- [ ] UniversalCompletionProvider factory pattern is used for completion
- [ ] CrossPlatformLogger is used instead of print statements
- [ ] Sendable compliance is maintained for Swift 6
- [ ] Protocol/type naming conflicts are avoided
- [ ] Test assertions handle platform differences (e.g., cache hit counts)

---

### 🚀 **Successful Refactoring Patterns**

When identifying areas for improvement, consider these proven refactoring patterns from recent work:

**Large File Refactoring Example - CodeFoldingEngine (690→199 lines):**
- Extract provider registry: `FoldingProviderRegistry` (84 lines)
- Extract operations service: `FoldingOperationsService` (107 lines)  
- Extract state manager: `FoldingStateManager` (88 lines)
- Extract range calculator: `FoldingRangeCalculator` (72 lines)
- Extract UI updater: `FoldingUIUpdater` (68 lines)
- Extract animation coordinator: `FoldingAnimationCoordinator` (52 lines)

**Service Extraction Pattern - CompletionViewModel (686→378 lines):**
- Extract context extraction: `CompletionContextExtractor` (132 lines)
- Extract cache management: `CompletionCacheManager` (124 lines)
- Extract filtering logic: `CompletionFilteringService` (186 lines)
- Extract generation service: `CompletionGenerationService` (167 lines)

**Test Optimization Patterns:**
- Reduce test data size: 50,000 lines → 1,000 lines
- Simplify code generation: Complex React components → Simple statements
- Use relative assertions for platform differences: `stats.hitCount - baseline` instead of absolute counts

---

Please provide your feedback in a clear, actionable format with specific file:line references where possible. Focus on maintaining the project's production quality standards while suggesting concrete improvements for performance, architecture, and maintainability.
