# Language Support & Syntax Highlighting Pipeline

This diagram shows the complete pipeline for language detection and syntax highlighting, including both SwiftSyntax and regex-based paths, with sophisticated performance optimization capabilities including multiple highlighting strategies, intelligent caching, error recovery, and comprehensive monitoring.

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
        REG[Language Registry<br/>20+ Languages]
        SWIFT[Swift]
        PYTHON[Python]
        JS[JavaScript/TypeScript]
        JSON["JSON (FastTokenizer)"]
        OTHER[Rust, Go, C/C++,<br/>Java, Ruby, etc.]
    end

    %% Advanced Coordination Layer
    subgraph "Advanced Coordination Layer"
        COORD[SyntaxHighlightingCoordinator]
        OPTCOORD["OptimizedSyntaxHighlightingCoordinator<br/>📊 Circuit Breaker (P95/P99)<br/>🔄 Performance Degradation Protection<br/>📈 Chunking Strategies<br/>⚡ Performance Tracking"]
        STRATEGY[Strategy Selection<br/>File Size & Performance Based]
        MEMMON[MemoryMonitor Integration<br/>📊 Resource-Aware Processing<br/>🔍 Memory Pressure Detection<br/>⚙️ Adaptive Processing]
    end

    %% Smart Caching System
    subgraph "Smart Caching System"
        SMARTCACHE[SmartTokenCache<br/>🎯 Viewport-Aware Caching<br/>🔮 Predictive Prefetching<br/>📊 Cache Hit Rate Monitoring<br/>🧠 Intelligent Cache Warming]
        CACHESTATS[Cache Statistics<br/>Hit Rate: 85-95%<br/>Memory Usage<br/>Eviction Patterns]
        LRULOGIC[LRU Eviction Logic<br/>With Memory Monitoring]
        PREFETCH[Predictive Prefetching<br/>Based on Scroll Patterns]
    end

    %% Highlighting Strategies
    subgraph "Highlighting Strategies"
        subgraph "Standard Path"
            SS[SwiftSyntaxHighlighter]
            RH[RegexHighlighter]
        end
        
        subgraph "Performance Strategies"
            STREAMING[StreamingHighlighter<br/>📁 500KB+ Files<br/>🔄 AsyncSequence Processing<br/>📊 Chunk-by-Chunk Rendering]
            VIEWPORT_COORD[ViewportSyntaxCoordinator<br/>👁️ Viewport-Only Highlighting<br/>🎯 Smart Boundary Detection<br/>⚡ Ultra-Fast Updates]
            BACKGROUND[BackgroundSyntaxHighlighter<br/>🎯 Priority Queuing<br/>📊 Processing Statistics<br/>⚙️ Resource Balancing]
            FASTJSON[FastJSONTokenizer<br/>⚡ Specialized JSON Performance<br/>🔍 Streaming Parser<br/>📊 Optimized Token Stream]
        end
    end

    %% Error Recovery & Resilience
    subgraph "Error Recovery & Resilience"
        ERRORRECOV["ErrorRecoveryCoordinator (Actor)<br/>🔄 Automatic Retry Logic<br/>📊 Failure Pattern Analysis<br/>⚙️ Progressive Fallback"]
        SYNTAXERROR[SyntaxHighlightingError<br/>🛡️ Recovery Strategies<br/>📊 Error Classification<br/>🔄 Retry Policies]
        FALLBACK[Fallback Highlighting<br/>💡 Plain Text Mode<br/>🎨 Basic Syntax Colors<br/>⚡ Minimal Processing]
        CIRCUITBREAKER[Circuit Breaker Pattern<br/>🔒 Automatic Protection<br/>📊 Health Monitoring<br/>⚙️ Smart Recovery]
    end

    %% Token Processing Pipeline
    subgraph "Token Processing Pipeline"
        TOKENS[Token Stream<br/>- type<br/>- range<br/>- attributes<br/>- priority]
        MERGE[Token Merger<br/>🔄 Combine Overlaps<br/>⚡ Batch Optimization]
        PRIORITIZE[Priority Processing<br/>🎯 Viewport First<br/>📊 Performance Aware]
        PROGRESSIVE[Progressive Rendering<br/>📁 Large File Support<br/>🔄 Incremental Updates]
    end

    %% Rendering Pipeline
    subgraph "Rendering Pipeline"
        ATTRS[NSAttributedString Builder<br/>📊 Performance Optimized<br/>🎯 Batch Updates]
        THEME[Theme Application<br/>🎨 Colors, Fonts<br/>⚡ Cached Attributes]
        ASYNC[Async Renderer<br/>🔄 Main Thread Coordination<br/>📊 Frame Rate Monitoring]
        ADAPTIVE[Adaptive Rendering<br/>📊 60fps Target<br/>⚙️ Quality Scaling]
    end

    %% Performance Monitoring
    subgraph "Performance Monitoring & Analytics"
        PERFTRACK[SyntaxHighlightingPerformanceTracker<br/>📊 P95/P99 Metrics<br/>⏱️ Tokenization Time<br/>💾 Cache Hit Rate<br/>🎯 Apply Attributes Time]
        DEBOUNCE[Smart Debouncer<br/>⏱️ 250ms default<br/>📊 Adaptive Timing<br/>🎯 Event Coalescing]
        VIEWPORT[Viewport Manager<br/>👁️ Visible Range<br/>📊 Scroll Prediction<br/>⚡ Smart Boundaries]
        INCREMENTAL[Incremental Engine<br/>🔄 Change Detection<br/>📊 Minimal Updates<br/>⚡ Delta Processing]
        CHUNKING[Advanced Chunking<br/>📁 Dynamic Sizing<br/>📊 Performance Aware<br/>⚙️ Memory Conscious]
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
    REG --> JSON
    REG --> OTHER
    
    %% Flow - Advanced Coordination
    LANG --> COORD
    COORD --> OPTCOORD
    OPTCOORD --> MEMMON
    MEMMON --> STRATEGY
    
    %% Flow - Caching Integration
    STRATEGY --> SMARTCACHE
    SMARTCACHE --> CACHESTATS
    SMARTCACHE --> LRULOGIC
    SMARTCACHE --> PREFETCH
    
    %% Flow - Strategy Selection
    SMARTCACHE -->|Cache Hit| ATTRS
    SMARTCACHE -->|Cache Miss| STRATEGY_DECISION{File Size &<br/>Performance?}
    
    STRATEGY_DECISION -->|Standard| SS
    STRATEGY_DECISION -->|Standard| RH
    STRATEGY_DECISION -->|500KB+| STREAMING
    STRATEGY_DECISION -->|Viewport Only| VIEWPORT_COORD
    STRATEGY_DECISION -->|Background| BACKGROUND
    STRATEGY_DECISION -->|JSON| FASTJSON
    
    %% Flow - Error Recovery Integration
    SS --> ERRORRECOV
    RH --> ERRORRECOV
    STREAMING --> ERRORRECOV
    VIEWPORT_COORD --> ERRORRECOV
    BACKGROUND --> ERRORRECOV
    FASTJSON --> ERRORRECOV
    
    ERRORRECOV --> SYNTAXERROR
    SYNTAXERROR -->|Retry| STRATEGY_DECISION
    SYNTAXERROR -->|Fallback| FALLBACK
    ERRORRECOV --> CIRCUITBREAKER
    CIRCUITBREAKER --> FALLBACK
    
    %% Flow - Token Processing
    SS --> TOKENS
    RH --> TOKENS
    STREAMING --> TOKENS
    VIEWPORT_COORD --> TOKENS
    BACKGROUND --> TOKENS
    FASTJSON --> TOKENS
    FALLBACK --> TOKENS
    
    TOKENS --> MERGE
    MERGE --> PRIORITIZE
    PRIORITIZE --> PROGRESSIVE
    PROGRESSIVE --> ATTRS
    
    %% Flow - Rendering
    ATTRS --> THEME
    THEME --> ASYNC
    ASYNC --> ADAPTIVE
    
    %% Flow - Performance Integration
    OPTCOORD --> DEBOUNCE
    OPTCOORD --> PERFTRACK
    DEBOUNCE --> VIEWPORT
    VIEWPORT --> INCREMENTAL
    INCREMENTAL --> CHUNKING
    CHUNKING --> CIRCUITBREAKER
    PERFTRACK --> ADAPTIVE
    MEMMON --> ADAPTIVE
    
    %% Output
    ADAPTIVE --> RENDER[📱 Rendered Text<br/>60fps Target<br/>Resource Aware]

    %% Styling - Enhanced color scheme
    classDef input fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef detection fill:#FF950020,stroke:#FF9500,stroke-width:2px,color:#1D1D1F
    classDef coordinator fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef cache fill:#5856D620,stroke:#5856D6,stroke-width:2px,color:#1D1D1F
    classDef strategies fill:#AF52DE20,stroke:#AF52DE,stroke-width:2px,color:#1D1D1F
    classDef error fill:#FF3B3020,stroke:#FF3B30,stroke-width:2px,color:#1D1D1F
    classDef process fill:#34C75920,stroke:#34C759,stroke-width:2px,color:#1D1D1F
    classDef perf fill:#8E8E9320,stroke:#8E8E93,stroke-width:2px,color:#1D1D1F
    classDef render fill:#00D4AA20,stroke:#00D4AA,stroke-width:2px,color:#1D1D1F
    
    class FILE,CONTENT,MANUAL input
    class LDS,DETECT,LANG,REG,SWIFT,PYTHON,JS,JSON,OTHER detection
    class COORD,OPTCOORD,STRATEGY,MEMMON coordinator
    class SMARTCACHE,CACHESTATS,LRULOGIC,PREFETCH cache
    class SS,RH,STREAMING,VIEWPORT_COORD,BACKGROUND,FASTJSON strategies
    class ERRORRECOV,SYNTAXERROR,FALLBACK,CIRCUITBREAKER error
    class TOKENS,MERGE,PRIORITIZE,PROGRESSIVE process
    class ATTRS,THEME,ASYNC,ADAPTIVE render
    class DEBOUNCE,VIEWPORT,INCREMENTAL,PERFTRACK,CHUNKING perf
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
    let performanceProfile: PerformanceProfile
}

