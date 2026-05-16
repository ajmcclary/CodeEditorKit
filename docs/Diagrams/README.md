# CodeEditorPlugin Architecture Diagrams

This directory contains architectural diagrams for the CodeEditorPlugin framework, illustrating major components, systems, integrations, and their data flows.

> **Note (0.2.0):** several diagrams in this folder were authored while Mac Catalyst was a supported platform and legacy TextKit was a live fallback. As of 0.2.0 both have been retired — the framework targets macOS and iOS only, and TextKit2 is the only supported layout system. Catalyst-specific boxes / class members in the mermaid sources below are preserved for historical context but no longer reflect source. For the current state, see [`docs/Platform/platform-abstraction.md`](../Platform/platform-abstraction.md) and [`docs/FeatureMatrix.md`](../FeatureMatrix.md). The pre-0.2.0 platform-abstraction diagram is preserved as a historical snapshot in [`../archive/Diagrams/08-platform-abstraction-layer.md`](../archive/Diagrams/08-platform-abstraction-layer.md).

When a diagram conflicts with source or a topic page, treat the source and topic page as authoritative. The diagrams are subsystem maps, not complete generated type inventories.

Design-only diagrams covering features that are not yet implemented (the plugin system, the extended debugging-integration design, and the planned enhanced syntax-highlighting design) live in [`../archive/Diagrams/`](../archive/Diagrams/).

## Index of Diagrams

### 1. [High-Level Architecture](01-high-level-architecture.md)
Overview of the entire CodeEditorPlugin framework showing main layers and their relationships. Includes SwiftUI integration, core components, services, configuration, platform abstraction, features, language support, and external integrations.

### 2. [Core Components Class Diagram](02-core-components-class.md)
Detailed class diagram of the main components including CodeEditorView, CodeEditorAPI protocol, UnifiedEventSystem, EditorRuntime, and their relationships. Shows the protocol-oriented design and delegation patterns.

### 3. [Configuration System](03-configuration-system.md)
Configuration architecture including EditorConfiguration structure with Display, Layout, Behavior, and Performance sections. Shows presets, validation, and SwiftUI environment integration.

### 4. [Service Architecture](04-service-architecture.md)
Service-oriented architecture diagram showing EditorRuntime and all managed services (TextEditingService, SyntaxHighlightingService, LanguageDetectionService, CompletionProviderRegistry, LineNumberCalculationService, GutterSizingService, CodeFoldingCoordinatorService, EditorLayoutService, MemoryManagementCoordinator).

### 5. [Event System Flow](05-event-system-flow.md)
Unified event system flow diagram illustrating event sources (UI, text changes, system, service, configuration), built-in `EditorEvent` creation, filtering, history, Combine subscriptions, and handler-token execution. Adjacent debouncing and async utilities are shown as integration points rather than custom event-type support.

### 6. [Language Support & Syntax Highlighting Pipeline](06-language-syntax-highlighting-pipeline.md)
Complete pipeline for language detection and syntax highlighting, including both SwiftSyntax and regex-based paths. Shows caching, tokenization, rendering stages, and enhanced performance optimization with OptimizedSyntaxHighlightingCoordinator, performance tracking, chunking, and circuit breaker pattern.

### 7. [Completion System Architecture](07-completion-system-architecture.md)
Code completion system including CompletionManager, provider registry, session management, caching, and UI components. Includes sequence diagram of completion flow.

### 9. [Text Processing Pipeline](09-text-processing-pipeline.md)
Text processing flow from input to rendering, including TextKit2 integration, line index management, batch processing, and performance optimizations. Shows incremental updates and viewport rendering.

### 10. [UI Component Hierarchy](10-ui-component-hierarchy.md)
Visual component hierarchy showing CodeEditorContainerView and all child components including gutter, minimap, overlays, and status bar. Includes layout structure diagram.

### 11. [Advanced Features Integration Architecture](11-advanced-features-integration.md)
Comprehensive architecture for advanced features including debugging integration, search functionality, smart editing, and code folding. Shows feature coordination, state management, and UI integration.

### 12. [LSP System Complete Architecture](12-lsp-system-architecture.md)
Complete Language Server Protocol implementation with transport layers, protocol integration, and multi-language support. Includes message routing, capability negotiation, error handling, and retry configuration with exponential backoff and jitter support.

### 13. [Performance Monitoring & Optimization System](13-performance-monitoring-system.md)
Current performance monitoring implementation, including `PerformanceMonitor`, `UnifiedPerformanceSystem`, `PerformanceInsights`, memory monitoring, production metrics, adaptive performance mode, viewport tracking, iOS large-file optimization, and performance budget reporting.

### 14. [Symbol Navigation & Code Intelligence](14-symbol-navigation-intelligence.md)
Symbol navigation and code intelligence system with multi-language support, cross-reference tracking, and intelligent navigation. Includes definition lookup, reference finding, and workspace symbol search.

### 15. [Language Provider Complete Ecosystem](15-language-provider-ecosystem.md)
Language provider ecosystem supporting 25 concrete languages plus plain text with completion, symbols, folding, and data providers. Shows the matrix of supported languages and their capabilities.

