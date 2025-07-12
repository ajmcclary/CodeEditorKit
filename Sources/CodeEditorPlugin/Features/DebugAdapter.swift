import Combine
import Foundation

/// Adapter errors
public enum AdapterError: LocalizedError {
    case invalidResponse(String)
    case notInitialized
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse(let message):
            return "Invalid response: \(message)"

        case .notInitialized:
            return "Debug adapter not initialized"

        case .timeout:
            return "Request timed out"
        }
    }
}

/// Protocol for debug adapters following the Debug Adapter Protocol (DAP)
public protocol DebugAdapter: AnyObject {
    /// Event publisher for debug events
    var eventPublisher: AnyPublisher<DebugEvent, Never> { get }
    
    /// Initialize the debug adapter
    func initialize(capabilities: DebugCapabilities) async throws
    
    /// Launch a new debug session
    func launch(_ configuration: LaunchConfiguration) async throws
    
    /// Attach to an existing process
    func attach(_ configuration: LaunchConfiguration) async throws
    
    /// Set breakpoints for a source file
    func setBreakpoints(source: Source, breakpoints: [SourceBreakpoint]) async throws -> [Breakpoint]
    
    /// Continue execution
    func `continue`(threadId: Int) async throws
    
    /// Step over
    func next(threadId: Int) async throws
    
    /// Step into
    func stepIn(threadId: Int) async throws
    
    /// Step out
    func stepOut(threadId: Int) async throws
    
    /// Pause execution
    func pause(threadId: Int) async throws
    
    /// Get stack trace
    func stackTrace(threadId: Int) async throws -> [StackFrame]
    
    /// Get scopes for a stack frame
    func scopes(frameId: Int) async throws -> [Scope]
    
    /// Get variables for a scope or variable reference
    func variables(variablesReference: Int) async throws -> [Variable]
    
    /// Evaluate an expression
    func evaluate(expression: String, frameId: Int?, context: EvaluateContext) async throws -> Variable
    
    /// Restart debugging
    func restart() async throws
    
    /// Disconnect and end session
    func disconnect() async throws
}

/// Source breakpoint for setting
public struct SourceBreakpoint: Sendable {
    public let line: Int
    public let column: Int?
    public let condition: String?
    public let hitCondition: String?
    public let logMessage: String?
    
    public init(
        line: Int,
        column: Int? = nil,
        condition: String? = nil,
        hitCondition: String? = nil,
        logMessage: String? = nil
    ) {
        self.line = line
        self.column = column
        self.condition = condition
        self.hitCondition = hitCondition
        self.logMessage = logMessage
    }
}

/// Debug events
public enum DebugEvent: Sendable {
    case stopped(reason: StoppedReason, threadId: Int, allThreadsStopped: Bool)
    case continued(threadId: Int, allThreadsContinued: Bool)
    case exited(exitCode: Int)
    case terminated
    case thread(reason: String, threadId: Int)
    case output(category: String, output: String)
    case breakpoint(reason: String, breakpoint: Breakpoint)
    case module(reason: String, module: Module)
}

// MARK: - Base Debug Adapter

/// Base implementation of debug adapter with common functionality
@MainActor
internal class BaseDebugAdapter: @preconcurrency DebugAdapter {
    // Event subject
    private let eventSubject = PassthroughSubject<DebugEvent, Never>()
    var eventPublisher: AnyPublisher<DebugEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    // Process management
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    internal var process: Process?
    internal var stdin: Pipe?
    internal var stdout: Pipe?
    internal var stderr: Pipe?
    #endif
    
    // State
    internal var isInitialized = false
    internal var nextSequence = 1
    internal var pendingRequests: [Int: CheckedContinuation<Any, Error>] = [:]
    
    init() {}
    
    // MARK: - Protocol Implementation
    
    internal func initialize(capabilities _: DebugCapabilities) async throws {
        // Send initialize request
        _ = try await sendRequest("initialize", arguments: [
            "clientID": "CodeEditorPlugin",
            "clientName": "Code Editor Plugin",
            "adapterID": adapterID,
            "locale": Locale.current.identifier,
            "linesStartAt1": true,
            "columnsStartAt1": true,
            "pathFormat": "path",
            "supportsVariableType": true,
            "supportsVariablePaging": false,
            "supportsRunInTerminalRequest": false,
            "supportsMemoryReferences": false
        ])
        
        isInitialized = true
        
        // Send initialized event
        _ = try await sendRequest("configurationDone", arguments: [:])
    }
    