enum HighlighterType {
    case swiftSyntax
    case regex(patterns: LanguagePatterns)
    case streaming(chunkSize: Int)
    case fastJSON
    case viewport(boundaries: ViewportBoundaries)
}

struct PerformanceProfile {
    let maxFileSize: Int
    let preferredStrategy: HighlightingStrategy
    let fallbackStrategy: HighlightingStrategy
    let circuitBreakerThreshold: TimeInterval
}
```

## Advanced Performance Optimizations

### 1. Multi-Strategy Highlighting System
- **StreamingHighlighter**: AsyncSequence processing for 500KB+ files
- **ViewportSyntaxCoordinator**: Ultra-fast viewport-only highlighting
- **BackgroundSyntaxHighlighter**: Priority queuing with resource balancing
- **FastJSONTokenizer**: Specialized high-performance JSON parsing

### 2. Smart Caching Infrastructure
- **Viewport-Aware Caching**: Intelligently caches based on visible content
- **Predictive Prefetching**: Anticipates user scroll patterns
- **Cache Hit Rate Monitoring**: 85-95% target hit rates with analytics
- **Intelligent Cache Warming**: Proactive caching of likely-to-be-used content
- **LRU Eviction with Memory Monitoring**: Memory-conscious cache management

### 3. Error Recovery & Resilience
- **ErrorRecoveryCoordinator**: Actor-based automatic retry logic
- **Circuit Breaker Patterns**: Automatic protection with P95/P99 monitoring
- **Progressive Fallback System**: Graceful degradation through multiple strategies
- **SyntaxHighlightingError**: Comprehensive error classification and recovery

### 4. Memory Management Integration
- **MemoryMonitor Integration**: Resource-aware processing decisions
- **Memory Pressure Detection**: Automatic adaptation to system constraints
- **Adaptive Processing**: Dynamic adjustment based on available resources
- **Progressive Rendering**: Memory-efficient rendering for large files

### 5. Performance Monitoring & Analytics
- **P95/P99 Metrics**: Advanced percentile tracking for performance optimization
- **Circuit Breaker Monitoring**: Health tracking with automatic recovery
- **Cache Statistics**: Hit rates, memory usage, and eviction pattern analysis
- **Processing Statistics**: Detailed breakdown of tokenization and rendering times

## OptimizedSyntaxHighlightingCoordinator Configuration

```swift
let memoryMonitor = MemoryMonitor()

