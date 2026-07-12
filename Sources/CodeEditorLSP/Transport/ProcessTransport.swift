#if canImport(AppKit)
import CodeEditorCommon
import Foundation

/// Transport implementation using Process for local LSP servers (macOS only)
///
/// ProcessTransport launches and communicates with LSP servers as local processes
/// using stdin/stdout pipes. This is the traditional way to interact with language
/// servers on desktop platforms.
///
/// ## Platform Availability
/// This transport is only available on macOS due to Process API restrictions.
///
/// ## Example Usage
/// ```swift
/// let transport = ProcessTransport(
///     executablePath: "/usr/bin/sourcekit-lsp",
///     arguments: [],
///     workingDirectory: projectURL,
///     environment: ProcessInfo.processInfo.environment
/// )
/// 
/// try await transport.connect()
/// ```
@available(macOS 10.15, *)
public actor ProcessTransport: LSPTransport {
    // MARK: - Properties

    private let executablePath: String
    private let arguments: [String]
    private let workingDirectory: URL?
    private let environment: [String: String]
    private let configuration: LSPTransportConfiguration

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    private var dataHandler: (@Sendable (Data) async -> Void)?
    private var stdoutReading: Bool = false

    private let logger = CodeEditorLog.lsp(category: "ProcessTransport")

    // MARK: - Initialization

    public init(
        executablePath: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String] = [:],
        configuration: LSPTransportConfiguration = LSPTransportConfiguration()
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.configuration = configuration
    }

    // MARK: - LSPTransport Implementation

    public var isConnected: Bool {
        process?.isRunning ?? false
    }

    public func connect() async throws {
        guard process == nil else {
            throw LSPTransportError.transportSpecific(message: "Process already running")
        }

        logger.info("Starting LSP process: \(executablePath)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        if !environment.isEmpty {
            process.environment = environment
        }

        // Set up pipes
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Store references
        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe

        // Start the process
        do {
            try process.run()
            logger.info("LSP process started successfully")

            // Start reading from stdout
            if dataHandler != nil {
                startReading()
            }

            // Monitor stderr for debugging
            attachStderrLogging()
        } catch {
            self.process = nil
            self.stdinPipe = nil
            self.stdoutPipe = nil
            self.stderrPipe = nil
            throw LSPTransportError.connectionFailed(underlying: error)
        }
    }

    public func disconnect() async {
        logger.info("Stopping LSP process")

        // Detach kernel-driven readers before terminating to avoid the
        // background queue racing the cleanup that follows.
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutReading = false

        process?.terminate()

        // Wait for process to exit (with timeout)
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            return false
        }

        let exitTask = Task {
            process?.waitUntilExit()
            return true
        }

        let didExit = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await timeoutTask.value }
            group.addTask { await exitTask.value }

            for await result in group where result {
                group.cancelAll()
                return true
            }
            return false
        }

        if !didExit {
            logger.warning("Process did not exit gracefully, forcing termination")
            process?.interrupt()
        }

        // Clean up
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        dataHandler = nil
    }

    public func send(_ data: Data) async throws {
        guard let stdinPipe, process?.isRunning == true else {
            throw LSPTransportError.notConnected
        }

        do {
            let fileHandle = stdinPipe.fileHandleForWriting

            // Format as LSP message with Content-Length header
            let header = "Content-Length: \(data.count)\r\n\r\n"
            guard let headerData = header.data(using: .utf8) else {
                throw LSPTransportError.transportSpecific(message: "Failed to encode header as UTF-8")
            }

            try fileHandle.write(contentsOf: headerData)
            try fileHandle.write(contentsOf: data)

            logger.debug("Sent \(data.count) bytes to LSP process")
        } catch {
            throw LSPTransportError.sendFailed(underlying: error)
        }
    }

    public func receive() async throws -> Data {
        guard let stdoutPipe, process?.isRunning == true else {
            throw LSPTransportError.notConnected
        }

        // This is a blocking receive for compatibility
        // In practice, most callers should use setDataHandler for async processing
        let fileHandle = stdoutPipe.fileHandleForReading

        do {
            let data = try fileHandle.read(upToCount: 65_536) ?? Data()
            if data.isEmpty {
                throw LSPTransportError.transportSpecific(message: "Process terminated")
            }
            return data
        } catch {
            throw LSPTransportError.receiveFailed(underlying: error)
        }
    }

    public func setDataHandler(_ handler: @escaping @Sendable (Data) async -> Void) async {
        self.dataHandler = handler

        // Start reading if connected
        if isConnected {
            startReading()
        }
    }

    // MARK: - Private Methods

    private func startReading() {
        guard !stdoutReading, let stdoutPipe else { return }
        stdoutReading = true
        logger.debug("Started reading from LSP process")

        // The kernel notifies us via `readabilityHandler` whenever data is
        // available — no need to busy-poll. The handler runs on a private
        // background queue; we hop back into the actor to deliver bytes to
        // the handler and to mutate any actor state.
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let self else { return }
            Task { [data] in
                await self.deliverStdoutData(data)
            }
        }
    }

    private func deliverStdoutData(_ data: Data) async {
        // Empty data signals EOF on the pipe — the process closed stdout.
        guard !data.isEmpty else {
            if process?.isRunning == false {
                logger.info("LSP process terminated")
            }
            stdoutPipe?.fileHandleForReading.readabilityHandler = nil
            stdoutReading = false
            return
        }
        if let handler = dataHandler {
            await handler(data)
        }
    }

    private func attachStderrLogging() {
        guard let stderrPipe else { return }
        // Mirror the stdout pattern: bounce off the FileHandle's private
        // dispatch queue into the actor via a Task so a chatty server
        // emitting MB/s of stderr cannot starve stdout's reads on the
        // same queue. The Task hop also serializes stderr deliveries with
        // any other actor-isolated work (teardown, EOF cleanup).
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let self else { return }
            Task { [data] in
                await self.deliverStderrData(data)
            }
        }
    }

    private func deliverStderrData(_ data: Data) async {
        // Empty data signals EOF on the pipe — the process closed stderr.
        guard !data.isEmpty else {
            stderrPipe?.fileHandleForReading.readabilityHandler = nil
            return
        }
        if let string = String(data: data, encoding: .utf8) {
            logger.debug("LSP stderr: \(string)")
        }
    }

    deinit {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        if process?.isRunning == true {
            logger.warning("ProcessTransport deallocated while process still running")
            process?.terminate()
        }
    }
}
#endif
