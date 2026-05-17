import Foundation

// MARK: - Indentation Analyzer

/// Analyzes and extracts indentation information from text lines.
public enum IndentationAnalyzer {
    // MARK: - Public API

    /// Extracts line indentation with detailed analysis
    public static func extractLineIndentation(_ line: String, tabWidth: Int = 4) -> IndentationInfo {
        var spaces = 0
        var tabs = 0
        var mixed = false
        var hasSeenSpaces = false
        var hasSeenTabs = false

        for char in line {
            if char == " " {
                spaces += 1
                hasSeenSpaces = true
                if hasSeenTabs { mixed = true }
            } else if char == "\t" {
                tabs += 1
                hasSeenTabs = true
                if hasSeenSpaces { mixed = true }
            } else {
                break // First non-whitespace character
            }
        }

        let indentationStyle: IndentationInfo.IndentationStyle
        if mixed {
            indentationStyle = .mixed
        } else if tabs > 0 {
            indentationStyle = .tabs
        } else {
            indentationStyle = .spaces(width: tabWidth)
        }

        let level = mixed ? (spaces + tabs * tabWidth) / tabWidth : max(spaces / tabWidth, tabs)

        return IndentationInfo(
            spaces: spaces,
            tabs: tabs,
            mixed: mixed,
            level: level,
            indentationStyle: indentationStyle
        )
    }

    // MARK: - Types

    /// Detailed information about indentation patterns in a line of text.
    public struct IndentationInfo {
        /// Number of space characters used for indentation.
        public let spaces: Int
        /// Number of tab characters used for indentation.
        public let tabs: Int
        /// Whether the line uses mixed indentation (both spaces and tabs).
        public let mixed: Bool
        /// Calculated indentation level based on the style.
        public let level: Int
        /// The detected indentation style for this line.
        public let indentationStyle: IndentationStyle

        /// Indentation style categories for consistent formatting.
        public enum IndentationStyle {
            /// Space-based indentation with specified width per level.
            case spaces(width: Int)
            /// Tab-based indentation.
            case tabs
            /// Mixed indentation using both spaces and tabs.
            case mixed
        }

        /// Total indentation width assuming 4-space tab equivalents.
        public var totalIndentation: Int {
            spaces + (tabs * 4)
        }
    }
}
