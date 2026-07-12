import Foundation

/// An editor event annotated with its global publication order.
public struct SequencedEditorEvent: Sendable {
    public let sequence: UInt64
    public let event: EditorEvent

    public init(sequence: UInt64, event: EditorEvent) {
        self.sequence = sequence
        self.event = event
    }
}

/// Canonical synchronous publication point for editor events.
@MainActor
public final class EditorEventBus {
    private var nextSequence: UInt64 = 1
    private var continuations: [UUID: AsyncStream<SequencedEditorEvent>.Continuation] = [:]
    private var observers: [UUID: (SequencedEditorEvent) -> Void] = [:]
    private var history: [SequencedEditorEvent] = []
    private let historyLimit: Int

    public init(historyLimit: Int = 100) {
        self.historyLimit = max(1, historyLimit)
    }

    public func publish(_ event: EditorEvent) {
        let value = SequencedEditorEvent(sequence: nextSequence, event: event)
        nextSequence &+= 1
        history.append(value)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
        continuations.values.forEach { $0.yield(value) }
        observers.values.forEach { $0(value) }
    }

    public func stream(
        bufferingPolicy: AsyncStream<SequencedEditorEvent>.Continuation.BufferingPolicy = .bufferingNewest(100)
    ) -> AsyncStream<SequencedEditorEvent> {
        let identifier = UUID()
        return AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            continuations[identifier] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.continuations.removeValue(forKey: identifier)
                }
            }
        }
    }

    public func recentEvents(
        matching predicate: (EditorEvent) -> Bool = { _ in true }
    ) -> [SequencedEditorEvent] {
        history.filter { predicate($0.event) }
    }

    var subscriberCount: Int {
        continuations.count
    }

    @discardableResult
    func observe(
        _ observer: @escaping (SequencedEditorEvent) -> Void
    ) -> EditorEventObservation {
        let identifier = UUID()
        observers[identifier] = observer
        return EditorEventObservation(bus: self, identifier: identifier)
    }

    fileprivate func removeObserver(_ identifier: UUID) {
        observers.removeValue(forKey: identifier)
    }
}

/// Lifetime token for a synchronous event-bus adapter.
@MainActor
final class EditorEventObservation {
    private weak var bus: EditorEventBus?
    private let identifier: UUID

    init(bus: EditorEventBus, identifier: UUID) {
        self.bus = bus
        self.identifier = identifier
    }

    func cancel() {
        bus?.removeObserver(identifier)
        bus = nil
    }

    deinit {
        MainActor.assumeIsolated {
            bus?.removeObserver(identifier)
        }
    }
}