    internal func launch(_ configuration: LaunchConfiguration) async throws {
        var args: [String: Any] = [
            "name": configuration.name,
            "type": configuration.type,
            "request": "launch",
            "noDebug": configuration.noDebug,
            "stopOnEntry": configuration.stopOnEntry
        ]
        
        if let program = configuration.program {
            args["program"] = program
        }
        
        if !configuration.args.isEmpty {
            args["args"] = configuration.args
        }
        
        if !configuration.env.isEmpty {
            args["env"] = configuration.env
        }
        
        if let cwd = configuration.cwd {
            args["cwd"] = cwd
        }
        
        _ = try await sendRequest("launch", arguments: args)
    }
    
    internal func attach(_: LaunchConfiguration) async throws {
        // Override in subclasses
        throw DebugError.adapterError("Attach not implemented")
    }
    
    internal func setBreakpoints(source: Source, breakpoints: [SourceBreakpoint]) async throws -> [Breakpoint] {
        let response = try await sendRequest("setBreakpoints", arguments: [
            "source": [
                "path": source.path,
                "name": source.name ?? URL(fileURLWithPath: source.path).lastPathComponent
            ],
            "breakpoints": breakpoints.map { bp in
                var dict: [String: Any] = ["line": bp.line]
                if let column = bp.column { dict["column"] = column }
                if let condition = bp.condition { dict["condition"] = condition }
                if let hitCondition = bp.hitCondition { dict["hitCondition"] = hitCondition }
                if let logMessage = bp.logMessage { dict["logMessage"] = logMessage }
                return dict
            }
        ])
        
        // Parse response and return breakpoints
        guard let body = response["body"] as? [String: Any],
              let breakpointsData = body["breakpoints"] as? [[String: Any]] else {
            return []
        }
        
        return breakpointsData.compactMap { parseBreakpoint($0) }
    }
    
    internal func `continue`(threadId: Int) async throws {
        _ = try await sendRequest("continue", arguments: ["threadId": threadId])
    }
    
    internal func next(threadId: Int) async throws {
        _ = try await sendRequest("next", arguments: ["threadId": threadId])
    }
    
    internal func stepIn(threadId: Int) async throws {
        _ = try await sendRequest("stepIn", arguments: ["threadId": threadId])
    }
    
    internal func stepOut(threadId: Int) async throws {
        _ = try await sendRequest("stepOut", arguments: ["threadId": threadId])
    }
    
    internal func pause(threadId: Int) async throws {
        _ = try await sendRequest("pause", arguments: ["threadId": threadId])
    }
    
    internal func stackTrace(threadId: Int) async throws -> [StackFrame] {
        let response = try await sendRequest("stackTrace", arguments: [
            "threadId": threadId,
            "startFrame": 0,
            "levels": 50
        ])
        
        guard let body = response["body"] as? [String: Any],
              let stackFramesData = body["stackFrames"] as? [[String: Any]] else {
            return []
        }
        
        return stackFramesData.compactMap { parseStackFrame($0) }
    }
    
    internal func scopes(frameId: Int) async throws -> [Scope] {
        let response = try await sendRequest("scopes", arguments: ["frameId": frameId])
        
        guard let body = response["body"] as? [String: Any],
              let scopesData = body["scopes"] as? [[String: Any]] else {
            return []
        }
        
        return scopesData.compactMap { parseScope($0) }
    }
    
    internal func variables(variablesReference: Int) async throws -> [Variable] {
        let response = try await sendRequest("variables", arguments: [
            "variablesReference": variablesReference
        ])
        
        guard let body = response["body"] as? [String: Any],
              let variablesData = body["variables"] as? [[String: Any]] else {
            return []
        }
        
        return variablesData.compactMap { parseVariable($0) }
    }
    
    internal func evaluate(expression: String, frameId: Int?, context: EvaluateContext) async throws -> Variable {
        var args: [String: Any] = [
            "expression": expression,
            "context": context.rawValue
        ]
        
        if let frameId {
            args["frameId"] = frameId
        }
        
        let response = try await sendRequest("evaluate", arguments: args)
        
        guard let body = response["body"] as? [String: Any] else {
            throw DebugError.adapterError("Invalid evaluate response")
        }
        
        return Variable(
            name: expression,
            value: body["result"] as? String ?? "",
            type: body["type"] as? String,
            variablesReference: body["variablesReference"] as? Int ?? 0,
            namedVariables: body["namedVariables"] as? Int,
            indexedVariables: body["indexedVariables"] as? Int,
            presentationHint: nil
        )
    }
    
    internal func restart() async throws {
        _ = try await sendRequest("restart", arguments: [:])
    }
    
    internal func disconnect() async throws {
        _ = try await sendRequest("disconnect", arguments: ["restart": false])
        
        // Clean up process
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        process?.terminate()
        process = nil
        stdin = nil
        stdout = nil
        stderr = nil
        #endif
    }
    
    // MARK: - Subclass Requirements
    
