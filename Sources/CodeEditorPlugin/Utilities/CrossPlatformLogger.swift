import Foundation

#if canImport(os.log)
import os.log
#endif

/// Cross-platform logging utility that provides a unified interface for logging
/// across Apple platforms and Linux
public enum CrossPlatformLogger {
    // MARK: - Properties

    /// Default subsystem for the plugin
    private static let defaultSubsystem = "com.codeeditor.plugin"

    /// Default category for general logging
    private static let defaultCategory = "general"

    /// Log levels for cross-platform compatibility
    public enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case fault = "FAULT"

        #if canImport(os.log)
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .fault: return .fault
            }
        }
        #endif
    }

    /// Create a logger for a specific subsystem and category
    public static func logger(subsystem: String, category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }

    /// Create a logger with default subsystem and category
    public static func logger() -> Logger {
        Logger(subsystem: defaultSubsystem, category: defaultCategory)
    }

    /// Logger instance that provides cross-platform logging functionality
    public struct Logger: Sendable {
        #if !canImport(os.log)
        private let subsystem: String
        private let category: String
        #endif

        #if canImport(os.log)
        private let osLogger: os.Logger
        #endif

        init(subsystem: String, category: String) {
            #if !canImport(os.log)
            self.subsystem = subsystem
            self.category = category
            #endif

            #if canImport(os.log)
            self.osLogger = os.Logger(subsystem: subsystem, category: category)
            #endif
        }

        /// Log a debug message
        public func debug(_ message: String) {
            log(level: .debug, message)
        }

        /// Log an info message
        public func info(_ message: String) {
            log(level: .info, message)
        }

        /// Log a warning message
        public func warning(_ message: String) {
            log(level: .warning, message)
        }

        /// Log an error message
        public func error(_ message: String) {
            log(level: .error, message)
        }

        /// Log a fault message
        public func fault(_ message: String) {
            log(level: .fault, message)
        }

        /// Internal logging method.
        ///
        /// **Privacy contract.** Messages are logged with explicit
        /// `.public` privacy on Apple platforms. This wrapper accepts a
        /// pre-interpolated `String`, so OSLog cannot redact individual
        /// substitutions — the whole message is one opaque value at the
        /// boundary. The choice is `.public` so production logs stay
        /// useful (`<private>` everywhere would defeat the purpose of
        /// diagnostic logging). Callers are responsible for redacting
        /// sensitive data (tokens, paths, user identifiers) at the
        /// interpolation site before passing the string here.
        private func log(level: Level, _ message: String) {
            #if canImport(os.log)
            osLogger.log(level: level.osLogType, "\(message, privacy: .public)")
            #else
            // Fallback to stderr on platforms without os.log.
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "[\(timestamp)] [\(subsystem)/\(category)] [\(level.rawValue)] \(message)\n"
            if let data = line.data(using: .utf8) {
                FileHandle.standardError.write(data)
            }
            #endif
        }
    }
}

// MARK: - Legacy Compatibility

/// Compatibility extension for existing code that uses static logger
extension CrossPlatformLogger {
    /// Default logger for backward compatibility
    public static let `default` = Logger(subsystem: "com.codeeditor.plugin", category: "general")
}
