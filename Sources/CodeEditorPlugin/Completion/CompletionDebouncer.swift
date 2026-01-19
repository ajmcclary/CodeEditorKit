import Foundation

/// Manages debouncing and throttling for completion requests to optimize performance
@MainActor
public final class CompletionDebouncer: ObservableObject {
    // MARK: - Configuration

    /// Debounce delay in seconds (default: 300ms)
    public var debounceDelay: TimeInterval = 0.3

    /// Throttle interval in seconds (default: 100ms)
    public var throttleInterval: TimeInterval = 0.1

    /// Maximum number of queued requests (default: 5)
    public var maxQueuedRequests: Int = 5

    /// Enable smart debouncing based on typing patterns
    public var enableSmartDebouncing: Bool = true

    // MARK: - State

    /// Current debounce task
    private var debounceTask: Task<Void, Never>?

    /// Last throttle execution time
    private var lastThrottleTime = Date.distantPast

    /// Queued completion requests
    private var requestQueue: [CompletionRequest] = []

    /// Statistics for debouncing performance
    @Published public private(set) var statistics = DebouncingStatistics()

    /// Currently active request
    private var activeRequest: Task<Void, Never>?

    /// Typing pattern analyzer for smart debouncing
    private var typingAnalyzer = TypingPatternAnalyzer()

    /// Completion handler for performing actual requests
    private var completionHandler: (@Sendable (CompletionContextModel) async throws -> CompletionResult)?

    // MARK: - Configuration

    /// Set the completion handler for performing actual completion requests
    public func setCompletionHandler(_ handler: @escaping @Sendable (CompletionContextModel) async throws -> CompletionResult) {
        self.completionHandler = handler
    }

    deinit {
        // Note: Cannot call @MainActor isolated methods in deinit
        // Timer and Task will be cleaned up automatically by ARC
    }

    // MARK: - Public Methods

    /// Request completions with debouncing and throttling
    /// - Parameters:
    ///   - context: The completion context
    ///   - priority: Request priority
    ///   - completion: Completion handler
    public func requestCompletions(
        for context: CompletionContextModel,
        priority: CompletionPriority = .normal,
        completion: @escaping @Sendable (Result<CompletionResult, Error>) -> Void
    ) {
        let request = CompletionRequest(
            context: context,
            priority: priority,
            timestamp: Date(),
            completion: completion
        )

        statistics.recordRequest()

        // Analyze typing pattern for smart debouncing
        if enableSmartDebouncing {
            typingAnalyzer.addTypingEvent(at: Date(), context: context)
            updateDynamicDebounceDelay()
        }

        // Check if we should throttle
        if shouldThrottle() {
            statistics.recordThrottled()
            queueRequest(request)
            return
        }

        // Cancel existing debounce task
        debounceTask?.cancel()
        debounceTask = nil

        // Check if we should execute immediately (high priority or immediate trigger)
        if shouldExecuteImmediately(request) {
            statistics.recordImmediate()
            executeRequest(request)
            return
        }

        // Debounce the request
        statistics.recordDebounced()
        debounceRequest(request)
    }

    /// Cancel all pending requests
    public func cancelAllRequests() {
        debounceTask?.cancel()
        debounceTask = nil

        // Cancel active request
        activeRequest?.cancel()
        activeRequest = nil

        // Clear queue and notify cancellation
        for request in requestQueue {
            request.completion(.failure(CompletionDebouncingError.cancelled))
        }
        requestQueue.removeAll()

        statistics.recordCancellation()
    }

    /// Force execute any pending requests immediately
    public func flushPendingRequests() {
        debounceTask?.cancel()
        debounceTask = nil

        // Execute the highest priority queued request
        if let highestPriorityRequest = getHighestPriorityRequest() {
            executeRequest(highestPriorityRequest)
        }
    }

    // MARK: - Private Methods

    private func shouldThrottle() -> Bool {
        let timeSinceLastThrottle = Date().timeIntervalSince(lastThrottleTime)
        return timeSinceLastThrottle < throttleInterval
    }

    private func shouldExecuteImmediately(_ request: CompletionRequest) -> Bool {
        switch request.priority {
        case .immediate:
            return true

        case .high:
            return requestQueue.isEmpty

        case .normal, .low:
            return false
        }
    }

    private func queueRequest(_ request: CompletionRequest) {
        // Remove oldest requests if queue is full
        while requestQueue.count >= maxQueuedRequests {
            let removedRequest = requestQueue.removeFirst()
            removedRequest.completion(.failure(CompletionDebouncingError.queueFull))
            statistics.recordDropped()
        }

        requestQueue.append(request)

        // Sort by priority
        requestQueue.sort { lhs, rhs in
            lhs.priority.rawValue > rhs.priority.rawValue
        }
    }

    private func debounceRequest(_ request: CompletionRequest) {
        // Add to queue
        queueRequest(request)

        // Start debounce task
        debounceTask = Task { [weak self] in
            do {
                guard let self else { return }
                try await Task.sleep(for: .seconds(self.debounceDelay))

                await MainActor.run { [weak self] in
                    self?.processDebouncedRequests()
                }
            } catch {
                // Task was cancelled, which is expected behavior
            }
        }
    }

