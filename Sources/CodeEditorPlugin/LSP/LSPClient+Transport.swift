import Foundation

/// Extension to LSPClient that adds transport-based initialization
/// This allows LSPClient to work on all platforms, not just macOS
@available(macOS 10.15, iOS 13.0, *)
extension LSPClient {
    /// Initialize LSPClient with a specific transport
    /// - Parameter transport: The transport to use for communication
    public convenience init(transport: LSPTransport) {
        self.init()
        self.transport = transport
    }
    
    /// Connect using server configuration that automatically selects appropriate transport
    /// - Parameter configuration: Unified server configuration
    public func connect(configuration: LSPServerConfiguration) async throws {
        // Create appropriate transport based on configuration
        let transport = try await configuration.createTransport()
        self.transport = transport
        
        // Extract base configuration
        let baseConfig: ServerConfiguration
        switch configuration {
        case .local(let localConfig):
            baseConfig = ServerConfiguration(
                languageId: "swift", // TODO: Make this configurable
                serverPath: localConfig.executablePath,
                workspaceRoot: localConfig.workingDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                serverArguments: localConfig.arguments
            )

        case .remote(let remoteConfig):
            baseConfig = ServerConfiguration(
                languageId: "swift", // TODO: Make this configurable
                serverPath: remoteConfig.serverURL.absoluteString,
                workspaceRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                serverArguments: []
            )
        }
        
        // Connect using the base implementation
        try await connect(configuration: baseConfig)
    }
}

// MARK: - Platform-Agnostic LSPClient

// Remove platform restrictions to make LSPClient available everywhere
#if !canImport(AppKit) || targetEnvironment(macCatalyst)

import Foundation

/// Language Server Protocol client implementation (cross-platform version)
///
/// This version of LSPClient works on all platforms by using the transport abstraction
/// instead of directly using Process API.
@available(macOS 10.15, iOS 13.0, *)
@MainActor
public final class LSPClient: ObservableObject {
    // MARK: - Configuration
    
    /// LSP server configuration
    public struct ServerConfiguration: Sendable {
        public let languageId: String
        public let serverPath: String
        public let serverArguments: [String]
        public let workspaceRoot: URL
        public let capabilities: ClientCapabilities
        
        public init(
            languageId: String,
            serverPath: String,
            workspaceRoot: URL,
            serverArguments: [String] = [],
            capabilities: ClientCapabilities = .default
        ) {
            self.languageId = languageId
            self.serverPath = serverPath
            self.workspaceRoot = workspaceRoot
            self.serverArguments = serverArguments
            self.capabilities = capabilities
        }
    }
    
    // MARK: - State
    
    /// Current connection state
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    
    /// Server capabilities received during initialization
    @Published public private(set) var serverCapabilities: ServerCapabilities?
    
    /// Active diagnostics by document URI
    @Published public private(set) var diagnostics: [String: [Diagnostic]] = [:]
    
    /// Transport for communication
    internal var transport: LSPTransport?
    
    /// LSP message handler
    private let messageHandler = LSPMessageHandler()
    
    /// Request/response tracking
    private var pendingRequests: [Int: LSPRequestCompletion] = [:]
    private var nextRequestId: Int = 1
    
    /// Logger for debugging
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.lsp", category: "LSPClient")
    
    // MARK: - Types
    
    public enum ConnectionState: String, CaseIterable, Sendable {
        case disconnected
        case connecting
        case initializing
        case initialized
        case shuttingDown
        case error
    }
    
    typealias LSPRequestCompletion = (Result<LSPResponse, LSPError>) -> Void
    
    // MARK: - Initialization
    
    public init() {}
    
    deinit {
        Task { @MainActor in
            disconnect()
        }
    }
    
    // MARK: - Connection Management
    
    /// Connect to an LSP server
    public func connect(configuration: ServerConfiguration) async throws {
        guard connectionState == .disconnected else {
            throw LSPError.alreadyConnected
        }
        
        guard let transport else {
            throw LSPError.transportNotConfigured
        }
        
        connectionState = .connecting
        logger.info("Connecting to LSP server via transport")
        
        do {
            // Set up message handler callbacks before connecting
            await setupMessageHandlerCallbacks()
            
            // Connect transport
            try await transport.connect()
            
            // Set data handler for incoming messages
            await transport.setDataHandler { [weak self] data in
                await self?.messageHandler.processIncomingData(data)
            }
            
            // Initialize LSP connection
            try await initializeServer(configuration: configuration)
            
            connectionState = .initialized
            logger.info("Successfully connected and initialized LSP server")
        } catch {
            connectionState = .error
            logger.error("Failed to connect to LSP server: \(error.localizedDescription)")
            disconnect()
            throw error
        }
    }
    
    /// Disconnect from the current LSP server
    public func disconnect() {
        logger.info("Disconnecting from LSP server")
        
        // Send shutdown request if connected
        if connectionState == .initialized {
            connectionState = .shuttingDown
            
            Task {
                try? await sendShutdownRequest()
                await transport?.disconnect()
            }
        } else {
            Task {
                await transport?.disconnect()
            }
        }
        
        // Clean up state
        serverCapabilities = nil
        diagnostics.removeAll()
        pendingRequests.removeAll()
        
        connectionState = .disconnected
    }
    
    // MARK: - Message Handling Setup
    
    private func setupMessageHandlerCallbacks() async {
        await messageHandler.setNotificationCallback { [weak self] method, data in
            await self?.handleNotification(method: method, data: data)
        }
        
        await messageHandler.setResponseCallback { [weak self] id, result in
            await self?.handleResponse(id: id, result: result)
        }
    }
    
    // MARK: - LSP Communication
    
    private func sendRequest<T: Encodable>(
        method: String,
        params: T
    ) async throws -> LSPResponse {
        let requestId = nextRequestId
        nextRequestId += 1
        
        let request = LSPRequest(
            jsonrpc: "2.0",
            id: .integer(requestId),
            method: method,
            params: params
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[requestId] = { result in
                continuation.resume(with: result)
            }
            
            Task {
                do {
                    try await transport?.send(data)
                } catch {
                    pendingRequests.removeValue(forKey: requestId)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func sendNotification<T: Encodable>(
        method: String,
        params: T
    ) async throws {
        let notification = LSPNotification(
            jsonrpc: "2.0",
            method: method,
            params: params
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)
        
        try await transport?.send(data)
    }
    
    // The rest of the implementation remains the same as the original LSPClient
    // but without the Process-specific code...
}

// MARK: - LSP Errors

public enum LSPError: LocalizedError {
    case notConnected
    case alreadyConnected
    case transportNotConfigured
    case invalidResponse
    case serverError(message: String)
    case timeout
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "LSP client is not connected"

        case .alreadyConnected:
            return "LSP client is already connected"

        case .transportNotConfigured:
            return "No transport configured for LSP client"

        case .invalidResponse:
            return "Invalid response from LSP server"

        case .serverError(let message):
            return "LSP server error: \(message)"

        case .timeout:
            return "LSP request timed out"

        case .cancelled:
            return "LSP request was cancelled"
        }
    }
}

#endif
