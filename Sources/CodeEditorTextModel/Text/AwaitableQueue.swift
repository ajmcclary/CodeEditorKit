import Foundation
import os

/// FIFO queue with continuation-based wait semantics.
///
/// `@unchecked Sendable` rationale: `pendingEvents` is mutated under an
/// `OSAllocatedUnfairLock`, so all reads, writes, and check-then-append
/// sequences are serialized regardless of the caller's actor context.
/// Continuation resumption happens outside the lock to avoid re-entrancy.
/// `Element: Sendable` is enforced so values trapped in the queue can safely
/// cross actor boundaries when delivered.
final class AwaitableQueue<Element>: @unchecked Sendable where Element: Sendable {
    private typealias Continuation = CheckedContinuation<Void, Never>

    private enum Event {
        case element(Element)
        case waiter(Continuation)
    }

    private let lock = OSAllocatedUnfairLock<[Event]>(initialState: [])

    init() {}

    private static func containsPendingElement(in events: [Event]) -> Bool {
        events.contains { event in
            switch event {
            case .element:
                true

            case .waiter:
                false
            }
        }
    }

    var hasPendingEvents: Bool {
        lock.withLock { Self.containsPendingElement(in: $0) }
    }

    func processingCompleted(isolation _: isolated any Actor) async {
        let hasEvents = lock.withLock { Self.containsPendingElement(in: $0) }

        if hasEvents == false {
            return
        }

        await withCheckedContinuation { continuation in
            let resumeImmediately = lock.withLock { events -> Bool in
                if Self.containsPendingElement(in: events) {
                    events.append(.waiter(continuation))
                    return false
                }
                // Drained between the first check and here; resume immediately
                // so the caller doesn't wait for a notification that will never
                // arrive.
                return true
            }
            if resumeImmediately {
                continuation.resume()
            }
        }
    }

    package func enqueue(_ element: Element) {
        lock.withLock { events in
            events.append(.element(element))
        }
    }

    var pendingElements: [Element] {
        lock.withLock { events in
            events.compactMap {
                switch $0 {
                case let .element(value):
                    value

                case .waiter:
                    nil
                }
            }
        }
    }

    func handlePendingWaiters() {
        // Drain waiter continuations under the lock, then resume them outside
        // the lock — resumed tasks may call back into the queue, and resuming
        // inside the lock would deadlock on re-entry.
        let toResume = lock.withLock { events -> [Continuation] in
            var drained: [Continuation] = []
            while let event = events.first {
                guard case let .waiter(continuation) = event else {
                    break
                }
                drained.append(continuation)
                events.removeFirst()
            }
            return drained
        }

        for continuation in toResume {
            continuation.resume()
        }
    }

    package func next() -> Element? {
        handlePendingWaiters()

        return lock.withLock { events -> Element? in
            guard case let .element(first) = events.first else {
                return nil
            }
            events.removeFirst()
            return first
        }
    }
}
