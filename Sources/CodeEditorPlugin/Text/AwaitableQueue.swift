/// FIFO queue with continuation-based wait semantics.
///
/// `@unchecked Sendable` rationale: `pendingEvents` is mutated freely, but the
/// queue's contract is that all access happens from a caller-supplied actor
/// context (see `processingCompleted(isolation:)`). The actor parameter is the
/// synchronization mechanism — direct cross-actor access without that
/// parameter is unsupported. `Element: Sendable` is enforced so values
/// trapped in the queue can safely cross actor boundaries when delivered.
final class AwaitableQueue<Element>: @unchecked Sendable where Element: Sendable {
    private typealias Continuation = CheckedContinuation<Void, Never>

    private enum Event {
        case element(Element)
        case waiter(Continuation)
    }

    private var pendingEvents = [Event]()

    init() {}

    var hasPendingEvents: Bool {
        pendingEvents.contains { event in
            switch event {
            case .element:
                true

            case .waiter:
                false
            }
        }
    }

    func processingCompleted(isolation _: isolated any Actor) async {
        if hasPendingEvents == false {
            return
        }

        await withCheckedContinuation { continuation in
            pendingEvents.append(.waiter(continuation))
        }
    }

    func enqueue(_ element: Element) {
        pendingEvents.append(.element(element))
    }

    var pendingElements: [Element] {
        pendingEvents.compactMap {
            switch $0 {
            case let .element(value):
                value

            case .waiter:
                nil
            }
        }
    }

    func handlePendingWaiters() {
        while let event = pendingEvents.first {
            guard case let .waiter(continuation) = event else {
                break
            }

            continuation.resume()
            pendingEvents.removeFirst()
        }
    }

    func next() -> Element? {
        handlePendingWaiters()

        guard case let .element(first) = pendingEvents.first else {
            return nil
        }

        pendingEvents.removeFirst()

        return first
    }

    deinit {
        // Cleanup if needed
    }
}
