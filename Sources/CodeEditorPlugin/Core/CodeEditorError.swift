// MARK: - CodeEditorError System

import Foundation

/// Comprehensive error types for CodeEditorPlugin
public enum CodeEditorError: LocalizedError, CustomStringConvertible {
    // MARK: - Configuration Errors
    case invalidConfiguration(String)
    case configurationValidationFailed([ValidationError])
    
    // MARK: - Text Processing Errors
    case invalidRange(NSRange, textLength: Int)
    case invalidPosition(Int, textLength: Int)
    case textProcessingFailed(String)
    
    // MARK: - Language Server Errors
    case languageServerNotAvailable(String)
    case languageServerTimeout(TimeInterval)
    case languageServerCommunicationFailed(Error)
    
    // MARK: - Completion Errors
    case completionProviderNotFound(String)
    case completionRequestFailed(Error)
    case completionTimeout(TimeInterval)
    
    // MARK: - Syntax Highlighting Errors
    case syntaxHighlightingFailed(String)
    case unsupportedLanguage(String)
    case highlightingTimeout(TimeInterval)
    
    // MARK: - File System Errors
    case fileTooLarge(Int, maxSize: Int)
    case fileReadingFailed(Error)
    case fileWritingFailed(Error)
    
    // MARK: - Platform Errors
    case unsupportedPlatform(String)
    case platformFeatureUnavailable(String)
    case hardwareAccelerationUnavailable
    
    // MARK: - LocalizedError Conformance
    
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let details):
            return "Invalid configuration: \(details)"
            
        case .configurationValidationFailed(let errors):
            let errorStrings = errors.map(\.description)
            return "Configuration validation failed: \(errorStrings.joined(separator: ", "))"
            
        case let .invalidRange(range, textLength):
            return "Invalid range \(range) for text of length \(textLength)"
            
        case let .invalidPosition(position, textLength):
            return "Invalid position \(position) for text of length \(textLength)"
            
        case .textProcessingFailed(let details):
            return "Text processing failed: \(details)"
            
        case .languageServerNotAvailable(let language):
            return "Language server not available: \(language)"
            
        case .languageServerTimeout(let timeout):
            return "Language server timeout: \(timeout) seconds"
            
        case .languageServerCommunicationFailed(let error):
            return "Language server communication failed: \(error.localizedDescription)"
            
        case .completionProviderNotFound(let providerId):
            return "Completion provider '\(providerId)' not found"
            
        case .completionRequestFailed(let error):
            return "Completion request failed: \(error.localizedDescription)"
            
        case .completionTimeout(let timeout):
            return "Completion timeout: \(timeout) seconds"
            
        case .syntaxHighlightingFailed(let details):
            return "Syntax highlighting failed: \(details)"
            
        case .unsupportedLanguage(let language):
            return "Unsupported language: \(language)"
            
        case .highlightingTimeout(let timeout):
            return "Syntax highlighting timeout: \(timeout) seconds"
            
        case let .fileTooLarge(size, maxSize):
            return "File too large: \(size) bytes (maximum: \(maxSize) bytes)"
            
        case .fileReadingFailed(let error):
            return "File reading failed: \(error.localizedDescription)"
            
        case .fileWritingFailed(let error):
            return "File writing failed: \(error.localizedDescription)"
            
        case .unsupportedPlatform(let platform):
            return "Unsupported platform: \(platform)"
            
        case .platformFeatureUnavailable(let feature):
            return "Platform feature unavailable: \(feature)"
            
        case .hardwareAccelerationUnavailable:
            return "Hardware acceleration is not available on this device"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .invalidConfiguration:
            return "The provided configuration contains invalid values"
            
        case .configurationValidationFailed:
            return "One or more configuration values failed validation"
            
        case .invalidRange, 
             .invalidPosition:
            return "The specified text range or position is outside the valid bounds"
            
        case .textProcessingFailed:
            return "An error occurred while processing the text content"
            
        case .languageServerNotAvailable, 
             .languageServerTimeout, 
             .languageServerCommunicationFailed:
            return "The language server is not responding or unavailable"
            
        case .completionProviderNotFound, 
             .completionRequestFailed, 
             .completionTimeout:
            return "The code completion system encountered an error"
            
        case .syntaxHighlightingFailed, 
             .unsupportedLanguage, 
             .highlightingTimeout:
            return "The syntax highlighting system encountered an error"
            
        case .fileTooLarge, 
             .fileReadingFailed, 
             .fileWritingFailed:
            return "A file system operation failed"
            
        case .unsupportedPlatform, 
             .platformFeatureUnavailable, 
             .hardwareAccelerationUnavailable:
            return "The requested feature is not supported on this platform"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidConfiguration:
            return "Check the configuration values and ensure they are within valid ranges"
            
        case .configurationValidationFailed:
            return "Review the validation errors and correct the invalid configuration values"
            
        case .invalidRange, 
             .invalidPosition:
            return "Ensure the range or position is within the bounds of the text content"
            
        case .textProcessingFailed:
            return "Try again with different text content or check for encoding issues"
            
        case .languageServerNotAvailable:
            return "Install and configure a language server for this language"
            
        case .languageServerTimeout:
            return "Try again or increase the timeout interval"
            
        case .languageServerCommunicationFailed:
            return "Check the language server configuration and restart if necessary"
            
        case .completionProviderNotFound:
            return "Register a completion provider for this language or feature"
            
        case .completionRequestFailed, 
             .completionTimeout:
            return "Try again or check the completion provider configuration"
            
        case .syntaxHighlightingFailed:
            return "Try disabling and re-enabling syntax highlighting"
            
        case .unsupportedLanguage:
            return "Add support for this language or use a different language"
            
        case .highlightingTimeout:
            return "Try with a smaller file or increase the highlighting timeout"
            
        case .fileTooLarge:
            return "Use a smaller file or increase the maximum file size limit"
            
        case .fileReadingFailed, 
             .fileWritingFailed:
            return "Check file permissions and disk space"
            
        case .unsupportedPlatform:
            return "Use a supported platform or check for platform-specific alternatives"
            
        case .platformFeatureUnavailable:
            return "Use an alternative feature or upgrade to a supported platform"
            
        case .hardwareAccelerationUnavailable:
            return "Disable hardware acceleration in the performance settings"
        }
    }
    
    // MARK: - CustomStringConvertible
    
    public var description: String {
        errorDescription ?? "Unknown CodeEditor error"
    }
}

