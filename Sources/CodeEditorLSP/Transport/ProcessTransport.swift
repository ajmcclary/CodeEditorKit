#if canImport(AppKit)
import CodeEditorCommon
import Foundation
import ProcessKit

/// Transport implementation for local LSP servers (macOS only), built on
/// ProcessKit's neutral primitives.
///
/// Responsibility split (the ProcessKit "proof-of-two" contract):
/// - `ProcessLauncher` owns spawning (posix_spawnp, pipes, CLOEXEC/SIGPIPE).
/// - `FileHandleChunkChannel` preserves stdout/stderr byte-arrival order
///   (a per-chunk `Task` per `readabilityHandler` callback does not).
/// - `ProcessTermination` owns SIGTERM→SIGKILL escalation and reaping —
///   this actor is the child's single reaper, in `disconnect()`.
/// - `LSPFrameCodec` owns LSP Content-Length framing.
/// - This actor owns only LSP-specific orchestration and state.
///
/// ## Platform Availability
/// macOS only (process spawning).
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

    private var spawned: SpawnedProcess?
    private var stdoutEOF = false

    private var dataHandler: (@Sendable (Data) async -> Void)?
    private var stdoutReading = false
    private var stdoutConsumer: Task<Void, Never>?
    private var stderrConsumer: Task<Void, Never>?

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
        guard let spawned else { return false }
        // kill(pid, 0) probes liveness without signalling. A zombie (exited
        // but not yet reaped) still probes alive, so the stdout-EOF flag
        // covers the exited-before-disconnect window.
        return !stdoutEOF && kill(spawned.pid, 0) == 0
    }

    public func connect() async throws {
        guard spawned == nil else {
            throw LSPTransportError.transportSpecific(message: "Process already running")
        }

        logger.info("Starting LSP process: \(executablePath)")

        // Foundation's `Process` inherited the parent environment when no
        // explicit environment was set; posix_spawnp REPLACES the
        // environment, so replicate the inheritance branch explicitly.
        let childEnvironment = environment.isEmpty
            ? ProcessInfo.processInfo.environment
            : environment

        do {
            let child = try ProcessLauncher.spawn(
                command: executablePath,
                arguments: arguments,
                environment: childEnvironment,
                workingDirectory: workingDirectory?.path
            )
            spawned = child
            stdoutEOF = false
            logger.info("LSP process started successfully")

            // Start reading from stdout
            if dataHandler != nil {
                startReading()
            }

            // Monitor stderr for debugging
            attachStderrLogging()
        } catch {
            spawned = nil
            throw LSPTransportError.connectionFailed(underlying: error)
        }
    }

    public func disconnect() async {
        logger.info("Stopping LSP process")

        guard let spawned else {
            dataHandler = nil
            return
        }

        // Detach kernel-driven readers before terminating to avoid the
        // background queue racing the cleanup that follows.
        spawned.stdout.readabilityHandler = nil
        spawned.stderr.readabilityHandler = nil
        stdoutConsumer?.cancel()
        stderrConsumer?.cancel()
        stdoutConsumer = nil
        stderrConsumer = nil
        stdoutReading = false

        // Single reaper: SIGTERM → SIGKILL escalation with default grace
        // periods, then the child is reaped exactly once, here.
        let reapLogger: (String) -> Void = { [logger] message in
            logger.warning("\(message)")
        }
        let exitCode = await ProcessTermination.terminateAndReap(
            pid: spawned.pid,
            policy: .default,
            logger: reapLogger
        )
        logger.debug("LSP process reaped with exit code \(exitCode)")

        // The launcher's caller owns the pipe handles; release them.
        spawned.stdin?.closeFile()
        spawned.stdout.closeFile()
        spawned.stderr.closeFile()

        self.spawned = nil
        dataHandler = nil
    }

    public func send(_ data: Data) async throws {
        guard let spawned, isConnected, let stdinFD = spawned.stdinDescriptor else {
            throw LSPTransportError.notConnected
        }

        do {
            // Frame via the shared codec and write to the server's stdin.
            try FDWriteSupport.writeAll(LSPFrameCodec.encode(data), to: stdinFD)
            logger.debug("Sent \(data.count) bytes to LSP process")
        } catch {
            throw LSPTransportError.sendFailed(underlying: error)
        }
    }

    public func receive() async throws -> Data {
        guard let spawned, isConnected else {
            throw LSPTransportError.notConnected
        }

        // This is a blocking receive for compatibility
        // In practice, most callers should use setDataHandler for async processing
        do {
            let data = try spawned.stdout.read(upToCount: 65_536) ?? Data()
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
        guard !stdoutReading, let spawned else { return }
        stdoutReading = true
        logger.debug("Started reading from LSP process")

        // The kernel notifies via `readabilityHandler` on a private queue.
        // Chunks flow through a FileHandleChunkChannel so delivery order
        // matches byte-arrival order (spawning a Task per chunk would not
        // guarantee start order); ONE consumer task drains the stream.
        let channel = Self.installChunkReader(on: spawned.stdout)

        stdoutConsumer = Task { [weak self] in
            for await chunk in channel.stream {
                await self?.deliverStdoutData(chunk)
            }
            await self?.markStdoutEOF()
        }
    }

    private func deliverStdoutData(_ data: Data) async {
        if let handler = dataHandler {
            await handler(data)
        }
    }

    private func markStdoutEOF() {
        // The channel finished: the process closed stdout (EOF) or teardown
        // detached the reader.
        guard stdoutReading else { return }
        stdoutReading = false
        stdoutEOF = true
        logger.info("LSP process stdout reached EOF")
    }

    private func attachStderrLogging() {
        guard let spawned else { return }
        // Same channel pattern as stdout so a chatty server emitting MB/s
        // of stderr cannot starve stdout's reads, and stderr lines log in
        // arrival order.
        let channel = Self.installChunkReader(on: spawned.stderr)

        stderrConsumer = Task { [weak self] in
            for await chunk in channel.stream {
                await self?.logStderr(chunk)
            }
        }
    }

    /// Install a `readabilityHandler` that feeds an ordered chunk channel,
    /// finishing it (and detaching itself) on EOF.
    private static func installChunkReader(on handle: FileHandle) -> FileHandleChunkChannel {
        let channel = FileHandleChunkChannel()
        handle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                channel.finish()
            } else {
                channel.yield(data)
            }
        }
        return channel
    }

    private func logStderr(_ data: Data) {
        if let string = String(data: data, encoding: .utf8) {
            logger.debug("LSP stderr: \(string)")
        }
    }

    deinit {
        if let spawned {
            logger.warning("ProcessTransport deallocated while process still running")
            spawned.stdout.readabilityHandler = nil
            spawned.stderr.readabilityHandler = nil
            // Best effort — deinit cannot await the reap.
            kill(spawned.pid, SIGTERM)
        }
    }
}
#endif
