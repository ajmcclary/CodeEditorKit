import Foundation

// MARK: - Completion Provider Utilities

/// Shared utilities for completion providers
public enum CompletionProviderUtilities {
    // MARK: - Filtering

    /// Filter items based on fuzzy matching
    public static func fuzzyFilter<T>(
        items: [T],
        filter: String,
        keyPath: KeyPath<T, String>
    ) -> [T] {
        guard !filter.isEmpty else { return items }

        return items.filter { item in
            let text = item[keyPath: keyPath]
            return fuzzyMatch(text: text, pattern: filter)
        }
    }

    /// Perform fuzzy matching
    public static func fuzzyMatch(text: String, pattern: String) -> Bool {
        let text = text.lowercased()
        let pattern = pattern.lowercased()

        var patternIndex = pattern.startIndex
        var textIndex = text.startIndex

        while patternIndex < pattern.endIndex && textIndex < text.endIndex {
            if text[textIndex] == pattern[patternIndex] {
                patternIndex = pattern.index(after: patternIndex)
            }
            textIndex = text.index(after: textIndex)
        }

        return patternIndex == pattern.endIndex
    }

    // MARK: - Scoring

    /// Calculate relevance score for completion items
    public static func calculateRelevanceScore(
        item: String,
        filter: String,
        contextType: CompletionContextType
    ) -> Double {
        var score = 1.0

        // Exact match bonus
        if item.lowercased() == filter.lowercased() {
            score += 10.0
        }

        // Prefix match bonus
        if item.lowercased().hasPrefix(filter.lowercased()) {
            score += 5.0
        }

        // Context type bonus
        switch contextType {
        case .keyword:
            score += 3.0

        case .general:
            score += 2.5

        case .function:
            score += 2.0

        case .member:
            score += 1.5

        default:
            break
        }

        // Length penalty (prefer shorter completions)
        score -= Double(item.count) * 0.01

        return max(0, score)
    }

    // MARK: - Common Patterns

    /// Extract import statement context
    public static func extractImportContext(from line: String) -> (module: String?, isPartial: Bool) {
        let importPattern = #"^\s*(import|from)\s+(\S*)"#

        if let regex = try? NSRegularExpression(pattern: importPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            if let moduleRange = Range(match.range(at: 2), in: line) {
                let module = String(line[moduleRange])
                return (module.isEmpty ? nil : module, true)
            }
        }

        return (nil, false)
    }

    /// Extract function call context
    public static func extractFunctionCallContext(from text: String, at position: Int) -> (function: String?, parameterIndex: Int) {
        // Look backwards for opening parenthesis
        let beforeCursor = String(text.prefix(position))

        var parenDepth = 0
        var commaCount = 0
        var functionEnd = -1

        for (index, char) in beforeCursor.enumerated().reversed() {
            switch char {
            case ")":
                parenDepth += 1

            case "(":
                parenDepth -= 1
                if parenDepth == -1 {
                    functionEnd = index
                    break
                }

            case "," where parenDepth == 0:
                commaCount += 1

            default:
                break
            }
        }

        if functionEnd >= 0 {
            // Extract function name
            let beforeParen = String(beforeCursor.prefix(functionEnd))
            let components = beforeParen.components(separatedBy: CharacterSet.alphanumerics.inverted)
            if let functionName = components.last, !functionName.isEmpty {
                return (functionName, commaCount)
            }
        }

        return (nil, 0)
    }

    // MARK: - Documentation

    /// Generate documentation for common programming constructs
    public static func generateDocumentation(
        for item: String,
        kind: CompletionItemKind,
        language: Language
    ) -> String? {
        switch kind {
        case .keyword:
            return keywordDocumentation(for: item, language: language)

        case .function:
            return functionDocumentation(for: item, language: language)

        case .class:
            return typeDocumentation(for: item, language: language)

        default:
            return nil
        }
    }

    private static func keywordDocumentation(for keyword: String, language _: Language) -> String? {
        // Common keyword documentation
        let commonDocs: [String: String] = [
            "if": "Conditional statement that executes code when a condition is true",
            "for": "Loop that iterates over a sequence or range",
            "while": "Loop that continues while a condition is true",
            "class": "Defines a new class type",
            "func": "Defines a new function",
            "def": "Defines a new function (Python)",
            "return": "Returns a value from a function",
            "import": "Imports code from another module",
            "try": "Begins an error handling block",
            "catch": "Handles errors from a try block"
        ]

        return commonDocs[keyword]
    }

    private static func functionDocumentation(for function: String, language _: Language) -> String? {
        // Common function documentation
        let commonDocs: [String: String] = [
            "print": "Outputs text to the console",
            "len": "Returns the length of a collection",
            "range": "Creates a sequence of numbers",
            "map": "Applies a function to each element in a collection",
            "filter": "Filters elements based on a condition"
        ]

        return commonDocs[function]
    }

    private static func typeDocumentation(for type: String, language _: Language) -> String? {
        // Common type documentation
        let commonDocs: [String: String] = [
            "String": "Text data type",
            "Int": "Integer number type",
            "Float": "Floating-point number type",
            "Bool": "Boolean true/false type",
            "Array": "Ordered collection type",
            "Dictionary": "Key-value collection type"
        ]

        return commonDocs[type]
    }
}
