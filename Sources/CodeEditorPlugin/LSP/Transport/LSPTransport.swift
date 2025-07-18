import Foundation

/// Protocol defining the transport layer for LSP communication
///
/// This abstraction allows different transport mechanisms (Process, WebSocket, HTTP, etc.)
/// to be used for LSP communication, enabling cross-platform support.
///
/// ## Overview
///
/// LSPTransport provides a uniform interface for bidirectional communication with
/// Language Server Protocol servers, regardless of the underlying transport mechanism.
///
/// ## Implementations
///
/// - `ProcessTransport`: Uses Process and Pipes for local language servers (macOS only)
/// - `WebSocketTransport`: Uses URLSession WebSocket for remote servers (all platforms)
/// - Future: HTTP, SSH, TCP transports
///
/// ## Example Usage
///
/// ```swift
/// // Local transport (macOS)
/// let transport = ProcessTransport(
///     executablePath: "/usr/bin/sourcekit-lsp",
///     arguments: ["--log-level", "info"]
/// )
///
/// // Remote transport (all platforms)
/// let transport = WebSocketTransport(
///     url: URL(string: "wss://lsp.example.com/swift")!
/// )
///
/// try await transport.connect()
/// try await transport.send(messageData)
/// let response = try await transport.receive()
/// ```
@available(macOS 10.15, iOS 13.0, *)
public protocol LSPTransport: Actor {
    /// Current connection state
    var isConnected: Bool { get }
    
    /// Connect to the LSP server
    /// - Throws: Transport-specific connection errors
    func connect() async throws
    
    /// Disconnect from the LSP server
    func disconnect() async
    
    /// Send data to the LSP server
    /// - Parameter data: The data to send
    /// - Throws: Transport-specific send errors
    func send(_ data: Data) async throws
    
    /// Receive data from the LSP server
    /// - Returns: The received data
    /// - Throws: Transport-specific receive errors
    /// - Note: This method should block until data is available
    func receive() async throws -> Data
    
    /// Set a handler for incoming data
    /// - Parameter handler: Closure called when data is received
    /// - Note: Some transports may push data asynchronously
    func setDataHandler(_ handler: @escaping @Sendable (Data) async -> Void) async
}

/// Errors that can occur during transport operations
public enum LSPTransportError: LocalizedError {
    case notConnected
    case connectionFailed(underlying: Error?)
    case sendFailed(underlying: Error?)
    case receiveFailed(underlying: Error?)
    case invalidData
    case transportSpecific(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Transport is not connected"

        case .connectionFailed(let error):
            return "Connection failed: \(error?.localizedDescription ?? "Unknown error")"

        case .sendFailed(let error):
            return "Send failed: \(error?.localizedDescription ?? "Unknown error")"

        case .receiveFailed(let error):
            return "Receive failed: \(error?.localizedDescription ?? "Unknown error")"

        case .invalidData:
            return "Received invalid data"

        case .transportSpecific(let message):
            return message
        }
    }
}

/// Connection configuration shared by all transports
public struct LSPTransportConfiguration: Sendable, Codable {
    /// Timeout for connection attempts
    public let connectionTimeout: TimeInterval
    
    /// Timeout for read operations
    public let readTimeout: TimeInterval
    
    /// Timeout for write operations  
    public let writeTimeout: TimeInterval
    
    /// Whether to automatically reconnect on disconnection
    public let autoReconnect: Bool
    
    /// Maximum number of reconnection attempts
    public let maxReconnectAttempts: Int
    
    /// Delay between reconnection attempts
    public let reconnectDelay: TimeInterval
    
    public init(
        connectionTimeout: TimeInterval = 30.0,
        readTimeout: TimeInterval = 60.0,
        writeTimeout: TimeInterval = 30.0,
        autoReconnect: Bool = true,
        maxReconnectAttempts: Int = 3,
        reconnectDelay: TimeInterval = 2.0
    ) {
        self.connectionTimeout = connectionTimeout
        self.readTimeout = readTimeout
        self.writeTimeout = writeTimeout
        self.autoReconnect = autoReconnect
        self.maxReconnectAttempts = maxReconnectAttempts
        self.reconnectDelay = reconnectDelay
    }
}
