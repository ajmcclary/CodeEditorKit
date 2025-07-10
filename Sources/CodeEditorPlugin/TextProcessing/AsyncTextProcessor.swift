import Combine
import Foundation
import os.log

// MARK: - AsyncTextProcessor

/// Advanced async text processing with priority queues and adaptive performance
actor AsyncTextProcessor {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.codeeditor.plugin", category: "AsyncTextProcessor")
    
    /// Processing queue with priority support
    private var processingQueue = PriorityQueue<ProcessingTask>()
    
    /// Active processing tasks
    private var activeTasks: [UUID: Task<ProcessingResult, Error>] = [:]
    
    /// Maximum concurrent operations
    private let maxConcurrentOperations: Int
    
    /// Current processing load
    private var currentLoad: ProcessingLoad = .idle
    
    /// Performance monitor
    private let performanceMonitor = ProcessingPerformanceMonitor()
    
    /// Adaptive performance settings
    private var adaptiveSettings = AdaptiveSettings()
    
    /// Memory monitor
    private let memoryMonitor: MemoryMonitor
    
    /// Result cache
    private var resultCache: LRUCache<ProcessingCacheKey, ProcessingResult>?
    
    // MARK: - Initialization
    
    init(memoryMonitor: MemoryMonitor, maxConcurrentOperations: Int? = nil) {
        // Cap at 4 to prevent oversubscription on highly-threaded systems
        let defaultConcurrency = min(4, ProcessInfo.processInfo.activeProcessorCount)
        self.maxConcurrentOperations = maxConcurrentOperations ?? defaultConcurrency
        self.memoryMonitor = memoryMonitor
    }
    
    deinit {
        // Note: Cannot call async cleanup() from deinit
        // Users should call cleanup() explicitly before releasing the actor
        for task in activeTasks.values {
            task.cancel()
        }
    }
    
    private func getCache() async -> LRUCache<ProcessingCacheKey, ProcessingResult> {
        if let cache = resultCache {
            return cache
        }
        
        // Initialize cache on MainActor
        let cache = await MainActor.run {
            LRUCache<ProcessingCacheKey, ProcessingResult>(capacity: 100, memoryMonitor: self.memoryMonitor)
        }
        resultCache = cache
        return cache
    }
    
    // MARK: - Public Methods
    
    /// Submit a text processing task
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
        
        // Check cache first
        let cache = await getCache()
        if let cachedResult = await cache.get(cacheKey) {
            logger.debug("Cache hit for operation: \(operation.name)")
            await performanceMonitor.recordCacheHit()
            completion(.success(cachedResult))
            return ProcessingTaskHandle(id: taskId, processor: self)
        }
        
        await performanceMonitor.recordCacheMiss()
        
        // Create processing task
        let task = ProcessingTask(
            id: taskId,
            text: text,
            range: range,
            operation: operation,
            priority: priority,
            completion: completion
        )
        
        // Add to queue
        processingQueue.enqueue(task)
        
        // Start processing if under limit
        await processNextTaskIfPossible()
        
        return ProcessingTaskHandle(id: taskId, processor: self)
    }
    
    /// Cancel a processing task
    func cancel(taskId: UUID) async {
        // Remove from queue if not started
        processingQueue.remove { $0.id == taskId }
        
        // Cancel if active
        if let activeTask = activeTasks[taskId] {
            activeTask.cancel()
            activeTasks.removeValue(forKey: taskId)
            await performanceMonitor.recordCancellation()
        }
    }
    
    /// Get current processing status
    func getStatus() async -> ProcessingStatus {
        ProcessingStatus(
            queuedTasks: processingQueue.count,
            activeTasks: activeTasks.count,
            currentLoad: currentLoad,
            performanceMetrics: await performanceMonitor.getCurrentMetrics()
        )
    }
    
    /// Clear all pending tasks
    func clearQueue() {
        processingQueue.clear()
        
        // Cancel all active tasks
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
        
        updateProcessingLoad()
    }
    
    /// Cleanup method to be called before deallocation
    func cleanup() async {
        clearQueue()
        
        // Wait for all active tasks to complete
        for (_, task) in activeTasks {
            _ = try? await task.value
        }
        
        // Clear the cache
        resultCache = nil
    }
    
    // MARK: - Private Methods
    
    private func processNextTaskIfPossible() async {
        guard activeTasks.count < maxConcurrentOperations,
              let nextTask = processingQueue.dequeue() else {
            return
        }
        
        // Capture task data for use in Task closure
        let taskId = nextTask.id
        let taskText = nextTask.text
        let taskRange = nextTask.range
        let taskOperation = nextTask.operation
        let taskCompletion = nextTask.completion
        
        // Start processing with proper isolation
        let processingTask = Task { [weak self] () -> ProcessingResult in
            guard let self else {
                throw ProcessingError.processorDeallocated
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            do {
                // Create local task for processing to avoid capturing nextTask
                let localTask = ProcessingTask(
                    id: taskId,
                    text: taskText,
                    range: taskRange,
                    operation: taskOperation,
                    priority: nextTask.priority,
                    completion: taskCompletion
                )
                
                // Perform the actual processing
                let result = try await self.performProcessing(localTask)
                
                // Record metrics
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                await self.performanceMonitor.recordProcessingTime(duration, for: taskOperation)
                
                // Cache the result
                let cacheKey = ProcessingCacheKey(
                    text: taskText,
                    range: taskRange,
                    operation: taskOperation
                )
                let cache = await self.getCache()
                await cache.set(result, forKey: cacheKey)
                
                return result
            } catch {
                await self.performanceMonitor.recordError()
                throw error
            }
        }
        
        activeTasks[taskId] = processingTask
        
        // Handle completion with guaranteed cleanup
        Task { [weak self] in
            defer {
                // Ensure cleanup happens even on cancellation
                Task { [weak self] in
                    await self?.taskCompleted(taskId)
                }
            }
            
            do {
                let result = try await processingTask.value
                taskCompletion(.success(result))
            } catch {
                if !Task.isCancelled {
                    taskCompletion(.failure(error))
                }
            }
        }
        
        updateProcessingLoad()
    }
    
    private func taskCompleted(_ taskId: UUID) async {
        activeTasks.removeValue(forKey: taskId)
        updateProcessingLoad()
        
        // Automatic cache cleanup when queue is empty and no active tasks
        if processingQueue.isEmpty && activeTasks.isEmpty {
            await performCacheCleanupIfNeeded()
        }
        
        await processNextTaskIfPossible()
    }
    
    private func performCacheCleanupIfNeeded() async {
        // Clear cache when idle to free memory
        // This helps prevent long-lived tasks from keeping stale cache entries
        if processingQueue.isEmpty && activeTasks.isEmpty {
            logger.debug("Clearing cache - queue is empty")
            resultCache = nil
        }
    }
    
    private func performProcessing(_ task: ProcessingTask) async throws -> ProcessingResult {
        // Apply adaptive settings
        let settings = adaptiveSettings.settingsForLoad(currentLoad)
        
        // Perform the operation with adaptive batching
        let batchSize = settings.batchSize
        var results: [Any] = []
        
        // Optimized: work with String.Index directly instead of converting to array
        let startIndex = task.text.index(task.text.startIndex, offsetBy: task.range.location)
        
        var currentIndex = startIndex
        var currentLocation = task.range.location
        let endLocation = NSMaxRange(task.range)
        
        while currentLocation < endLocation {
            // Check for cancellation
            try Task.checkCancellation()
            
            let batchEnd = min(currentLocation + batchSize, endLocation)
            let batchLength = batchEnd - currentLocation
            let batchRange = NSRange(location: currentLocation, length: batchLength)
            
            // Calculate batch end index efficiently
            let batchEndIndex = task.text.index(currentIndex, offsetBy: batchLength)
            
            // Extract substring without array conversion
            let batchText = String(task.text[currentIndex..<batchEndIndex])
            
            // Process batch
            let batchResult = try await task.operation.process(batchText, batchRange)
            results.append(batchResult)
            
            currentIndex = batchEndIndex
            currentLocation = batchEnd
            
            // Adaptive delay between batches
            if settings.delayBetweenBatches > 0 {
                try await Task.sleep(nanoseconds: UInt64(settings.delayBetweenBatches * 1_000_000_000))
            }
        }
        
        return ProcessingResult(
            taskId: task.id,
            operation: task.operation.name,
            dataDescription: "Processed \(results.count) batches",
            processingTime: 0 // Will be set by caller
        )
    }
    
    private func updateProcessingLoad() {
        let activeCount = activeTasks.count
        let queuedCount = processingQueue.count
        
        if activeCount >= maxConcurrentOperations && queuedCount > 10 {
            currentLoad = .high
        } else if activeCount > maxConcurrentOperations / 2 {
            currentLoad = .medium
        } else if activeCount > 0 {
            currentLoad = .low
        } else {
            currentLoad = .idle
        }
        
        // Update adaptive settings based on load
        adaptiveSettings.updateForLoad(currentLoad)
    }
}