// MARK: - Validation Error

/// Specific validation errors for configuration
public struct ValidationError: CustomStringConvertible, Equatable, Sendable {
    public let field: String
    public let valueDescription: String
    public let constraint: String
    
    public init(field: String, value: Any?, constraint: String) {
        self.field = field
        self.valueDescription = value.map(String.init(describing:)) ?? "nil"
        self.constraint = constraint
    }
    
    public var description: String {
        "\(field): '\(valueDescription)' violates constraint '\(constraint)'"
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.field == rhs.field && lhs.constraint == rhs.constraint && lhs.valueDescription == rhs.valueDescription
    }
}

// MARK: - Result Type Aliases

/// Result type for operations that can fail with CodeEditor errors
public typealias CodeEditorResult<T> = Result<T, CodeEditorError>

/// Result type for async operations
public typealias AsyncCodeEditorResult<T> = CodeEditorResult<T>

// MARK: - Error Extensions

extension CodeEditorError {
    /// Check if this error indicates a recoverable condition
    public var isRecoverable: Bool {
        switch self {
        case .invalidConfiguration, 
             .configurationValidationFailed,
             .invalidRange, 
             .invalidPosition,
             .languageServerTimeout, 
             .completionTimeout, 
             .highlightingTimeout,
             .completionRequestFailed, 
             .syntaxHighlightingFailed,
             .textProcessingFailed,
             .fileReadingFailed, 
             .fileWritingFailed:
            return true

        case .languageServerNotAvailable, 
             .languageServerCommunicationFailed,
             .completionProviderNotFound,
             .unsupportedLanguage,
             .fileTooLarge,
             .unsupportedPlatform, 
             .platformFeatureUnavailable, 
             .hardwareAccelerationUnavailable:
            return false
        }
    }
    
    /// Get the error category for logging and debugging
    public var category: String {
        switch self {
        case .invalidConfiguration, 
             .configurationValidationFailed:
            return "Configuration"

        case .invalidRange, 
             .invalidPosition, 
             .textProcessingFailed:
            return "TextProcessing"

        case .languageServerNotAvailable, 
             .languageServerTimeout, 
             .languageServerCommunicationFailed:
            return "LanguageServer"

        case .completionProviderNotFound, 
             .completionRequestFailed, 
             .completionTimeout:
            return "Completion"

        case .syntaxHighlightingFailed, 
             .unsupportedLanguage, 
             .highlightingTimeout:
            return "SyntaxHighlighting"

        case .fileTooLarge, 
             .fileReadingFailed, 
             .fileWritingFailed:
            return "FileSystem"

        case .unsupportedPlatform, 
             .platformFeatureUnavailable, 
             .hardwareAccelerationUnavailable:
            return "Platform"
        }
    }
}
