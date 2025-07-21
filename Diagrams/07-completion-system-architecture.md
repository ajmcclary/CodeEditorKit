# Completion System Architecture

This diagram shows the code completion system architecture, including provider management, caching, and UI integration.

```mermaid
classDiagram
    %% Core Manager
    class CompletionManager {
        -providers: Dictionary~String, CompletionProvider~
        -activeSession: CompletionSession?
        -debouncer: Debouncer
        -cache: CompletionCache
        -eventSystem: UnifiedEventSystem
        +requestCompletions(context: CompletionContext)
        +registerProvider(language: String, provider: CompletionProvider)
        +cancelActiveSession()
        +applyCompletion(item: CompletionItem)
        +updateTriggerCharacters(Set~String~)
    }

    %% Completion Context
    class CompletionContext {
        +textView: CodeEditorView
        +position: TextPosition
        +prefix: String
        +lineContent: String
        +language: LanguageConfig
        +trigger: CompletionTrigger
        +scopeContext: ScopeContext
    }

    class CompletionTrigger {
        &lt;&lt;enumeration&gt;&gt;
        automatic(character: String)
        manual
        snippet
        import
    }

    %% Session Management
    class CompletionSession {
        +id: UUID
        +context: CompletionContext
        +provider: CompletionProvider
        +startTime: Date
        +items: [CompletionItem]
        +isActive: Bool
        +cancel()
        +filter(prefix: String)
        +sort(by: CompletionSortCriteria)
    }

    %% Provider System
    class CompletionProvider {
        &lt;&lt;protocol&gt;&gt;
        +languageId: String
        +triggerCharacters: Set~String~
        +provideCompletions(context: CompletionContext) async [CompletionItem]
        +resolveCompletion(item: CompletionItem) async CompletionItem?
        +shouldTrigger(context: CompletionContext) Bool
    }

    class UniversalCompletionProvider {
        -registry: ProviderRegistry
        +createProvider(for: LanguageConfig) CompletionProvider
        +registerCustomProvider(CompletionProvider)
    }

    %% Provider Implementations
    class SwiftCompletionProvider {
        -sourceKitService: SourceKitService
        -astCache: ASTCache
        +provideCompletions(context) async [CompletionItem]
        +resolveCompletion(item) async CompletionItem?
    }

    class LSPCompletionProvider {
        -lspClient: LSPClient
        -documentManager: DocumentManager
        +provideCompletions(context) async [CompletionItem]
        +resolveCompletion(item) async CompletionItem?
    }

    class KeywordCompletionProvider {
        -keywordDatabase: KeywordDatabase
        +provideCompletions(context) async [CompletionItem]
    }

    class SnippetCompletionProvider {
        -snippetLibrary: SnippetLibrary
        +provideCompletions(context) async [CompletionItem]
        +expandSnippet(CompletionItem) String
    }

    %% Completion Items
    class CompletionItem {
        +label: String
        +kind: CompletionItemKind
        +detail: String?
        +documentation: String?
        +insertText: String
        +range: NSRange
        +sortText: String?
        +filterText: String?
        +additionalEdits: [TextEdit]?
        +score: Double
    }

    class CompletionItemKind {
        &lt;&lt;enumeration&gt;&gt;
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
        keyword
        snippet
    }

    %% UI Components
    class CompletionWindowController {
        -tableView: NSTableView
        -items: [CompletionItem]
        -selectedIndex: Int
        +show(items: [CompletionItem], at: NSPoint)
        +hide()
        +selectNext()
        +selectPrevious()
        +applySelectedCompletion()
    }

    class CompletionCellView {
        +iconView: NSImageView
        +labelField: NSTextField
        +detailField: NSTextField
        +configure(with: CompletionItem)
    }

    %% Caching
    class CompletionCache {
        -cache: LRUCache~String, CachedCompletion~
        -ttl: TimeInterval
        +get(key: String) CachedCompletion?
        +set(key: String, completion: CachedCompletion)
        +invalidate(for: String?)
        +cleanExpired()
    }

    class CachedCompletion {
        +items: [CompletionItem]
        +timestamp: Date
        +context: CompletionContext
    }

    %% Relationships
    CompletionManager --> CompletionSession : manages
    CompletionManager --> CompletionProvider : uses
    CompletionManager --> CompletionCache : uses
    CompletionManager --> CompletionWindowController : controls
    
    CompletionSession --> CompletionContext : contains
    CompletionSession --> CompletionItem : produces
    
    CompletionProvider <|-- SwiftCompletionProvider : implements
    CompletionProvider <|-- LSPCompletionProvider : implements
    CompletionProvider <|-- KeywordCompletionProvider : implements
    CompletionProvider <|-- SnippetCompletionProvider : implements
    
    UniversalCompletionProvider --> CompletionProvider : creates
    
    CompletionContext --> CompletionTrigger : contains
    CompletionItem --> CompletionItemKind : has
    
    CompletionWindowController --> CompletionCellView : displays
    
    CompletionCache --> CachedCompletion : stores
    
    %% Styling - Dark mode friendly colors
    classDef manager fill:#6366f120,stroke:#6366f1,stroke-width:3px,color:#fff
    classDef provider fill:#8b5cf620,stroke:#8b5cf6,stroke-width:2px,color:#fff
    classDef context fill:#10b98120,stroke:#10b981,stroke-width:2px,color:#fff
    classDef ui fill:#3b82f620,stroke:#3b82f6,stroke-width:2px,color:#fff
    classDef cache fill:#f59e0b20,stroke:#f59e0b,stroke-width:2px,color:#fff
    classDef enum fill:#06b6d420,stroke:#06b6d4,stroke-width:2px,color:#fff
    
    class CompletionManager manager
    class CompletionProvider provider
    class UniversalCompletionProvider provider
    class SwiftCompletionProvider provider
    class LSPCompletionProvider provider
    class KeywordCompletionProvider provider
    class SnippetCompletionProvider provider
    class CompletionContext context
    class CompletionSession context
    class CompletionItem context
    class CompletionWindowController ui
    class CompletionCellView ui
    class CompletionCache cache
    class CachedCompletion cache
    class CompletionTrigger enum
    class CompletionItemKind enum
```

## Completion Flow

```mermaid
sequenceDiagram
    participant User
    participant TextView
    participant CompletionManager
    participant Provider
    participant Cache
    participant UI

    User->>TextView: Type character
    TextView->>CompletionManager: Trigger completion
    CompletionManager->>Cache: Check cache
    
    alt Cache hit
        Cache-->>CompletionManager: Return cached items
    else Cache miss
        CompletionManager->>Provider: Request completions
        Provider-->>CompletionManager: Return items
        CompletionManager->>Cache: Store items
    end
    
    CompletionManager->>UI: Show completion window
    User->>UI: Select item
    UI->>CompletionManager: Apply completion
    CompletionManager->>TextView: Insert text
```

## Key Features

1. **Multi-Provider Support**: Different providers for different languages
2. **Async Processing**: Non-blocking completion requests
3. **Smart Caching**: LRU cache with context-aware invalidation
4. **Debouncing**: Prevents excessive completion requests
5. **Filtering & Sorting**: Client-side filtering of results
6. **LSP Integration**: Full Language Server Protocol support
7. **Snippet Expansion**: Template-based code snippets