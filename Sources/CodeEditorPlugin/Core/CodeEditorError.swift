// MARK: - CodeEditorError System

import Foundation

/// Comprehensive error types for CodeEditorPlugin.
///
/// `CodeEditorError` provides a structured error system for all components of the
/// code editor. Each error case includes detailed localized descriptions, failure
/// reasons, and recovery suggestions.
///
/// ## Error Categories
///
/// ### Configuration Errors
/// - `invalidConfiguration`: Invalid configuration values
/// - `configurationValidationFailed`: Validation errors with specific fields
///
/// ### Text Processing Errors
/// - `invalidRange`: Text range outside valid bounds
/// - `invalidPosition`: Cursor position outside text bounds
/// - `textProcessingFailed`: General text processing failures
///
/// ### Language Server Errors
/// - `languageServerNotAvailable`: LSP not configured for language
/// - `languageServerTimeout`: LSP request exceeded timeout
/// - `languageServerCommunicationFailed`: LSP communication error
///
/// ### Completion Errors
/// - `completionProviderNotFound`: No provider for requested completion
/// - `completionRequestFailed`: Completion request error
/// - `completionTimeout`: Completion exceeded timeout
///
/// ### Syntax Highlighting Errors
/// - `syntaxHighlightingFailed`: Highlighting processing error
/// - `unsupportedLanguage`: No highlighter for language
/// - `highlightingTimeout`: Highlighting exceeded timeout
///
/// ### File System Errors
/// - `fileTooLarge`: File exceeds size limit
/// - `fileReadingFailed`: Cannot read file
/// - `fileWritingFailed`: Cannot write file
///
/// ### Platform Errors
/// - `unsupportedPlatform`: Feature not available on platform
/// - `platformFeatureUnavailable`: Specific platform feature missing
/// - `hardwareAccelerationUnavailable`: GPU acceleration not supported
///
/// ## Error Handling
///
/// ```swift
/// do {
///     try editor.performOperation()
/// } catch let error as CodeEditorError {
///     print("Error: \(error.errorDescription ?? "Unknown")")
///     print("Reason: \(error.failureReason ?? "Unknown")")
///     print("Recovery: \(error.recoverySuggestion ?? "None")")
///     
///     if error.isRecoverable {
///         // Attempt recovery
///     }
/// }
/// ```
///
/// ## Error Properties
///
/// ```swift
/// let error = CodeEditorError.fileTooLarge(1_000_000, maxSize: 500_000)
/// print(error.category)        // "FileSystem"
/// print("\(error.isRecoverable)")   // false
/// ```
///
/// - SeeAlso: ``ValidationError``, ``CodeEditorResult``
public enum CodeEditorError: LocalizedError, CustomStringConvertible, Sendable {
    // MARK: - Configuration Errors
    case invalidConfiguration(String)
    case configurationValidationFailed([ValidationError])

    // MARK: - Text Processing Errors
    case invalidRange(NSRange, textLength: Int)
    case invalidPosition(Int, textLength: Int)
    case textProcessingFailed(String)
    case encodingFailed(String.Encoding)

    // MARK: - Language Server Errors
    case languageServerNotAvailable(String)
    case languageServerTimeout(TimeInterval)
    case languageServerCommunicationFailed(String)

    // MARK: - Completion Errors
    case completionProviderNotFound(String)
    case completionRequestFailed(String)
    case completionTimeout(TimeInterval)

    // MARK: - Syntax Highlighting Errors
    case syntaxHighlightingFailed(String)
    case unsupportedLanguage(String)
    case highlightingTimeout(TimeInterval)

    // MARK: - File System Errors
    case fileTooLarge(Int, maxSize: Int)
    case fileReadingFailed(String)
    case fileWritingFailed(String)

    // MARK: - Service Errors
    case serviceUnavailable(String)

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

        case .encodingFailed(let encoding):
            return "Failed to convert text to encoding: \(encoding)"

        case .languageServerNotAvailable(let language):
            return "Language server not available: \(language)"

        case .languageServerTimeout(let timeout):
            return "Language server timeout: \(timeout) seconds"

        case .languageServerCommunicationFailed(let details):
            return "Language server communication failed: \(details)"

        case .completionProviderNotFound(let providerId):
            return "Completion provider '\(providerId)' not found"

        case .completionRequestFailed(let details):
            return "Completion request failed: \(details)"

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

        case .fileReadingFailed(let details):
            return "File reading failed: \(details)"

        case .fileWritingFailed(let details):
            return "File writing failed: \(details)"

        case .unsupportedPlatform(let platform):
            return "Unsupported platform: \(platform)"

        case .platformFeatureUnavailable(let feature):
            return "Platform feature unavailable: \(feature)"

        case .hardwareAccelerationUnavailable:
            return "Hardware acceleration is not available on this device"

        case .serviceUnavailable(let serviceName):
            return "Required service unavailable: \(serviceName)"
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

        case .encodingFailed:
            return "Text encoding conversion failed"

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

        case .serviceUnavailable:
            return "A required editor service has not been configured"
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

        case .encodingFailed:
            return "Ensure the text can be represented in the target encoding or use a different encoding"

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

        case .serviceUnavailable:
            return "Register the required dependency before requesting this service"
        }
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        errorDescription ?? "Unknown CodeEditor error"
    }
}

// MARK: - Validation Error

/// Specific validation errors for configuration.
///
/// Provides detailed information about configuration validation failures,
/// including the field name, invalid value, and constraint that was violated.
///
/// ## Example
///
/// ```swift
/// let error = ValidationError(
///     field: "fontSize",
///     value: -1,
///     constraint: "must be greater than 0"
/// )
/// print(error) // "fontSize: '-1' violates constraint 'must be greater than 0'"
/// ```
///
/// - SeeAlso: ``CodeEditorError``, ``EditorConfiguration``
public struct ValidationError: CustomStringConvertible, Equatable, Sendable {
    /// The configuration field that failed validation.
    public let field: String

    /// String representation of the invalid value.
    public let valueDescription: String

    /// Description of the constraint that was violated.
    public let constraint: String

    /// Creates a validation error.
    ///
    /// - Parameters:
    ///   - field: The field name (e.g., "fontSize", "tabWidth")
    ///   - value: The invalid value that was provided
    ///   - constraint: Description of the validation constraint
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
             .encodingFailed,
             .fileReadingFailed,
             .fileWritingFailed,
             .serviceUnavailable:
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
             .textProcessingFailed,
             .encodingFailed:
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

        case .serviceUnavailable:
            return "Service"
        }
    }
}
