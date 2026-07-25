import Foundation

/// Fan-out for `CompletionEvent` over an unbounded number of synchronous
/// subscribers.
///
/// Mirrors the lock-based shape of
/// `SyntaxHighlightingCoordinator.HighlightingTaskManager` so callers from any
/// isolation domain can subscribe and publish without trampolines.
///
/// `@unchecked Sendable` rationale: every access to `continuations` happens
/// while holding `lock`. `subscribe()`, `publish(_:)`, `subscriberCount`, and
/// the `onTermination` closure all acquire the lock before touching the
/// dictionary. `AsyncStream.Continuation.yield(_:)` is documented thread-safe;
/// publishing snapshots the continuation array under lock and yields outside
/// the critical section.
final class CompletionEventBroadcaster: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<CompletionEvent>.Continuation] = [:]

    /// Returns a fresh stream. Each call registers a new continuation; every
    /// subscriber receives every event published while its iterator is alive.
    /// The per-subscriber buffer drops the oldest event when full
    /// (`.bufferingNewest(256)`), so a slow subscriber cannot backpressure the
    /// publisher.
    func subscribe() -> AsyncStream<CompletionEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(256)) { continuation in
            let token = UUID()
            lock.lock()
            continuations[token] = continuation
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                let removed = self.continuations.removeValue(forKey: token)
                self.lock.unlock()
                removed?.finish()
            }
        }
    }

    /// Synchronous publish. Safe from any isolation domain — call sites in
    /// `CompletionManager.collectResultsConcurrently` invoke this from inside
    /// the `withTaskGroup` provider tasks.
    func publish(_ event: CompletionEvent) {
        lock.lock()
        let snapshot = Array(continuations.values)
        lock.unlock()
        for continuation in snapshot { continuation.yield(event) }
    }

    /// Test-only probe. `internal` so production code cannot reach it; tests
    /// access via `@testable import CodeEditorKit`.
    var subscriberCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return continuations.count
    }
}
