import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - SyntaxHighlightingService

/// Service responsible for syntax highlighting business logic
/// Separates highlighting decisions from UI implementation
@MainActor
public final class SyntaxHighlightingService {
    // MARK: - Properties

    private let syntaxHighlighter: SyntaxHighlightingCoordinator
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "SyntaxHighlightingService")

    // MARK: - Initialization

    /// Creates a new syntax highlighting service.
    ///
    /// - Parameter syntaxHighlighter: The coordinator to use for highlighting.
    ///   If `nil`, a new coordinator will be created.
    public init(syntaxHighlighter: SyntaxHighlightingCoordinator? = nil) {
        self.syntaxHighlighter = syntaxHighlighter ?? SyntaxHighlightingCoordinator()
    }

    // MARK: - Public Methods

    /// Determines if syntax highlighting should be applied based on configuration and content
    public func shouldApplySyntaxHighlighting(
        isEnabled: Bool,
        textLength: Int,
        maxLength: Int
    ) -> Bool {
        guard isEnabled else {
            logger.debug("Syntax highlighting disabled by configuration")
            return false
        }

        guard textLength <= maxLength else {
            logger.debug("Text length \(textLength) exceeds maximum \(maxLength) for syntax highlighting")
            return false
        }

        return true
    }

    /// Calculates the appropriate range for syntax highlighting
    public func calculateHighlightingRange(
        editedRange: NSRange,
        textLength: Int,
        visibleRange: NSRange?
    ) -> NSRange? {
        guard editedRange.location != NSNotFound else {
            return nil
        }

        // Validate range bounds
        let maxLocation = editedRange.location + editedRange.length
        guard maxLocation <= textLength else {
            logger.warning("Edited range \(editedRange) exceeds text length \(textLength)")
            return nil
        }

        // If visible range is provided, expand to include it
        if let visible = visibleRange {
            let combinedLocation = min(editedRange.location, visible.location)
            let combinedEnd = max(
                editedRange.location + editedRange.length,
                visible.location + visible.length
            )
            return NSRange(location: combinedLocation, length: combinedEnd - combinedLocation)
        }

        return editedRange
    }

    /// Schedules syntax highlighting with appropriate debouncing
    public func scheduleHighlighting(
        asyncHighlighter: AsyncSyntaxHighlighter,
        textView: CodeEditorView,
        language: Language,
        visibleRange: NSRange?
    ) {
        logger.debug("Scheduling syntax highlighting for language: \(language.name)")

        asyncHighlighter.scheduleHighlighting(
            for: textView,
            language: language,
            visibleRange: visibleRange
        )
    }

    /// Cancels all pending highlighting operations
    public func cancelHighlighting(asyncHighlighter: AsyncSyntaxHighlighter) {
        logger.debug("Cancelling all syntax highlighting")
        asyncHighlighter.cancelAllHighlighting()
    }

    /// Updates completion trigger characters for a language
    public func getCompletionTriggerCharacters(for language: Language) -> Set<Character> {
        switch language {
        case .swift:
            return [".", "(", "[", "<", " ", ":"]

        case .python:
            return [".", "(", "[", " ", ":"]

        case .javascript, .typescript:
            return [".", "(", "[", "{", " ", ":"]

        case .rust:
            return [".", ":", "<", "(", "[", " "]

        case .go:
            return [".", "(", "[", " "]

        case .c, .cpp:
            return [".", ">", ":", "(", "[", " "]

        case .java:
            return [".", "(", "[", "<", " "]

        case .ruby:
            return [".", "(", "[", "{", " ", ":"]

        case .php:
            return ["$", ">", "(", "[", " ", ":"]

        case .sql:
            return [".", "(", " "]

        case .html, .xml:
            return ["<", " ", "=", "\"", "'"]

        case .css:
            return [".", "#", ":", " ", "("]

        case .json, .yaml:
            return ["\"", "'", " ", ":"]

        case .markdown:
            return ["[", "(", " "]

        case .shell:
            return ["$", "-", " ", "/"]

        case .dockerfile:
            return [" ", "$"]

        case .toml:
            return ["=", " ", "[", "\"", "'"]

        case .lua:
            return [".", ":", "(", " "]

        case .csharp:
            return [".", "(", "[", "<", " "]

        case .kotlin:
            return [".", "(", "[", "<", " ", ":"]

        case .dart:
            return [".", "(", "[", "<", " ", ":"]

        case .plainText:
            return []
        }
    }

    /// Validates if a range is safe to highlight
    public func isValidHighlightingRange(_ range: NSRange, textLength: Int) -> Bool {
        range.location >= 0 &&
        range.length >= 0 &&
        range.location + range.length <= textLength
    }

    /// Determines if highlighting should be viewport-based
    public func shouldUseViewportHighlighting(
        textLength: Int,
        viewportThreshold: Int = 50_000
    ) -> Bool {
        textLength > viewportThreshold
    }

    /// Calculates performance mode for highlighting
    public func determineHighlightingMode(
        textLength: Int,
        configuration: EditorConfiguration
    ) -> HighlightingMode {
        if textLength > configuration.performance.maxSyntaxHighlightingLength {
            return .disabled
        } else if textLength > 100_000 {
            return .viewportOnly
        } else if textLength > 50_000 {
            return .progressive
        } else {
            return .full
        }
    }

    // MARK: - Cache Management

    /// Clears any cached highlighting data
    public func clearCache() {
        // The actual cache is managed by AsyncSyntaxHighlighter
        logger.debug("Syntax highlighting cache cleared")
    }
}

// MARK: - Supporting Types

/// Highlighting performance modes.
///
/// `HighlightingMode` determines the extent and performance characteristics
/// of syntax highlighting based on document size and editor configuration.
public enum HighlightingMode {
    /// Syntax highlighting is completely disabled
    case disabled
    /// Only highlight the visible viewport area
    case viewportOnly
    /// Gradually highlight the document in chunks
    case progressive
    /// Highlight the entire document at once
    case full
}

// MARK: - Platform-Specific Extensions
