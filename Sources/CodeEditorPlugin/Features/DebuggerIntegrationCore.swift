#if canImport(Combine)
import Combine
#endif
import Foundation

/// Main debugger integration system for CodeEditorPlugin
/// - Note: This is currently a preview feature with internal visibility
@available(macOS 10.15, iOS 13.0, *)
@MainActor
internal class DebuggerIntegrationCore: ObservableObject {
    // MARK: - Properties

    @Published internal private(set) var debugSessions: [String: DebugSession] = [:]
    @Published internal private(set) var activeSession: DebugSession?
    @Published internal var breakpoints: [Breakpoint] = []
    @Published internal private(set) var currentFrame: StackFrame?
    @Published internal var variables: [Variable] = []
    @Published internal private(set) var isDebugging = false

    internal let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "DebuggerIntegration")
    private var debugAdapters: [String: DebugAdapter] = [:]
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    internal struct Configuration: Sendable {
        internal var enableInlineValues = true
        internal var enableHoverEvaluation = true
        internal var enableConditionalBreakpoints = true
        internal var enableLogpoints = true
        internal var maxInlineValueLength = 50
        internal var maxVariableDepth = 3
        internal var autoExpandVariables = true

        internal static let `default` = Self()
    }

    internal var configuration = Configuration.default

    // MARK: - Initialization

    internal init() {
        setupDefaultAdapters()
    }

    // MARK: - Debug Adapter Management

    /// Register a debug adapter for a language
    internal func registerAdapter(_ adapter: DebugAdapter, for language: String) {
        debugAdapters[language] = adapter
        logger.info("Registered debug adapter for \(language)")
    }

    /// Get debug adapter for a language
    internal func adapter(for language: String) -> DebugAdapter? {
        debugAdapters[language]
    }

    // MARK: - Session Management

    /// Start a debug session
    internal func startSession(
        configuration: LaunchConfiguration,
        in _: CodeEditorView
    ) async throws -> DebugSession {
        guard let adapter = debugAdapters[configuration.language] else {
            throw DebugError.noAdapterForLanguage(configuration.language)
        }

        logger.info("Starting debug session for \(configuration.language)")

        let session = DebugSession(
            id: UUID().uuidString,
            configuration: configuration,
            adapter: adapter
        )

        // Initialize adapter
        try await adapter.initialize(capabilities: DebugCapabilities())

        // Launch or attach
        if configuration.request == .launch {
            try await adapter.launch(configuration)
        } else {
            try await adapter.attach(configuration)
        }

        // Store session
        debugSessions[session.id] = session
        activeSession = session
        isDebugging = true

        // Set up event handling
        setupEventHandling(for: session)

        // Apply existing breakpoints
        await syncBreakpoints()

        logger.info("Debug session started: \(session.id)")

        return session
    }

    /// Stop a debug session
    func stopSession(_ sessionId: String) async throws {
        guard let session = debugSessions[sessionId] else {
            throw DebugError.sessionNotFound(sessionId)
        }

        logger.info("Stopping debug session: \(sessionId)")

        // Disconnect adapter
        try await session.adapter.disconnect()

        // Clean up
        debugSessions.removeValue(forKey: sessionId)
        if activeSession?.id == sessionId {
            activeSession = nil
            isDebugging = false
            currentFrame = nil
            variables.removeAll()
        }

        logger.info("Debug session stopped: \(sessionId)")
    }

    /// Stop all debug sessions
    func stopAllSessions() async {
        for sessionId in debugSessions.keys {
            try? await stopSession(sessionId)
        }
    }

    // MARK: - Private Methods

    private func setupDefaultAdapters() {
        // Register built-in debug adapters
        registerAdapter(LLDBAdapter(), for: "swift")
        registerAdapter(LLDBAdapter(), for: "c")
        registerAdapter(LLDBAdapter(), for: "cpp")
        registerAdapter(NodeDebugAdapter(), for: "javascript")
        registerAdapter(NodeDebugAdapter(), for: "typescript")
        registerAdapter(PythonDebugAdapter(), for: "python")
    }

    private func setupEventHandling(for session: DebugSession) {
        // Handle adapter events using MainActor
        session.adapter.eventPublisher
            .sink { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleDebugEvent(event, session: session)
                }
            }
            .store(in: &cancellables)
    }

    private func handleDebugEvent(_ event: DebugEvent, session: DebugSession) {
        switch event {
        case let .stopped(reason, threadId, _):
            handleStoppedEvent(reason: reason, threadId: threadId, session: session)

        case let .continued(threadId, _):
            handleContinuedEvent(threadId: threadId, session: session)

        case .exited(let exitCode):
            handleExitedEvent(exitCode: exitCode, session: session)

        case .terminated:
            handleTerminatedEvent(session: session)

        case let .thread(reason, threadId):
            handleThreadEvent(reason: reason, threadId: threadId, session: session)

        case let .output(category, output):
            handleOutputEvent(category: category, output: output, session: session)

        case let .breakpoint(reason, breakpoint):
            handleBreakpointEvent(reason: reason, breakpoint: breakpoint, session: session)

        case let .module(reason, module):
            handleModuleEvent(reason: reason, module: module, session: session)
        }
    }

    private func handleStoppedEvent(reason: StoppedReason, threadId: Int, session: DebugSession) {
        logger.info("Debugger stopped: \(reason.rawValue)")

        session.currentThreadId = threadId
        session.state = .paused

        // Update UI
        Task {
            do {
                let frames = try await getStackTrace()
                if let firstFrame = frames.first {
                    try await selectFrame(firstFrame)
                }
            } catch {
                logger.error("Failed to get stack trace: \(error)")
            }
        }
    }

    private func handleContinuedEvent(threadId _: Int, session: DebugSession) {
        logger.info("Debugger continued")
        session.state = .running
        currentFrame = nil
        variables.removeAll()
    }

    private func handleExitedEvent(exitCode: Int, session: DebugSession) {
        logger.info("Program exited with code: \(exitCode)")
        session.state = .terminated
    }

    private func handleTerminatedEvent(session: DebugSession) {
        logger.info("Debug session terminated")
        session.state = .terminated

        Task {
            try? await stopSession(session.id)
        }
    }

    private func handleThreadEvent(reason: String, threadId: Int, session _: DebugSession) {
        logger.info("Thread event: \(reason) for thread \(threadId)")
    }

    private func handleOutputEvent(category: String, output: String, session: DebugSession) {
        logger.info("Debug output [\(category)]: \(output)")

        // Notify output handler
        NotificationCenter.default.post(
            name: .debugOutput,
            object: nil,
            userInfo: ["category": category, "output": output, "sessionId": session.id]
        )
    }

    private func handleBreakpointEvent(reason: String, breakpoint: Breakpoint, session _: DebugSession) {
        logger.info("Breakpoint event: \(reason)")

        // Update breakpoint state
        if let index = breakpoints.firstIndex(where: { $0.id == breakpoint.id }) {
            breakpoints[index].verified = breakpoint.verified
        }
    }

    private func handleModuleEvent(reason: String, module: Module, session _: DebugSession) {
        logger.info("Module event: \(reason) for \(module.name)")
    }

    internal func syncBreakpoints() async {
        guard let session = activeSession else { return }

        // Group breakpoints by source
        let breakpointsBySource = Dictionary(grouping: breakpoints) { $0.source.path }

        for (path, sourceBreakpoints) in breakpointsBySource {
            do {
                let setBreakpoints = try await session.adapter.setBreakpoints(
                    source: Source(path: path),
                    breakpoints: sourceBreakpoints.map { bp in
                        SourceBreakpoint(
                            line: bp.line,
                            column: bp.column,
                            condition: bp.condition,
                            hitCondition: bp.hitCondition,
                            logMessage: bp.logMessage
                        )
                    }
                )

                // Update verified state
                for (index, bp) in sourceBreakpoints.enumerated() where index < setBreakpoints.count {
                    if let bpIndex = breakpoints.firstIndex(where: { $0.id == bp.id }) {
                        breakpoints[bpIndex].verified = setBreakpoints[index].verified
                    }
                }
            } catch {
                logger.error("Failed to set breakpoints for \(path): \(error)")
            }
        }
    }

    internal func findVariableLocation(_: String, in _: NSRange) -> Int? {
        // This is a simplified implementation
        // In a real implementation, you'd use the AST or regex to find variable references
        nil
    }

    // MARK: - Stack and Variables

    /// Get stack trace for current thread
    func getStackTrace() async throws -> [StackFrame] {
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }

        return try await session.adapter.stackTrace(threadId: session.currentThreadId)
    }

    /// Select stack frame
    func selectFrame(_ frame: StackFrame) async throws {
        currentFrame = frame

        // Load variables for frame
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }

        let scopes = try await session.adapter.scopes(frameId: frame.id)
        variables.removeAll()

        for scope in scopes {
            let scopeVariables = try await session.adapter.variables(
                variablesReference: scope.variablesReference
            )
            variables.append(contentsOf: scopeVariables)
        }
    }

    deinit {
        // Cleanup is handled automatically by ARC
    }
}
