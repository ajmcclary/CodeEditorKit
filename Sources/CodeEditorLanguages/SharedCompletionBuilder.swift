import Foundation

// MARK: - Shared Completion Builder

/// Provides shared completion building logic to eliminate duplication across language providers
public enum SharedCompletionBuilder {
    // MARK: - Common Completion Creation

    /// Creates keyword completions from an array of keywords
    public static func createKeywordCompletions(
        from keywords: [String],
        filter: String,
        languageName: String
    ) -> [CompletionItemModel] {
        keywords
            .filter { keyword in
                filter.isEmpty || keyword.localizedCaseInsensitiveContains(filter)
            }
            .map { keyword in
                CompletionItemModel(
                    label: keyword,
                    insertText: keyword,
                    kind: .keyword,
                    detail: "\(languageName) keyword",
                    priority: 80,
                    preselect: keyword == filter
                )
            }
    }

    /// Creates type completions from an array of types
    public static func createTypeCompletions(
        from types: [String],
        filter: String,
        languageName: String
    ) -> [CompletionItemModel] {
        types
            .filter { type in
                filter.isEmpty || type.localizedCaseInsensitiveContains(filter)
            }
            .map { type in
                CompletionItemModel(
                    label: type,
                    insertText: type,
                    kind: .class,
                    detail: "\(languageName) type",
                    priority: 70
                )
            }
    }

    /// Creates function completions from an array of functions
    public static func createFunctionCompletions(
        from functions: [String],
        filter: String,
        languageName: String
    ) -> [CompletionItemModel] {
        functions
            .filter { function in
                filter.isEmpty || function.localizedCaseInsensitiveContains(filter)
            }
            .map { function in
                let insertText = function.hasSuffix("!") || function.hasSuffix("()")
                    ? function
                    : "\(function)($0)"

                return CompletionItemModel(
                    label: function,
                    insertText: insertText,
                    kind: .function,
                    detail: "\(languageName) function",
                    priority: 75
                )
            }
    }

    /// Creates literal completions from an array of literals
    public static func createLiteralCompletions(
        from literals: [String],
        filter: String,
        languageName: String
    ) -> [CompletionItemModel] {
        literals
            .filter { literal in
                filter.isEmpty || literal.localizedCaseInsensitiveContains(filter)
            }
            .map { literal in
                let kind: CompletionItemKind = literal.hasPrefix("__") ? .method : .value
                let detail = literal.hasPrefix("__") ? "\(languageName) magic method" : "\(languageName) literal"

                return CompletionItemModel(
                    label: literal,
                    insertText: literal,
                    kind: kind,
                    detail: detail,
                    priority: 60
                )
            }
    }

    /// Creates snippet completions from descriptor snippet templates.
    public static func createSnippetCompletions(
        from snippets: [SnippetTemplate],
        filter: String,
        languageName: String
    ) -> [CompletionItemModel] {
        snippets
            .filter { snippet in
                filter.isEmpty || snippet.label.localizedCaseInsensitiveContains(filter)
            }
            .map { snippet in
                CompletionItemModel(
                    label: snippet.label,
                    insertText: snippet.insertText,
                    kind: .snippet,
                    detail: "\(languageName) snippet",
                    documentation: snippet.description,
                    priority: 90,
                    snippetSupport: true
                )
            }
    }

    /// Creates module completions from descriptor module metadata.
    public static func createModuleCompletions(
        from modules: [String],
        filter: String,
        languageName: String
    ) -> [CompletionItemModel] {
        modules
            .filter { module in
                filter.isEmpty || module.localizedCaseInsensitiveContains(filter)
            }
            .map { module in
                CompletionItemModel(
                    label: module,
                    insertText: module,
                    kind: .module,
                    detail: "\(languageName) module",
                    priority: 65
                )
            }
    }

    /// Creates parameter completions for common parameter names by language
    public static func createParameterCompletions(
        for language: Language,
        filter: String
    ) -> [CompletionItemModel] {
        let parameters = getCommonParameters(for: language)

        return parameters
            .filter { param in
                filter.isEmpty || param.localizedCaseInsensitiveContains(filter)
            }
            .map { param in
                CompletionItemModel(
                    label: param,
                    insertText: param,
                    kind: .variable,
                    detail: "Parameter suggestion",
                    priority: 50
                )
            }
    }

    /// Creates member completions from tuples of (name, type, description)
    public static func createMemberItems(
        from members: [(String, String, String)],
        filter: String
    ) -> [CompletionItemModel] {
        members
            .filter { name, _, _ in
                filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
            }
            .map { name, type, description in
                let kind: CompletionItemKind = switch type {
                case "method": .method
                case "property": .property
                case "module": .module
                default: .property
                }

                return CompletionItemModel(
                    label: name,
                    insertText: name,
                    kind: kind,
                    detail: description,
                    priority: 85
                )
            }
    }

    // MARK: - Language-Specific Parameter Lists

    private static func getCommonParameters(for language: Language) -> [String] {
        switch language {
        case .python:
            return ["self", "cls", "args", "kwargs", "key", "value", "index", "item", "data", "result", "error", "callback"]

        case .javascript:
            return ["event", "error", "data", "result", "callback", "options", "config", "request", "response", "next", "done", "resolve", "reject"]

        case .rust:
            return ["self", "other", "value", "data", "result", "error", "callback", "closure", "predicate", "key", "index"]

        case .swift:
            return ["self", "value", "data", "result", "error", "completion", "handler", "delegate", "index", "key"]

        default:
            return ["value", "data", "result", "error", "index", "key", "callback"]
        }
    }
}

