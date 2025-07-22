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
    classDef input fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef detection fill:#FF950020,stroke:#FF9500,stroke-width:2px,color:#1D1D1F
    classDef coordinator fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef swift fill:#AF52DE20,stroke:#AF52DE,stroke-width:2px,color:#1D1D1F
    classDef regex fill:#FF3B3020,stroke:#FF3B30,stroke-width:2px,color:#1D1D1F
    classDef process fill:#34C75920,stroke:#34C759,stroke-width:2px,color:#1D1D1F
    classDef perf fill:#8E8E9320,stroke:#8E8E93,stroke-width:2px,color:#1D1D1F
    
    class FILE input
    class CONTENT input
    class MANUAL input
    class LDS detection
    class DETECT detection
    class LANG detection
    class REG detection
    class COORD coordinator
    class SELECT coordinator
    class CACHE coordinator
    class SS swift
    class PARSE swift
    class VISIT swift
    class ASTCACHE swift
    class RH regex
    class PATTERNS regex
    class TOKENIZE regex
    class TOKENS process
    class MERGE process
    class OPTIMIZE process
    class ATTRS process
    class THEME process
    class ASYNC process
    class DEBOUNCE perf
    class VIEWPORT perf
    class INCREMENTAL perf
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