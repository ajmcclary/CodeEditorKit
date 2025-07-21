# Service Architecture Diagram

This diagram shows the service-oriented architecture and how services interact within the CodeEditorPlugin framework.

```mermaid
classDiagram
    direction LR
    
    %% Top Row - Central Registry & Core Services
    class BusinessLogicServiceRegistry {
        &lt;&lt;dependency injection&gt;&gt;
        -services Dictionary
        -eventSystem UnifiedEventSystem
        +register()
        +resolve()
        +initialize()
        +shutdown()
    }

    class ServiceDependencies {
        &lt;&lt;dependency container&gt;&gt;
        +eventSystem UnifiedEventSystem
        +configuration EditorConfiguration
        +logger CrossPlatformLogger
        +cache CacheManager
    }

    class ServiceEventHandler {
        &lt;&lt;event dispatcher&gt;&gt;
        -registry BusinessLogicServiceRegistry
        +handleTextChange()
        +handleLanguageChange()
        +handleConfigurationChange()
    }

    %% Second Row - Core Text & Language Services
    class TextEditingService {
        &lt;&lt;text operations&gt;&gt;
        -textView CodeEditorView
        -undoManager UndoManager
        +performEdit()
        +insertText()
        +deleteText()
        +replaceText()
        +applyIndentation()
    }

    class SyntaxHighlightingService {
        &lt;&lt;syntax coloring&gt;&gt;
        -coordinator SyntaxHighlightingCoordinator
        -cache HighlightingCache
        -queue DispatchQueue
        +highlightDocument()
        +highlightRange()
        +invalidateCache()
    }

    class LanguageDetectionService {
        &lt;&lt;language recognition&gt;&gt;
        -detectors [LanguageDetector]
        -cache Dictionary
        +detectLanguage()
        +registerDetector()
        +clearCache()
    }

    %% Third Row - Completion & Memory Management
    class CompletionManager {
        &lt;&lt;code completion&gt;&gt;
        -providers Dictionary
        -activeSession CompletionSession?
        -debouncer Debouncer
        +requestCompletions()
        +registerProvider()
        +cancelActiveSession()
    }

    class MemoryMonitor {
        &lt;&lt;resource monitoring&gt;&gt;
        -threshold Double
        -timer Timer?
        -delegate MemoryMonitorDelegate?
        +startMonitoring()
        +stopMonitoring()
        +currentMemoryUsage()
    }

    class CacheManager {
        &lt;&lt;cache orchestrator&gt;&gt;
        -caches Dictionary
        +syntaxCache Cache
        +completionCache Cache
        +languageCache Cache
        +clearAll()
        +clearExpired()
    }

    %% Fourth Row - Service Coordination & Session Management
    class SyntaxHighlightingCoordinator {
        &lt;&lt;highlighting orchestrator&gt;&gt;
        -highlighters Dictionary
        -swiftSyntaxHighlighter SwiftSyntaxHighlighter?
        -regexHighlighter RegexHighlighter
        +coordinate()
        +selectHighlighter()
    }

    class CompletionSession {
        &lt;&lt;completion state&gt;&gt;
        +id UUID
        +context CompletionContext
        +provider CompletionProvider
        +startTime Date
        +items [CompletionItem]
        +isActive Bool
        +cancel()
    }

    class ServiceLifecycle {
        &lt;&lt;lifecycle protocol&gt;&gt;
        +initialize()
        +shutdown()
        +suspend()
        +resume()
    }

    %% Fifth Row - Provider Protocols & Core Types
    class LanguageDetector {
        &lt;&lt;detection protocol&gt;&gt;
        +detectorName String
        +supportedExtensions [String]
        +confidence Double
        +detectLanguage()
        +canDetect()
    }

    class CompletionProvider {
        &lt;&lt;completion protocol&gt;&gt;
        +providerId String
        +supportedLanguages [String]
        +priority Int
        +provideCompletions()
        +canProvideCompletions()
    }

    class SyntaxHighlighter {
        &lt;&lt;highlighter protocol&gt;&gt;
        +highlighterName String
        +supportedLanguages [String]
        +highlight()
        +highlightRange()
        +canHighlight()
    }

    %% Sixth Row - Highlighter Implementations
    class SwiftSyntaxHighlighter {
        &lt;&lt;Swift AST highlighter&gt;&gt;
        +swiftSyntax SwiftSyntaxAPI
        +colorScheme SyntaxColorScheme
        +highlight()
        +parseSwiftCode()
        +applyColors()
    }

    class RegexHighlighter {
        &lt;&lt;pattern-based highlighter&gt;&gt;
        +patterns Dictionary
        +colorMappings Dictionary
        +highlight()
        +loadPatterns()
        +applyPattern()
    }

    class HighlightingCache {
        &lt;&lt;highlighting cache&gt;&gt;
        +maxSize Int
        +cache LRUCache
        +store()
        +retrieve()
        +invalidate()
        +clear()
    }

    %% Seventh Row - Support Types & Utilities
    class EditAction {
        &lt;&lt;operation types&gt;&gt;
        insert
        delete
        replace
        indent
        outdent
        comment
    }

    class CompletionContext {
        &lt;&lt;completion request&gt;&gt;
        +position NSRange
        +text String
        +language LanguageConfig?
        +triggerCharacter String?
    }

    class CompletionItem {
        &lt;&lt;completion suggestion&gt;&gt;
        +title String
        +detail String?
        +kind CompletionItemKind
        +insertText String
        +priority Int
    }

    %% Bottom Row - Basic Support Types
    class LanguageConfig {
        &lt;&lt;language definition&gt;&gt;
        +identifier String
        +name String
        +fileExtensions [String]
        +supportsCompletion Bool
        +supportsSyntaxHighlighting Bool
    }

    class Debouncer {
        &lt;&lt;timing utility&gt;&gt;
        +delay TimeInterval
        +queue DispatchQueue
        +debounce()
        +cancel()
        +flush()
    }

    class CrossPlatformLogger {
        &lt;&lt;logging&gt;&gt;
        +logLevel LogLevel
        +destinations [LogDestination]
        +log()
        +debug()
        +info()
        +warning()
        +error()
    }

    %% Key Relationships
    BusinessLogicServiceRegistry *-- TextEditingService : manages
    BusinessLogicServiceRegistry *-- SyntaxHighlightingService : manages
    BusinessLogicServiceRegistry *-- LanguageDetectionService : manages
    BusinessLogicServiceRegistry *-- CompletionManager : manages
    BusinessLogicServiceRegistry *-- MemoryMonitor : manages
    
    BusinessLogicServiceRegistry --> ServiceDependencies : uses
    BusinessLogicServiceRegistry --> ServiceEventHandler : uses
    
    TextEditingService --> EditAction : uses
    TextEditingService ..|> ServiceLifecycle : implements
    
    SyntaxHighlightingService --> SyntaxHighlightingCoordinator : uses
    SyntaxHighlightingService --> HighlightingCache : uses
    SyntaxHighlightingService ..|> ServiceLifecycle : implements
    
    SyntaxHighlightingCoordinator --> SyntaxHighlighter : coordinates
    SyntaxHighlighter <|-- SwiftSyntaxHighlighter : implements
    SyntaxHighlighter <|-- RegexHighlighter : implements
    
    LanguageDetectionService --> LanguageDetector : uses
    LanguageDetectionService --> LanguageConfig : detects
    LanguageDetectionService ..|> ServiceLifecycle : implements
    
    CompletionManager --> CompletionSession : creates
    CompletionManager --> CompletionProvider : uses
    CompletionManager --> CompletionContext : creates
    CompletionManager --> CompletionItem : provides
    CompletionManager --> Debouncer : uses
    CompletionManager ..|> ServiceLifecycle : implements
    
    MemoryMonitor ..|> ServiceLifecycle : implements
    
    ServiceDependencies --> CrossPlatformLogger : includes
    ServiceDependencies --> CacheManager : includes
    
    %% Styling - Dark mode friendly colors
    classDef registry fill:#6366f120,stroke:#6366f1,stroke-width:3px,color:#fff
    classDef service fill:#8b5cf620,stroke:#8b5cf6,stroke-width:2px,color:#fff
    classDef coordinator fill:#10b98120,stroke:#10b981,stroke-width:2px,color:#fff
    classDef lifecycle fill:#3b82f620,stroke:#3b82f6,stroke-width:2px,color:#fff
    classDef support fill:#f59e0b20,stroke:#f59e0b,stroke-width:2px,color:#fff
    classDef enum fill:#06b6d420,stroke:#06b6d4,stroke-width:2px,color:#fff
    classDef protocol fill:#ec489920,stroke:#ec4899,stroke-width:2px,color:#fff
    classDef cache fill:#6b728020,stroke:#6b7280,stroke-width:2px,color:#fff
    classDef highlighting fill:#10b98120,stroke:#10b981,stroke-width:2px,color:#fff
    classDef completion fill:#3b82f620,stroke:#3b82f6,stroke-width:2px,color:#fff
    
    class BusinessLogicServiceRegistry registry
    class TextEditingService service
    class SyntaxHighlightingService service
    class LanguageDetectionService service
    class CompletionManager service
    class MemoryMonitor service
    class SyntaxHighlightingCoordinator coordinator
    class CompletionSession coordinator
    class ServiceLifecycle lifecycle
    class ServiceDependencies support
    class CacheManager support
    class ServiceEventHandler support
    class Debouncer support
    class CrossPlatformLogger support
    class EditAction enum
    class CompletionItemKind enum
    class SyntaxTokenType enum
    class LanguageDetector protocol
    class CompletionProvider protocol
    class MemoryMonitorDelegate protocol
    class SyntaxHighlighter protocol
    class HighlightingCache cache
    class Cache cache
    class CacheEntry cache
    class HighlightingRequest highlighting
    class HighlightingResult highlighting
    class SwiftSyntaxHighlighter highlighting
    class RegexHighlighter highlighting
    class SyntaxToken highlighting
    class CompletionContext completion
    class CompletionItem completion
    class LanguageConfig completion
```

## Service Architecture Principles

1. **Service Registry Pattern**: Central registry manages all service instances
2. **Dependency Injection**: Services receive dependencies through constructor
3. **Lifecycle Management**: All services implement lifecycle protocol
4. **Event-Driven Communication**: Services communicate through event system
5. **Caching Strategy**: Shared cache manager for performance
6. **Async Operations**: Heavy operations run on background queues
7. **Memory Management**: Automatic cleanup on memory warnings