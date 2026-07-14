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
/// - Automatic reconnection with exponential backoff
/// - Message queuing during disconnection
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
    private var receiveTask: Task<Void, Never>?

    private var messageQueue: [Data] = []
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

            // Send any queued messages
            await sendQueuedMessages()

            // Reset reconnect attempts on successful connection
            reconnectAttempts = 0
        } catch {
            webSocketTask?.cancel()
            webSocketTask = nil
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
        messageQueue.removeAll()
        isReconnecting = false
    }

    public func send(_ data: Data) async throws {
        // Frame via the shared codec; sent below as a single binary frame.
        let message = LSPFrameCodec.encode(data)

        guard let webSocketTask, webSocketTask.state == .running else {
            if configuration.autoReconnect && !isReconnecting {
                // Queue message for later delivery
                logger.debug("Queuing message while disconnected")
                messageQueue.append(message)

                // Attempt reconnection
                Task {
                    await attemptReconnection()
                }
                return
            } else {
                throw LSPTransportError.notConnected
            }
        }

        do {
            // Send as binary message
            try await webSocketTask.send(.data(message))
            logger.debug("Sent \(message.count) bytes via WebSocket")
        } catch {
            // Handle send failure
            if configuration.autoReconnect {
                messageQueue.append(message)
                Task {
                    await attemptReconnection()
                }
            }
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

    public func setDataHandler(_ handler: @escaping @Sendable (Data) async -> Void) async {
        self.dataHandler = handler

        // Start receiving if connected
        if isConnected {
            startReceiving()
        }
    }

    // MARK: - Private Methods

    private func waitForConnection() async throws {
        let maxAttempts = 30 // 30 * 100ms = 3 seconds
        var attempts = 0

        while attempts < maxAttempts {
            if webSocketTask?.state == .running {
                return
            }

            if webSocketTask?.state == .completed || webSocketTask?.state == .canceling {
                throw LSPTransportError.connectionFailed(underlying: nil)
            }

            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            attempts += 1
        }

        throw LSPTransportError.transportSpecific(message: "Connection timeout")
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

                    if configuration.autoReconnect && !isReconnecting {
                        await attemptReconnection()
                    }
                    break
                }
            }

            logger.debug("Stopped receiving from WebSocket")
        }
    }

    private func sendQueuedMessages() async {
        guard !messageQueue.isEmpty else { return }

        logger.info("Sending \(messageQueue.count) queued messages")

        let messages = messageQueue
        messageQueue.removeAll()

        for message in messages {
            do {
                if let webSocketTask {
                    try await webSocketTask.send(.data(message))
                }
            } catch {
                logger.error("Failed to send queued message: \(error)")
                // Re-queue failed messages
                messageQueue.append(message)
            }
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
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

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
