struct AwaitableQueue<Element> {
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

    mutating func processingCompleted(isolation _: isolated any Actor) async {
        if hasPendingEvents == false {
            return
        }

        await withCheckedContinuation { continuation in
            pendingEvents.append(.waiter(continuation))
        }
    }

    mutating func enqueue(_ element: Element) {
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

    mutating func handlePendingWaiters() {
        while let event = pendingEvents.first {
            guard case let .waiter(continuation) = event else {
                break
            }

            continuation.resume()
            pendingEvents.removeFirst()
        }
    }

    mutating func next() -> Element? {
        handlePendingWaiters()

        guard case let .element(first) = pendingEvents.first else {
            return nil
        }

        pendingEvents.removeFirst()

        return first
    }
}
