import Foundation

/// Serializes connection teardown so transport cleanup runs at most once.
@MainActor
final class LSPConnectionLifecycle {
    private var disconnectTask: Task<Void, Never>?

    var isDisconnecting: Bool {
        disconnectTask != nil
    }

    @discardableResult
    func beginDisconnect(
        _ operation: @escaping @MainActor @Sendable () async -> Void
    ) -> Bool {
        guard disconnectTask == nil else { return false }
        disconnectTask = Task { @MainActor [weak self] in
            await operation()
            self?.disconnectTask = nil
        }
        return true
    }
}
