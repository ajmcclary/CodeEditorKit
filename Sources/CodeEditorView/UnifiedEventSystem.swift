import CodeEditorCommon
import CodeEditorCompletion
import CodeEditorPlatform
import Foundation
#if canImport(Combine)
import Combine
#endif

// MARK: - UnifiedEventSystem

/// Centralized event system for all editor events across platforms
@MainActor
public final class UnifiedEventSystem: ObservableObject {
    // MARK: - Properties

    /// Main event publisher
    private let eventSubject = PassthroughSubject<EditorEvent, Never>()

    /// Event publisher for external subscribers
    public var events: AnyPublisher<EditorEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    /// Typed event publishers
    @Published public private(set) var lastTextChangeEvent: String?
    @Published public private(set) var lastSelectionChangeEvent: NSRange?
    @Published public private(set) var lastCompletionContext: CompletionContext?
    @Published public private(set) var lastPerformanceWarning: String?
    @Published public private(set) var lastError: SendableError?

    /// Event filters
    private var eventFilters: [EventFilter] = []

    /// Event handlers
    private var eventHandlers: [UUID: EventHandler] = [:]

    /// Event history (for debugging)
    private var eventHistory = CircularBuffer<EditorEvent>(capacity: 100)

    /// Performance metrics
    private var eventMetrics = EventMetrics()

    /// Platform capabilities for adaptive behavior
    private let capabilities: PlatformCapabilities

    // MARK: - Initialization

    /// Creates a new UnifiedEventSystem with optional configuration
    /// - Parameters:
    ///   - enableDefaultFilters: Whether to setup default filters (default: true)
    ///   - capabilities: Platform capabilities for adaptive behavior (defaults to shared instance)
    public init(enableDefaultFilters: Bool = true, capabilities: PlatformCapabilities? = nil) {
        self.capabilities = capabilities ?? CodeEditorDependencies.makePlatformCapabilities()
        if enableDefaultFilters {
            setupDefaultFilters()
        }
    }

    // MARK: - Event Publishing

    /// Publish an event to the system
    public func publish(_ event: EditorEvent) {
        // Apply filters
        let shouldPublish = eventFilters.allSatisfy { $0.shouldAllow(event) }
        guard shouldPublish else {
            eventMetrics.filteredCount += 1
            return
        }

        // Update metrics
        eventMetrics.publishedCount += 1
        eventMetrics.lastEventTime = Date()

        // Add to history
        eventHistory.append(event)

        // Update typed event properties
        updateTypedEvents(event)

        // Publish to main subject
        eventSubject.send(event)

        // Call registered handlers
        notifyHandlers(of: event)
    }

    /// Publish multiple events as a batch
    public func publishBatch(_ events: [EditorEvent]) {
        for event in events {
            publish(event)
        }
    }

    // MARK: - Event Subscription

    /// Subscribe to specific event types
    public func subscribe<T: EditorEventType>(
        to eventType: T.Type,
        handler: @escaping (T) -> Void
    ) -> AnyCancellable {
        events
            .compactMap { event in
                eventType.extract(from: event)
            }
            .sink(receiveValue: handler)
    }

    /// Register an event handler
    @discardableResult
    public func registerHandler(_ handler: EventHandler) -> EventHandlerToken {
        let id = UUID()
        eventHandlers[id] = handler
        return EventHandlerToken(id: id, system: self)
    }

    /// Unregister an event handler
    public func unregisterHandler(with id: UUID) {
        eventHandlers.removeValue(forKey: id)
    }

    // MARK: - Event Filtering

    /// Add an event filter
    public func addFilter(_ filter: EventFilter) {
        eventFilters.append(filter)
    }

    /// Remove all filters
    public func clearFilters() {
        eventFilters = []
        setupDefaultFilters()
    }

    // MARK: - Event History

    /// Returns the most recent events from the history buffer.
    public func recentEvents(count: Int = 10) -> [EditorEvent] {
        Array(eventHistory.suffix(count))
    }

    /// Returns the most recent events from the history buffer.
    @available(*, deprecated, renamed: "recentEvents(count:)")
    public func getRecentEvents(count: Int = 10) -> [EditorEvent] {
        recentEvents(count: count)
    }

    /// Returns events of the given type from the history buffer.
    public func events<T: EditorEventType>(
        ofType type: T.Type,
        limit: Int = 10
    ) -> [T] {
        Array(
            eventHistory
                .compactMap { event in
                    type.extract(from: event)
                }
                .suffix(limit)
        )
    }

    /// Returns events of the given type from the history buffer.
    @available(*, deprecated, renamed: "events(ofType:limit:)")
    public func getEvents<T: EditorEventType>(
        ofType type: T.Type,
        limit: Int = 10
    ) -> [T] {
        events(ofType: type, limit: limit)
    }

    /// Clear event history
    public func clearHistory() {
        eventHistory.clear()
    }

    /// Configure event throttling rate
    /// - Parameter maxEventsPerSecond: Maximum number of events per second for each event type
    public func configureThrottling(maxEventsPerSecond: Int) {
        // Remove existing performance filter
        eventFilters.removeAll { $0 is PerformanceEventFilter }

        // Add new filter with updated rate
        let performanceFilter = PerformanceEventFilter(
            maxEventsPerSecond: maxEventsPerSecond
        )
        eventFilters.append(performanceFilter)
    }

    // MARK: - Metrics

    /// Get event system metrics
    public func getMetrics() -> EventMetrics {
        eventMetrics
    }

    // MARK: - Private Methods

    private func setupDefaultFilters() {
        // Throttle high-frequency events.
        let performanceFilter = PerformanceEventFilter(
            maxEventsPerSecond: 60  // Default throttle rate
        )
        eventFilters.append(performanceFilter)
    }

