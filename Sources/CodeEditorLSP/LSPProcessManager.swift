import CodeEditorCommon
import Foundation

// MARK: - LSP Process Manager

/// Manages LSP server process lifecycle (macOS only)
///
/// This module handles starting, monitoring, and terminating LSP server processes
/// using the Process API. Only available on macOS (not iOS).
@MainActor
final class LSPProcessManager {
    // MARK: - Properties

    #if canImport(AppKit)
    /// The running server process
    private var serverProcess: Process?

    /// Pipe for writing to server stdin
    private var stdinPipe: Pipe?

    /// Pipe for reading from server stdout
    private var stdoutPipe: Pipe?
    #endif

    /// Logger for debugging
    private let logger = CodeEditorLog.lsp(category: "LSPProcessManager")

    /// Message handler for processing incoming data
    private let messageHandler: LSPMessageHandler

    // MARK: - Initialization

    /// Creates a new process manager
    /// - Parameter messageHandler: Handler for processing incoming LSP messages
    init(messageHandler: LSPMessageHandler) {
        self.messageHandler = messageHandler
    }

    // MARK: - Process Management

    #if canImport(AppKit)
    /// Indicates whether a server process is currently running
    var isRunning: Bool {
        serverProcess?.isRunning ?? false
    }

    /// Starts the LSP server process
    /// - Parameter configuration: Server configuration
    func startServerProcess(configuration: LSPClient.ServerConfiguration) throws {
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

        // Wire up an event-driven stdout reader BEFORE the process starts so
        // the very first byte the server emits triggers the handler. The
        // reader is callback-based (`FileHandle.readabilityHandler`); there
        // is no polling loop.
        installStdoutReader(on: stdoutPipe.fileHandleForReading)

        // Start the process
        try process.run()

        self.serverProcess = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe

        logger.info("Started LSP server process: \(configuration.serverPath)")
    }

    /// Terminates the server process
    func terminateServerProcess() {
        // Drop the readability handler first so a final pipe drain after
        // terminate() doesn't schedule one last `processIncomingData` Task
        // against a dead message handler / nil stdout pipe.
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        serverProcess?.terminate()
        serverProcess?.waitUntilExit()
        serverProcess = nil
        stdinPipe = nil
        stdoutPipe = nil

        logger.info("Terminated LSP server process")
    }

    /// Sends a message to the server via stdin pipe
    /// - Parameter data: The encoded message data
    func sendMessage(_ data: Data) throws {
        guard let stdinPipe else {
            throw LSPError.notConnected
        }

        let header = "Content-Length: \(data.count)\r\n\r\n"
        let headerData = header.data(using: .utf8) ?? Data()

        let fullMessage = headerData + data
        try stdinPipe.fileHandleForWriting.write(contentsOf: fullMessage)
    }

    // MARK: - Private Methods

    /// Installs an event-driven readability handler on the stdout file
    /// handle. The closure runs on `FileHandle`'s dispatch queue (not the
    /// main actor); incoming bytes are forwarded to the message-handler
    /// actor via a detached `Task`. On EOF (an empty read) the handler
    /// removes itself so we stop receiving callbacks. `internal` so tests
    /// can drive a real `Pipe` without spinning a real server process.
    internal func installStdoutReader(on fileHandle: FileHandle) {
        // Capture the actor reference locally so the @Sendable closure
        // doesn't have to capture `self` (which would be `@MainActor` and
        // force a hop just to read the property).
        let handler = messageHandler
        fileHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                // EOF — server closed its stdout. Detach the handler so the
                // dispatch source can release this closure.
                handle.readabilityHandler = nil
                return
            }
            Task {
                await handler.processIncomingData(data)
            }
        }
    }
    #else
    /// Indicates whether a server process is currently running (always false on non-macOS)
    var isRunning: Bool {
        false
    }

    /// Starts the LSP server process (not supported on this platform)
    func startServerProcess(configuration _: LSPClient.ServerConfiguration) throws {
        throw LSPError.serverError(
            code: -1,
            message: "LSP server process not supported on this platform",
            data: nil
        )
    }

    /// Terminates the server process (no-op on non-macOS)
    func terminateServerProcess() {
        // No-op on non-macOS platforms
    }

    /// Sends a message to the server (not supported on this platform)
    func sendMessage(_: Data) throws {
        throw LSPError.serverError(
            code: -1,
            message: "LSP not supported on this platform",
            data: nil
        )
    }
    #endif
}
