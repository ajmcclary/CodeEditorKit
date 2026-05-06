import Foundation

// MARK: - Sendable Conformance for Cross-Actor Types

// Note: HighlightedToken, TokenType, Language, and AnnotationKind already conform to Sendable in their declarations.

/// `Annotation` stores an `NSTextRange` (reference type). Stored properties are
/// immutable post-init and `NSTextRange` is treated as effectively-immutable
/// here, so the conformance is `@unchecked Sendable` rather than synthesised.
extension Annotation: @unchecked Sendable {}

// `CompletionItem`'s `Sendable` conformance lives alongside its declaration in
// `Completion/CompletionViewModels.swift`.

// MARK: - Sendable Wrappers for Non-Sendable Types

/// A Sendable wrapper for editor events that need to cross actor boundaries
@available(macOS 13.0, iOS 16.0, *)
public struct SendableEditorEvent: Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: EventType

    public enum EventType: Sendable {
        case textChanged(newText: String, range: NSRange)
        case selectionChanged(newRange: NSRange)
        case languageChanged(newLanguage: Language)
        case configurationChanged
        case annotationAdded(id: String)
        case annotationRemoved(id: String)
        case scrollPositionChanged(visibleRange: NSRange)
    }

    public init(type: EventType) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
    }
}

/// A Sendable wrapper for completion context
@available(macOS 13.0, iOS 16.0, *)
public struct SendableCompletionContext: Sendable {
    public let text: String
    public let cursorPosition: Int
    public let language: Language
    public let lineNumber: Int
    public let columnNumber: Int
    public let precedingText: String
    public let followingText: String

    public init(
        text: String,
        cursorPosition: Int,
        language: Language,
        lineNumber: Int,
        columnNumber: Int,
        precedingText: String,
        followingText: String
    ) {
        self.text = text
        self.cursorPosition = cursorPosition
        self.language = language
        self.lineNumber = lineNumber
        self.columnNumber = columnNumber
        self.precedingText = precedingText
        self.followingText = followingText
    }
}

/// A Sendable result type for async operations
@available(macOS 13.0, iOS 16.0, *)
public enum SendableResult<Success: Sendable, Failure: Error>: Sendable where Failure: Sendable {
    case success(Success)
    case failure(Failure)

    public var value: Success? {
        switch self {
        case .success(let value): return value
        case .failure: return nil
        }
    }

    public var error: Failure? {
        switch self {
        case .success: return nil
        case .failure(let error): return error
        }
    }
}

/// A Sendable progress indicator for long-running operations
@available(macOS 13.0, iOS 16.0, *)
public struct SendableProgress: Sendable {
    public let id: UUID
    public let current: Int
    public let total: Int
    public let message: String?
    public let isIndeterminate: Bool

    public var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }

    public init(
        current: Int,
        total: Int,
        message: String? = nil,
        isIndeterminate: Bool = false
    ) {
        self.id = UUID()
        self.current = current
        self.total = total
        self.message = message
        self.isIndeterminate = isIndeterminate
    }

    public static func indeterminate(message: String? = nil) -> Self {
        Self(current: 0, total: 0, message: message, isIndeterminate: true)
    }
}

/// A Sendable cache key for cross-actor caching
@available(macOS 13.0, iOS 16.0, *)
public struct SendableCacheKey: Hashable, Sendable {
    public let identifier: String
    public let version: Int
    public let metadata: [String: String]

    public init(
        identifier: String,
        version: Int = 0,
        metadata: [String: String] = [:]
    ) {
        self.identifier = identifier
        self.version = version
        self.metadata = metadata
    }
}

/// A Sendable performance metric
@available(macOS 13.0, iOS 16.0, *)
public struct SendablePerformanceMetric: Sendable {
    public let name: String
    public let duration: Duration
    public let metadata: [String: String]
    public let timestamp: Date

    public init(
        name: String,
        duration: Duration,
        metadata: [String: String] = [:]
    ) {
        self.name = name
        self.duration = duration
        self.metadata = metadata
        self.timestamp = Date()
    }
}

// MARK: - Sendable Protocol Conformances

/// `CodeEditorError` carries `any Error` associated values in several cases
/// (e.g. `.completionRequestFailed`, `.languageServerCommunicationFailed`,
/// `.fileReadingFailed`). The Swift `Error` protocol is not `Sendable`-bound,
/// so the conformance is `@unchecked Sendable` and treats those payloads as
/// effectively-immutable.
extension CodeEditorError: @unchecked Sendable {}

/// A Sendable configuration change event
@available(macOS 13.0, iOS 16.0, *)
public struct SendableConfigurationChange: Sendable {
    public let keyPath: String
    public let oldValue: String?
    public let newValue: String?
    public let timestamp: Date

    public init(
        keyPath: String,
        oldValue: String?,
        newValue: String?
    ) {
        self.keyPath = keyPath
        self.oldValue = oldValue
        self.newValue = newValue
        self.timestamp = Date()
    }
}

/// A Sendable file change notification
@available(macOS 13.0, iOS 16.0, *)
public struct FileChangeNotification: Sendable {
    public enum ChangeType: Sendable {
        case created
        case modified
        case deleted
        case renamed(from: String, to: String)
    }

    public let path: String
    public let changeType: ChangeType
    public let timestamp: Date

    public init(path: String, changeType: ChangeType) {
        self.path = path
        self.changeType = changeType
        self.timestamp = Date()
    }
}
