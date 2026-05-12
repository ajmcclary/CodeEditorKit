#if canImport(Combine)
import Combine
#endif
import Foundation

// MARK: - Debug Session

/// Debug session
class DebugSession {
    /// Unique identifier for this debug session
    let id: String
    /// The launch configuration used to start this session
    let configuration: LaunchConfiguration
    /// The debug adapter handling communication with the debugger
    let adapter: DebugAdapter
    /// Current state of the debug session
    var state: SessionState = .initializing
    /// The currently active thread ID
    var currentThreadId: Int = 1

    init(id: String, configuration: LaunchConfiguration, adapter: DebugAdapter) {
        self.id = id
        self.configuration = configuration
        self.adapter = adapter
    }

    /// The possible states of a debug session
    enum SessionState {
        /// Session is being initialized
        case initializing
        /// Session is running normally
        case running
        /// Session is paused at a breakpoint or step
        case paused
        /// Session has been terminated
        case terminated
    }

    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - Launch Configuration

/// Launch configuration
struct LaunchConfiguration: Sendable {
    let name: String
    let type: String
    let request: RequestType
    let language: String
    let program: String?
    let args: [String]
    let env: [String: String]
    let cwd: String?
    let stopOnEntry: Bool
    let noDebug: Bool

    enum RequestType: Sendable {
        case launch
        case attach
    }

    init(
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

// MARK: - Breakpoint

/// Breakpoint
struct Breakpoint: Identifiable, Sendable {
    let id = UUID()
    let source: Source
    let line: Int
    var column: Int?
    var condition: String?
    var hitCondition: String?
    var logMessage: String?
    var verified = false

    var isConditional: Bool {
        condition != nil || hitCondition != nil
    }

    var isLogpoint: Bool {
        logMessage != nil
    }
}

// MARK: - Source

/// Source file
struct Source: Sendable {
    let name: String?
    let path: String
    let sourceReference: Int?

    init(path: String, name: String? = nil, sourceReference: Int? = nil) {
        self.name = name
        self.path = path
        self.sourceReference = sourceReference
    }
}

// MARK: - Stack Frame

/// Stack frame
struct StackFrame: Identifiable, Sendable {
    let id: Int
    let name: String
    let source: Source?
    let line: Int
    let column: Int
    let presentationHint: PresentationHint?

    enum PresentationHint: String, Sendable {
        case normal
        case label
        case subtle
    }
}

// MARK: - Variable

/// Variable
struct Variable: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let value: String
    let type: String?
    let variablesReference: Int
    let namedVariables: Int?
    let indexedVariables: Int?
    let presentationHint: VariablePresentationHint?

    struct VariablePresentationHint: Sendable {
        let kind: String?
        let attributes: [String]
        let visibility: String?
    }
}

// MARK: - Scope

/// Scope
struct Scope: Sendable {
    let name: String
    let variablesReference: Int
    let namedVariables: Int?
    let indexedVariables: Int?
    let expensive: Bool
}

// MARK: - Module

/// Module
struct Module: Sendable {
    let id: Int
    let name: String
    let path: String?
    let isOptimized: Bool
    let isUserCode: Bool
    let symbolStatus: String?
}

// MARK: - Inline Value

/// Inline value
struct InlineValue: Sendable {
    let range: NSRange
    let value: String
    let variableName: String?
    let type: String?
}

// MARK: - Hover Evaluation

/// Hover evaluation result
struct HoverEvaluation: Sendable {
    let expression: String
    let value: String
    let type: String?
    let hasChildren: Bool
    let location: Int
}

// MARK: - Enums

/// Evaluate context
enum EvaluateContext: String, Sendable {
    case watch
    case repl
    case hover
    case clipboard
}

/// Stopped reason
enum StoppedReason: String, Sendable {
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

// MARK: - Debug Capabilities

/// Debug capabilities
struct DebugCapabilities: Sendable {
    var supportsConfigurationDoneRequest = true
    var supportsFunctionBreakpoints = true
    var supportsConditionalBreakpoints = true
    var supportsHitConditionalBreakpoints = true
    var supportsEvaluateForHovers = true
    var supportsStepBack = false
    var supportsSetVariable = true
    var supportsRestartFrame = false
    var supportsGotoTargetsRequest = false
    var supportsStepInTargetsRequest = false
    var supportsCompletionsRequest = true
    var supportsModulesRequest = true
    var supportsRestartRequest = true
    var supportsExceptionOptions = true
    var supportsValueFormattingOptions = true
    var supportsExceptionInfoRequest = true
    var supportTerminateDebuggee = true
    var supportSuspendDebuggee = true
    var supportsDelayedStackTraceLoading = true
    var supportsLoadedSourcesRequest = true
    var supportsLogPoints = true
    var supportsTerminateThreadsRequest = false
    var supportsSetExpression = false
    var supportsTerminateRequest = true
    var supportsDataBreakpoints = false
    var supportsReadMemoryRequest = false
    var supportsWriteMemoryRequest = false
    var supportsDisassembleRequest = false
    var supportsCancelRequest = true
    var supportsBreakpointLocationsRequest = true
    var supportsClipboardContext = true
    var supportsSteppingGranularity = false
    var supportsInstructionBreakpoints = false
    var supportsExceptionFilterOptions = false
}

// MARK: - Errors

/// Debug error
enum DebugError: LocalizedError, Sendable {
    case noAdapterForLanguage(String)
    case sessionNotFound(String)
    case noActiveSession
    case adapterError(String)
    case communicationError(String)

    var errorDescription: String? {
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
