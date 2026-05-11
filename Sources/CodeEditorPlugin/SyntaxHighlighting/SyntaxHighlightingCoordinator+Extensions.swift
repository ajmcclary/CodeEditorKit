import Foundation

// MARK: - SyntaxHighlightingCoordinator Extensions

extension SyntaxHighlightingCoordinator {
    /// Check if the coordinator supports highlighting for a specific language
    public func supportsLanguage(_ language: Language) -> Bool {
        switch language {
        case .swift, .python, .javascript, .typescript, .rust, .go, .java, .c, .cpp,
             .ruby, .php, .html, .css, .json, .yaml, .markdown, .xml, .sql, .shell,
             .dockerfile, .plainText:
            return true
        }
    }

    /// Get available languages for syntax highlighting
    public var supportedLanguages: [Language] {
        Language.allCases.filter { supportsLanguage($0) }
    }

    /// Get the appropriate highlighter for a language
    public func highlighter(for language: Language) -> (any SyntaxHighlighter)? {
        // Note: Custom highlighter registry has been removed in favor of built-in highlighters

        // Return built-in highlighters
        switch language {
        case .swift:
            // SwiftSyntaxHighlighter is created on demand
            return nil // Will be handled by highlightAsync

        default:
            // RegexSyntaxHighlighter handles most languages
            return nil // Will be handled by highlightAsync
        }
    }
}

// MARK: - MemoryMonitor Extension for Available Memory

extension MemoryMonitor {
    /// Get available memory in MB (estimated based on current usage)
    @MainActor
    public var availableMemoryMB: Double {
        // For simplicity, assume we have at least 100MB available if not under pressure
        // This is a reasonable assumption for modern devices
        let pressure = getMemoryPressure()

        switch pressure {
        case .normal:
            return 500.0 // Plenty of memory available

        case .warning:
            return 100.0 // Some memory available

        case .critical:
            return 50.0 // Very limited memory

        case .urgent:
            return 10.0 // Almost no memory
        }
    }
}
