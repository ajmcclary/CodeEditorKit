# Text Processing Pipeline

This diagram illustrates the modern TextKit2-based text processing pipeline with sophisticated async processing, comprehensive performance optimization, and intelligent coordination mechanisms based on the latest codebase implementations.

```mermaid
flowchart TB
    %% Input Layer
    subgraph "Input Sources"
        KEYBOARD[Keyboard Input]
        PASTE[Paste Operations]
        API[API Calls<br/>setText, insertText]
        UNDO[Undo/Redo]
    end

    %% Text Storage
    subgraph "Text Storage Layer"
        TS[NSTextStorage<br/>Main text buffer]
        TSN[Text Storage Notifications<br/>willProcessEditing<br/>didProcessEditing]
        ATTR[Attribute Management<br/>Syntax highlighting<br/>Text attributes]
    end

    %% Modern TextKit2 Components
    subgraph "Modern TextKit2 Engine"
        MTK2[ModernTextKit2Bridge<br/>Pure TextKit2 implementation<br/>Cross-platform abstractions<br/>No TextKit1 fallbacks]
        NTLM[NSTextLayoutManager<br/>Delegate support<br/>Advanced layout controls<br/>Fragment enumeration]
        TVLC[TextViewportLayoutController<br/>Viewport-based layout<br/>Efficient scrolling<br/>Delegate-driven updates]
        TK2RO[TextKit2RenderingOptimizer<br/>Fragment caching & recycling<br/>Large file optimizations<br/>Adaptive performance tuning]
    end

    %% Actor-Based Processing System
    subgraph "Actor-Based Processing System"
        AC[ActorCoordinator<br/>Central coordination<br/>Dependency injection<br/>Resource management]
        ATP[AsyncTextProcessor<br/>Priority queues<br/>Adaptive performance<br/>System load monitoring]
        TPA[TextProcessingActor<br/>Thread-safe operations<br/>Background processing]
        AOF[AsyncOperationManager<br/>Debouncing & throttling<br/>Priority scheduling<br/>Retry logic with backoff]
    end

    %% Unified Performance System
    subgraph "Unified Performance System"
        UPS[UnifiedPerformanceSystem<br/>Comprehensive metrics<br/>Auto-optimization<br/>Performance profiles]
        VM[ViewportManager<br/>Predictive prefetching<br/>Scroll velocity tracking<br/>Cache optimization]
        MM[MemoryMonitor<br/>Dependency injection<br/>Cleanup handlers<br/>Pressure detection]
        PMA[PerformanceMetricsActor<br/>Real-time tracking<br/>Aggregated insights]
    end

    %% Optimized Line Index System
    subgraph "Optimized Line Index System"
        OLIC["OptimizedLineIndexCache<br/>Red-Black tree structure<br/>O(log n) operations<br/>Lookup cache with LRU"]
        VR[VersionedRange<br/>Change tracking<br/>Conflict resolution<br/>Delta processing]
        IU[Incremental Updates<br/>Multi-line changes<br/>Batch operations]
        RIB[RangeInvalidationBuffer<br/>Buffered invalidations<br/>Change coalescence]
    end

    %% Cross-Platform Text Processing
    subgraph "Cross-Platform Processing"
        PC[PlatformCapabilities<br/>TextKit version detection<br/>Feature compatibility<br/>Performance recommendations]
        CPC[CrossPlatformCoordinator<br/>Event coordination<br/>Platform abstractions]
        TPH[TextKit2PerformanceHelper<br/>Platform-specific optimizations<br/>Capability detection]
    end

    %% Text Processing Pipeline
    subgraph "Text Processing Operations"
        VAL[Input Validation<br/>Unicode normalization<br/>Character validation]
        TRANS[Text Transformation<br/>Tab expansion<br/>Auto-indentation]
        RANGE[Range Calculation<br/>Affected ranges<br/>Line mapping]
    end

    %% Advanced Caching System
    subgraph "Multi-Level Caching"
        CCA[CacheCoordinatorActor<br/>Unified cache management<br/>Smart eviction policies]
        LRU[LRU Caches<br/>Fragment cache<br/>Range cache<br/>Viewport cache]
        SC[SmartTokenCache<br/>Syntax highlighting cache<br/>Performance tracking]
    end

    %% Rendering Pipeline
    subgraph "Rendering"
        DRAW[Drawing Context<br/>Core Graphics<br/>Hardware acceleration]
        LAYERS[Layer Management<br/>Text layer<br/>Selection layer<br/>Cursor layer]
        COMP[Compositing<br/>Final output<br/>60fps target]
    end

    %% Event System
    subgraph "Event Notifications"
        EVENTS[Event Emission<br/>textChanged<br/>selectionChanged<br/>layoutChanged<br/>performanceUpdated]
    end

    %% Text Processing Pipeline
    subgraph "Text Processing"
        VAL[Input Validation<br/>Unicode normalization<br/>Character validation]
        TRANS[Text Transformation<br/>Tab expansion<br/>Auto-indentation]
        RANGE[Range Calculation<br/>Affected ranges<br/>Line mapping]
    end

    %% Rendering Pipeline
    subgraph "Rendering"
        DRAW[Drawing Context<br/>Core Graphics]
        LAYERS[Layer Management<br/>Text layer<br/>Selection layer<br/>Cursor layer]
        COMP[Compositing<br/>Final output]
    end

    %% Event System
    subgraph "Event Notifications"
        EVENTS[Event Emission<br/>textChanged<br/>selectionChanged<br/>layoutChanged]
    end

    %% Flow - Input Processing
    KEYBOARD --> VAL
    PASTE --> VAL
    API --> VAL
    UNDO --> VAL
    
    %% Input validation through cross-platform coordination
    VAL --> CPC
    CPC --> PC
    PC --> AOF
    
    %% Actor-based processing coordination
    AOF --> AC
    AC --> ATP
    AC --> TPA
    
    %% Text transformation and processing
    VAL --> TRANS
    TRANS --> ATP
    ATP --> RANGE
    RANGE --> TS
    
    %% Storage Processing and Notifications
    TS --> TSN
    TSN --> ATTR
    
    %% Optimized Line Index Updates
    ATTR --> VR
    VR --> IU
    IU --> RIB
    RIB --> OLIC
    
    %% Modern TextKit2 Flow with Performance Helper
    TS --> MTK2
    MTK2 --> TPH
    TPH --> NTLM
    NTLM --> TVLC
    TVLC --> TK2RO
    
    %% Unified Performance System Integration
    AC --> UPS
    UPS --> VM
    UPS --> MM
    UPS --> PMA
    
    %% Advanced Caching Integration
    AC --> CCA
    CCA --> LRU
    LRU --> SC
    SC --> TK2RO
    
    %% Viewport Management
    VM --> TVLC
    VM --> TK2RO
    
    %% Memory Management Integration
    MM --> CCA
    MM --> TK2RO
    MM --> OLIC
    
    %% Rendering Flow with Performance Coordination
    TK2RO --> DRAW
    LRU --> DRAW
    DRAW --> LAYERS
    LAYERS --> COMP
    
    %% Enhanced Event Flow with Performance Metrics
    TSN --> EVENTS
    IU --> EVENTS
    COMP --> EVENTS
    UPS --> EVENTS
    PMA --> EVENTS
    VM --> EVENTS

    %% Styling - Dark mode friendly colors
    classDef input fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef storage fill:#AF52DE20,stroke:#AF52DE,stroke-width:2px,color:#1D1D1F
    classDef textkit2 fill:#34C75920,stroke:#34C759,stroke-width:2px,color:#1D1D1F
    classDef actor fill:#32D74B20,stroke:#32D74B,stroke-width:2px,color:#1D1D1F
    classDef performance fill:#FF950020,stroke:#FF9500,stroke-width:2px,color:#1D1D1F
    classDef line fill:#5856D620,stroke:#5856D6,stroke-width:2px,color:#1D1D1F
    classDef platform fill:#FF375F20,stroke:#FF375F,stroke-width:2px,color:#1D1D1F
    classDef cache fill:#30D15820,stroke:#30D158,stroke-width:2px,color:#1D1D1F
    classDef process fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef render fill:#FF453A20,stroke:#FF453A,stroke-width:2px,color:#1D1D1F
    
    class KEYBOARD input
    class PASTE input
    class API input
    class UNDO input
    class TS storage
    class TSN storage
    class ATTR storage
    
    class MTK2 textkit2
    class NTLM textkit2
    class TVLC textkit2
    class TK2RO textkit2
    class TPH textkit2
    
    class AC actor
    class ATP actor
    class TPA actor
    class AOF actor
    
    class UPS performance
    class VM performance
    class MM performance
    class PMA performance
    
    class OLIC line
    class RIB line
    class IU line
    class VR line
    
    class PC platform
    class CPC platform
    
    class CCA cache
    class LRU cache
    class SC cache
    
    class VAL process
    class TRANS process
    class RANGE process
    
    class DRAW render
    class LAYERS render
    class COMP render
    class EVENTS render
```

