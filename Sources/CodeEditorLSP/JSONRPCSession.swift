import Foundation

/// Owns JSON-RPC request identifiers and exactly-once response continuations.
///
/// Every request is bounded: it completes with the server's response, fails
/// with `LSPError.timeout` once `requestTimeout` elapses, fails with
/// `CancellationError` when the awaiting task is cancelled, or fails with
/// the error passed to `failAllPending(with:)` when the connection ends.
@MainActor
final class JSONRPCSession {
    typealias SendHandler = @Sendable (Data) async throws -> Void

    /// Default deadline for a request that has no explicit timeout.
    static let defaultRequestTimeout: Duration = .seconds(30)

    private struct Pending {
        let continuation: CheckedContinuation<LSPResponse, any Error>
        let deadline: Task<Void, Never>?
    }

    private var pending: [RequestId: Pending] = [:]
    private var nextRequestID: Int
    private var sendHandler: SendHandler?
    private let requestTimeout: Duration?

    /// Called with the id of a request abandoned by cancellation or timeout,
    /// so the owner can tell the server (`$/cancelRequest`).
    var onAbandon: ((RequestId) -> Void)?

    init(
        nextRequestID: Int = 1,
        requestTimeout: Duration? = JSONRPCSession.defaultRequestTimeout,
        send: SendHandler? = nil
    ) {
        self.nextRequestID = nextRequestID
        self.requestTimeout = requestTimeout
        self.sendHandler = send
    }

    func setSendHandler(_ handler: @escaping SendHandler) {
        sendHandler = handler
    }

    func request(
        method: String,
        params: any Codable & Sendable
    ) async throws -> LSPResponse {
        let id = allocateRequestID()
        let data = try JSONEncoder().encode(
            LSPRequest(id: id, method: method, params: params)
        )
        guard let sendHandler else {
            throw LSPError.transportNotConfigured
        }
        try Task.checkCancellation()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[id] = Pending(continuation: continuation, deadline: makeDeadline(for: id))
                Task { @MainActor [weak self] in
                    do {
                        try await sendHandler(data)
                    } catch {
                        self?.complete(id, with: .failure(error))
                    }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.abandon(id, with: CancellationError())
            }
        }
    }

    func handleResponse(
        id: RequestId,
        result: Result<LSPResponse, LSPError>
    ) {
        complete(id, with: result.mapError { $0 as any Error })
    }

    func failAllPending(with error: LSPError) {
        let entries = Array(pending.values)
        pending.removeAll()
        for entry in entries {
            entry.deadline?.cancel()
            entry.continuation.resume(throwing: error)
        }
    }

    var pendingCount: Int {
        pending.count
    }

    // MARK: - Private

    private func makeDeadline(for id: RequestId) -> Task<Void, Never>? {
        guard let requestTimeout else { return nil }
        return Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: requestTimeout)
            } catch {
                return
            }
            self?.abandon(id, with: LSPError.timeout)
        }
    }

    /// Fails a request the client gave up on, and reports it so the server
    /// can stop working on it. A request that already completed is ignored.
    private func abandon(_ id: RequestId, with error: any Error) {
        guard pending[id] != nil else { return }
        complete(id, with: .failure(error))
        onAbandon?(id)
    }

    private func complete(_ id: RequestId, with result: Result<LSPResponse, any Error>) {
        guard let entry = pending.removeValue(forKey: id) else { return }
        entry.deadline?.cancel()
        entry.continuation.resume(with: result)
    }

    private func allocateRequestID() -> RequestId {
        let value = nextRequestID
        nextRequestID = value == Int.max ? 1 : value + 1
        return .number(value)
    }
}
