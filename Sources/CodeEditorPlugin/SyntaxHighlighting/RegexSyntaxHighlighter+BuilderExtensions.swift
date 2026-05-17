import CodeEditorLanguages
import Foundation

// MARK: - Language Definition Builder

extension RegexSyntaxHighlighter {
    /// A builder class to reduce boilerplate when creating language definitions
    internal struct LanguageDefinitionBuilder {
        private var rules: [RegexHighlightRule] = []

        /// Add comment patterns for the language
        func addComments(singleLine: String? = nil, multiLineStart: String? = nil, multiLineEnd: String? = nil) -> Self {
            var newRules = rules

            if let singleLine {
                if let rule = Self.rule(singleLine + #".*$"#, .comment, 10) {
                    newRules.append(rule)
                }
            }

            if let start = multiLineStart, let end = multiLineEnd {
                let pattern = NSRegularExpression.escapedPattern(for: start) + #"[\s\S]*?"# + NSRegularExpression.escapedPattern(for: end)
                if let rule = Self.rule(pattern, .comment, 10) {
                    newRules.append(rule)
                }
            }

            return Self(rules: newRules)
        }

        /// Add string patterns for the language
        func addStrings(single: Bool = true, double: Bool = true, backtick: Bool = false) -> Self {
            var newRules = rules

            if double {
                if let rule = Self.rule(#"\"(?:[^\"\\]|\\.)*\""#, .string, 9) {
                    newRules.append(rule)
                }
            }

            if single {
                if let rule = Self.rule(#"'(?:[^'\\]|\\.)*'"#, .string, 9) {
                    newRules.append(rule)
                }
            }

            if backtick {
                if let rule = Self.rule(#"`(?:[^`\\]|\\.)*`"#, .string, 9) {
                    newRules.append(rule)
                }
            }

            return Self(rules: newRules)
        }

        /// Add number patterns for the language
        func addNumbers(pattern: String = #"\b\d+\.?\d*\b"#) -> Self {
            var newRules = rules
            if let rule = Self.rule(pattern, .number, 8) {
                newRules.append(rule)
            }
            return Self(rules: newRules)
        }

        /// Add keywords for the language
        func addKeywords(_ keywords: [String]) -> Self {
            var newRules = rules
            let keywordPattern = #"\b("# + keywords.joined(separator: "|") + #")\b"#
            if let rule = Self.rule(keywordPattern, .keyword, 7) {
                newRules.append(rule)
            }
            return Self(rules: newRules)
        }

        /// Add function call patterns
        func addFunctionCalls(pattern: String = #"\b\w+(?=\s*\()"#) -> Self {
            var newRules = rules
            if let rule = Self.rule(pattern, .function, 6) {
                newRules.append(rule)
            }
            return Self(rules: newRules)
        }

        /// Add operator patterns
        func addOperators(pattern: String = #"[+\-*/%=<>!&|^~?:]+"#) -> Self {
            var newRules = rules
            if let rule = Self.rule(pattern, .operator, 5) {
                newRules.append(rule)
            }
            return Self(rules: newRules)
        }

        /// Add a custom rule
        func addCustomRule(pattern: String, type: RegexSyntaxTokenType, priority: Int) -> Self {
            var newRules = rules
            if let rule = Self.rule(pattern, type, priority) {
                newRules.append(rule)
            }
            return Self(rules: newRules)
        }

        /// Build the final language definition
        func build(name: String, fileExtensions: [String]) -> RegexLanguageDefinition {
            RegexLanguageDefinition(name: name, fileExtensions: fileExtensions, rules: rules)
        }

        /// Helper method to create rules. Delegates to the outer
        /// `RegexSyntaxHighlighter.rule(_:_:_:)`, which logs a fault and trips
        /// `assertionFailure` in debug when the pattern is invalid.
        private static func rule(
            _ pattern: String,
            _ tokenType: RegexSyntaxTokenType,
            _ priority: Int,
            file: StaticString = #fileID,
            line: UInt = #line
        ) -> RegexHighlightRule? {
            RegexSyntaxHighlighter.rule(pattern, tokenType, priority, file: file, line: line)
        }
    }
}