// MARK: - Supporting Types

/// Processing task handle for cancellation
public struct ProcessingTaskHandle: Sendable {
    private let id: UUID
    private let processor: AsyncTextProcessor
    
    init(id: UUID, processor: AsyncTextProcessor) {
        self.id = id
        self.processor = processor
    }
    
    /// Cancel this task
    public func cancel() async {
        await processor.cancel(taskId: id)
    }
}

/// Processing task priority
public enum TaskPriority: Int, Comparable, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
    
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Processing operation protocol
public protocol ProcessingOperation: Sendable {
    var name: String { get }

    func process(_ text: String, _ range: NSRange) async throws -> Any
}

/// Processing task
private struct ProcessingTask: Comparable {
    let id: UUID
    let text: String
    let range: NSRange
    let operation: any ProcessingOperation
    let priority: TaskPriority
    let completion: @Sendable (Result<ProcessingResult, Error>) -> Void
    let timestamp = Date()
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }
        return lhs.timestamp < rhs.timestamp
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

/// Processing result
public struct ProcessingResult: Sendable {
    public let taskId: UUID
    public let operation: String
    public let dataDescription: String // Changed from [Any] for Sendable
    public let processingTime: TimeInterval
}

/// Processing error types
public enum ProcessingError: Error, Sendable {
    case processorDeallocated
    case operationFailed(String)
    case timeout
}

