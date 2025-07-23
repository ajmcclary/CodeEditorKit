#if canImport(Combine)
import Combine
#endif
import Foundation

// MARK: - Debug Session

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

// MARK: - Launch Configuration

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

// MARK: - Breakpoint

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

// MARK: - Source

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

// MARK: - Stack Frame

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

// MARK: - Variable

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

// MARK: - Scope

/// Scope
public struct Scope: Sendable {
    public let name: String
    public let variablesReference: Int
    public let namedVariables: Int?
    public let indexedVariables: Int?
    public let expensive: Bool
}

// MARK: - Module

/// Module
public struct Module: Sendable {
    public let id: Int
    public let name: String
    public let path: String?
    public let isOptimized: Bool
    public let isUserCode: Bool
    public let symbolStatus: String?
}

// MARK: - Inline Value

/// Inline value
public struct InlineValue: Sendable {
    public let range: NSRange
    public let value: String
    public let variableName: String?
    public let type: String?
}

// MARK: - Hover Evaluation

/// Hover evaluation result
public struct HoverEvaluation: Sendable {
    public let expression: String
    public let value: String
    public let type: String?
    public let hasChildren: Bool
    public let location: Int
}

// MARK: - Enums

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

// MARK: - Debug Capabilities

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

// MARK: - Errors

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
