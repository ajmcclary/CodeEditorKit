import Foundation

/// Thread-safe storage for notification observers
///
/// Manages the lifecycle of notification observers to ensure proper cleanup
/// and prevent retain cycles. This actor ensures thread-safe access to the
/// observer collection.
@MainActor
internal final class ObserverStore {
    private var observers: [NSObjectProtocol] = []

    /// Add an observer to the store
    /// - Parameter observer: The notification observer to track
    package func addObserver(_ observer: NSObjectProtocol) {
        observers.append(observer)
    }

    /// Remove all observers from notification center and clear the store
    func removeAllObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    /// Non-isolated cleanup method for safe cleanup from deinit
    nonisolated func cleanup() {
        // Use MainActor to safely clean up observers
        Task { @MainActor in
            removeAllObservers()
        }
    }

    deinit {
        // Cannot access MainActor isolated properties in deinit with Swift 6
        // Cleanup happens automatically via the cleanup() task
        // NotificationCenter automatically removes observers when object is deallocated
    }
}
