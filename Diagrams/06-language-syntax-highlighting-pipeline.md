# Language Support & Syntax Highlighting Pipeline

This diagram shows the complete pipeline for language detection and syntax highlighting, including both SwiftSyntax and regex-based paths.

```mermaid
flowchart TB
    %% Input
    subgraph "Input Sources"
        FILE[File Extension<br/>.swift, .py, .js]
        CONTENT[File Content<br/>Shebang, Keywords]
        MANUAL[Manual Selection<br/>setLanguage]
    end

    %% Language Detection
    subgraph "Language Detection"
        LDS[LanguageDetectionService]
        DETECT[Detection Pipeline<br/>1. Extension Map<br/>2. Content Analysis<br/>3. Heuristics]
        LANG[LanguageConfig<br/>- identifier<br/>- extensions<br/>- highlighter]
    end

    %% Language Registry
    subgraph "Language Registry"
        REG[Language Registry<br/>17+ Languages]
        SWIFT[Swift]
        PYTHON[Python]
        JS[JavaScript/TypeScript]
        OTHER[Rust, Go, C/C++,<br/>Java, Ruby, etc.]
    end

    %% Highlighting Coordinator
    subgraph "SyntaxHighlightingCoordinator"
        COORD[Coordinator]
        SELECT[Highlighter Selection<br/>Based on Language]
        CACHE[Highlighting Cache<br/>LRU with TTL]
    end

    %% Highlighter Types
    subgraph "Highlighters"
        subgraph "SwiftSyntax Path"
            SS[SwiftSyntaxHighlighter]
            PARSE[Swift Parser<br/>Full AST]
            VISIT[Syntax Visitor<br/>Token Classification]
            ASTCACHE[AST Cache]
        end
        
        subgraph "Regex Path"
            RH[RegexHighlighter]
            PATTERNS[Language Patterns<br/>Keywords, Strings,<br/>Comments, etc.]
            TOKENIZE[Tokenizer<br/>Pattern Matching]
        end
    end

    %% Token Processing
    subgraph "Token Processing"
        TOKENS[Token Stream<br/>- type<br/>- range<br/>- attributes]
        MERGE[Token Merger<br/>Combine Overlaps]
        OPTIMIZE[Optimization<br/>Batch Updates]
    end

    %% Rendering
    subgraph "Rendering Pipeline"
        ATTRS[NSAttributedString<br/>Builder]
        THEME[Theme Application<br/>Colors, Fonts]
        ASYNC[Async Renderer<br/>Main Thread Updates]
    end

    %% Performance
    subgraph "Performance Features"
        DEBOUNCE[Debouncer<br/>250ms default]
        VIEWPORT[Viewport Only<br/>Visible Range]
        INCREMENTAL[Incremental<br/>Updates]
    end

    %% Flow - Language Detection
    FILE --> LDS
    CONTENT --> LDS
    MANUAL --> LDS
    
    LDS --> DETECT
    DETECT --> LANG
    
    LANG --> REG
    REG --> SWIFT
    REG --> PYTHON
    REG --> JS
    REG --> OTHER
    
    %% Flow - Highlighting
    LANG --> COORD
    COORD --> SELECT
    SELECT --> CACHE
    
    CACHE -->|Hit| ATTRS
    CACHE -->|Miss| HIGHLIGHTER{Language?}
    
    HIGHLIGHTER -->|Swift| SS
    HIGHLIGHTER -->|Others| RH
    
    %% SwiftSyntax Path
    SS --> PARSE
    PARSE --> ASTCACHE
    ASTCACHE --> VISIT
    VISIT --> TOKENS
    
    %% Regex Path
    RH --> PATTERNS
    PATTERNS --> TOKENIZE
    TOKENIZE --> TOKENS
    
    %% Token Processing
    TOKENS --> MERGE
    MERGE --> OPTIMIZE
    OPTIMIZE --> ATTRS
    
    %% Rendering
    ATTRS --> THEME
    THEME --> ASYNC
    
    %% Performance Integration
    COORD --> DEBOUNCE
    DEBOUNCE --> VIEWPORT
    VIEWPORT --> INCREMENTAL
    INCREMENTAL --> ASYNC
    
    %% Output
    ASYNC --> RENDER[Rendered Text]

    %% Styling - Dark mode friendly colors
    classDef input fill:#3b82f620,stroke:#3b82f6,stroke-width:2px,color:#fff
    classDef detection fill:#f59e0b20,stroke:#f59e0b,stroke-width:2px,color:#fff
    classDef coordinator fill:#6366f120,stroke:#6366f1,stroke-width:2px,color:#fff
    classDef swift fill:#8b5cf620,stroke:#8b5cf6,stroke-width:2px,color:#fff
    classDef regex fill:#ec489920,stroke:#ec4899,stroke-width:2px,color:#fff
    classDef process fill:#10b98120,stroke:#10b981,stroke-width:2px,color:#fff
    classDef perf fill:#6b728020,stroke:#6b7280,stroke-width:2px,color:#fff
    
    class FILE,CONTENT,MANUAL input
    class LDS,DETECT,LANG,REG detection
    class COORD,SELECT,CACHE coordinator
    class SS,PARSE,VISIT,ASTCACHE swift
    class RH,PATTERNS,TOKENIZE regex
    class TOKENS,MERGE,OPTIMIZE,ATTRS,THEME,ASYNC process
    class DEBOUNCE,VIEWPORT,INCREMENTAL perf
```

## Language Configuration Example

```swift
struct LanguageConfig {
    let identifier: String
    let displayName: String
    let fileExtensions: [String]
    let highlighterType: HighlighterType
    let completionProvider: CompletionProvider?
    let indentationRules: IndentationRules
}

enum HighlighterType {
    case swiftSyntax
    case regex(patterns: LanguagePatterns)
}
```

## Performance Optimizations

1. **AST Caching**: SwiftSyntax ASTs cached for reuse
2. **LRU Cache**: Recently highlighted documents cached
3. **Viewport Rendering**: Only visible text highlighted
4. **Incremental Updates**: Only changed regions re-highlighted
5. **Debouncing**: Rapid changes batched together
6. **Background Processing**: Heavy parsing off main thread
7. **Token Batching**: Multiple tokens applied in single update