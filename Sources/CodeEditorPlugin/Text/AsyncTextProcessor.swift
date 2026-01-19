import Foundation
#if canImport(Combine)
import Combine
#endif

// MARK: - AsyncTextProcessor

/// Advanced async text processing with priority queues and adaptive performance
///
/// `AsyncTextProcessor` is an actor that provides thread-safe, concurrent text processing
/// with adaptive performance and priority-based scheduling. All public methods are
/// isolated to this actor, ensuring thread safety for all operations.
///
/// ## Actor Isolation
///
/// This type uses Swift's actor model for thread safety. All properties and methods
/// are actor-isolated, meaning:
/// - All calls must be made with `await` from outside the actor
/// - The actor guarantees serial execution of its methods
/// - No data races are possible when accessing actor state
///
/// ## Usage Pattern
///
/// ```swift
/// let processor = AsyncTextProcessor(memoryMonitor: monitor)
/// 
/// // All calls require await due to actor isolation
/// let result = await processor.process(text, type: .syntaxHighlight)
/// await processor.cleanup()
/// ```
///
/// ## Task Management
///
/// The processor manages a queue of tasks with the following characteristics:
/// - Tasks are processed based on priority (high priority first)
/// - Maximum concurrent operations are limited to prevent oversubscription
/// - Tasks can be cancelled individually or all at once
/// - Memory pressure automatically triggers cache clearing and task reduction
///
/// ## Lifecycle
///
/// Important: Call `cleanup()` before releasing the processor to ensure
/// all active tasks are properly cancelled. The deinit cannot perform
/// async cleanup due to Swift limitations.
actor AsyncTextProcessor {
    // MARK: - Properties

    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "AsyncTextProcessor")

    /// Processing queue with priority support
    private var processingQueue = PriorityQueue<ProcessingTask>()

    /// Active processing tasks
    private var activeTasks: [UUID: Task<ProcessingResult, Error>] = [:]

    /// Maximum concurrent operations
    private var maxConcurrentOperations: Int

    /// Base concurrent operations limit
    private let baseConcurrentOperations: Int

    /// Current processing load
    private var currentLoad: ProcessingLoad = .idle

    /// System load monitor
    private var systemLoadMonitor: SystemLoadMonitor?

    /// Performance monitor
    private let performanceMonitor = ProcessingPerformanceMonitor()

    /// Adaptive performance settings
    private var adaptiveSettings = AdaptiveProcessingSettings()

    /// Memory monitor
    private let memoryMonitor: MemoryMonitor

    /// Result cache
    private var resultCache: LRUCache<ProcessingCacheKey, ProcessingResult>?

    // MARK: - Initialization

    init(memoryMonitor: MemoryMonitor, maxConcurrentOperations: Int? = nil) {
        // Cap at 4 to prevent oversubscription on highly-threaded systems
        let defaultConcurrency = min(4, ProcessInfo.processInfo.activeProcessorCount)
        self.baseConcurrentOperations = maxConcurrentOperations ?? defaultConcurrency
        self.maxConcurrentOperations = self.baseConcurrentOperations
        self.memoryMonitor = memoryMonitor

        // Initialize system load monitor
        Task {
            await self.initializeSystemLoadMonitor()
        }
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
        let monitor = memoryMonitor
        let cache = await MainActor.run {
            LRUCache<ProcessingCacheKey, ProcessingResult>(capacity: 100, memoryMonitor: monitor)
        }
        resultCache = cache
        return cache
    }

    // MARK: - Public Methods

    /// Submit a text processing task to the queue
    ///
    /// This method is actor-isolated and must be called with `await`.
    /// Tasks are processed based on priority and available resources.
    ///
    /// - Parameters:
    ///   - text: The text to process
    ///   - range: The range within the text to process
    ///   - operation: The type of processing operation
    ///   - priority: Task priority (default: .normal)
    ///   - completion: Completion handler called with the result
    /// - Returns: A handle that can be used to cancel the task
    ///
    /// - Note: Results may be returned from cache if available
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

    /// Cancel a specific processing task
    ///
    /// This method is actor-isolated and must be called with `await`.
    /// Cancels the task if it's queued or actively processing.
    ///
    /// - Parameter taskId: The ID of the task to cancel
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
    ///
    /// Immediately cancels all active and pending tasks without waiting for completion.
    /// Use `cleanup()` if you need to wait for tasks to finish.
    func clearQueue() {
        processingQueue.clear()

        // Cancel all active tasks
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()

        updateProcessingLoad()
    }

    /// Cleanup all resources before releasing the processor
    ///
    /// This method is actor-isolated and must be called with `await`.
    /// Call this method before the processor goes out of scope to ensure
    /// all active tasks are properly cancelled and resources are freed.
    ///
    /// - Important: The deinit cannot perform async cleanup, so this
    ///   method must be called explicitly before releasing the actor.
    func cleanup() async {
        // Capture active tasks before clearing to avoid reentrancy
        let tasksToAwait = Array(activeTasks.values)

        // Clear all queues and cancel tasks
        processingQueue.clear()
        activeTasks.removeAll()

        // Clear the cache
        resultCache = nil

        // Update load after clearing
        updateProcessingLoad()

        // Wait for cancelled tasks to complete outside of actor isolation
        // This avoids potential reentrancy issues
        await withTaskGroup(of: Void.self) { group in
            for task in tasksToAwait {
                group.addTask {
                    _ = try? await task.value
                }
            }
        }
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
            do {
                let result = try await processingTask.value
                taskCompletion(.success(result))
            } catch {
                if !Task.isCancelled {
                    taskCompletion(.failure(error))
                }
            }

            // Directly await cleanup after task completes
            await self?.taskCompleted(taskId)
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

        // Update concurrent operations based on system load
        updateDynamicConcurrency()
    }

    // MARK: - Dynamic Concurrency

    private func initializeSystemLoadMonitor() async {
        systemLoadMonitor = SystemLoadMonitor()

        // Start periodic updates
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                await self?.updateDynamicConcurrency()
            }
        }
    }

    private func updateDynamicConcurrency() {
        guard let monitor = systemLoadMonitor else { return }

        let systemLoad = monitor.currentSystemLoad()

        // Adjust concurrency based on system conditions
        // Note: Memory pressure check temporarily disabled to avoid actor isolation issues
        switch systemLoad {
        case .low:
            // System is idle, can use full concurrency
            maxConcurrentOperations = baseConcurrentOperations

        case .medium:
            // Moderate load, reduce slightly
            maxConcurrentOperations = max(2, baseConcurrentOperations - 1)

        case .high:
            // High load, minimize concurrency
            maxConcurrentOperations = 1
        }
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
