// LSP client is available on all platforms to support remote LSP connections
// On platforms without Process API, only remote LSP servers can be used

import CodeEditorCommon
import CodeEditorLanguages
import Foundation
import os.lock

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
/// dedicated components: LSPConnectionManager, LSPLanguageFeatures, and an
/// `LSPTransport` (ProcessTransport for local servers, WebSocketTransport
/// for remote ones) installed via `connect(configuration:languageId:)` or
/// `init(transport:)`.
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

    /// JSON-RPC request allocation, encoding, and continuation routing.
    private lazy var jsonRPCSession = JSONRPCSession { [weak self] data in
        guard let self else { throw LSPError.notConnected }
        try await self.sendEncodedMessage(data)
    }

    /// In-flight disconnect Task, if any. Used to serialize transport teardown
    /// so two concurrent `disconnect()` calls cannot each spawn a Task that
    /// races on `transport.disconnect()` and `connectionState`. Accessed only
    /// from the `@MainActor`-isolated client.
    private let connectionLifecycle = LSPConnectionLifecycle()
    private let documentSession = LSPDocumentSession()
    private lazy var languageFeatureClient = LSPLanguageFeatureClient { [weak self] method, params in
        guard let self else { throw LSPError.notConnected }
        return try await self.sendRequest(method: method, params: params)
    }

    /// True while the client holds connection resources that need an explicit
    /// `disconnect()`/`shutdown()` before deallocation. Set true on `connect`,
    /// cleared on `disconnect`. `OSAllocatedUnfairLock` is used (rather than a
    /// plain `Bool`) so the (nonisolated) `deinit` can safely read it without
    /// crossing `@MainActor` isolation. Same pattern as `AwaitableQueue` /
    /// `RangeProcessor.fillTaskLock` elsewhere in the codebase.
    private let needsTeardownFlag = OSAllocatedUnfairLock<Bool>(initialState: false)

    /// Logger for debugging
    private let logger = CodeEditorLog.lsp(category: "LSPClient")

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
        // Cannot call MainActor-isolated methods from deinit, but the
        // `OSAllocatedUnfairLock`-backed `needsTeardownFlag` is safe to read
        // here. Warn if the owner dropped the client without calling
        // `disconnect()` / `shutdown()` — pending request continuations may
        // be stranded and the underlying process/transport will only be torn
        // down when the OS reclaims it on process exit.
        let stillNeedsTeardown = needsTeardownFlag.withLock { $0 }
        if stillNeedsTeardown {
            logger.warning("LSPClient deallocated without calling shutdown()/disconnect() — pending requests may leak; the transport will only be torn down at process exit")
        }
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

        // Mark the client as holding teardown-pending resources so the deinit
        // warning fires if the caller forgets `disconnect()`/`shutdown()`.
        needsTeardownFlag.withLock { $0 = true }

        connectionState = .connecting
        logger.info("Connecting to LSP server: \(configuration.serverPath)")

        do {
            // No implicit process fallback: local servers are reached via
            // ProcessTransport, installed by the modern
            // connect(configuration:languageId:) overload or init(transport:).
            guard transport != nil else {
                throw LSPError.transportNotConfigured
            }
            try await LSPConnectionManager.startTransportConnection(
                transport: transport,
                messageHandler: messageHandler
            )

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
        if connectionLifecycle.isDisconnecting {
            return
        }

        // Teardown is now in progress. Clearing the flag synchronously means
        // the deinit warning only fires when the owner dropped the client
        // *without* calling disconnect/shutdown — completing the async
        // teardown after this point is the caller's responsibility.
        needsTeardownFlag.withLock { $0 = false }

        let wasInitialized = (connectionState == .initialized)

        // Capture in-flight request continuations BEFORE clearing the map.
        // CheckedContinuations must be resumed exactly once — dropping the
        // closures would leave awaiters hanging forever (in production) or
        // trap (in DEBUG with strict-concurrency checks). Failing them with
        // `.notConnected` lets callers observe the disconnect deterministically.
        jsonRPCSession.failAllPending(with: .notConnected)
        serverCapabilities = nil
        documentSession.removeAll()
        diagnostics = documentSession.diagnostics

        if wasInitialized {
            connectionState = .shuttingDown

            connectionLifecycle.beginDisconnect { [weak self] in
                guard let self else {
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
                self.jsonRPCSession.failAllPending(with: .notConnected)

                if let transport = self.transport {
                    await transport.disconnect()
                }

                self.connectionState = .disconnected
            }
        } else {
            // Not initialized (e.g. `.connecting`, `.initializing`, `.error`):
            // skip the shutdown request and tear the transport down directly.
            if let transport {
                connectionLifecycle.beginDisconnect { [weak self] in
                    await transport.disconnect()
                    self?.connectionState = .disconnected
                }
            } else {
                connectionState = .disconnected
            }
        }
    }

    /// Tear down the LSP connection.
    ///
    /// Documented alias of `disconnect()` — the name matches the conventional
    /// lifecycle term referenced by the deinit-time warning when the client
    /// is dropped without an explicit teardown. Synchronous; the caller does
    /// not need to await the async transport drain.
    public func shutdown() {
        disconnect()
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

        let params = documentSession.openParameters(
            uri: uri,
            languageID: languageId,
            version: version,
            text: text
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

        let params = documentSession.changeParameters(
            uri: uri,
            version: version,
            changes: changes
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

        let params = documentSession.closeParameters(uri: uri)

        try await sendNotification(method: "textDocument/didClose", params: params)

        // Remove diagnostics for closed document
        diagnostics = documentSession.diagnostics

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

        return try await languageFeatureClient.completion(uri: uri, position: position)
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

        return try await languageFeatureClient.hover(uri: uri, position: position)
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

        return try await languageFeatureClient.definition(uri: uri, position: position)
    }

    /// Request document symbols
    /// - Throws: `LSPError.notConnected` if the client is not in
    ///   `.initialized`; `LSPError.serverError`, `LSPError.invalidResponse`,
    ///   or `LSPError.decodingError` per the standard request envelope.
    public func requestDocumentSymbols(uri: String) async throws -> [LSPDocumentSymbol] {
        try LSPConnectionManager.validateConnected(currentState: connectionState)

        return try await languageFeatureClient.documentSymbols(uri: uri)
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

        return try await languageFeatureClient.semanticTokens(uri: uri)
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

        return try await languageFeatureClient.semanticTokenDelta(
            uri: uri,
            previousResultID: previousResultId
        )
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

        return try await languageFeatureClient.semanticTokens(uri: uri, range: range)
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
        try await jsonRPCSession.request(method: method, params: params)
    }

    private func sendNotification(method: String, params: any Codable & Sendable) async throws {
        let notification = LSPNotification(method: method, params: params)
        try await sendMessage(notification)
    }

    private func sendMessage(_ message: any Codable) async throws {
        try await sendEncodedMessage(JSONEncoder().encode(message))
    }

    private func sendEncodedMessage(_ data: Data) async throws {
        guard let transport else { throw LSPError.notConnected }
        try await transport.send(data)
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
        jsonRPCSession.handleResponse(id: id, result: result)
    }

    private func handleDiagnosticsNotification(params: Data) async {
        do {
            let publishDiagnostics = try JSONDecoder().decode(PublishDiagnosticsParams.self, from: params)
            documentSession.updateDiagnostics(
                publishDiagnostics.diagnostics,
                for: publishDiagnostics.uri
            )
            diagnostics = documentSession.diagnostics
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