    internal var adapterID: String {
        fatalError("Subclasses must override adapterID")
    }
    
    internal var adapterPath: String {
        fatalError("Subclasses must override adapterPath")
    }
    
    // MARK: - Internal Methods
    
    internal func sendRequest(_ command: String, arguments: [String: Any]) async throws -> [String: Any] {
        let seq = nextSequence
        nextSequence += 1
        
        let request: [String: Any] = [
            "seq": seq,
            "type": "request",
            "command": command,
            "arguments": arguments
        ]
        
        // Convert to JSON and send
        let data = try JSONSerialization.data(withJSONObject: request)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw AdapterError.invalidResponse("Failed to encode JSON as UTF-8")
        }
        _ = "Content-Length: \(data.count)\r\n\r\n" + jsonString
        
        // Send message
        // This is simplified - in reality you'd write to the process stdin
        
        // Wait for response
        let response = try await withCheckedThrowingContinuation { continuation in
            pendingRequests[seq] = continuation
        }
        
        // Convert response to dictionary
        guard let dict = response as? [String: Any] else {
            throw AdapterError.invalidResponse("Expected dictionary response")
        }
        
        return dict
    }
    
    internal func sendEvent(_ event: DebugEvent) {
        eventSubject.send(event)
    }
    
    // MARK: - Parsing Helpers
    
    private func parseBreakpoint(_ data: [String: Any]) -> Breakpoint? {
        guard let line = data["line"] as? Int else { return nil }
        
        let sourceData = data["source"] as? [String: Any]
        let source = Source(
            path: sourceData?["path"] as? String ?? "",
            name: sourceData?["name"] as? String,
            sourceReference: sourceData?["sourceReference"] as? Int
        )
        
        var breakpoint = Breakpoint(source: source, line: line)
        breakpoint.column = data["column"] as? Int
        breakpoint.verified = data["verified"] as? Bool ?? false
        
        return breakpoint
    }
    
    private func parseStackFrame(_ data: [String: Any]) -> StackFrame? {
        guard let id = data["id"] as? Int,
              let name = data["name"] as? String,
              let line = data["line"] as? Int,
              let column = data["column"] as? Int else {
            return nil
        }
        
        let sourceData = data["source"] as? [String: Any]
        let source = sourceData.map { data in
            Source(
                path: data["path"] as? String ?? "",
                name: data["name"] as? String,
                sourceReference: data["sourceReference"] as? Int
            )
        }
        
        let presentationHint = (data["presentationHint"] as? String).flatMap {
            StackFrame.PresentationHint(rawValue: $0)
        }
        
        return StackFrame(
            id: id,
            name: name,
            source: source,
            line: line,
            column: column,
            presentationHint: presentationHint
        )
    }
    
    private func parseScope(_ data: [String: Any]) -> Scope? {
        guard let name = data["name"] as? String,
              let variablesReference = data["variablesReference"] as? Int else {
            return nil
        }
        
        return Scope(
            name: name,
            variablesReference: variablesReference,
            namedVariables: data["namedVariables"] as? Int,
            indexedVariables: data["indexedVariables"] as? Int,
            expensive: data["expensive"] as? Bool ?? false
        )
    }
    
    private func parseVariable(_ data: [String: Any]) -> Variable? {
        guard let name = data["name"] as? String,
              let value = data["value"] as? String else {
            return nil
        }
        
        let presentationHint = (data["presentationHint"] as? [String: Any]).map { hint in
            Variable.VariablePresentationHint(
                kind: hint["kind"] as? String,
                attributes: hint["attributes"] as? [String] ?? [],
                visibility: hint["visibility"] as? String
            )
        }
        
        return Variable(
            name: name,
            value: value,
            type: data["type"] as? String,
            variablesReference: data["variablesReference"] as? Int ?? 0,
            namedVariables: data["namedVariables"] as? Int,
            indexedVariables: data["indexedVariables"] as? Int,
            presentationHint: presentationHint
        )
    }
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - Concrete Implementations

/// LLDB debug adapter for Swift, C, C++, Objective-C
@MainActor
internal class LLDBAdapter: BaseDebugAdapter {
    override internal var adapterID: String { "lldb" }
    override internal var adapterPath: String { "/usr/bin/lldb-vscode" }
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
}

/// Node.js debug adapter for JavaScript/TypeScript
@MainActor
internal class NodeDebugAdapter: BaseDebugAdapter {
    override internal var adapterID: String { "node" }
    override internal var adapterPath: String { "/usr/local/bin/node-debug2" }
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
}

/// Python debug adapter
@MainActor
internal class PythonDebugAdapter: BaseDebugAdapter {
    override internal var adapterID: String { "debugpy" }
    override internal var adapterPath: String { "/usr/local/bin/debugpy" }
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
}
