import CodeEditorCommon
import CodeEditorLanguages
import Foundation

// MARK: - Syntax Highlighting Errors

/// Errors that can occur during syntax highlighting operations
public enum SyntaxHighlightingError: RecoverableAsyncError {
    case textTooLarge(size: Int, limit: Int)
    case languageNotSupported(Language)
    case parsingFailed(underlying: Error)
    case cacheCorrupted
    case memoryPressure(availableMB: Double, requiredMB: Double)
    case timeout(duration: Duration)
    case cancelled

    public var recoveryStrategies: [RecoveryStrategy] {
        switch self {
        case .textTooLarge:
            return [
                RecoveryStrategy(
                    action: .useAlternativeImplementation(name: "StreamingHighlighter"),
                    priority: 100,
                    description: "Use streaming highlighter for large files"
                ),
                RecoveryStrategy(
                    action: .fallback(description: "Disable syntax highlighting"),
                    priority: 50,
                    description: "Continue without syntax highlighting"
                ),
                RecoveryStrategy(
                    action: .reduceResourceUsage(suggestion: "Increase performance limits in configuration"),
                    priority: 25,
                    description: "Adjust performance settings"
                )
            ]

        case .languageNotSupported:
            return [
                RecoveryStrategy(
                    action: .fallback(description: "Use plain text highlighting"),
                    priority: 100,
                    description: "Fall back to basic text display"
                ),
                RecoveryStrategy(
                    action: .reportToUser(message: "Language not supported for syntax highlighting"),
                    priority: 50,
                    description: "Inform user about limitation"
                )
            ]

        case .parsingFailed:
            return [
                RecoveryStrategy(
                    action: .retry(maxAttempts: 2, backoffStrategy: .constant(.milliseconds(100))),
                    priority: 75,
                    description: "Retry parsing with fresh state"
                ),
                RecoveryStrategy(
                    action: .clearCacheAndRetry,
                    priority: 50,
                    description: "Clear cache and retry"
                ),
                RecoveryStrategy(
                    action: .fallback(description: "Use regex-based highlighting"),
                    priority: 25,
                    description: "Fall back to simpler highlighting"
                )
            ]

        case .cacheCorrupted:
            return [
                RecoveryStrategy(
                    action: .clearCacheAndRetry,
                    priority: 100,
                    description: "Clear corrupted cache and rebuild"
                )
            ]

        case .memoryPressure:
            return [
                RecoveryStrategy(
                    action: .reduceResourceUsage(suggestion: "Reduce cache size and retry"),
                    priority: 100,
                    description: "Free memory and retry"
                ),
                RecoveryStrategy(
                    action: .useAlternativeImplementation(name: "LowMemoryHighlighter"),
                    priority: 75,
                    description: "Use memory-efficient implementation"
                ),
                RecoveryStrategy(
                    action: .fallback(description: "Postpone highlighting until memory available"),
                    priority: 50,
                    description: "Defer operation"
                )
            ]

        case .timeout:
            return [
                RecoveryStrategy(
                    action: .retry(maxAttempts: 1, backoffStrategy: .constant(.seconds(1))),
                    priority: 75,
                    description: "Retry with increased timeout"
                ),
                RecoveryStrategy(
                    action: .useAlternativeImplementation(name: "StreamingHighlighter"),
                    priority: 50,
                    description: "Use incremental processing"
                )
            ]

        case .cancelled:
            return [
                RecoveryStrategy(
                    action: .ignore,
                    priority: 100,
                    description: "Operation was intentionally cancelled"
                )
            ]
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .parsingFailed, .timeout, .memoryPressure:
            return true

        case .textTooLarge, .languageNotSupported, .cacheCorrupted, .cancelled:
            return false
        }
    }

    public var retryDelay: Duration? {
        switch self {
        case .parsingFailed:
            return .milliseconds(100)

        case .timeout:
            return .seconds(1)

        case .memoryPressure:
            return .seconds(2)

        default:
            return nil
        }
    }

    public var userDescription: String {
        switch self {
        case let .textTooLarge(size, limit):
            return "File too large for syntax highlighting (\(size) > \(limit) characters)"

        case .languageNotSupported(let language):
            return "\(language.rawValue) is not supported for syntax highlighting"

        case .parsingFailed:
            return "Failed to parse file for syntax highlighting"

        case .cacheCorrupted:
            return "Syntax highlighting cache is corrupted"

        case let .memoryPressure(available, required):
            return "Insufficient memory (available: \(Int(available))MB, required: \(Int(required))MB)"

        case .timeout:
            return "Syntax highlighting took too long"

        case .cancelled:
            return "Syntax highlighting was cancelled"
        }
    }
}
