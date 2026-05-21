// LSP client is available on all platforms to support remote LSP connections
// On platforms without Process API, only remote LSP servers can be used

import CodeEditorCommon
import CodeEditorLanguages
import Foundation

/// Language Server Protocol client implementation
///
/// Provides integration with Language Server Protocol (LSP) servers for
/// advanced code intelligence features including:
/// - Code completion
/// - Go to definition
/// - Hover documentation
/// - Diagnostics
/// - Symbol navigation
///
/// This class serves as a facade that coordinates LSP communication through
/// dedicated components: LSPConnectionManager, LSPLanguageFeatures, and LSPProcessManager.
///
/// - Important: LSP client is available on all platforms, but functionality varies:
///   - macOS: Full support for both local and remote LSP servers
///   - iOS / iPadOS: Remote LSP servers only (via WebSocket transport)
///
/// ## Platform Support
/// - macOS: Full support (local + remote servers)
/// - iOS: Remote servers only — local servers require the `Process` API (AppKit)
///
/// ## Example Usage
/// ```swift
/// // Construct via LanguageServerConfig (the public-facing path).
/// let manager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: projectURL)
///
/// // Local server (macOS only). Throws LSPError on iOS at startLanguageServer time.
/// manager.registerLanguageServer(.local(
///     languageId: "swift",
///     serverPath: "/usr/bin/sourcekit-lsp",
///     fileExtensions: ["swift"]
/// ))
///
/// // Remote server (all platforms).
/// manager.registerLanguageServer(.remote(
///     languageId: "swift",
///     url: URL(string: "wss://lsp.example.com/swift")!,
///     fileExtensions: ["swift"],
///     authentication: .bearerToken("token")
/// ))
/// ```
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

    // MARK: - Types

    public enum ConnectionState: String, CaseIterable, Sendable {
        case disconnected
        case connecting
        case initializing
        case initialized
        case shuttingDown
        case error
    }

    public typealias LSPRequestCompletion = @Sendable (Result<LSPResponse, LSPError>) -> Void

    // MARK: - State

    /// Current connection state
    @Published public private(set) var connectionState: ConnectionState = .disconnected

    /// Server capabilities received during initialization
    @Published public private(set) var serverCapabilities: ServerCapabilities?

    /// Active diagnostics by document URI
    @Published public private(set) var diagnostics: [String: [LSPDiagnostic]] = [:]

    // MARK: - Private Properties

    /// LSP message handler
    private let messageHandler = LSPMessageHandler()

    /// Transport for communication (optional for backward compatibility)
    internal var transport: LSPTransport?

    /// Test-only hook: fires from the modern `connect(configuration:, languageId:)` overload
    /// before any transport work. Production callers leave this `nil`.
    internal var recordingHandler: (@Sendable (LSPServerConfiguration, String) async -> Void)?

    /// Process manager for local server processes (macOS only)
    private lazy var processManager = LSPProcessManager(messageHandler: messageHandler)

    /// Request/response tracking. Keyed by the JSON-RPC `RequestId` so
    /// string-typed IDs (UUID-style or otherwise) route back to their
    /// pending continuation; the prior `[Int: ...]` map silently dropped
    /// non-numeric IDs at the message-handler layer.
    private var pendingRequests: [RequestId: LSPRequestCompletion] = [:]
    private var nextRequestId: Int = 1

    /// In-flight disconnect Task, if any. Used to serialize transport teardown
    /// so two concurrent `disconnect()` calls cannot each spawn a Task that
    /// races on `transport.disconnect()` and `connectionState`. Accessed only
    /// from the `@MainActor`-isolated client.
    private var disconnectTask: Task<Void, Never>?

    /// Logger for debugging
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.lsp", category: "LSPClient")

    // MARK: - Initialization

    /// Creates a new LSP client.
    ///
    /// - Important: The message handler is not automatically set up in the initializer.
    ///   Use `createAndSetup()` for a fully initialized client, or call `setupMessageHandler()`
    ///   manually after initialization.
    public init() {
        // No async work in synchronous init
    }

    /// Creates and sets up a new LSP client with message handlers initialized.
    /// This is the preferred way to create an LSP client.
    ///
    /// - Returns: A fully initialized LSP client ready for connection
    public static func createAndSetup() async -> LSPClient {
        let client = LSPClient()
        await client.setupMessageHandler()
        return client
    }

    deinit {
        // Note: Cannot call MainActor-isolated methods from deinit
        // Disconnection cleanup will happen automatically when the process terminates
    }

    // MARK: - Connection Management

    /// Connect to an LSP server with the given configuration
    /// - Parameter configuration: Server configuration
    /// - Throws: `LSPError.alreadyConnected` if the client is not in
    ///   `.disconnected`; `LSPError.transportNotConfigured` if a transport
    ///   was expected but missing; `LSPError.connectionFailed`,
    ///   `LSPError.invalidResponse`, or `LSPError.decodingError` for
    ///   transport / initialize-handshake failures. On failure the state
    ///   moves to `.error` and `disconnect()` is dispatched to tear the
    ///   transport down before the error rethrows.
    public func connect(configuration: ServerConfiguration) async throws {
        try LSPConnectionManager.validateCanConnect(currentState: connectionState)

        connectionState = .connecting
        logger.info("Connecting to LSP server: \(configuration.serverPath)")

        do {
            // Use transport if available, otherwise fall back to process
            if transport != nil {
                try await LSPConnectionManager.startTransportConnection(
                    transport: transport,
                    messageHandler: messageHandler
                )
            } else {
                try processManager.startServerProcess(configuration: configuration)
            }

            connectionState = .initializing
            serverCapabilities = try await LSPConnectionManager.initializeServer(
                configuration: configuration,
                sendRequest: { [weak self] method, params in
                    guard let self else { throw LSPError.notConnected }
                    return try await self.sendRequest(method: method, params: params)
                },
                sendNotification: { [weak self] method, params in
                    guard let self else { throw LSPError.notConnected }
                    try await self.sendNotification(method: method, params: params)
                }
            )

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

        // Already torn down — nothing to do. Without this guard a second
        // `disconnect()` would re-spawn transport teardown and re-fail an
        // already-empty pending-request map.
        if connectionState == .disconnected {
            return
        }

        // Disconnect already in flight — another `disconnect()` is awaiting
        // `transport.disconnect()` right now. Letting this call proceed would
        // spawn a second Task that races on the transport and on
        // `connectionState`. Skipping is safe because the in-flight Task will
        // drive state to `.disconnected` on its own.
        if disconnectTask != nil {
            return
        }

        let wasInitialized = (connectionState == .initialized)

        // Capture in-flight request continuations BEFORE clearing the map.
        // CheckedContinuations must be resumed exactly once — dropping the
        // closures would leave awaiters hanging forever (in production) or
        // trap (in DEBUG with strict-concurrency checks). Failing them with
        // `.notConnected` lets callers observe the disconnect deterministically.
        let pendingToFail = pendingRequests
        pendingRequests.removeAll()
        serverCapabilities = nil
        diagnostics.removeAll()

        if wasInitialized {
            connectionState = .shuttingDown

            disconnectTask = Task { [weak self] in
                guard let self else {
                    Self.failPending(pendingToFail)
                    return
                }

                do {
                    try await LSPConnectionManager.sendShutdownRequest(
                        sendRequest: { method, params in
                            try await self.sendRequest(method: method, params: params)
                        },
                        sendNotification: { method, params in
                            try await self.sendNotification(method: method, params: params)
                        }
                    )
                } catch {
                    self.logger.warning("Shutdown request failed: \(error.localizedDescription)")
                }

                // Capture anything still pending — typically the
                // shutdown request's own continuation when the server
                // didn't respond before the timeout. The abandoned
                // shutdown Task inside sendShutdownRequest stays
                // suspended on that continuation; failing it here
                // releases it so the task can complete on its own.
                let postShutdownPending = self.pendingRequests
                self.pendingRequests.removeAll()

                if let transport = self.transport {
                    await transport.disconnect()
                } else {
                    self.processManager.terminateServerProcess()
                }

                self.connectionState = .disconnected
                Self.failPending(pendingToFail)
                Self.failPending(postShutdownPending)
                self.disconnectTask = nil
            }
        } else {
            // Not initialized (e.g. `.connecting`, `.initializing`, `.error`):
            // skip the shutdown request and tear the transport down directly.
            if let transport {
                disconnectTask = Task { [weak self] in
                    await transport.disconnect()
                    self?.connectionState = .disconnected
                    Self.failPending(pendingToFail)
                    self?.disconnectTask = nil
                }
            } else {
                processManager.terminateServerProcess()
                connectionState = .disconnected
                Self.failPending(pendingToFail)
            }
        }
    }

    /// Fail any captured pending request continuations. Called after transport
    /// teardown so awaiters do not observe a `.notConnected` failure while the
    /// transport is still draining.
    private static func failPending(_ pending: [RequestId: LSPRequestCompletion]) {
        for completion in pending.values {
            completion(.failure(.notConnected))
        }
    }

    // MARK: - Document Management

    /// Open a document in the language server
    /// - Throws: `LSPError.notConnected` if the client is not in
    ///   `.initialized`; transport-layer errors (`.connectionFailed`,
    ///   underlying I/O) if the `textDocument/didOpen` notification cannot
    ///   be sent.
    public func openDocument(
        uri: String,
        languageId: String,
        version: Int,
        text: String
    ) async throws {
        try LSPConnectionManager.validateConnected(currentState: connectionState)

        let params = DidOpenTextDocumentParams(
            textDocument: TextDocumentItem(
                uri: uri,
                languageId: languageId,
                version: version,
                text: text
            )
        )

        try await sendNotification(method: "textDocument/didOpen", params: params)
        logger.debug("Opened document: \(uri)")
    }

    /// Update document content
    /// - Throws: `LSPError.notConnected` if the client is not in
    ///   `.initialized`; transport-layer errors if the
    ///   `textDocument/didChange` notification cannot be sent.
    public func updateDocument(
        uri: String,
        version: Int,
        changes: [TextDocumentContentChangeEvent]
    ) async throws {
        try LSPConnectionManager.validateConnected(currentState: connectionState)

        let params = DidChangeTextDocumentParams(
            textDocument: VersionedTextDocumentIdentifier(uri: uri, version: version),
            contentChanges: changes
        )

        try await sendNotification(method: "textDocument/didChange", params: params)
        logger.debug("Updated document: \(uri)")
    }

    /// Close a document
    /// - Throws: `LSPError.notConnected` if the client is not in
    ///   `.initialized`; transport-layer errors if the
    ///   `textDocument/didClose` notification cannot be sent.
    public func closeDocument(uri: String) async throws {
        try LSPConnectionManager.validateConnected(currentState: connectionState)

        let params = DidCloseTextDocumentParams(
            textDocument: TextDocumentIdentifier(uri: uri)
        )

        try await sendNotification(method: "textDocument/didClose", params: params)

        // Remove diagnostics for closed document
        diagnostics.removeValue(forKey: uri)

        logger.debug("Closed document: \(uri)")
    }

    // MARK: - Language Features

    /// Request code completion
    /// - Throws: `LSPError.notConnected` if the client is not in
    ///   `.initialized`; `LSPError.serverError` if the server responded
    ///   with an error code; `LSPError.invalidResponse` or
    ///   `LSPError.decodingError` if the response payload was malformed.
    public func requestCompletion(
        uri: String,
        position: Position
    ) async throws -> CompletionList {
        try LSPConnectionManager.validateConnected(currentState: connectionState)

        let params = LSPLanguageFeatures.createCompletionParams(uri: uri, position: position)
        let response = try await sendRequest(method: LSPLanguageFeatures.Methods.completion, params: params)
        return try LSPLanguageFeatures.parseCompletionResponse(response)
    }

    /// Request hover information
    /// - Throws: `LSPError.notConnected` if the client is not in
    ///   `.initialized`; `LSPError.serverError`, `LSPError.invalidResponse`,
    ///   or `LSPError.decodingError` per the standard request envelope.
    public func requestHover(
        uri: String,
        position: Position
    ) async throws -> Hover? {
        try LSPConnectionManager.validateConnected(currentState: connectionState)

        let params = LSPLanguageFeatures.createHoverParams(uri: uri, position: position)
        let response = try await sendRequest(method: LSPLanguageFeatures.Methods.hover, params: params)
        return LSPLanguageFeatures.parseHoverResponse(response)
    }

    /// Request symbol definition
    /// - Throws: `LSPError.notConnected` if the client is not in
    ///   `.initialized`; `LSPError.serverError`, `LSPError.invalidResponse`,
    ///   or `LSPError.decodingError` per the standard request envelope.
    public func requestDefinition(
        uri: String,
        position: Position
    ) async throws -> [Location] {
        try LSPConnectionManager.validateConnected(currentState: connectionState)

        let params = LSPLanguageFeatures.createDefinitionParams(uri: uri, position: position)
        let response = try await sendRequest(method: LSPLanguageFeatures.Methods.definition, params: params)
        return try LSPLanguageFeatures.parseDefinitionResponse(response)
    }

    /// Request document symbols
    /// - Throws: `LSPError.notConnected` if the client is not in
    ///   `.initialized`; `LSPError.serverError`, `LSPError.invalidResponse`,
    ///   or `LSPError.decodingError` per the standard request envelope.
    public func requestDocumentSymbols(uri: String) async throws -> [LSPDocumentSymbol] {
        try LSPConnectionManager.validateConnected(currentState: connectionState)

        let params = LSPLanguageFeatures.createDocumentSymbolParams(uri: uri)
        let response = try await sendRequest(method: LSPLanguageFeatures.Methods.documentSymbol, params: params)
        return try LSPLanguageFeatures.parseDocumentSymbolResponse(response)
    }

    // MARK: - Semantic Tokens

    /// Request full semantic tokens for a document.
    ///
    /// Returns `nil` without throwing if the client is not currently
    /// `.initialized` — semantic-token consumers are expected to tolerate a
    /// not-yet-ready server rather than treat it as an error condition.
    ///
    /// - Throws: `LSPError.serverError`, `LSPError.invalidResponse`, or
    ///   `LSPError.decodingError` if the request envelope succeeds but the
    ///   payload is malformed or the server reports an error.
    public func requestSemanticTokens(uri: String) async throws -> SemanticTokens? {
        guard connectionState == .initialized else { return nil }

        let params = SemanticTokensParams(
            textDocument: TextDocumentIdentifier(uri: uri)
        )
        let response = try await sendRequest(
            method: "textDocument/semanticTokens/full",
            params: params
        )
        return try response.decode(as: SemanticTokens.self)
    }

    /// Request semantic-token delta since a previous result.
    ///
    /// Returns `nil` without throwing if the client is not currently
    /// `.initialized`. See `requestSemanticTokens(uri:)` for the rationale.
    ///
    /// - Throws: `LSPError.serverError`, `LSPError.invalidResponse`, or
    ///   `LSPError.decodingError` for malformed-payload / server-error
    ///   responses.
    public func requestSemanticTokensDelta(
        uri: String,
        previousResultId: String
    ) async throws -> SemanticTokensDelta? {
        guard connectionState == .initialized else { return nil }

        let params = SemanticTokensDeltaParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            previousResultId: previousResultId
        )
        let response = try await sendRequest(
            method: "textDocument/semanticTokens/full/delta",
            params: params
        )
        return try response.decode(as: SemanticTokensDelta.self)
    }

    /// Request semantic tokens for a specific range.
    ///
    /// Returns `nil` without throwing if the client is not currently
    /// `.initialized`. See `requestSemanticTokens(uri:)` for the rationale.
    ///
    /// - Throws: `LSPError.serverError`, `LSPError.invalidResponse`, or
    ///   `LSPError.decodingError` for malformed-payload / server-error
    ///   responses.
    public func requestSemanticTokensRange(
        uri: String,
        range: LSPRange
    ) async throws -> SemanticTokens? {
        guard connectionState == .initialized else { return nil }

        let params = SemanticTokensRangeParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            range: range
        )
        let response = try await sendRequest(
            method: "textDocument/semanticTokens/range",
            params: params
        )
        return try response.decode(as: SemanticTokens.self)
    }

    // MARK: - Message Handler Setup

    /// Sets up the message handler callbacks for processing LSP messages.
    /// This method is automatically called by `createAndSetup()`.
    public func setupMessageHandler() async {
        await messageHandler.setNotificationCallback { [weak self] method, params in
            Task { @MainActor [weak self] in
                await self?.handleNotification(method: method, params: params)
            }
        }

        await messageHandler.setResponseCallback { [weak self] id, result in
            Task { @MainActor [weak self] in
                await self?.handleResponse(id: id, result: result)
            }
        }
    }

    // MARK: - Private Methods

    private func sendRequest(method: String, params: any Codable & Sendable) async throws -> LSPResponse {
        let requestId = nextRequestId
        nextRequestId += 1
        let key: RequestId = .number(requestId)

        let request = LSPRequest(
            id: key,
            method: method,
            params: params
        )

        return try await withCheckedThrowingContinuation { continuation in
            // Store completion handler
            pendingRequests[key] = { result in
                continuation.resume(with: result)
            }

            // Send request
            Task {
                do {
                    try await self.sendMessage(request)
                } catch {
                    _ = await MainActor.run {
                        self.pendingRequests.removeValue(forKey: key)
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func sendNotification(method: String, params: any Codable & Sendable) async throws {
        let notification = LSPNotification(method: method, params: params)
        try await sendMessage(notification)
    }

    private func sendMessage(_ message: any Codable) async throws {
        // Use transport if available
        if let transport {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(message)
            try await transport.send(jsonData)
            return
        }

        // Fall back to process-based implementation
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(message)
        try processManager.sendMessage(jsonData)
    }

    private func handleNotification(method: String, params: Data) async {
        switch method {
        case "textDocument/publishDiagnostics":
            await handleDiagnosticsNotification(params: params)

        case "window/logMessage":
            await handleLogMessage(params: params)

        case "window/showMessage":
            await handleShowMessage(params: params)

        default:
            logger.debug("Unhandled notification: \(method)")
        }
    }

    private func handleResponse(id: RequestId, result: Result<LSPResponse, LSPError>) async {
        if let completion = pendingRequests.removeValue(forKey: id) {
            completion(result)
        }
    }

    private func handleDiagnosticsNotification(params: Data) async {
        do {
            let publishDiagnostics = try JSONDecoder().decode(PublishDiagnosticsParams.self, from: params)
            diagnostics[publishDiagnostics.uri] = publishDiagnostics.diagnostics
            logger.debug("Received diagnostics for \(publishDiagnostics.uri): \(publishDiagnostics.diagnostics.count) items")
        } catch {
            logger.error("Failed to decode diagnostics: \(error.localizedDescription)")
        }
    }

    private func handleLogMessage(params: Data) async {
        do {
            let logMessage = try JSONDecoder().decode(LogMessageParams.self, from: params)
            logger.info("LSP Server Log: [\(logMessage.type.rawValue)] \(logMessage.message)")
        } catch {
            logger.error("Failed to decode log message: \(error.localizedDescription)")
        }
    }

    private func handleShowMessage(params: Data) async {
        do {
            let showMessage = try JSONDecoder().decode(ShowMessageParams.self, from: params)
            logger.info("LSP Server Message: [\(showMessage.type.rawValue)] \(showMessage.message)")
        } catch {
            logger.error("Failed to decode show message: \(error.localizedDescription)")
        }
    }
}
