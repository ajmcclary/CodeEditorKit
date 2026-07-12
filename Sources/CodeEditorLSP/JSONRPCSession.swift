import Foundation

/// Owns JSON-RPC request identifiers and exactly-once response continuations.
@MainActor
final class JSONRPCSession {
    typealias SendHandler = @Sendable (Data) async throws -> Void

    private var pending: [RequestId: CheckedContinuation<LSPResponse, any Error>] = [:]
    private var nextRequestID: Int
    private var sendHandler: SendHandler?

    init(
        nextRequestID: Int = 1,
        send: SendHandler? = nil
    ) {
        self.nextRequestID = nextRequestID
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

        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            Task { @MainActor [weak self] in
                do {
                    try await sendHandler(data)
                } catch {
                    guard let continuation = self?.pending.removeValue(forKey: id) else {
                        return
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func handleResponse(
        id: RequestId,
        result: Result<LSPResponse, LSPError>
    ) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        continuation.resume(with: result.mapError { $0 as any Error })
    }

    func failAllPending(with error: LSPError) {
        let continuations = Array(pending.values)
        pending.removeAll()
        continuations.forEach { $0.resume(throwing: error) }
    }

    var pendingCount: Int {
        pending.count
    }

    private func allocateRequestID() -> RequestId {
        let value = nextRequestID
        nextRequestID = value == Int.max ? 1 : value + 1
        return .number(value)
    }
}