let coordinator = OptimizedSyntaxHighlightingCoordinator(
    memoryMonitor: memoryMonitor,
    configuration: .performance
)

var configuration = OptimizedSyntaxHighlightingCoordinator.HighlightingConfiguration.default
configuration.enableViewportOptimization = true
configuration.viewportPadding = 500
configuration.maxChunkSize = 5_000
configuration.enableIncrementalHighlighting = true
configuration.cacheWarmingEnabled = true
configuration.circuitBreakerThreshold = 0.1

coordinator.updateConfiguration(configuration)
```

## AsyncSyntaxHighlighter Cache Settings

```swift
let highlighter = AsyncSyntaxHighlighter(memoryMonitor: memoryMonitor)

await highlighter.configureCacheSettings(
    maxCacheSize: 100,
    maxMemoryUsageMB: 50.0,
    staleThreshold: .hours(1)
)
```

## Highlighting Strategy Selection Logic

```swift
func selectHighlightingStrategy(
    fileSize: Int,
    language: LanguageConfig,
    memoryPressure: Double,
    performanceMetrics: PerformanceMetrics
) -> HighlightingStrategy {
    
    // Circuit breaker check
    if performanceMetrics.p95ResponseTime > circuitBreakerThreshold {
        return .fallback(.plainText)
    }
    
    // Memory pressure adaptation
    if memoryPressure > 0.8 {
        return .viewport(boundaries: .conservative)
    }
    
    // File size-based strategy selection
    switch fileSize {
    case 0..<10_000:
        return .standard(language.highlighterType)
        
    case 10_000..<100_000:
        return .background(priority: .normal)
        
    case 100_000..<500_000:
        return .viewport(boundaries: .standard)
        
    case 500_000...:
        return .streaming(chunkSize: largeFileChunkSize)
        
    default:
        return .fallback(.basicSyntax)
    }
}
```

## Error Recovery Strategies

```swift
enum RecoveryStrategy {
    case retry(attempts: Int, backoff: TimeInterval)
    case fallbackToSimpler(strategy: HighlightingStrategy)
    case enableCircuitBreaker(threshold: TimeInterval)
    case reduceQuality(level: QualityLevel)
    case plainTextMode
}

enum SyntaxHighlightingError: Error {
    case parsingTimeout(TimeInterval)
    case memoryPressure(usage: Double)
    case circuitBreakerTripped(threshold: TimeInterval)
    case tokenizationFailure(reason: String)
    
    var recoveryStrategy: RecoveryStrategy {
        switch self {
        case .parsingTimeout(let time) where time < 0.2:
            return .retry(attempts: 2, backoff: 0.1)
        case .memoryPressure(let usage) where usage > 0.9:
            return .fallbackToSimpler(.viewport(boundaries: .minimal))
        case .circuitBreakerTripped:
            return .plainTextMode
        case .tokenizationFailure:
            return .fallbackToSimpler(.basicSyntax)
        default:
            return .enableCircuitBreaker(threshold: 0.05)
        }
    }
}
```
