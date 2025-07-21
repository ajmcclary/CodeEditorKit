# CodeEditorPlugin Architecture Diagrams

This directory contains comprehensive architectural diagrams for the CodeEditorPlugin framework. These diagrams illustrate the various components, their relationships, and data flows throughout the system.

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

## How to View These Diagrams

All diagrams are written in Mermaid syntax and can be viewed:
1. Directly in GitHub (automatic rendering)
2. In VS Code with a Mermaid preview extension
3. In any Mermaid-compatible viewer
4. Exported to SVG/PNG using Mermaid CLI tools

## Diagram Conventions

- **Blue boxes**: Core components/main systems
- **Orange boxes**: Services/processing components
- **Green boxes**: UI/visual components
- **Purple boxes**: Configuration/settings
- **Pink boxes**: External integrations
- **Arrows**: Dependencies and data flow
- **Subgraphs**: Logical groupings of related components