    private func processDebouncedRequests() {
        guard let request = getHighestPriorityRequest() else { return }

        statistics.recordDebounceProcessed()
        executeRequest(request)
    }

    private func executeRequest(_ request: CompletionRequest) {
        // Remove from queue if present
        requestQueue.removeAll { $0.id == request.id }

        // Cancel any active request
        activeRequest?.cancel()

        // Update throttle time
        lastThrottleTime = Date()

        // Execute the request
        activeRequest = Task {
            do {
                let result = try await performCompletionRequest(request.context)
                await MainActor.run {
                    request.completion(.success(result))
                    statistics.recordSuccess()
                }
            } catch {
                await MainActor.run {
                    request.completion(.failure(error))
                    statistics.recordError()
                }
            }
        }
    }

    private func getHighestPriorityRequest() -> CompletionRequest? {
        requestQueue.max { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.timestamp < rhs.timestamp // Earlier timestamp wins for same priority
            }
            return lhs.priority.rawValue < rhs.priority.rawValue
        }
    }

    private func performCompletionRequest(_ context: CompletionContextModel) async throws -> CompletionResult {
        guard let handler = completionHandler else {
            throw CompletionDebouncingError.noHandlerConfigured
        }

        return try await handler(context)
    }

    private func updateDynamicDebounceDelay() {
        let pattern = typingAnalyzer.getCurrentPattern()

        switch pattern {
        case .rapid:
            debounceDelay = 0.5 // Longer delay for rapid typing

        case .steady:
            debounceDelay = 0.3 // Normal delay

        case .slow:
            debounceDelay = 0.1 // Shorter delay for slow typing

        case .paused:
            debounceDelay = 0.05 // Very short delay when user pauses
        }
    }
}

// MARK: - Supporting Types

/// Represents a queued completion request
private struct CompletionRequest {
    let id = UUID()
    let context: CompletionContextModel
    let priority: CompletionPriority
    let timestamp: Date
    let completion: @Sendable (Result<CompletionResult, Error>) -> Void
}

/// Priority levels for completion requests
public enum CompletionPriority: Int, CaseIterable, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case immediate = 3
}

/// Errors related to completion debouncing
public enum CompletionDebouncingError: Error, Sendable {
    case cancelled
    case queueFull
    case timeout
    case noHandlerConfigured
}

/// Statistics for debouncing performance
@MainActor
public final class DebouncingStatistics: ObservableObject {
    @Published public private(set) var totalRequests: Int = 0
    @Published public private(set) var debouncedRequests: Int = 0
    @Published public private(set) var throttledRequests: Int = 0
    @Published public private(set) var immediateRequests: Int = 0
    @Published public private(set) var successfulRequests: Int = 0
    @Published public private(set) var errorRequests: Int = 0
    @Published public private(set) var droppedRequests: Int = 0
    @Published public private(set) var cancelledRequests: Int = 0

    public var debouncingEfficiency: Double {
        totalRequests > 0 ? Double(debouncedRequests) / Double(totalRequests) : 0
    }

    public var throttlingRate: Double {
        totalRequests > 0 ? Double(throttledRequests) / Double(totalRequests) : 0
    }

    public var successRate: Double {
        let completedRequests = successfulRequests + errorRequests
        return completedRequests > 0 ? Double(successfulRequests) / Double(completedRequests) : 0
    }

    internal func recordRequest() {
        totalRequests += 1
    }

    internal func recordDebounced() {
        debouncedRequests += 1
    }

    internal func recordThrottled() {
        throttledRequests += 1
    }

    internal func recordImmediate() {
        immediateRequests += 1
    }

    internal func recordSuccess() {
        successfulRequests += 1
    }

    internal func recordError() {
        errorRequests += 1
    }

    internal func recordDropped() {
        droppedRequests += 1
    }

    internal func recordCancellation() {
        cancelledRequests += 1
    }

    internal func recordDebounceProcessed() {
        // This tracks when debounced requests are actually processed
    }

    public func reset() {
        totalRequests = 0
        debouncedRequests = 0
        throttledRequests = 0
        immediateRequests = 0
        successfulRequests = 0
        errorRequests = 0
        droppedRequests = 0
        cancelledRequests = 0
    }
}

/// Analyzes typing patterns for smart debouncing
private final class TypingPatternAnalyzer {
    private var typingEvents: [(Date, CompletionContextModel)] = []
    private let maxEvents = 10

    func addTypingEvent(at date: Date, context: CompletionContextModel) {
        typingEvents.append((date, context))

        // Keep only recent events
        if typingEvents.count > maxEvents {
            typingEvents.removeFirst()
        }
    }

    func getCurrentPattern() -> TypingPattern {
        guard typingEvents.count >= 2 else { return .steady }

        let intervals = zip(typingEvents, typingEvents.dropFirst()).map { first, second in
            second.0.timeIntervalSince(first.0)
        }

        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)

        switch averageInterval {
        case 0..<0.1:
            return .rapid

        case 0.1..<0.3:
            return .steady

        case 0.3..<1.0:
            return .slow

        default:
            return .paused
        }
    }
}

/// Typing pattern classifications
private enum TypingPattern {
    case rapid    // Very fast typing
    case steady   // Normal typing speed
    case slow     // Slow, deliberate typing
    case paused   // User has paused typing
}