/// Processing load levels
public enum ProcessingLoad: Sendable {
    case idle
    case low
    case medium
    case high
}

/// Processing status
public struct ProcessingStatus: Sendable {
    public let queuedTasks: Int
    public let activeTasks: Int
    public let currentLoad: ProcessingLoad
    public let performanceMetrics: ProcessingMetrics
}

/// Processing metrics
public struct ProcessingMetrics: Sendable {
    public let totalProcessed: Int
    public let averageProcessingTime: TimeInterval
    public let cacheHitRate: Double
    public let errorRate: Double
}

/// Cache key for processing results
private struct ProcessingCacheKey: Hashable {
    let textHash: Int
    let range: NSRange
    let operationName: String
    
    init(text: String, range: NSRange, operation: ProcessingOperation) {
        // Use hash of text substring for efficiency
        let substring = String(text.dropFirst(range.location).prefix(range.length))
        var hasher = Hasher()
        hasher.combine(substring)
        self.textHash = hasher.finalize()
        self.range = range
        self.operationName = operation.name
    }
}

/// Adaptive performance settings
private struct AdaptiveSettings {
    var batchSize: Int = 1_000
    var delayBetweenBatches: TimeInterval = 0
    
    mutating func updateForLoad(_ load: ProcessingLoad) {
        switch load {
        case .idle:
            batchSize = 2_000
            delayBetweenBatches = 0

        case .low:
            batchSize = 1_000
            delayBetweenBatches = 0

        case .medium:
            batchSize = 500
            delayBetweenBatches = 0.001 // 1ms
        case .high:
            batchSize = 200
            delayBetweenBatches = 0.005 // 5ms
        }
    }
    