## Modern Architecture Components

### 1. Actor-Based Coordination
```swift
@MainActor
public final class ActorCoordinator {
    public let textProcessor: TextProcessingActor
    public let cacheCoordinator: CacheCoordinatorActor
    public let fileSystem: FileSystemActor
    public let performanceMetrics: PerformanceMetricsActor
    public let documentState: DocumentStateActor
    public let errorRecovery: ErrorRecoveryCoordinator
    
    public func processText(
        _ text: String,
        processorType: TextProcessingActor.TextProcessor.ProcessorType,
        priority: TaskPriority = .high
    ) async throws -> String {
        do {
            return try await textProcessor.process(
                text: text,
                with: processorType,
                priority: priority
            )
        } catch {
            // Auto error recovery with retry logic
            if let recoverableError = error as? any RecoverableAsyncError {
                return try await errorRecovery.recover(from: recoverableError) {
                    try await self.textProcessor.process(
                        text: text,
                        with: processorType,
                        priority: priority
                    )
                }
            }
            throw error
        }
    }
}
```

### 2. Modern TextKit2 Bridge with Cross-Platform Support
```swift
@MainActor
internal class ModernTextKit2Bridge: NSObject {
    private weak var textView: PlatformTextView?
    private var textLayoutManager: NSTextLayoutManager? { textView?.textLayoutManager }
    private var textContentManager: NSTextContentManager? { textLayoutManager?.textContentManager }
    
    init(textView: PlatformTextView) {
        self.textView = textView
        super.init()
        ensureTextKit2Configuration()
    }
    
    private func ensureTextKit2Configuration() {
        // Configure delegate support and advanced layout controls
        textLayoutManager?.delegate = self
        textLayoutManager?.textViewportLayoutController.delegate = self
        textLayoutManager?.limitsLayoutForSuspiciousContents = true
        textLayoutManager?.usesFontLeading = true
    }
    
    func enumerateFragments(
        in textRange: NSTextRange,
        using block: (NSTextLayoutFragment) -> Bool
    ) {
        textLayoutManager?.enumerateTextLayoutFragments(
            from: textRange.location,
            options: [.ensuresLayout, .ensuresExtraLineFragment]
        ) { fragment in
            return block(fragment)
        }
    }
}
```

