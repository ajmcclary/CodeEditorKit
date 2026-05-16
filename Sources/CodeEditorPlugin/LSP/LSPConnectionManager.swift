import Foundation

// MARK: - LSP Connection Manager

/// Manages LSP server connection lifecycle
@MainActor
enum LSPConnectionManager {
    // MARK: - Type Alias

    typealias ConnectionState = LSPClient.ConnectionState

    // MARK: - Connection Methods

    /// Validates that connection can proceed
    /// - Parameter currentState: The current connection state
    /// - Throws: LSPError.alreadyConnected if not disconnected
    static func validateCanConnect(currentState: ConnectionState) throws {
        guard currentState == .disconnected else {
            throw LSPError.alreadyConnected
        }
    }

    /// Validates that the client is connected
    /// - Parameter currentState: The current connection state
    /// - Throws: LSPError.notConnected if not initialized
    static func validateConnected(currentState: ConnectionState) throws {
        guard currentState == .initialized else {
            throw LSPError.notConnected
        }
    }

    /// Starts a connection using a transport
    /// - Parameters:
    ///   - transport: The transport to use
    ///   - messageHandler: The message handler for incoming data
    /// - Throws: LSPError.transportNotConfigured if transport is nil
    static func startTransportConnection(
        transport: LSPTransport?,
        messageHandler: LSPMessageHandler
    ) async throws {
        guard let transport else {
            throw LSPError.transportNotConfigured
        }

        // Set up data handler before connecting
        await transport.setDataHandler { data in
            await messageHandler.processIncomingData(data)
        }

        // Connect transport
        try await transport.connect()
    }

    /// Initializes the LSP server with the given configuration
    /// - Parameters:
    ///   - configuration: Server configuration
    ///   - sendRequest: Function to send requests
    ///   - sendNotification: Function to send notifications
    /// - Returns: Server capabilities from initialization
    static func initializeServer(
        configuration: LSPClient.ServerConfiguration,
        sendRequest: @escaping (String, any Codable & Sendable) async throws -> LSPResponse,
        sendNotification: @escaping (String, any Codable & Sendable) async throws -> Void
    ) async throws -> ServerCapabilities {
        let initializeParams = InitializeParams(
            processId: ProcessInfo.processInfo.processIdentifier,
            rootUri: configuration.workspaceRoot.absoluteString,
            capabilities: configuration.capabilities,
            workspaceFolders: [
                WorkspaceFolder(
                    uri: configuration.workspaceRoot.absoluteString,
                    name: configuration.workspaceRoot.lastPathComponent
                )
            ]
        )

        let response = try await sendRequest("initialize", initializeParams)
        let capabilities = try response.decode(as: InitializeResult.self).capabilities

        // Send initialized notification
        try await sendNotification("initialized", EmptyParams())

        return capabilities
    }

    /// Default deadline for `sendShutdownRequest`. Servers that don't ack
    /// shutdown within this window are abandoned so disconnect() can finish
    /// cleanup; the caller is responsible for failing any continuation the
    /// abandoned attempt left behind in `pendingRequests`.
    static let defaultShutdownTimeout: Duration = .seconds(2)

    /// Sends shutdown request and exit notification, bounded by a timeout.
    ///
    /// A wedged or dead language server can leave `sendRequest` suspended
    /// on a pending-response continuation that never resumes; without a
    /// bound, `disconnect()` cleanup never runs and the transport/process
    /// leaks. We can't put the wait inside a structured `TaskGroup`
    /// because `Task<T>.value` and `withCheckedThrowingContinuation`
    /// don't honor cancellation — a structured group would itself hang
    /// waiting for the cancelled child to complete.
    ///
    /// Instead, two MainActor child tasks race to resume a single
    /// continuation:
    ///
    /// 1. The shutdown attempt runs unstructured; on success/failure it
    ///    resumes the continuation if no one has yet.
    /// 2. A timer task resumes the continuation with `LSPError.timeout`
    ///    if the deadline elapses first.
    ///
    /// When the timeout wins, we return immediately and leave the
    /// shutdown task suspended in the background. The caller is
    /// responsible for draining `pendingRequests` so the abandoned
    /// continuation is failed and the background task can complete.
    /// MainActor serialization makes the `didResume` check-and-set
    /// atomic without an explicit lock.
    /// - Parameters:
    ///   - sendRequest: Function to send requests
    ///   - sendNotification: Function to send notifications
    ///   - timeout: Maximum time to wait for the server's shutdown ack
    ///     before throwing `LSPError.timeout`. Defaults to
    ///     `defaultShutdownTimeout`.
    static func sendShutdownRequest(
        sendRequest: @escaping (String, any Codable & Sendable) async throws -> LSPResponse,
        sendNotification: @escaping (String, any Codable & Sendable) async throws -> Void,
        timeout: Duration = defaultShutdownTimeout
    ) async throws {
        let state = ShutdownRaceState()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Shutdown attempt — fire-and-forget once the race resolves.
            let shutdownTask = Task { @MainActor in
                do {
                    _ = try await sendRequest("shutdown", EmptyParams())
                    try await sendNotification("exit", EmptyParams())
                    if state.tryClaim() {
                        continuation.resume()
                    }
                } catch {
                    if state.tryClaim() {
                        continuation.resume(throwing: error)
                    }
                }
            }

            // Timer — wins the race when the server doesn't ack in time.
            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                if state.tryClaim() {
                    shutdownTask.cancel()
                    continuation.resume(throwing: LSPError.timeout)
                }
            }
        }
    }
}

// MARK: - Shutdown Race State

/// Single-resumption flag for `sendShutdownRequest`'s shutdown/timeout
/// race. `tryClaim()` is the only mutation point and runs exclusively on
/// the MainActor (both racing tasks inherit the enclosing `@MainActor`
/// isolation), so the check-and-set is serialized without a lock.
@MainActor
private final class ShutdownRaceState {
    private var didResume = false

    func tryClaim() -> Bool {
        if didResume { return false }
        didResume = true
        return true
    }
}

// MARK: - Empty Parameters

struct EmptyParams: Codable, Sendable {}
