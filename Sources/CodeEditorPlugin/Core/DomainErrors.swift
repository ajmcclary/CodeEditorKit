import Foundation

/// Domain-specific error types for CodeEditor subsystems
public enum DomainError: LocalizedError, Sendable {
    case configuration(ConfigurationDomainError)
    case syntax(SyntaxDomainError)
    case completion(CompletionDomainError)
    case memory(MemoryDomainError)
    case textKit(TextKitDomainError)
    case performance(PerformanceDomainError)
    case platform(PlatformDomainError)
    
    public var errorDescription: String? {
        switch self {
        case .configuration(let error):
            return "Configuration Error: \(error.localizedDescription)"

        case .syntax(let error):
            return "Syntax Error: \(error.localizedDescription)"

        case .completion(let error):
            return "Completion Error: \(error.localizedDescription)"

        case .memory(let error):
            return "Memory Error: \(error.localizedDescription)"

        case .textKit(let error):
            return "TextKit Error: \(error.localizedDescription)"

        case .performance(let error):
            return "Performance Error: \(error.localizedDescription)"

        case .platform(let error):
            return "Platform Error: \(error.localizedDescription)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .configuration(let error):
            return error.recoverySuggestion

        case .syntax(let error):
            return error.recoverySuggestion

        case .completion(let error):
            return error.recoverySuggestion

        case .memory(let error):
            return error.recoverySuggestion

        case .textKit(let error):
            return error.recoverySuggestion

        case .performance(let error):
            return error.recoverySuggestion

        case .platform(let error):
            return error.recoverySuggestion
        }
    }
}

// MARK: - Configuration Errors

/// Errors related to editor configuration
public enum ConfigurationDomainError: LocalizedError, Sendable {
    case invalidValue(property: String, value: String, reason: String)
    case incompatibleSettings(setting1: String, setting2: String)
    case missingRequiredProperty(property: String)
    case presetNotFound(name: String)
    case validationFailed(errors: [String])
    
    public var errorDescription: String? {
        switch self {
        case let .invalidValue(property, value, reason):
            return "Invalid value '\(value)' for property '\(property)': \(reason)"

        case let .incompatibleSettings(setting1, setting2):
            return "Settings '\(setting1)' and '\(setting2)' are incompatible"

        case .missingRequiredProperty(let property):
            return "Required property '\(property)' is missing"

        case .presetNotFound(let name):
            return "Configuration preset '\(name)' not found"

        case .validationFailed(let errors):
            return "Configuration validation failed: \(errors.joined(separator: ", "))"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidValue(let property, _, _):
            return "Check the documentation for valid values for '\(property)'"

        case .incompatibleSettings:
            return "Review your configuration to ensure settings are compatible"

        case .missingRequiredProperty:
            return "Add the missing property to your configuration"

        case .presetNotFound:
            return "Use one of the available presets: default, minimal, readOnly, markdown, presentation"

        case .validationFailed:
            return "Fix the validation errors before applying the configuration"
        }
    }
}

// MARK: - Syntax Highlighting Errors

/// Errors related to syntax highlighting
public enum SyntaxDomainError: LocalizedError, Sendable {
    case languageNotSupported(language: String)
    case parserInitializationFailed(language: String, reason: String)
    case highlightingFailed(range: NSRange, reason: String)
    case treeSitterError(message: String)
    case swiftSyntaxError(message: String)
    case cacheCorrupted
    
    public var errorDescription: String? {
        switch self {
        case .languageNotSupported(let language):
            return "Language '\(language)' is not supported for syntax highlighting"

        case let .parserInitializationFailed(language, reason):
            return "Failed to initialize parser for '\(language)': \(reason)"

        case let .highlightingFailed(range, reason):
            return "Syntax highlighting failed at range \(range): \(reason)"

        case .treeSitterError(let message):
            return "Tree-sitter error: \(message)"

        case .swiftSyntaxError(let message):
            return "SwiftSyntax error: \(message)"

        case .cacheCorrupted:
            return "Syntax highlighting cache is corrupted"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .languageNotSupported:
            return "Use a supported language or disable syntax highlighting"

        case .parserInitializationFailed:
            return "Check that the language parser is properly installed"

        case .highlightingFailed:
            return "Try disabling and re-enabling syntax highlighting"

        case .treeSitterError, .swiftSyntaxError:
            return "Report this issue with the problematic code sample"

        case .cacheCorrupted:
            return "Clear the syntax highlighting cache and retry"
        }
    }
}

// MARK: - Code Completion Errors

/// Errors related to code completion
public enum CompletionDomainError: LocalizedError, Sendable {
    case providerNotAvailable(type: String)
    case completionFailed(reason: String)
    case lspConnectionFailed(server: String, reason: String)
    case timeoutExceeded(operation: String)
    case invalidCompletionContext
    
