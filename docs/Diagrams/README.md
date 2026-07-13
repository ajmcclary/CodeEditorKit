# CodeEditorPlugin Architecture Diagrams

This directory contains architectural diagrams for the CodeEditorPlugin framework, illustrating major components, systems, integrations, and their data flows.

> **Current platform baseline:** these diagrams describe the native macOS and iOS / iPadOS implementation. Mac Catalyst and legacy TextKit fallback designs have been moved to the archive; current diagrams should not introduce Catalyst-specific boxes or TextKit1 branches.

When a diagram conflicts with source or a topic page, treat the source and topic page as authoritative. The diagrams are subsystem maps, not complete generated type inventories.

Design-only diagrams covering features that are not yet implemented (the plugin system, the extended debugging-integration design, and the planned enhanced syntax-highlighting design) live in [`../archive/Diagrams/`](../archive/Diagrams/).

## Index of Diagrams

### 1. [High-Level Architecture](01-high-level-architecture.md)
Overview of the entire CodeEditorPlugin framework showing main layers and their relationships. Includes SwiftUI integration, core components, services, configuration, platform abstraction, features, language support, and external integrations.

### 2. [Core Components Class Diagram](02-core-components-class.md)
Current editor ownership map: `CodeEditorView`, `EditorSession`, focused feature controllers, `EditorRuntime`, the event bus, and memory rebinding.

### 3. [Configuration System](03-configuration-system.md)
Configuration architecture including EditorConfiguration structure with Display, Layout, Behavior, and Performance sections. Shows presets, validation, and SwiftUI environment integration.

### 4. [Service Architecture](04-service-architecture.md)
Runtime composition and state-preserving infrastructure rebinding across the editor session and monitor-aware feature owners.

### 5. [Event System Flow](05-event-system-flow.md)
Canonical `EditorEventBus` publication and its ordered Combine, legacy publisher, async-stream, weak-handler, and `NotificationCenter` adapters.

### 6. [Language Support & Syntax Highlighting Pipeline](06-language-syntax-highlighting-pipeline.md)
Complete pipeline for language detection and syntax highlighting, including both SwiftSyntax and regex-based paths. Shows caching, tokenization, rendering stages, and enhanced performance optimization with OptimizedSyntaxHighlightingCoordinator, performance tracking, chunking, and circuit breaker pattern.

### 7. [Completion System Architecture](07-completion-system-architecture.md)
The `CompletionManager` façade and its focused provider registry, request coordinator, response cache, learning store, ranker, broadcaster, and debouncer.

### 10. [UI Component Hierarchy](10-ui-component-hierarchy.md)
Visual component hierarchy showing CodeEditorContainerView and all child components including gutter, minimap, overlays, and status bar. Includes layout structure diagram.

### 12. [LSP System Complete Architecture](12-lsp-system-architecture.md)
The `LSPClient` façade over JSON-RPC, connection lifecycle, document session, language-feature client, registry, and transports.

### 13. [Performance Monitoring & Optimization System](13-performance-monitoring-system.md)
Current performance monitoring implementation, including `PerformanceMonitor`, `UnifiedPerformanceSystem`, `PerformanceInsights`, memory monitoring, production metrics, adaptive performance mode, viewport tracking, iOS large-file optimization, and performance budget reporting.

### 14. [Symbol Navigation & Code Intelligence](14-symbol-navigation-intelligence.md)
Symbol navigation and code intelligence system with multi-language support, cross-reference tracking, and intelligent navigation. Includes definition lookup, reference finding, and workspace symbol search.

### 15. [Language Provider Complete Ecosystem](15-language-provider-ecosystem.md)
Language provider ecosystem supporting 25 concrete languages plus plain text with completion, symbols, folding, and data providers. Shows the matrix of supported languages and their capabilities.

### 16. [Annotation System Detailed Architecture](16-annotation-system-architecture.md)
Comprehensive annotation system providing code annotations, diagnostics, and contextual information overlay capabilities. Includes multi-source annotation support, interactive features, and visual customization.

### 18. [Data Models & Type System Architecture](18-data-models-type-system.md)
Comprehensive data models and type system forming the foundation of CodeEditorPlugin's data structures. Includes rich text models, versioning system, type information, and performance optimization.

### 19. [SwiftUI Integration Complete Ecosystem](19-swiftui-integration-ecosystem.md)
SwiftUI hosting with a thin coordinator delegating binding, interaction, runtime/value rendering, and completion-modifier reconciliation.

### 21. [Utility Systems & Extensions Network](21-utility-systems-extensions.md)
Utility systems and extensions network providing shared utilities, cross-platform helpers, and extensibility infrastructure. Includes async operation management, logging, caching, and extension management.

### 22. [Advanced Layout & UI Components Architecture](22-advanced-layout-ui-components.md)
Advanced layout system and UI component architecture handling positioning, responsive design, and complex component interactions. Includes flexbox/grid layouts, constraint solving, animation coordination, and accessibility integration.

### 23. [Multi-Language Support Matrix](23-multi-language-support-matrix.md)
Matrix view of language support capabilities across 25 concrete supported languages plus plain text. Shows feature comparison, performance characteristics, and LSP integration notes.

### 25. [Package Dependencies](25-package-dependencies.md)
Package dependency diagram showing the current library products, the single-file `CodeEditorPlugin` umbrella target, runtime dependencies, and test target dependencies.

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

Dependency diagram 25 should be manually updated when `Package.swift` changes (run `./Scripts/generate-dependency-diagrams.sh`). It reflects the actual products and important target dependencies declared in the manifest, including the focused library products, the umbrella `CodeEditorPlugin`, runtime dependencies, and test-only dependencies. (The former diagram 26 covered the `CodeEditorSample` demo app, which was extracted to the workspace's `apps/CodeEditorDemo` package.)

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
