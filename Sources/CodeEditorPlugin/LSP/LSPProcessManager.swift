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
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.lsp", category: "LSPProcessManager")

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

        // Start reading from stdout
        Task {
            await startReadingFromServer(pipe: stdoutPipe)
        }

        // Start the process
        try process.run()

        self.serverProcess = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe

        logger.info("Started LSP server process: \(configuration.serverPath)")
    }

    /// Terminates the server process
    func terminateServerProcess() {
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

    /// Starts reading from the server's stdout pipe
    private func startReadingFromServer(pipe: Pipe) async {
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
