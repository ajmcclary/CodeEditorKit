# Service Architecture Diagram

This diagram shows the service-oriented architecture and how services interact within the CodeEditorPlugin framework.

```mermaid
classDiagram
    %% Central Service Registry
    class BusinessLogicServiceRegistry {
        &lt;&lt;dependency injection container&gt;&gt;
        -services Dictionary~String, Any~
        -eventSystem UnifiedEventSystem
        +shared BusinessLogicServiceRegistry
        +register~T~(type T.Type, service T)
        +resolve~T~(type T.Type) T?
        +initialize(eventSystem UnifiedEventSystem)
        +shutdown()
    }

    %% Text Processing Services
    class TextEditingService {
        &lt;&lt;text operations&gt;&gt;
        -textView CodeEditorView
        -undoManager UndoManager
        +performEdit(EditAction)
        +insertText(String, at NSRange)
        +deleteText(in NSRange)
        +replaceText(in NSRange, with String)
        +applyIndentation(to NSRange)
        +toggleComment(in NSRange)
    }

    class EditAction {
        &lt;&lt;operation types&gt;&gt;
        insert(text String, range NSRange)
        delete(range NSRange)
        replace(range NSRange, text String)
        indent(range NSRange)
        outdent(range NSRange)
        comment(range NSRange)
    }

    class SyntaxHighlightingService {
        &lt;&lt;syntax coloring&gt;&gt;
        -coordinator SyntaxHighlightingCoordinator
        -cache HighlightingCache
        -queue DispatchQueue
        +highlightDocument(text String, language LanguageConfig)
        +highlightRange(NSRange, in String, language LanguageConfig)
        +invalidateCache(for NSRange?)
        +cancelPendingHighlighting()
    }

    class LanguageDetectionService {
        &lt;&lt;language recognition&gt;&gt;
        -detectors [LanguageDetector]
        -cache Dictionary~String, LanguageConfig~
        +detectLanguage(fileExtension String) LanguageConfig?
        +detectLanguage(content String) LanguageConfig?
        +registerDetector(LanguageDetector)
        +clearCache()
    }

    class CompletionManager {
        &lt;&lt;code completion&gt;&gt;
        -providers Dictionary~String, CompletionProvider~
        -activeSession CompletionSession?
        -debouncer Debouncer
        +requestCompletions(context CompletionContext)
        +registerProvider(for String, provider CompletionProvider)
        +cancelActiveSession()
        +applyCompletion(CompletionItem)
    }

    class MemoryMonitor {
        &lt;&lt;resource monitoring&gt;&gt;
        -threshold Double
        -timer Timer?
        -delegate MemoryMonitorDelegate?
        +startMonitoring(interval TimeInterval)
        +stopMonitoring()
        +currentMemoryUsage() Double
        +checkMemoryPressure()
    }

    %% Service Infrastructure
    class ServiceLifecycle {
        &lt;&lt;lifecycle protocol&gt;&gt;
        +initialize()
        +shutdown()
        +suspend()
        +resume()
    }

    class ServiceDependencies {
        &lt;&lt;dependency container&gt;&gt;
        +eventSystem UnifiedEventSystem
        +configuration EditorConfiguration
        +logger CrossPlatformLogger
        +cache CacheManager
    }

    %% Service Coordination Layer
    class SyntaxHighlightingCoordinator {
        &lt;&lt;highlighting orchestrator&gt;&gt;
        -highlighters Dictionary~String, SyntaxHighlighter~
        -swiftSyntaxHighlighter SwiftSyntaxHighlighter?
        -regexHighlighter RegexHighlighter
        +coordinate(request HighlightingRequest)
        +selectHighlighter(for LanguageConfig) SyntaxHighlighter
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

    %% Performance & Caching
    class CacheManager {
        &lt;&lt;cache orchestrator&gt;&gt;
        -caches Dictionary~String, Cache~
        +syntaxCache Cache~HighlightingResult~
        +completionCache Cache~CompletionResult~
        +languageCache Cache~LanguageConfig~
        +clearAll()
        +clearExpired()
    }

    class ServiceEventHandler {
        &lt;&lt;event dispatcher&gt;&gt;
        -registry BusinessLogicServiceRegistry
        +handleTextChange(Event)
        +handleLanguageChange(Event)
        +handleConfigurationChange(Event)
        +handleMemoryWarning(Event)
    }

    %% Provider Protocols & Support Types
    class LanguageDetector {
        &lt;&lt;detection protocol&gt;&gt;
        +detectorName String
        +supportedExtensions [String]
        +confidence Double
        +detectLanguage(content String) LanguageConfig?
        +detectLanguage(fileExtension String) LanguageConfig?
        +canDetect(content String) Bool
    }

    class CompletionProvider {
        &lt;&lt;completion protocol&gt;&gt;
        +providerId String
        +supportedLanguages [String]
        +priority Int
        +provideCompletions(context CompletionContext) [CompletionItem]
        +canProvideCompletions(context CompletionContext) Bool
    }

    class CompletionContext {
        &lt;&lt;completion request&gt;&gt;
        +position NSRange
        +text String
        +language LanguageConfig?
        +triggerCharacter String?
        +isRetrigger Bool
        +previousContext CompletionContext?
    }

    class CompletionItem {
        &lt;&lt;completion suggestion&gt;&gt;
        +title String
        +detail String?
        +kind CompletionItemKind
        +insertText String
        +replaceRange NSRange
        +priority Int
        +documentation String?
    }

    class CompletionItemKind {
        &lt;&lt;suggestion types&gt;&gt;
        text
        method
        function
        constructor
        field
        variable
        class
        interface
        module
        property
        unit
        value
        enum
        keyword
        snippet
        color
        file
        reference
    }

    %% Supporting Infrastructure
    class MemoryMonitorDelegate {
        &lt;&lt;monitoring protocol&gt;&gt;
        +memoryMonitor(MemoryMonitor, didExceedThreshold Double)
        +memoryMonitor(MemoryMonitor, memoryPressureChanged MemoryPressure)
        +memoryMonitorDidReceiveWarning(MemoryMonitor)
    }

    class Debouncer {
        &lt;&lt;timing utility&gt;&gt;
        +delay TimeInterval
        +queue DispatchQueue
        +workItem DispatchWorkItem?
        +debounce(action @escaping () -> Void)
        +cancel()
        +flush()
    }

    %% Syntax Highlighting System
    class HighlightingCache {
        &lt;&lt;highlighting cache&gt;&gt;
        +maxSize Int
        +cache LRUCache~String, HighlightingResult~
        +store(key String, result HighlightingResult)
        +retrieve(key String) HighlightingResult?
        +invalidate(key String)
        +clear()
    }

    class HighlightingRequest {
        &lt;&lt;highlighting task&gt;&gt;
        +text String
        +language LanguageConfig
        +range NSRange?
        +priority HighlightingPriority
        +completion (HighlightingResult) -> Void
    }

    class HighlightingResult {
        &lt;&lt;highlighting output&gt;&gt;
        +attributedString NSAttributedString
        +tokens [SyntaxToken]
        +processingTime TimeInterval
        +cacheKey String
        +isFromCache Bool
    }

    class SyntaxHighlighter {
        &lt;&lt;highlighter protocol&gt;&gt;
        +highlighterName String
        +supportedLanguages [String]
        +highlight(text String, language LanguageConfig) HighlightingResult
        +highlightRange(text String, range NSRange, language LanguageConfig) HighlightingResult
        +canHighlight(language LanguageConfig) Bool
    }

    class SwiftSyntaxHighlighter {
        &lt;&lt;Swift AST highlighter&gt;&gt;
        +swiftSyntax SwiftSyntaxAPI
        +colorScheme SyntaxColorScheme
        +highlight(text String, language LanguageConfig) HighlightingResult
        +parseSwiftCode(text String) SyntaxTree
        +applyColors(tokens [SyntaxToken]) NSAttributedString
    }

    class RegexHighlighter {
        &lt;&lt;pattern-based highlighter&gt;&gt;
        +patterns [String: NSRegularExpression]
        +colorMappings [String: NSColor]
        +highlight(text String, language LanguageConfig) HighlightingResult
        +loadPatterns(for LanguageConfig) [NSRegularExpression]
        +applyPattern(pattern NSRegularExpression, to String) [SyntaxToken]
    }

    %% Generic Cache System
    class Cache~T~ {
        &lt;&lt;generic cache&gt;&gt;
        +maxSize Int
        +storage [String: CacheEntry~T~]
        +hitCount Int
        +missCount Int
        +store(key String, value T, expiry Date?)
        +retrieve(key String) T?
        +remove(key String)
        +clear()
    }

    class CacheEntry~T~ {
        &lt;&lt;cache entry&gt;&gt;
        +value T
        +timestamp Date
        +expiry Date?
        +accessCount Int
        +isExpired Bool
    }

    class SyntaxToken {
        &lt;&lt;syntax element&gt;&gt;
        +text String
        +range NSRange
        +type SyntaxTokenType
        +attributes [NSAttributedString.Key: Any]
    }

    class SyntaxTokenType {
        <<enumeration>>
        keyword
        identifier
        string
        number
        comment
        operator
        punctuation
        whitespace
        newline
        unknown
    }

    class LanguageConfig {
        +identifier: String
        +name: String
        +fileExtensions: [String]
        +mimeTypes: [String]
        +supportsCompletion: Bool
        +supportsSyntaxHighlighting: Bool
        +supportsFormatting: Bool
        +configuration: [String: Any]
    }

    class CrossPlatformLogger {
        +logLevel: LogLevel
        +destinations: [LogDestination]
        +log(level: LogLevel, message: String, file: String, function: String, line: Int)
        +debug(String)
        +info(String)
        +warning(String)
        +error(String)
    }

    %% Relationships
    BusinessLogicServiceRegistry "1" *-- "*" TextEditingService : manages
    BusinessLogicServiceRegistry "1" *-- "1" SyntaxHighlightingService : manages
    BusinessLogicServiceRegistry "1" *-- "1" LanguageDetectionService : manages
    BusinessLogicServiceRegistry "1" *-- "1" CompletionManager : manages
    BusinessLogicServiceRegistry "1" *-- "1" MemoryMonitor : manages
    
    TextEditingService --> EditAction : uses
    TextEditingService ..|> ServiceLifecycle : implements
    
    SyntaxHighlightingService --> SyntaxHighlightingCoordinator : uses
    SyntaxHighlightingService --> CacheManager : uses
    SyntaxHighlightingService ..|> ServiceLifecycle : implements
    
    LanguageDetectionService --> CacheManager : uses
    LanguageDetectionService ..|> ServiceLifecycle : implements
    
    CompletionManager --> CompletionSession : creates
    CompletionManager --> CacheManager : uses
    CompletionManager ..|> ServiceLifecycle : implements
    
    MemoryMonitor ..|> ServiceLifecycle : implements
    
    BusinessLogicServiceRegistry --> ServiceDependencies : uses
    BusinessLogicServiceRegistry --> ServiceEventHandler : uses
    
    ServiceEventHandler --> UnifiedEventSystem : listens to
    
    SyntaxHighlightingCoordinator --> SyntaxHighlighter : coordinates
    SyntaxHighlightingCoordinator --> SwiftSyntaxHighlighter : uses
    SyntaxHighlightingCoordinator --> RegexHighlighter : uses
    
    LanguageDetectionService --> LanguageDetector : uses
    LanguageDetectionService --> LanguageConfig : detects
    
    CompletionManager --> CompletionProvider : uses
    CompletionManager --> CompletionContext : creates
    CompletionManager --> CompletionItem : provides
    CompletionManager --> Debouncer : uses
    
    CompletionProvider --> CompletionContext : receives
    CompletionProvider --> CompletionItem : creates
    CompletionItem --> CompletionItemKind : categorized by
    
    MemoryMonitor --> MemoryMonitorDelegate : notifies
    
    SyntaxHighlightingService --> HighlightingCache : caches in
    SyntaxHighlightingCoordinator --> HighlightingRequest : processes
    SyntaxHighlightingCoordinator --> HighlightingResult : produces
    
    SyntaxHighlighter <|-- SwiftSyntaxHighlighter : implements
    SyntaxHighlighter <|-- RegexHighlighter : implements
    
    HighlightingResult --> SyntaxToken : contains
    SyntaxToken --> SyntaxTokenType : categorized by
    
    CacheManager --> Cache : manages
    Cache --> CacheEntry : stores
    
    ServiceDependencies --> CrossPlatformLogger : includes
    
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