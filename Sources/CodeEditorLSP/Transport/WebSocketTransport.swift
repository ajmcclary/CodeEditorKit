import CodeEditorCommon
import Foundation

/// Transport implementation using WebSocket for remote LSP servers (all platforms)
///
/// WebSocketTransport enables communication with LSP servers over WebSocket connections,
/// allowing language server functionality on platforms that don't support local process
/// execution (iOS / iPadOS).
///
/// ## Features
/// - Cross-platform support (macOS and iOS / iPadOS)
/// - Reports a dropped connection to its owner (`setDisconnectHandler`); a
///   transport without an owner handler reconnects with backoff
///   (`autoReconnect`). Messages are never queued for, or replayed to, a
///   new connection: that server has not been `initialize`d.
/// - Support for both ws:// and wss:// protocols
/// - Binary and text message support
///
/// ## Example Usage
/// ```swift
/// let transport = WebSocketTransport(
///     url: URL(string: "wss://lsp.example.com/swift")!,
///     headers: ["Authorization": "Bearer token"]
/// )
/// 
/// try await transport.connect()
/// ```
@available(macOS 10.15, iOS 13.0, *)
public actor WebSocketTransport: LSPTransport {
    // MARK: - Properties

    private let url: URL
    private let headers: [String: String]
    private let configuration: LSPTransportConfiguration
    private let securityOptions: SecurityOptions
    private let certificatePinning: CertificatePinning?
    private let validateSSLCertificates: Bool

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var sessionDelegate: WebSocketPinningDelegate?
    private var dataHandler: (@Sendable (Data) async -> Void)?
    private var disconnectHandler: (@Sendable () async -> Void)?
    private var receiveTask: Task<Void, Never>?

    private var reconnectAttempts = 0
    private var isReconnecting = false

    private let logger = CodeEditorLog.lsp(category: "WebSocketTransport")

    // MARK: - Initialization

    public init(
        url: URL,
        headers: [String: String] = [:],
        configuration: LSPTransportConfiguration = LSPTransportConfiguration(),
        securityOptions: SecurityOptions = SecurityOptions(),
        certificatePinning: CertificatePinning? = nil,
        validateSSLCertificates: Bool = true
    ) {
        self.url = url
        self.headers = headers
        self.configuration = configuration
        self.securityOptions = securityOptions
        self.certificatePinning = certificatePinning
        self.validateSSLCertificates = validateSSLCertificates
    }

    // MARK: - Configuration Builders

    /// Snapshot of the security-relevant settings the transport applies on
    /// connect. Exposed for unit tests; not part of the production API
    /// surface used at runtime.
    public struct SecuritySnapshot: Sendable {
        public let minimumTLSVersion: SecurityOptions.TLSVersion
        public let pinningMethod: CertificatePinning.PinningMethod?
        public let pinnedDataCount: Int
        public let validateSSLCertificates: Bool
    }

    /// Read back the configured security settings. Useful for verifying
    /// that `RemoteLSPConfiguration` plumbed through correctly.
    public func securityConfigurationSnapshot() -> SecuritySnapshot {
        SecuritySnapshot(
            minimumTLSVersion: securityOptions.minimumTLSVersion,
            pinningMethod: certificatePinning?.method,
            pinnedDataCount: (certificatePinning?.pinnedData.count ?? 0)
                + (certificatePinning?.backupPins.count ?? 0),
            validateSSLCertificates: validateSSLCertificates
        )
    }

    /// Build a `URLSessionConfiguration` honoring the transport's connection
    /// timeouts and the security options' minimum TLS version. Extracted so
    /// the mapping can be unit-tested without spinning up a real session.
    public static func makeURLSessionConfiguration(
        transport: LSPTransportConfiguration,
        security: SecurityOptions
    ) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = transport.connectionTimeout
        config.timeoutIntervalForResource = transport.connectionTimeout
        config.tlsMinimumSupportedProtocolVersion = security.minimumTLSVersion.tlsProtocolVersion
        return config
    }

    // MARK: - LSPTransport Implementation

    public var isConnected: Bool {
        webSocketTask?.state == .running
    }

    public func connect() async throws {
        guard webSocketTask == nil else {
            throw LSPTransportError.transportSpecific(message: "WebSocket already connected")
        }

        logger.info("Connecting to WebSocket LSP server: \(url)")

        // A reconnect must not leak the previous session (and its delegate).
        urlSession?.invalidateAndCancel()
        urlSession = nil

        let sessionConfig = Self.makeURLSessionConfiguration(
            transport: configuration, security: securityOptions
        )

        // Only install a delegate when the caller asked for non-default trust
        // handling. Default-cert validation is already what `URLSession`
        // does with a `nil` delegate, so avoid paying the actor-hop cost
        // when nothing custom is requested.
        let needsCustomTrustHandling = certificatePinning != nil || !validateSSLCertificates
        if needsCustomTrustHandling {
            let delegate = WebSocketPinningDelegate(
                pinning: certificatePinning,
                validateSSLCertificates: validateSSLCertificates
            )
            sessionDelegate = delegate
            urlSession = URLSession(
                configuration: sessionConfig, delegate: delegate, delegateQueue: nil
            )
        } else {
            sessionDelegate = nil
            urlSession = URLSession(configuration: sessionConfig)
        }

        // Create WebSocket task
        var request = URLRequest(url: url)
        request.timeoutInterval = configuration.connectionTimeout

        // Add headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        guard let urlSession else {
            throw LSPTransportError.connectionFailed(underlying: nil)
        }

        webSocketTask = urlSession.webSocketTask(with: request)

        // Start the connection
        webSocketTask?.resume()

        // Wait for connection to be established
        do {
            try await waitForConnection()
            logger.info("WebSocket connection established")

            // Start receiving messages
            if dataHandler != nil {
                startReceiving()
            }

            // Reset reconnect attempts on successful connection
            reconnectAttempts = 0
        } catch {
            webSocketTask?.cancel()
            webSocketTask = nil
            self.urlSession?.invalidateAndCancel()
            self.urlSession = nil
            throw LSPTransportError.connectionFailed(underlying: error)
        }
    }

    public func disconnect() async {
        logger.info("Disconnecting WebSocket")

        receiveTask?.cancel()
        receiveTask = nil

        // Send close frame
        if let webSocketTask {
            webSocketTask.cancel(with: .normalClosure, reason: nil)
        }

        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        sessionDelegate = nil
        isReconnecting = false
    }

    public func send(_ data: Data) async throws {
        // Frame via the shared codec; sent below as a single binary frame.
        let message = LSPFrameCodec.encode(data)

        guard let webSocketTask, webSocketTask.state == .running, !isReconnecting else {
            throw LSPTransportError.notConnected
        }

        do {
            // Send as binary message
            try await webSocketTask.send(.data(message))
            logger.debug("Sent \(message.count) bytes via WebSocket")
        } catch {
            throw LSPTransportError.sendFailed(underlying: error)
        }
    }

    public func receive() async throws -> Data {
        guard let webSocketTask, webSocketTask.state == .running else {
            throw LSPTransportError.notConnected
        }

        do {
            let message = try await webSocketTask.receive()

            switch message {
            case .data(let data):
                return data

            case .string(let string):
                guard let data = string.data(using: .utf8) else {
                    throw LSPTransportError.invalidData
                }
                return data

            @unknown default:
                throw LSPTransportError.invalidData
            }
        } catch {
            throw LSPTransportError.receiveFailed(underlying: error)
        }
    }

    public func setDisconnectHandler(_ handler: @escaping @Sendable () async -> Void) async {
        disconnectHandler = handler
    }

    public func setDataHandler(_ handler: @escaping @Sendable (Data) async -> Void) async {
        self.dataHandler = handler

        // Start receiving if connected
        if isConnected {
            startReceiving()
        }
    }

    // MARK: - Private Methods

    /// Waits until the WebSocket handshake has completed. A task reports
    /// `.running` as soon as `resume()` is called, so the connection is
    /// proven with a ping/pong round trip instead.
    private func waitForConnection() async throws {
        guard let webSocketTask else {
            throw LSPTransportError.connectionFailed(underlying: nil)
        }
        let timeout = configuration.connectionTimeout
        let state = PingWaitState()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            webSocketTask.sendPing { error in
                guard state.claim() else { return }
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            Task {
                try? await Task.sleep(for: .seconds(timeout.isFinite ? max(0, timeout) : 0))
                guard state.claim() else { return }
                continuation.resume(throwing: LSPTransportError.transportSpecific(message: "Connection timeout"))
            }
        }
    }

    private func startReceiving() {
        receiveTask?.cancel()

        receiveTask = Task {
            logger.debug("Started receiving from WebSocket")

            while !Task.isCancelled && webSocketTask?.state == .running {
                do {
                    let data = try await receive()
                    if let handler = dataHandler {
                        await handler(data)
                    }
                } catch {
                    logger.error("Error receiving from WebSocket: \(error)")

                    // An owner (LSPClient) must re-initialize on a new
                    // connection, so it is told instead of reconnecting
                    // silently underneath it.
                    if let disconnectHandler {
                        await disconnectHandler()
                    } else if configuration.autoReconnect && !isReconnecting {
                        await attemptReconnection()
                    }
                    break
                }
            }

            logger.debug("Stopped receiving from WebSocket")
        }
    }

    private func attemptReconnection() async {
        guard configuration.autoReconnect && !isReconnecting else { return }
        guard reconnectAttempts < configuration.maxReconnectAttempts else {
            logger.error("Max reconnection attempts reached")
            return
        }

        isReconnecting = true
        reconnectAttempts += 1

        let delay = configuration.reconnectDelay * Double(reconnectAttempts)
        logger.info("Attempting reconnection \(reconnectAttempts)/\(configuration.maxReconnectAttempts) after \(delay)s")

        // Wait with exponential backoff
        try? await Task.sleep(for: .seconds(delay.isFinite ? max(0, delay) : 0))

        // Clean up existing connection
        webSocketTask?.cancel()
        webSocketTask = nil

        do {
            try await connect()
            isReconnecting = false
        } catch {
            logger.error("Reconnection failed: \(error)")
            isReconnecting = false

            // Try again if we haven't reached the limit
            if reconnectAttempts < configuration.maxReconnectAttempts {
                await attemptReconnection()
            }
        }
    }

    deinit {
        receiveTask?.cancel()
        webSocketTask?.cancel()
    }
}

/// Single-resumption flag for `waitForConnection`'s ping/timeout race.
private final class PingWaitState: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
