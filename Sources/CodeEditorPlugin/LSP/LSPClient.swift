#if canImport(AppKit) && !targetEnvironment(macCatalyst)
// LSP functionality is only available on macOS

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
/// - Important: LSP functionality is **only available on macOS** as it requires
///   the `Process` API to launch and communicate with language servers.
///   On iOS and Mac Catalyst, LSP methods will throw `LSPError.notSupported`.
///
/// ## Platform Support
/// - ✅ macOS: Full support
/// - ❌ iOS: Not supported (no Process API)
/// - ❌ Mac Catalyst: Not supported (no Process API)
///
/// ## Example Usage
/// ```swift
/// // Check platform before using LSP
/// if PlatformCapabilities.shared.currentPlatform == .macOS {
///     let client = LSPClient()
///     try await client.connect(configuration: serverConfig)
/// }
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
    
    // MARK: - State
    
    /// Current connection state
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    
    /// Server capabilities received during initialization
    @Published public private(set) var serverCapabilities: ServerCapabilities?
    
    /// Active diagnostics by document URI
    @Published public private(set) var diagnostics: [String: [Diagnostic]] = [:]
    
    /// LSP message handler
    private let messageHandler = LSPMessageHandler()
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Process for running the language server
    private var serverProcess: Process?
    
    /// Communication pipes
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    #endif
    
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
    
    public typealias LSPRequestCompletion = @Sendable (Result<LSPResponse, LSPError>) -> Void
    
    // MARK: - Initialization
    
    /// Creates a new LSP client.
    /// 
    /// - Important: The message handler is not automatically set up in the initializer.
    ///   Use `createAndSetup()` for a fully initialized client, or call `setupMessageHandler()`
    ///   manually after initialization.
    ///
    /// ## Example
    /// ```swift
    /// // Option 1: Use the factory method (recommended)
    /// let client = await LSPClient.createAndSetup()
    /// 
    /// // Option 2: Manual setup
    /// let client = LSPClient()
    /// await client.setupMessageHandler()
    /// ```
    public init() {
        // No async work in synchronous init
    }
    
    /// Creates and sets up a new LSP client with message handlers initialized.
    /// This is the preferred way to create an LSP client.
    ///
    /// ## Example
    /// ```swift
    /// let client = await LSPClient.createAndSetup()
    /// try await client.connect(configuration: serverConfig)
    /// ```
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
    public func connect(configuration: ServerConfiguration) async throws {
        guard connectionState == .disconnected else {
            throw LSPError.alreadyConnected
        }
        
        connectionState = .connecting
        logger.info("Connecting to LSP server: \(configuration.serverPath)")
        
        do {
            try await startServerProcess(configuration: configuration)
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
                terminateServerProcess()
            }
        } else {
            terminateServerProcess()
        }
        
        // Clean up state
        serverCapabilities = nil
        diagnostics.removeAll()
        pendingRequests.removeAll()
        
        connectionState = .disconnected
    }
    
    // MARK: - Document Management
    
    /// Open a document in the language server
    /// - Parameters:
    ///   - uri: Document URI
    ///   - languageId: Language identifier
    ///   - version: Document version
    ///   - text: Document content
    public func openDocument(
        uri: String,
        languageId: String,
        version: Int,
        text: String
    ) async throws {
        guard connectionState == .initialized else {
            throw LSPError.notConnected
        }
        
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
    /// - Parameters:
    ///   - uri: Document URI
    ///   - version: New document version
    ///   - changes: Content changes
    public func updateDocument(
        uri: String,
        version: Int,
        changes: [TextDocumentContentChangeEvent]
    ) async throws {
        guard connectionState == .initialized else {
            throw LSPError.notConnected
        }
        
        let params = DidChangeTextDocumentParams(
            textDocument: VersionedTextDocumentIdentifier(uri: uri, version: version),
            contentChanges: changes
        )
        
        try await sendNotification(method: "textDocument/didChange", params: params)
        logger.debug("Updated document: \(uri)")
    }
    
    /// Close a document
    /// - Parameter uri: Document URI
    public func closeDocument(uri: String) async throws {
        guard connectionState == .initialized else {
            throw LSPError.notConnected
        }
        
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
    /// - Parameters:
    ///   - uri: Document URI
    ///   - position: Cursor position
    /// - Returns: Completion list
    public func requestCompletion(
        uri: String,
        position: Position
    ) async throws -> CompletionList {
        guard connectionState == .initialized else {
            throw LSPError.notConnected
        }
        
        let params = CompletionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: position
        )
        
        let response = try await sendRequest(method: "textDocument/completion", params: params)
        return try response.decode(as: CompletionList.self)
    }
    
    /// Request hover information
    /// - Parameters:
    ///   - uri: Document URI
    ///   - position: Cursor position
    /// - Returns: Hover information
    public func requestHover(
        uri: String,
        position: Position
    ) async throws -> Hover? {
        guard connectionState == .initialized else {
            throw LSPError.notConnected
        }
        
        let params = HoverParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: position
        )
        
        let response = try await sendRequest(method: "textDocument/hover", params: params)
        return try? response.decode(as: Hover.self)
    }
    
    /// Request symbol definition
    /// - Parameters:
    ///   - uri: Document URI
    ///   - position: Cursor position
    /// - Returns: Definition locations
    public func requestDefinition(
        uri: String,
        position: Position
    ) async throws -> [Location] {
        guard connectionState == .initialized else {
            throw LSPError.notConnected
        }
        
        let params = DefinitionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: position
        )
        
        let response = try await sendRequest(method: "textDocument/definition", params: params)
        
        // Handle both single Location and array of Locations
        if let location = try? response.decode(as: Location.self) {
            return [location]
        } else {
            return try response.decode(as: [Location].self)
        }
    }
    
    /// Request document symbols
    /// - Parameter uri: Document URI
    /// - Returns: Document symbols
    public func requestDocumentSymbols(uri: String) async throws -> [LSPDocumentSymbol] {
        guard connectionState == .initialized else {
            throw LSPError.notConnected
        }
        
        let params = DocumentSymbolParams(
            textDocument: TextDocumentIdentifier(uri: uri)
        )
        
        let response = try await sendRequest(method: "textDocument/documentSymbol", params: params)
        return try response.decode(as: [LSPDocumentSymbol].self)
    }
    
    // MARK: - Private Methods
    
    /// Sets up the message handler callbacks for processing LSP messages.
    /// This method is automatically called by `createAndSetup()`.
    ///
    /// - Note: This method is idempotent and can be called multiple times safely.
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
    
    private func startServerProcess(configuration: ServerConfiguration) async throws {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: configuration.serverPath)
        process.arguments = configuration.serverArguments
        process.currentDirectoryURL = configuration.workspaceRoot
        
        // Set up pipes for communication
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        // Start reading from stdout
        Task {
            await startReadingFromServer(pipe: stdoutPipe)
        }
        
        // Start the process
        try process.run()
        
        self.serverProcess = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        
        logger.info("Started LSP server process")
        #else
        throw LSPError.serverError(code: -1, message: "LSP server process not supported on this platform", data: nil)
        #endif
    }
    
    private func initializeServer(configuration: ServerConfiguration) async throws {
        connectionState = .initializing
        
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
        
        let response = try await sendRequest(method: "initialize", params: initializeParams)
        serverCapabilities = try response.decode(as: InitializeResult.self).capabilities
        
        // Send initialized notification
        try await sendNotification(method: "initialized", params: EmptyParams())
        
        logger.info("LSP server initialized successfully")
    }
    
    private func sendShutdownRequest() async throws {
        _ = try await sendRequest(method: "shutdown", params: EmptyParams())
        try await sendNotification(method: "exit", params: EmptyParams())
    }
    
    private func terminateServerProcess() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        serverProcess?.terminate()
        serverProcess?.waitUntilExit()
        serverProcess = nil
        stdinPipe = nil
        stdoutPipe = nil
        #endif
    }
    
    private func startReadingFromServer(pipe: Pipe) async {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let fileHandle = pipe.fileHandleForReading
        
        while serverProcess?.isRunning == true {
            do {
                let data = fileHandle.availableData
                if !data.isEmpty {
                    await messageHandler.processIncomingData(data)
                }
                
                // Small delay to prevent busy waiting
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            } catch {
                logger.error("Error reading from server: \(error.localizedDescription)")
                break
            }
        }
        #endif
    }
    
    private func sendRequest(method: String, params: any Codable & Sendable) async throws -> LSPResponse {
        let requestId = nextRequestId
        nextRequestId += 1
        
        let request = LSPRequest(
            id: .number(requestId),
            method: method,
            params: params
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            // Store completion handler
            pendingRequests[requestId] = { result in
                continuation.resume(with: result)
            }
            
            // Send request
            Task {
                do {
                    try await self.sendMessage(request)
                } catch {
                    _ = await MainActor.run {
                        self.pendingRequests.removeValue(forKey: requestId)
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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let stdinPipe else {
            throw LSPError.notConnected
        }
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(message)
        
        let header = "Content-Length: \(jsonData.count)\r\n\r\n"
        let headerData = header.data(using: .utf8) ?? Data()
        
        let fullMessage = headerData + jsonData
        
        try stdinPipe.fileHandleForWriting.write(contentsOf: fullMessage)
        #else
        throw LSPError.serverError(code: -1, message: "LSP not supported on this platform", data: nil)
        #endif
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
    
    private func handleResponse(id: Int, result: Result<LSPResponse, LSPError>) async {
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

// MARK: - Empty Parameters

private struct EmptyParams: Codable {}

#endif // canImport(AppKit) && !targetEnvironment(macCatalyst)