    func settingsForLoad(_: ProcessingLoad) -> (batchSize: Int, delayBetweenBatches: TimeInterval) {
        (batchSize: batchSize, delayBetweenBatches: delayBetweenBatches)
    }
}

/// Performance monitor for processing operations
private actor ProcessingPerformanceMonitor {
    private var totalProcessed: Int = 0
    private var totalProcessingTime: TimeInterval = 0
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    private var errors: Int = 0
    private var cancellations: Int = 0
    
    func recordProcessingTime(_ time: TimeInterval, for _: ProcessingOperation) {
        totalProcessed += 1
        totalProcessingTime += time
    }
    
    func recordCacheHit() {
        cacheHits += 1
    }
    
    func recordCacheMiss() {
        cacheMisses += 1
    }
    
    func recordError() {
        errors += 1
    }
    
    func recordCancellation() {
        cancellations += 1
    }
    
    func getCurrentMetrics() -> ProcessingMetrics {
        let averageTime = totalProcessed > 0 ? totalProcessingTime / Double(totalProcessed) : 0
        let cacheTotal = cacheHits + cacheMisses
        let cacheHitRate = cacheTotal > 0 ? Double(cacheHits) / Double(cacheTotal) : 0
        let errorRate = totalProcessed > 0 ? Double(errors) / Double(totalProcessed) : 0
        
        return ProcessingMetrics(
            totalProcessed: totalProcessed,
            averageProcessingTime: averageTime,
            cacheHitRate: cacheHitRate,
            errorRate: errorRate
        )
    }
}

// MARK: - Priority Queue Implementation

/// Simple priority queue for processing tasks
private struct PriorityQueue<T: Comparable> {
    private var heap: [T] = []
    
    var count: Int { heap.count }
    var isEmpty: Bool { heap.isEmpty }
    
    mutating func enqueue(_ element: T) {
        heap.append(element)
        heapifyUp(from: heap.count - 1)
    }
    
    mutating func dequeue() -> T? {
        guard !heap.isEmpty else { return nil }
        
        if heap.count == 1 {
            return heap.removeLast()
        }
        
        let value = heap[0]
        heap[0] = heap.removeLast()
        heapifyDown(from: 0)
        return value
    }
    
    mutating func remove(where predicate: (T) -> Bool) {
        heap.removeAll(where: predicate)
        // Rebuild heap
        let elements = heap
        heap = []
        for element in elements {
            enqueue(element)
        }
    }
    
    mutating func clear() {
        heap.removeAll()
    }
    
    private mutating func heapifyUp(from index: Int) {
        var childIndex = index
        let child = heap[childIndex]
        var parentIndex = (childIndex - 1) / 2
        
        while childIndex > 0 && heap[parentIndex] < child {
            heap[childIndex] = heap[parentIndex]
            childIndex = parentIndex
            parentIndex = (childIndex - 1) / 2
        }
        
        heap[childIndex] = child
    }
    
    private mutating func heapifyDown(from index: Int) {
        var parentIndex = index
        
        while true {
            let leftChildIndex = 2 * parentIndex + 1
            let rightChildIndex = leftChildIndex + 1
            var largestIndex = parentIndex
            
            if leftChildIndex < heap.count && heap[leftChildIndex] > heap[largestIndex] {
                largestIndex = leftChildIndex
            }
            
            if rightChildIndex < heap.count && heap[rightChildIndex] > heap[largestIndex] {
                largestIndex = rightChildIndex
            }
            
            if largestIndex == parentIndex {
                break
            }
            
            heap.swapAt(parentIndex, largestIndex)
            parentIndex = largestIndex
        }
    }
}