### 3. Advanced Async Text Processor with System Load Monitoring
```swift
actor AsyncTextProcessor {
    private var processingQueue = PriorityQueue<ProcessingTask>()
    private var activeTasks: [UUID: Task<ProcessingResult, Error>] = [:]
    private var maxConcurrentOperations: Int
    private var currentLoad: ProcessingLoad = .idle
    private var systemLoadMonitor: SystemLoadMonitor?
    private let performanceMonitor = ProcessingPerformanceMonitor()
    private var adaptiveSettings = AdaptiveSettings()
    private let memoryMonitor: MemoryMonitor
    
    @discardableResult
    func submit(
        text: String,
        range: NSRange,
        operation: ProcessingOperation,
        priority: TaskPriority = .normal,
        completion: @Sendable @escaping (Result<ProcessingResult, Error>) -> Void
    ) async -> ProcessingTaskHandle {
        let taskId = UUID()
        let cacheKey = ProcessingCacheKey(text: text, range: range, operation: operation)
        
        // Check cache first with LRU eviction
        let cache = await getCache()
        if let cachedResult = await cache.get(cacheKey) {
            logger.debug("Cache hit for operation: \(operation.name)")
            completion(.success(cachedResult))
            return ProcessingTaskHandle(id: taskId, processor: self)
        }
        
        // Create and enqueue processing task with adaptive batching
        let task = ProcessingTask(/*...*/)
        processingQueue.enqueue(task)
        await processNextTaskIfPossible()
        
        return ProcessingTaskHandle(id: taskId, processor: self)
    }
}
```