    private func updateTypedEvents(_ event: EditorEvent) {
        switch event {
        case .textDidChange(let text):
            lastTextChangeEvent = text

        case .textSelectionDidChange(let range):
            lastSelectionChangeEvent = range

        case .completionRequested(let context):
            lastCompletionContext = context

        case .performanceWarning(let message):
            lastPerformanceWarning = message

        case .error(let error):
            lastError = error

        default:
            break // Other events don't have typed properties
        }
    }

    private func notifyHandlers(of event: EditorEvent) {
        let handlers = Array(eventHandlers.values)
        for handler in handlers where handler.canHandle(event) {
            handler.handle(event)
        }
    }

    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - Event Filters

/// Protocol for event filtering
public protocol EventFilter {
    /// Determines if an event should be allowed through the filter
    /// - Parameter event: The event to evaluate
    /// - Returns: True if the event should be allowed, false otherwise
    func shouldAllow(_ event: EditorEvent) -> Bool
}

/// Filter events for performance (throttling)
public final class PerformanceEventFilter: EventFilter {
    private let maxEventsPerSecond: Int
    private var eventCounts: [String: (count: Int, resetTime: Date)] = [:]

    init(maxEventsPerSecond: Int) {
        self.maxEventsPerSecond = maxEventsPerSecond
    }

    public func shouldAllow(_ event: EditorEvent) -> Bool {
        // Create a simple key for the event type
        let eventKey: String
        switch event {
        case .textDidChange: eventKey = "textDidChange"
        case .textWillChange: eventKey = "textWillChange"
        case .textSelectionDidChange: eventKey = "textSelectionDidChange"
        case .didBecomeFirstResponder: eventKey = "didBecomeFirstResponder"
        case .didResignFirstResponder: eventKey = "didResignFirstResponder"
        case .completionRequested: eventKey = "completionRequested"
        case .completionItemSelected: eventKey = "completionItemSelected"
        case .annotationHovered: eventKey = "annotationHovered"
        case .annotationClicked: eventKey = "annotationClicked"
        case .performanceWarning: eventKey = "performanceWarning"
        case .error: eventKey = "error"
        }

        let now = Date()

        if let (count, resetTime) = eventCounts[eventKey] {
            if now.timeIntervalSince(resetTime) >= 1.0 {
                // Reset counter
                eventCounts[eventKey] = (1, now)
                return true
            } else if count < maxEventsPerSecond {
                // Increment counter
                eventCounts[eventKey] = (count + 1, resetTime)
                return true
            } else {
                // Throttle
                return false
            }
        } else {
            // First event of this type
            eventCounts[eventKey] = (1, now)
            return true
        }
    }

    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - Event Handlers

/// Protocol for handling events
public protocol EventHandler {
    /// Checks if this handler can process the given event
    /// - Parameter event: The event to check
    /// - Returns: True if this handler can process the event
    func canHandle(_ event: EditorEvent) -> Bool
    /// Handles the given event
    /// - Parameter event: The event to handle
    func handle(_ event: EditorEvent)
}

/// Token for unregistering event handlers
public struct EventHandlerToken {
    let id: UUID
    weak var system: UnifiedEventSystem?

    /// Unregisters this event handler from the system
    /// 
    /// This method removes the event handler from the unified event system.
    /// After calling this method, the handler will no longer receive events.
    @MainActor
    public func unregister() {
        system?.unregisterHandler(with: id)
    }
}

// MARK: - Event Metrics

/// Metrics for the event system
public struct EventMetrics {
    /// Number of events published through the system
    public var publishedCount: Int = 0
    /// Number of events filtered out
    public var filteredCount: Int = 0
    /// Timestamp of the last event processed
    public var lastEventTime: Date?

    /// Calculated events per second based on recent activity
    public var eventsPerSecond: Double {
        guard let lastTime = lastEventTime else { return 0 }
        let timeSinceLastEvent = Date().timeIntervalSince(lastTime)
        return timeSinceLastEvent > 0 ? 1.0 / timeSinceLastEvent : 0
    }
}

// Platform events are not currently supported in the base EditorEvent enum

// MARK: - Circular Buffer

/// Simple circular buffer for event history
private struct CircularBuffer<T: Sendable>: Sendable {
    private var buffer: [T?]
    private var writeIndex = 0
    private var count = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }

    mutating func append(_ element: T) {
        buffer[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        count = Swift.min(count + 1, capacity)
    }

    mutating func clear() {
        buffer = Array(repeating: nil, count: capacity)
        writeIndex = 0
        count = 0
    }

    func suffix(_ maxLength: Int) -> [T] {
        let suffixCount = Swift.min(maxLength, count)
        var result: [T] = []

        for offset in 0..<suffixCount {
            let index = (writeIndex - suffixCount + offset + capacity) % capacity
            if let element = buffer[index] {
                result.append(element)
            }
        }

        return result
    }
}

extension CircularBuffer: Sequence {
    func makeIterator() -> AnyIterator<T> {
        var index = 0
        return AnyIterator {
            guard index < self.count else { return nil }
            let bufferIndex = (self.writeIndex - self.count + index + self.capacity) % self.capacity
            index += 1
            return self.buffer[bufferIndex]
        }
    }
}

// MARK: - Integration with CodeEditorView

extension CodeEditorView {
    /// Publish events through the unified event system
    public func publishEvent(_ event: EditorEvent) {
        // Publish to the local event publisher
        eventPublisher.publishSync(event)

        runtime.dependencies.eventSystem?.publish(event)
    }
}
