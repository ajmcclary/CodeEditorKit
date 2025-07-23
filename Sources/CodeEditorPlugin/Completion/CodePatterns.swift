import Foundation

// MARK: - Code Pattern Analysis

/// Protocol for code patterns that can generate contextual completion suggestions
public protocol CodePattern {
    /// Generate a completion suggestion based on the current context
    /// - Parameter context: The current completion context
    /// - Returns: A completion suggestion if the pattern matches, nil otherwise
    func generateSuggestion(for context: CompletionContextModel) -> CompletionItemModel?
}

// MARK: - Pattern Implementations

/// Method chaining pattern for suggesting common chaining methods
public struct MethodChainingPattern: CodePattern {
    public init() {}

    public func generateSuggestion(for context: CompletionContextModel) -> CompletionItemModel? {
        // Suggest common chaining methods
        if context.currentWord.isEmpty && context.lineText.hasSuffix(".") {
            return CompletionItemModel(
                label: "map",
                insertText: "map { <#code#> }",
                kind: .method,
                detail: "Transform elements"
            )
        }
        return nil
    }
}

/// Property access pattern for suggesting common properties
public struct PropertyAccessPattern: CodePattern {
    public init() {}

    public func generateSuggestion(for context: CompletionContextModel) -> CompletionItemModel? {
        // Suggest common properties
        if context.currentWord.hasPrefix(".") {
            let propertyName = String(context.currentWord.dropFirst())
            if propertyName.isEmpty || "count".hasPrefix(propertyName) {
                return CompletionItemModel(
                    label: "count",
                    insertText: "count",
                    kind: .property,
                    detail: "Number of elements"
                )
            }
        }
        return nil
    }
}

/// Function call pattern for suggesting parameter completions
public struct FunctionCallPattern: CodePattern {
    public init() {}

    public func generateSuggestion(for context: CompletionContextModel) -> CompletionItemModel? {
        // Suggest function parameter completion
        if context.lineText.contains("(") && !context.lineText.contains(")") {
            return CompletionItemModel(
                label: "completion",
                insertText: "<#parameter#>)",
                kind: .keyword,
                detail: "Parameter placeholder"
            )
        }
        return nil
    }
}

// MARK: - Pattern Registry

/// Registry for managing code patterns
public struct CodePatternRegistry {
    private var patterns: [CodePattern] = []

    /// Creates a new code pattern registry with default patterns
    public init() {
        // Register default patterns
        patterns = [
            MethodChainingPattern(),
            PropertyAccessPattern(),
            FunctionCallPattern()
        ]
    }

    /// Register a new code pattern
    /// - Parameter pattern: The pattern to register
    public mutating func register(_ pattern: CodePattern) {
        patterns.append(pattern)
    }

    /// Generate suggestions from all registered patterns
    /// - Parameter context: The current completion context
    /// - Returns: Array of completion suggestions
    public func generateSuggestions(for context: CompletionContextModel) -> [CompletionItemModel] {
        patterns.compactMap { $0.generateSuggestion(for: context) }
    }
}
