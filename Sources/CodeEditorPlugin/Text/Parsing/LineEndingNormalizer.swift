import Foundation

// MARK: - Line Ending Normalizer

/// Normalizes and converts line endings in text.
public enum LineEndingNormalizer {
    // MARK: - Public API

    /// Normalizes line endings to specified format
    public static func normalizeLineEndings(in text: String, to format: LineEndingType) -> String {
        // First, normalize all line endings to \n
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // Then convert to target format
        switch format {
        case .unix:
            return normalized

        case .windows:
            return normalized.replacingOccurrences(of: "\n", with: "\r\n")

        case .classic:
            return normalized.replacingOccurrences(of: "\n", with: "\r")

        case .mixed:
            return text // Keep original
        }
    }

    /// Detects the predominant line ending type in text
    public static func detectLineEnding(in text: String) -> LineEndingType {
        let windowsCount = text.components(separatedBy: "\r\n").count - 1
        let unixCount = text.replacingOccurrences(of: "\r\n", with: "")
            .components(separatedBy: "\n").count - 1
        let classicCount = text.replacingOccurrences(of: "\r\n", with: "")
            .components(separatedBy: "\r").count - 1

        if windowsCount > 0 && unixCount > 0 {
            return .mixed
        }

        if windowsCount > unixCount && windowsCount > classicCount {
            return .windows
        }

        if classicCount > unixCount {
            return .classic
        }

        return .unix
    }

    // MARK: - Types

    /// Types of line endings used in text files
    public enum LineEndingType: Sendable {
        /// Unix/Linux/macOS line ending (\n)
        case unix
        /// Windows line ending (\r\n)
        case windows
        /// Classic Mac OS line ending (\r)
        case classic
        /// Mixed line endings
        case mixed

        /// The character sequence for this line ending type
        public var characters: String {
            switch self {
            case .unix: return "\n"
            case .windows: return "\r\n"
            case .classic: return "\r"
            case .mixed: return "\n" // Default fallback
            }
        }
    }
}