    public var errorDescription: String? {
        switch self {
        case .providerNotAvailable(let type):
            return "Completion provider '\(type)' is not available"

        case .completionFailed(let reason):
            return "Code completion failed: \(reason)"

        case let .lspConnectionFailed(server, reason):
            return "Failed to connect to LSP server '\(server)': \(reason)"

        case .timeoutExceeded(let operation):
            return "Timeout exceeded for completion operation: \(operation)"

        case .invalidCompletionContext:
            return "Invalid context for code completion"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .providerNotAvailable:
            return "Check that the completion provider is properly configured"

        case .completionFailed:
            return "Try again or check the completion settings"

        case .lspConnectionFailed:
            return "Ensure the LSP server is installed and accessible"

        case .timeoutExceeded:
            return "Increase the timeout or try with a smaller file"

        case .invalidCompletionContext:
            return "Move cursor to a valid code location"
        }
    }
}

// MARK: - Memory Errors

/// Errors related to memory management
public enum MemoryDomainError: LocalizedError, Sendable {
    case memoryLimitExceeded(limit: Int, current: Int)
    case allocationFailed(size: Int)
    case cacheOverflow(cacheType: String)
    case cleanupFailed(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case let .memoryLimitExceeded(limit, current):
            return "Memory limit exceeded: \(current)MB / \(limit)MB"

        case .allocationFailed(let size):
            return "Failed to allocate \(size) bytes of memory"

        case .cacheOverflow(let cacheType):
            return "\(cacheType) cache has exceeded its size limit"

        case .cleanupFailed(let reason):
            return "Memory cleanup failed: \(reason)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .memoryLimitExceeded:
            return "Close other applications or increase the memory limit"

        case .allocationFailed:
            return "Free up memory or work with smaller files"

        case .cacheOverflow:
            return "Clear the cache or increase cache size limits"

        case .cleanupFailed:
            return "Restart the editor to free up memory"
        }
    }
}

// MARK: - TextKit Errors

/// Errors related to TextKit operations
public enum TextKitDomainError: LocalizedError, Sendable {
    case textKit2NotAvailable
    case layoutManagerNotFound
    case textStorageCorrupted
    case invalidTextRange(range: NSRange, length: Int)
    case renderingFailed(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .textKit2NotAvailable:
            return "TextKit2 is not available on this platform"

        case .layoutManagerNotFound:
            return "Text layout manager not found"

        case .textStorageCorrupted:
            return "Text storage is corrupted"

        case let .invalidTextRange(range, length):
            return "Invalid text range \(range) for document length \(length)"

        case .renderingFailed(let reason):
            return "Text rendering failed: \(reason)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .textKit2NotAvailable:
            return "Use TextKit1 fallback or upgrade to a newer OS version"

        case .layoutManagerNotFound:
            return "Reinitialize the text view"

        case .textStorageCorrupted:
            return "Reload the document"

        case .invalidTextRange:
            return "Check that the range is within document bounds"

        case .renderingFailed:
            return "Try disabling hardware acceleration"
        }
    }
}

// MARK: - Performance Errors

/// Errors related to performance issues
public enum PerformanceDomainError: LocalizedError, Sendable {
    case frameRateTooLow(current: Double, target: Double)
    case operationTimeout(operation: String, duration: TimeInterval)
    case resourceExhausted(resource: String)
    case throttled(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case let .frameRateTooLow(current, target):
            return "Frame rate too low: \(current)fps (target: \(target)fps)"

        case let .operationTimeout(operation, duration):
            return "Operation '\(operation)' timed out after \(duration) seconds"

        case .resourceExhausted(let resource):
            return "Resource exhausted: \(resource)"

        case .throttled(let reason):
            return "Performance throttled: \(reason)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .frameRateTooLow:
            return "Reduce visual complexity or enable performance mode"

        case .operationTimeout:
            return "Try with a smaller file or increase timeout"

        case .resourceExhausted:
            return "Free up resources or reduce workload"

        case .throttled:
            return "Wait for the system to recover or reduce activity"
        }
    }
}

// MARK: - Platform Errors

/// Errors specific to platform compatibility
public enum PlatformDomainError: LocalizedError, Sendable {
    case featureNotSupported(feature: String, platform: String)
    case osVersionTooOld(required: String, current: String)
    case platformMismatch(expected: String, actual: String)
    
    public var errorDescription: String? {
        switch self {
        case let .featureNotSupported(feature, platform):
            return "Feature '\(feature)' is not supported on \(platform)"

        case let .osVersionTooOld(required, current):
            return "OS version \(current) is too old (requires \(required) or newer)"

        case let .platformMismatch(expected, actual):
            return "Platform mismatch: expected \(expected), got \(actual)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .featureNotSupported:
            return "Use an alternative feature or upgrade platform"

        case .osVersionTooOld:
            return "Upgrade to the required OS version"

        case .platformMismatch:
            return "Use the correct platform-specific implementation"
        }
    }
}

// MARK: - Error Recovery

/// Protocol for errors that support recovery actions
public protocol RecoverableError: Error {
    /// Attempts to recover from the error
    /// - Returns: true if recovery succeeded
    func attemptRecovery() async -> Bool
}

/// Extension to make some errors recoverable
extension MemoryDomainError: RecoverableError {
    public func attemptRecovery() async -> Bool {
        switch self {
        case .cacheOverflow:
            // Attempt to clear caches
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .codeEditorClearCaches,
                    object: nil
                )
            }
            return true

        default:
            return false
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let codeEditorClearCaches = Notification.Name("com.codeeditor.clearCaches")
}