// MARK: - Shared Context Analyzer

/// Provides shared context analysis logic to eliminate duplication
public enum SharedContextAnalyzer {
    /// Analyzes completion context for any language
    public static func analyzeContext(
        _ context: CompletionContextModel,
        for language: Language
    ) -> UniversalContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = context.textBeforeCursor

        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor, for: language)

        // Language-specific context analysis
        switch language {
        case .python:
            return analyzePythonContext(lineText: lineText, beforeCursor: beforeCursor, filter: filter)

        case .javascript:
            return analyzeJavaScriptContext(lineText: lineText, beforeCursor: beforeCursor, filter: filter)

        case .rust:
            return analyzeRustContext(lineText: lineText, beforeCursor: beforeCursor, filter: filter)

        default:
            return analyzeGeneralContext(lineText: lineText, beforeCursor: beforeCursor, filter: filter)
        }
    }

    // MARK: - Language-Specific Analysis

    private static func analyzePythonContext(
        lineText: String,
        beforeCursor: String,
        filter: String
    ) -> UniversalContextAnalysisResult {
        // Check for import statements
        if lineText.hasPrefix("import ") || lineText.hasPrefix("from ") {
            return UniversalContextAnalysisResult(type: .literal, filter: filter)
        }

        // Check for member access
        if beforeCursor.hasSuffix(".") {
            let targetType = extractTargetType(from: beforeCursor)
            return UniversalContextAnalysisResult(type: .member, filter: "", targetType: targetType)
        }

        // Check for function definition
        if lineText.contains("def ") && lineText.contains("(") && !lineText.contains("):") {
            return UniversalContextAnalysisResult(type: .parameter, filter: filter)
        }

        // Check for type hints
        if lineText.contains(": ") && !lineText.contains("=") {
            return UniversalContextAnalysisResult(type: .type, filter: filter)
        }

        return UniversalContextAnalysisResult(type: .general, filter: filter)
    }

    private static func analyzeJavaScriptContext(
        lineText: String,
        beforeCursor: String,
        filter: String
    ) -> UniversalContextAnalysisResult {
        // Check for import/require statements
        if lineText.hasPrefix("import ") || lineText.contains("from '") || lineText.contains("require(") {
            return UniversalContextAnalysisResult(type: .literal, filter: filter)
        }

        // Check for member access
        if beforeCursor.hasSuffix(".") {
            let targetType = extractTargetType(from: beforeCursor)
            return UniversalContextAnalysisResult(type: .member, filter: "", targetType: targetType)
        }

        // Check for function definition
        if lineText.contains("function ") && lineText.contains("(") && !lineText.contains(")") {
            return UniversalContextAnalysisResult(type: .parameter, filter: filter)
        }

        // Check for object property context
        if beforeCursor.hasSuffix(":") || lineText.contains("new ") {
            return UniversalContextAnalysisResult(type: .type, filter: filter)
        }

        return UniversalContextAnalysisResult(type: .general, filter: filter)
    }

    private static func analyzeRustContext(
        lineText: String,
        beforeCursor: String,
        filter: String
    ) -> UniversalContextAnalysisResult {
        // Check for use statements
        if lineText.hasPrefix("use ") {
            return UniversalContextAnalysisResult(type: .literal, filter: filter)
        }

        // Check for member access
        if beforeCursor.hasSuffix(".") {
            let targetType = extractTargetType(from: beforeCursor)
            return UniversalContextAnalysisResult(type: .member, filter: "", targetType: targetType)
        }

        // Check for module access
        if beforeCursor.hasSuffix("::") {
            let targetModule = extractTargetModule(from: beforeCursor)
            return UniversalContextAnalysisResult(type: .member, filter: "", targetType: targetModule)
        }

        // Check for type context
        if lineText.contains(": ") || lineText.contains("-> ") || lineText.contains("let ") {
            return UniversalContextAnalysisResult(type: .type, filter: filter)
        }

        return UniversalContextAnalysisResult(type: .general, filter: filter)
    }

    private static func analyzeGeneralContext(
        lineText _: String,
        beforeCursor: String,
        filter: String
    ) -> UniversalContextAnalysisResult {
        // Check for member access
        if beforeCursor.hasSuffix(".") {
            let targetType = extractTargetType(from: beforeCursor)
            return UniversalContextAnalysisResult(type: .member, filter: "", targetType: targetType)
        }

        return UniversalContextAnalysisResult(type: .general, filter: filter)
    }

    // MARK: - Helper Methods

    private static func extractCurrentWord(from text: String, for language: Language) -> String {
        let additionalChars = switch language {
        case .rust: "_!'"
        case .javascript: "_$"
        default: "_"
        }

        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: additionalChars)).inverted)
        return components.last ?? ""
    }

    private static func extractTargetType(from text: String) -> String? {
        // Simple heuristic to extract the object before the dot
        let pattern = #"(\w+)\s*\.\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }

    private static func extractTargetModule(from text: String) -> String? {
        // Extract the module before ::
        let pattern = #"([\w:]+)::\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }
}