### 16. [Annotation System Detailed Architecture](16-annotation-system-architecture.md)
Comprehensive annotation system providing code annotations, diagnostics, and contextual information overlay capabilities. Includes multi-source annotation support, interactive features, and visual customization.

### 17. [Advanced Text Processing & Validation Pipeline](17-advanced-text-processing-pipeline.md)
Advanced text processing and validation system with multi-phase validation, range management, text versioning, and flexible styling. Includes performance optimization and comprehensive validation approaches.

### 18. [Data Models & Type System Architecture](18-data-models-type-system.md)
Comprehensive data models and type system forming the foundation of CodeEditorPlugin's data structures. Includes rich text models, versioning system, type information, and performance optimization.

### 19. [SwiftUI Integration Complete Ecosystem](19-swiftui-integration-ecosystem.md)
Complete SwiftUI integration ecosystem providing seamless integration between CodeEditorPlugin and SwiftUI applications. Includes platform-specific representables, environment management, and animation coordination.

### 20. [Debugging Integration](20-debugging-integration.md)
Currently implemented debugging integration. The earlier extended design document is preserved in [`../archive/Diagrams/20-debugging-integration-architecture.md`](../archive/Diagrams/20-debugging-integration-architecture.md).

### 21. [Utility Systems & Extensions Network](21-utility-systems-extensions.md)
Utility systems and extensions network providing shared utilities, cross-platform helpers, and extensibility infrastructure. Includes async operation management, logging, caching, and extension management.

### 22. [Advanced Layout & UI Components Architecture](22-advanced-layout-ui-components.md)
Advanced layout system and UI component architecture handling positioning, responsive design, and complex component interactions. Includes flexbox/grid layouts, constraint solving, animation coordination, and accessibility integration.

### 23. [Multi-Language Support Matrix](23-multi-language-support-matrix.md)
Matrix view of language support capabilities across 25 concrete supported languages plus plain text. Shows feature comparison, performance characteristics, LSP integrations, and debugging support for each language.

### 24. [Performance Optimization Pipeline](24-performance-optimization-pipeline.md)
Comprehensive performance optimization pipeline that monitors, analyzes, and continuously optimizes performance. Includes real-time monitoring, bottleneck detection, adaptive optimization strategies, and machine learning-based improvements.

### 25. [Package Dependencies](25-package-dependencies.md)
Package dependency diagram showing the main CodeEditorPlugin framework's dependencies on SwiftSyntax, SwiftParser, swift-dependencies, and xctest-dynamic-overlay, plus test target dependencies.

### 26. [Sample App Dependencies](26-sample-dependencies.md)
CodeEditorSample demonstration app architecture showing dependencies on CodeEditorPlugin, CodeEditorUI, and CodeEditorDesignTokens, with sample code and configuration management.

### 28. [Performance Budget System](28-performance-budget-system.md)
Comprehensive performance budget system that monitors and enforces performance targets across all operations. Includes budget definitions, status tracking, violation reporting, test integration, and enforcement configuration with support for warning, critical, and exceeded thresholds.

### 29. [Enhanced Syntax Highlighting Architecture](29-enhanced-syntax-highlighting-architecture.md)
Current optimized syntax highlighting system with actor-based concurrency, streaming highlighter for large files, circuit breaker patterns, and comprehensive performance tracking. The original planned design document is preserved in [`../archive/Diagrams/29-enhanced-syntax-highlighting-architecture.md`](../archive/Diagrams/29-enhanced-syntax-highlighting-architecture.md).

### 30. [Diagram Colors](Colors.md)
Shared Mermaid color palette used by the diagrams in this directory.

## Archived diagrams

Historical snapshots and design-only diagrams have been moved to [`../archive/Diagrams/`](../archive/Diagrams/) so this index reflects current implementation only. See the [archive README](../archive/README.md) for the full list.

## How to View These Diagrams

All diagrams are written in Mermaid syntax and can be viewed:
1. Directly in GitHub (automatic rendering)
2. In VS Code with a Mermaid preview extension
3. In any Mermaid-compatible viewer
4. Exported to SVG/PNG using Mermaid CLI tools

## Regenerating Dependency Diagrams

Dependency diagrams (25, 26) should be manually updated when `Package.swift` changes. These diagrams reflect the actual dependencies declared in the package manifest — direct runtime dependencies (SwiftSyntax, SwiftParser, swift-dependencies, xctest-dynamic-overlay), internal product dependencies (CodeEditorDesignTokens, CodeEditorUI, CodeEditorSample), and test target dependencies (CodeEditorPluginTests, CodeEditorDesignTokensTests, CodeEditorUITests, CodeEditorSampleTests, swift-custom-dump, swift-snapshot-testing).

## Diagram Conventions

All diagrams use a consistent light/dark mode compatible color palette:

- **Primary Blue**: Core components/main systems  
- **Success Green**: UI/visual components  
- **Purple Accent**: Services/processing components  
- **Warning Orange**: Configuration/settings  
- **Error Red**: External integrations  
- **Neutral Gray**: Supporting data types and enums  
- **Arrows**: Dependencies and data flow  
- **Subgraphs**: Logical groupings of related components  

Colors automatically adapt to light/dark mode with semantic meaning maintained across all diagrams.