### 4. Optimized Line Index System with Red-Black Trees
```swift
public actor OptimizedLineIndexCache {
    private class LineNode {
        var lineStart: Int
        var lineLength: Int
        var subtreeLineCount: Int = 1
        var subtreeCharCount: Int = 0
        var isRed: Bool = true
        weak var parent: LineNode?
        var left: LineNode?
        var right: LineNode?
    }
    
    private var root: LineNode?
    private var lookupCache: [Int: (line: Int, column: Int)] = [:]
    
    /// Returns line and column for character offset - O(log n)
    public func lineAndColumn(for offset: Int) -> (line: Int, column: Int) {
        if let cached = lookupCache[offset] {
            return cached
        }
        
        let line = lineIndexForCharacterOffset(offset)
        let lineStart = characterOffsetForLine(line)
        let column = offset - lineStart
        
        let result = (line: line, column: column)
        
        // LRU cache management
        if lookupCache.count >= maxCacheSize {
            lookupCache.removeAll()
        }
        lookupCache[offset] = result
        
        return result
    }
}
```

### 5. Unified Performance System with Auto-Optimization
```swift
@MainActor
public final class UnifiedPerformanceSystem {
    public static let shared = UnifiedPerformanceSystem()
    
    private var metrics: [PerformanceMetricType: [PerformanceMetric]] = [:]
    private var activeOperations: [UUID: OperationInfo] = [:]
    private var performanceProfiles: [String: PerformanceProfile] = [:]
    
    public func track<T>(
        _ metricType: PerformanceMetricType,
        operation: () async throws -> T
    ) async throws -> T {
        let operationId = UUID()
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getMemoryUsage()
        
        activeOperations[operationId] = OperationInfo(/*...*/)
        
        do {
            let result = try await operation()
            let endTime = CFAbsoluteTimeGetCurrent()
            let endMemory = getMemoryUsage()
            
            await recordMetric(
                type: metricType,
                duration: endTime - startTime,
                memoryDelta: Int64(endMemory) - Int64(startMemory),
                success: true
            )
            
            return result
        } catch {
            await recordMetric(
                type: metricType,
                duration: CFAbsoluteTimeGetCurrent() - startTime,
                memoryDelta: 0,
                success: false,
                error: error
            )
            throw error
        }
    }
}
```

### 6. Advanced Viewport Manager with Predictive Prefetching
```swift
@MainActor
public final class ViewportManager: ObservableObject {
    @Published public private(set) var viewport: Viewport = .zero
    @Published public private(set) var metrics = ViewportMetrics()
    
    private var scrollVelocity: Double = 0.0
    private var renderingTasks: [UUID: Task<Void, Never>] = [:]
    private let rangeCache: LRUCache<ViewportManagerCacheKey, CachedViewportData>
    
    public func updateViewport() {
        // Calculate scroll velocity for predictive prefetching
        let currentTime = ProcessInfo.processInfo.systemUptime
        let currentPosition = visibleBounds.origin.y
        
        if lastScrollTime > 0 {
            let timeDelta = currentTime - lastScrollTime
            if timeDelta > 0 && timeDelta < 1.0 {
                scrollVelocity = (currentPosition - lastScrollPosition) / timeDelta
            }
        }
        
        // Perform viewport-based rendering
        performViewportRendering()
        
        // Trigger predictive prefetching if scrolling fast
        if abs(scrollVelocity) > 50.0 {
            performPredictivePrefetching()
        }
    }
}
```

