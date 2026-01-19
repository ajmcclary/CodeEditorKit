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

    /// Sends shutdown request and exit notification
    /// - Parameters:
    ///   - sendRequest: Function to send requests
    ///   - sendNotification: Function to send notifications
    static func sendShutdownRequest(
        sendRequest: @escaping (String, any Codable & Sendable) async throws -> LSPResponse,
        sendNotification: @escaping (String, any Codable & Sendable) async throws -> Void
    ) async throws {
        _ = try await sendRequest("shutdown", EmptyParams())
        try await sendNotification("exit", EmptyParams())
    }
}

// MARK: - Empty Parameters

struct EmptyParams: Codable, Sendable {}
