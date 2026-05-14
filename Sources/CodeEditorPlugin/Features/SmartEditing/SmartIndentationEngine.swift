import Foundation

// MARK: - Smart Indentation Engine

/// Handles automatic indentation for code editing
@MainActor
public enum SmartIndentationEngine {
    // MARK: - Calculate Indentation

    /// Calculate indentation for a new line
    /// - Parameters:
    ///   - location: The location in the text
    ///   - textView: The code editor view
    ///   - rules: Auto-indent rules to apply
    ///   - configuration: Smart editing configuration
    /// - Returns: The indentation string to use
    public static func calculateIndentation(
        at location: Int,
        in textView: CodeEditorView,
        rules: [AutoIndentRule],
        configuration: SmartEditingConfiguration
    ) -> String {
        guard configuration.isAutoIndentEnabled else { return "" }

        let bridge = textView.textKitBridge
        let documentString = bridge.documentString
        guard !documentString.isEmpty else { return "" }

        // Get the current line
        let lineRange = TextRangeUtilities.lineRange(containing: location, in: documentString)
        let currentLine = bridge.substring(in: lineRange) ?? ""

        // Extract current indentation
        let indentation = currentLine.prefix { $0 == " " || $0 == "\t" }
        var newIndentation = String(indentation)

        // Check auto-indent rules
        for rule in rules where currentLine.contains(rule.trigger) {
            switch rule.action {
            case .increaseIndent:
                newIndentation += configuration.insertSpacesForTabs ?
                    String(repeating: " ", count: configuration.tabWidth) : "\t"

            case .decreaseIndent:
                // Remove one level of indentation
                if configuration.insertSpacesForTabs {
                    for _ in 0..<configuration.tabWidth where newIndentation.hasSuffix(" ") {
                        newIndentation.removeLast()
                    }
                } else if newIndentation.hasSuffix("\t") {
                    newIndentation.removeLast()
                }

            case .increaseIndentNext:
                // Will increase on next line
                break

            case .maintainIndent:
                break
            }
        }

        return newIndentation
    }

    /// Creates default auto-indent rules
    /// - Returns: Array of default auto-indent rules
    public static func defaultRules() -> [AutoIndentRule] {
        [
            AutoIndentRule(trigger: "{", action: .increaseIndent),
            AutoIndentRule(trigger: "}", action: .decreaseIndent),
            AutoIndentRule(trigger: ":", action: .increaseIndentNext), // Python
            AutoIndentRule(trigger: "case", action: .increaseIndent), // Switch statements
            AutoIndentRule(trigger: "default:", action: .maintainIndent)
        ]
    }
}
