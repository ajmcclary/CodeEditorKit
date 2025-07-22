# CodeEditorPlugin Architecture Diagrams

This directory contains **24 comprehensive architectural diagrams** for the CodeEditorPlugin framework. These diagrams provide complete coverage of all major components, systems, and integrations, illustrating their relationships and data flows throughout the entire system.

## Index of Diagrams

### 1. [High-Level Architecture](01-high-level-architecture.md)
Overview of the entire CodeEditorPlugin framework showing main layers and their relationships. Includes SwiftUI integration, core components, services, configuration, platform abstraction, features, language support, and external integrations.

### 2. [Core Components Class Diagram](02-core-components-class.md)
Detailed class diagram of the main components including CodeEditorView, CodeEditorAPI protocol, UnifiedEventSystem, BusinessLogicServiceRegistry, and their relationships. Shows the protocol-oriented design and delegation patterns.

### 3. [Configuration System](03-configuration-system.md)
Complete configuration architecture including EditorConfiguration structure with Display, Layout, Behavior, and Performance sections. Shows presets, validation, persistence, and SwiftUI environment integration.

### 4. [Service Architecture](04-service-architecture.md)
Service-oriented architecture diagram showing BusinessLogicServiceRegistry and all managed services (TextEditingService, SyntaxHighlightingService, LanguageDetectionService, CompletionManager, MemoryMonitor). Includes lifecycle management and event integration.

### 5. [Event System Flow](05-event-system-flow.md)
Unified event system flow diagram illustrating event sources, creation, filtering, queuing, dispatching, and handler execution. Shows priority-based processing and async support.

### 6. [Language Support & Syntax Highlighting Pipeline](06-language-syntax-highlighting-pipeline.md)
Complete pipeline for language detection and syntax highlighting, including both SwiftSyntax and regex-based paths. Shows caching, tokenization, and rendering stages.

### 7. [Completion System Architecture](07-completion-system-architecture.md)
Code completion system including CompletionManager, provider registry, session management, caching, and UI components. Includes sequence diagram of completion flow.

### 8. [Platform Abstraction Layer](08-platform-abstraction-layer.md)
Cross-platform compatibility layer showing abstractions for macOS, iOS, and Mac Catalyst. Includes platform detection, type aliases, event/input adapters, and platform-specific implementations.

### 9. [Text Processing Pipeline](09-text-processing-pipeline.md)
Text processing flow from input to rendering, including TextKit2 integration, line index management, batch processing, and performance optimizations. Shows incremental updates and viewport rendering.

### 10. [UI Component Hierarchy](10-ui-component-hierarchy.md)
Visual component hierarchy showing CodeEditorContainerView and all child components including gutter, minimap, overlays, and status bar. Includes layout structure diagram.

### 11. [Advanced Features Integration Architecture](11-advanced-features-integration.md)
Comprehensive architecture for advanced features including debugging integration, search functionality, smart editing, and code folding. Shows feature coordination, state management, and UI integration.

### 12. [LSP System Complete Architecture](12-lsp-system-architecture.md)
Complete Language Server Protocol implementation with transport layers, protocol integration, and multi-language support. Includes message routing, capability negotiation, and error handling.

### 13. [Performance Monitoring & Optimization System](13-performance-monitoring-system.md)
Advanced performance monitoring with adaptive optimization, memory management, and real-time metrics. Includes profiling, bottleneck detection, and automatic performance tuning.

### 14. [Symbol Navigation & Code Intelligence](14-symbol-navigation-intelligence.md)
Symbol navigation and code intelligence system with multi-language support, cross-reference tracking, and intelligent navigation. Includes definition lookup, reference finding, and workspace symbol search.

### 15. [Language Provider Complete Ecosystem](15-language-provider-ecosystem.md)
Comprehensive language provider ecosystem supporting 17+ languages with completion, symbols, folding, and data providers. Shows the complete matrix of supported languages and their capabilities.

### 16. [Annotation System Detailed Architecture](16-annotation-system-architecture.md)
Comprehensive annotation system providing code annotations, diagnostics, and contextual information overlay capabilities. Includes multi-source annotation support, interactive features, and visual customization.

### 17. [Advanced Text Processing & Validation Pipeline](17-advanced-text-processing-pipeline.md)
Advanced text processing and validation system with multi-phase validation, range management, text versioning, and flexible styling. Includes performance optimization and comprehensive validation approaches.

### 18. [Data Models & Type System Architecture](18-data-models-type-system.md)
Comprehensive data models and type system forming the foundation of CodeEditorPlugin's data structures. Includes rich text models, versioning system, type information, and performance optimization.

### 19. [SwiftUI Integration Complete Ecosystem](19-swiftui-integration-ecosystem.md)
Complete SwiftUI integration ecosystem providing seamless integration between CodeEditorPlugin and SwiftUI applications. Includes platform-specific representables, environment management, and animation coordination.

### 20. [Debugging Integration Detailed Architecture](20-debugging-integration-architecture.md)
Comprehensive debugging integration system providing breakpoint management, debug session control, and debugging visualization capabilities. Supports multiple debuggers including LLDB, GDB, and Debug Adapter Protocol.

### 21. [Utility Systems & Extensions Network](21-utility-systems-extensions.md)
Comprehensive utility systems and extensions network providing shared utilities, cross-platform helpers, and extensibility infrastructure. Includes file system helpers, cryptography, networking, performance utilities, and extension management.

### 22. [Advanced Layout & UI Components Architecture](22-advanced-layout-ui-components.md)
Advanced layout system and UI component architecture handling positioning, responsive design, and complex component interactions. Includes flexbox/grid layouts, constraint solving, animation coordination, and accessibility integration.

### 23. [Multi-Language Support Matrix](23-multi-language-support-matrix.md)
Comprehensive matrix view of language support capabilities across all 17+ supported languages. Shows feature comparison, performance characteristics, LSP integrations, and debugging support for each language.

### 24. [Performance Optimization Pipeline](24-performance-optimization-pipeline.md)
Comprehensive performance optimization pipeline that monitors, analyzes, and continuously optimizes performance. Includes real-time monitoring, bottleneck detection, adaptive optimization strategies, and machine learning-based improvements.

## How to View These Diagrams

All diagrams are written in Mermaid syntax and can be viewed:
1. Directly in GitHub (automatic rendering)
2. In VS Code with a Mermaid preview extension
3. In any Mermaid-compatible viewer
4. Exported to SVG/PNG using Mermaid CLI tools

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