## Performance Characteristics

| Operation | Complexity | Modern Optimization |
|-----------|------------|---------------------|
| Text Insertion | O(log n) | Actor-based async processing + Red-Black tree line indexing |
| Line Lookup | O(log n) → O(1) | Red-Black tree with LRU lookup cache + batch operations |
| Syntax Highlight | O(visible) | Viewport-aware rendering + smart token caching |
| Layout | O(viewport) | Predictive prefetching + fragment recycling + adaptive batching |
| Scrolling | O(1) | Velocity tracking + predictive prefetch + viewport caching |
| Range Updates | O(log n) | Delta processing + versioned ranges + change coalescence |
| Memory Management | O(1) | Dependency injection + cleanup handlers + multi-level caching |
| Cross-Platform Operations | O(1) | Platform capability detection + optimized abstractions |

## Advanced Optimizations

### Actor-Based Concurrency
1. **ActorCoordinator**: Central coordination with dependency injection for specialized actors
2. **AsyncTextProcessor**: Priority-based task queues with system load monitoring
3. **TextProcessingActor**: Thread-safe background processing with error recovery
4. **CacheCoordinatorActor**: Unified cache management with smart eviction policies
5. **PerformanceMetricsActor**: Real-time performance tracking with aggregated insights

### Unified Performance System
6. **UnifiedPerformanceSystem**: Comprehensive metrics tracking with auto-optimization
7. **Performance Profiles**: Adaptive configurations based on system conditions (low memory, high latency, CPU intensive)
8. **Automatic Recommendations**: AI-driven performance optimization suggestions
9. **Real-Time Health Monitoring**: Continuous system health assessment with issue detection

### Advanced TextKit2 Integration
10. **ModernTextKit2Bridge**: Pure TextKit2 implementation with cross-platform abstractions
11. **TextKit2RenderingOptimizer**: Fragment caching, recycling, and large file optimizations
12. **TextKit2PerformanceHelper**: Platform-specific optimizations with capability detection
13. **Delegate-Driven Updates**: Fine-grained control over layout behavior with viewport coordination

### Optimized Data Structures
14. **OptimizedLineIndexCache**: Red-Black tree for O(log n) line operations with LRU caching
15. **VersionedRange**: Conflict-free concurrent updates with sophisticated change tracking
16. **Multi-Level Caching**: Fragment cache, range cache, viewport cache with unified coordination
17. **Smart Token Cache**: Syntax highlighting cache with performance tracking and adaptive sizing

### Advanced Viewport Management
18. **Predictive Prefetching**: ViewportManager with scroll velocity tracking and content anticipation
19. **Adaptive Rendering**: Dynamic fragment management based on scroll patterns and system load
20. **Cache Optimization**: Viewport-aware caching with intelligent prefetch boundaries
21. **Performance Budgets**: 60fps rendering targets with automatic fallback strategies

### Cross-Platform Excellence
22. **PlatformCapabilities**: Runtime detection of TextKit2 support and feature availability
23. **CrossPlatformCoordinator**: Unified event coordination across macOS and iOS
24. **Platform Abstractions**: Seamless text processing across different Apple platforms
25. **Capability-Driven Optimization**: Automatic feature enablement based on platform capabilities

### Memory Management Innovation
26. **Dependency Injection**: MemoryMonitor instances injected through configuration for better testability
27. **Cleanup Handlers**: Hierarchical cleanup with priority-based resource management
28. **Pressure Detection**: Proactive memory pressure handling with automatic cache reduction
29. **Multi-Component Coordination**: Unified memory management across all text processing components

### Async Operations Excellence
30. **AsyncOperationManager**: Advanced debouncing, throttling, and retry logic with exponential backoff
31. **Priority Scheduling**: Critical operations prioritized over background tasks
32. **Cancellation Support**: Proper task cancellation with resource cleanup
33. **System Load Adaptation**: Dynamic concurrency adjustment based on system conditions