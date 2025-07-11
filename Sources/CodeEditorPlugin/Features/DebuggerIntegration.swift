import Combine
import Foundation

/// Main debugger integration system for CodeEditorPlugin
/// - Note: This is currently a preview feature with internal visibility
@MainActor
internal class DebuggerIntegration: ObservableObject {
    // MARK: - Properties
    
    @Published internal private(set) var debugSessions: [String: DebugSession] = [:]
    @Published internal private(set) var activeSession: DebugSession?
    @Published internal private(set) var breakpoints: [Breakpoint] = []
    @Published internal private(set) var currentFrame: StackFrame?
    @Published internal private(set) var variables: [Variable] = []
    @Published internal private(set) var isDebugging = false
    
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "DebuggerIntegration")
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
    
    // MARK: - Breakpoint Management
    
    /// Add a breakpoint
    func addBreakpoint(_ breakpoint: Breakpoint) async {
        breakpoints.append(breakpoint)
        
        // Sync with active sessions
        if isDebugging {
            await syncBreakpoints()
        }
        
        logger.info("Added breakpoint at \(breakpoint.source.path):\(breakpoint.line)")
    }
    
    /// Remove a breakpoint
    func removeBreakpoint(_ breakpoint: Breakpoint) async {
        breakpoints.removeAll { $0.id == breakpoint.id }
        
        // Sync with active sessions
        if isDebugging {
            await syncBreakpoints()
        }
        
        logger.info("Removed breakpoint at \(breakpoint.source.path):\(breakpoint.line)")
    }
    
    /// Toggle breakpoint at line
    func toggleBreakpoint(at line: Int, in file: String) async {
        if let existing = breakpoints.first(where: { $0.source.path == file && $0.line == line }) {
            await removeBreakpoint(existing)
        } else {
            let breakpoint = Breakpoint(
                source: Source(path: file, name: URL(fileURLWithPath: file).lastPathComponent),
                line: line
            )
            await addBreakpoint(breakpoint)
        }
    }
    
    /// Update breakpoint condition
    func updateBreakpointCondition(
        _ breakpoint: Breakpoint,
        condition: String?
    ) async {
        guard let index = breakpoints.firstIndex(where: { $0.id == breakpoint.id }) else {
            return
        }
        
        breakpoints[index].condition = condition
        
        // Sync with active sessions
        if isDebugging {
            await syncBreakpoints()
        }
    }
    
    /// Update breakpoint hit condition
    func updateBreakpointHitCondition(
        _ breakpoint: Breakpoint,
        hitCondition: String?
    ) async {
        guard let index = breakpoints.firstIndex(where: { $0.id == breakpoint.id }) else {
            return
        }
        
        breakpoints[index].hitCondition = hitCondition
        
        // Sync with active sessions
        if isDebugging {
            await syncBreakpoints()
        }
    }
    
    /// Convert breakpoint to logpoint
    func convertToLogpoint(
        _ breakpoint: Breakpoint,
        logMessage: String
    ) async {
        guard let index = breakpoints.firstIndex(where: { $0.id == breakpoint.id }) else {
            return
        }
        
        breakpoints[index].logMessage = logMessage
        
        // Sync with active sessions
        if isDebugging {
            await syncBreakpoints()
        }
    }
    
    // MARK: - Execution Control
    
    /// Continue execution
    func continueExecution() async throws {
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }
        
        try await session.adapter.continue(threadId: session.currentThreadId)
    }
    
    /// Step over
    func stepOver() async throws {
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }
        
        try await session.adapter.next(threadId: session.currentThreadId)
    }
    
    /// Step into
    func stepInto() async throws {
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }
        
        try await session.adapter.stepIn(threadId: session.currentThreadId)
    }
    
    /// Step out
    func stepOut() async throws {
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }
        
        try await session.adapter.stepOut(threadId: session.currentThreadId)
    }
    
    /// Pause execution
    func pause() async throws {
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }
        
        try await session.adapter.pause(threadId: session.currentThreadId)
    }
    
    /// Restart debugging
    func restart() async throws {
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }
        
        try await session.adapter.restart()
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
    
    /// Evaluate expression
    func evaluate(
        expression: String,
        context: EvaluateContext = .repl
    ) async throws -> Variable {
        guard let session = activeSession,
              let frame = currentFrame else {
            throw DebugError.noActiveSession
        }
        
        return try await session.adapter.evaluate(
            expression: expression,
            frameId: frame.id,
            context: context
        )
    }
    
    /// Get variable children
    func getVariableChildren(_ variable: Variable) async throws -> [Variable] {
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }
        
        guard variable.variablesReference > 0 else {
            return []
        }
        
        return try await session.adapter.variables(
            variablesReference: variable.variablesReference
        )
    }
    
    // MARK: - Inline Values
    
    /// Get inline values for current frame
    func getInlineValues(for range: NSRange) async throws -> [InlineValue] {
        guard configuration.enableInlineValues,
              activeSession != nil,
              currentFrame != nil else {
            return []
        }
        
        var inlineValues: [InlineValue] = []
        
        // Get variables in scope
        for variable in variables {
            // Check if variable is referenced in range
            if let location = findVariableLocation(variable.name, in: range) {
                let value = variable.value.count > configuration.maxInlineValueLength ?
                    String(variable.value.prefix(configuration.maxInlineValueLength)) + "..." :
                    variable.value
                
                inlineValues.append(InlineValue(
                    range: NSRange(location: location, length: variable.name.count),
                    value: value,
                    variableName: variable.name,
                    type: variable.type
                ))
            }
        }
        
        return inlineValues
    }
    
    // MARK: - Hover Evaluation
    
    /// Evaluate expression on hover
    func evaluateOnHover(
        expression: String,
        at location: Int
    ) async throws -> HoverEvaluation? {
        guard configuration.enableHoverEvaluation,
              let session = activeSession,
              let frame = currentFrame else {
            return nil
        }
        
        do {
            let result = try await session.adapter.evaluate(
                expression: expression,
                frameId: frame.id,
                context: .hover
            )
            
            return HoverEvaluation(
                expression: expression,
                value: result.value,
                type: result.type,
                hasChildren: result.variablesReference > 0,
                location: location
            )
        } catch {
            // Evaluation failed, return nil
            return nil
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
        // Handle adapter events
        session.adapter.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleDebugEvent(event, session: session)
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
    
    private func syncBreakpoints() async {
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
    
    private func findVariableLocation(_: String, in _: NSRange) -> Int? {
        // This is a simplified implementation
        // In a real implementation, you'd use the AST or regex to find variable references
        nil
    }
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - Supporting Types

/// Debug session
public class DebugSession {
    public let id: String
    public let configuration: LaunchConfiguration
    public let adapter: DebugAdapter
    public var state: SessionState = .initializing
    public var currentThreadId: Int = 1
    
    init(id: String, configuration: LaunchConfiguration, adapter: DebugAdapter) {
        self.id = id
        self.configuration = configuration
        self.adapter = adapter
    }
    
    public enum SessionState {
        case initializing
        case running
        case paused
        case terminated
    }
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
}

/// Launch configuration
public struct LaunchConfiguration: Sendable {
    public let name: String
    public let type: String
    public let request: RequestType
    public let language: String
    public let program: String?
    public let args: [String]
    public let env: [String: String]
    public let cwd: String?
    public let stopOnEntry: Bool
    public let noDebug: Bool
    
    public enum RequestType: Sendable {
        case launch
        case attach
    }
    
    public init(
        name: String,
        type: String,
        request: RequestType,
        language: String,
        program: String? = nil,
        args: [String] = [],
        env: [String: String] = [:],
        cwd: String? = nil,
        stopOnEntry: Bool = false,
        noDebug: Bool = false
    ) {
        self.name = name
        self.type = type
        self.request = request
        self.language = language
        self.program = program
        self.args = args
        self.env = env
        self.cwd = cwd
        self.stopOnEntry = stopOnEntry
        self.noDebug = noDebug
    }
}

/// Breakpoint
public struct Breakpoint: Identifiable, Sendable {
    public let id = UUID()
    public let source: Source
    public let line: Int
    public var column: Int?
    public var condition: String?
    public var hitCondition: String?
    public var logMessage: String?
    public var verified = false
    
    public var isConditional: Bool {
        condition != nil || hitCondition != nil
    }
    
    public var isLogpoint: Bool {
        logMessage != nil
    }
}

/// Source file
public struct Source: Sendable {
    public let name: String?
    public let path: String
    public let sourceReference: Int?
    
    public init(path: String, name: String? = nil, sourceReference: Int? = nil) {
        self.name = name
        self.path = path
        self.sourceReference = sourceReference
    }
}

/// Stack frame
public struct StackFrame: Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let source: Source?
    public let line: Int
    public let column: Int
    public let presentationHint: PresentationHint?
    
    public enum PresentationHint: String, Sendable {
        case normal
        case label
        case subtle
    }
}

/// Variable
public struct Variable: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let value: String
    public let type: String?
    public let variablesReference: Int
    public let namedVariables: Int?
    public let indexedVariables: Int?
    public let presentationHint: VariablePresentationHint?
    
    public struct VariablePresentationHint: Sendable {
        public let kind: String?
        public let attributes: [String]
        public let visibility: String?
    }
}

/// Scope
public struct Scope: Sendable {
    public let name: String
    public let variablesReference: Int
    public let namedVariables: Int?
    public let indexedVariables: Int?
    public let expensive: Bool
}

/// Module
public struct Module: Sendable {
    public let id: Int
    public let name: String
    public let path: String?
    public let isOptimized: Bool
    public let isUserCode: Bool
    public let symbolStatus: String?
}

/// Inline value
public struct InlineValue: Sendable {
    public let range: NSRange
    public let value: String
    public let variableName: String?
    public let type: String?
}

/// Hover evaluation result
public struct HoverEvaluation: Sendable {
    public let expression: String
    public let value: String
    public let type: String?
    public let hasChildren: Bool
    public let location: Int
}

/// Evaluate context
public enum EvaluateContext: String, Sendable {
    case watch
    case repl
    case hover
    case clipboard
}

/// Stopped reason
public enum StoppedReason: String, Sendable {
    case step
    case breakpoint
    case exception
    case pause
    case entry
    case goto
    case functionBreakpoint
    case dataBreakpoint
    case instructionBreakpoint
}

/// Debug capabilities
public struct DebugCapabilities: Sendable {
    public var supportsConfigurationDoneRequest = true
    public var supportsFunctionBreakpoints = true
    public var supportsConditionalBreakpoints = true
    public var supportsHitConditionalBreakpoints = true
    public var supportsEvaluateForHovers = true
    public var supportsStepBack = false
    public var supportsSetVariable = true
    public var supportsRestartFrame = false
    public var supportsGotoTargetsRequest = false
    public var supportsStepInTargetsRequest = false
    public var supportsCompletionsRequest = true
    public var supportsModulesRequest = true
    public var supportsRestartRequest = true
    public var supportsExceptionOptions = true
    public var supportsValueFormattingOptions = true
    public var supportsExceptionInfoRequest = true
    public var supportTerminateDebuggee = true
    public var supportSuspendDebuggee = true
    public var supportsDelayedStackTraceLoading = true
    public var supportsLoadedSourcesRequest = true
    public var supportsLogPoints = true
    public var supportsTerminateThreadsRequest = false
    public var supportsSetExpression = false
    public var supportsTerminateRequest = true
    public var supportsDataBreakpoints = false
    public var supportsReadMemoryRequest = false
    public var supportsWriteMemoryRequest = false
    public var supportsDisassembleRequest = false
    public var supportsCancelRequest = true
    public var supportsBreakpointLocationsRequest = true
    public var supportsClipboardContext = true
    public var supportsSteppingGranularity = false
    public var supportsInstructionBreakpoints = false
    public var supportsExceptionFilterOptions = false
}

/// Debug error
public enum DebugError: LocalizedError, Sendable {
    case noAdapterForLanguage(String)
    case sessionNotFound(String)
    case noActiveSession
    case adapterError(String)
    case communicationError(String)
    
    public var errorDescription: String? {
        switch self {
        case .noAdapterForLanguage(let language):
            return "No debug adapter registered for language: \(language)"

        case .sessionNotFound(let id):
            return "Debug session not found: \(id)"

        case .noActiveSession:
            return "No active debug session"

        case .adapterError(let message):
            return "Debug adapter error: \(message)"

        case .communicationError(let message):
            return "Debug communication error: \(message)"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let debugOutput = Notification.Name("CodeEditorPlugin.debugOutput")
    static let debugStateChanged = Notification.Name("CodeEditorPlugin.debugStateChanged")
}
