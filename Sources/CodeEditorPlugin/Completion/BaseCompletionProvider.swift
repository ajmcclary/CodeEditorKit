import Foundation

// MARK: - Base Completion Provider

/// Base class for language-specific completion providers that reduces code duplication
/// and provides common functionality across all language implementations.
///
/// ## Overview
/// 
/// `BaseCompletionProvider` implements the standard completion flow and provides
/// reusable methods for creating completion items. Language-specific providers
/// inherit from this class and override only the parts they need to customize.
///
/// ## Usage Example
///
/// ```swift
/// public final class SwiftCompletionProvider: BaseCompletionProvider {
///     override public var keywords: [String] {
///         ["func", "var", "let", "class", "struct", "enum", "protocol"]
///     }
///     
///     override public var types: [String] {
///         ["String", "Int", "Double", "Bool", "Array", "Dictionary"]
///     }
///     
///     public init() {
///         super.init(
///             id: "swift-builtin",
///             supportedLanguages: [.swift],
///             triggerCharacters: [".", "(", "[", " "],
///             supportsSnippets: true
///         )
///     }
///     
///     override public func analyzeContext(_ context: CompletionContextModel) -> ContextAnalysisResult {
///         // Custom context analysis for Swift
///     }
/// }
/// ```
///
/// ## Customization Points
///
/// - **Language Elements**: Override `keywords`, `types`, `literals`, `functions`, and `snippets`
/// - **Context Analysis**: Override `analyzeContext(_:)` for language-specific parsing
/// - **Member Completions**: Override `createMemberCompletions(for:filter:)` for type members
/// - **Parameter Completions**: Override `createParameterCompletions(filter:)` for parameters
///
/// ## Benefits
///
/// 1. **Reduced Duplication**: Common completion logic is implemented once
/// 2. **Consistent Behavior**: All languages follow the same completion flow
/// 3. **Easy Maintenance**: Bug fixes and improvements benefit all languages
/// 4. **Simplified Testing**: Test the base behavior once, then test language specifics
///
@MainActor
open class BaseCompletionProvider: CompletionProvider {
    // MARK: - Properties
    
    public let id: String
    public let supportedLanguages: [Language]
    public let triggerCharacters: [String]
    public let supportsSnippets: Bool
    
    // Language elements - to be overridden by subclasses
    open var keywords: [String] { [] }
    open var types: [String] { [] }
    open var literals: [String] { [] }
    open var functions: [String] { [] }
    open var snippets: [SnippetTemplate] { [] }
    
    // MARK: - Initialization
    
    public init(
        id: String,
        supportedLanguages: [Language],
        triggerCharacters: [String] = [".", "(", "[", " "],
        supportsSnippets: Bool = true
    ) {
        self.id = id
        self.supportedLanguages = supportedLanguages
        self.triggerCharacters = triggerCharacters
        self.supportsSnippets = supportsSnippets
    }
    
    // MARK: - CompletionProvider Implementation
    
    public func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()
        
        // Analyze context to determine what kind of completions to provide
        let analysisResult = analyzeContext(context)
        var items: [CompletionItemModel] = []
        
        // Add appropriate completions based on context
        switch analysisResult.type {
        case .keyword:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            
        case .type:
            items.append(contentsOf: createTypeCompletions(filter: analysisResult.filter))
            
        case .function:
            items.append(contentsOf: createFunctionCompletions(filter: analysisResult.filter))
            
        case .member:
            items.append(contentsOf: createMemberCompletions(for: analysisResult.targetType, filter: analysisResult.filter))
            
        case .general:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createTypeCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createLiteralCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createFunctionCompletions(filter: analysisResult.filter))
            if supportsSnippets {
                items.append(contentsOf: createSnippetCompletions(filter: analysisResult.filter))
            }
            
        case .parameter:
            items.append(contentsOf: createParameterCompletions(filter: analysisResult.filter))
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return CompletionResult(
            items: items,
            context: context,
            isIncomplete: false,
            processingTime: processingTime
        )
    }
    
    // MARK: - Context Analysis (Override Points)
    
    /// Analyze the context to determine what kind of completions to provide
    open func analyzeContext(_ context: CompletionContextModel) -> ContextAnalysisResult {
        let beforeCursor = String(context.text.prefix(context.cursorPosition))
        
        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)
        
        // Check for member access
        if beforeCursor.hasSuffix(".") {
            let targetType = extractTargetType(from: beforeCursor)
            return ContextAnalysisResult(type: .member, filter: "", targetType: targetType)
        }
        
        // Default to general context
        return ContextAnalysisResult(type: .general, filter: filter)
    }
    
    /// Extract the current word being typed
    open func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return components.last ?? ""
    }
    
    /// Extract the target type for member completions
    open func extractTargetType(from text: String) -> String? {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        if let lastWord = words.last?.dropLast() { // Remove the dot
            return String(lastWord)
        }
        return nil
    }
    
    // MARK: - Completion Creation Methods
    
    /// Create keyword completions
    open func createKeywordCompletions(filter: String) -> [CompletionItemModel] {
        keywords
            .filter { keyword in
                filter.isEmpty || keyword.localizedCaseInsensitiveContains(filter)
            }
            .map { keyword in
                CompletionItemModel(
                    label: keyword,
                    insertText: keyword,
                    kind: .keyword,
                    detail: "Keyword",
                    sortText: "a_\(keyword)", // Keywords first
                    priority: 80
                )
            }
    }
    
    /// Create type completions
    open func createTypeCompletions(filter: String) -> [CompletionItemModel] {
        types
            .filter { type in
                filter.isEmpty || type.localizedCaseInsensitiveContains(filter)
            }
            .map { type in
                CompletionItemModel(
                    label: type,
                    insertText: type,
                    kind: .class,
                    detail: "Type",
                    sortText: "b_\(type)",
                    priority: 70
                )
            }
    }
    
    /// Create literal completions
    open func createLiteralCompletions(filter: String) -> [CompletionItemModel] {
        literals
            .filter { literal in
                filter.isEmpty || literal.localizedCaseInsensitiveContains(filter)
            }
            .map { literal in
                CompletionItemModel(
                    label: literal,
                    insertText: literal,
                    kind: .value,
                    detail: "Literal",
                    sortText: "c_\(literal)",
                    priority: 60
                )
            }
    }
    
    /// Create function completions
    open func createFunctionCompletions(filter: String) -> [CompletionItemModel] {
        functions
            .filter { function in
                filter.isEmpty || function.localizedCaseInsensitiveContains(filter)
            }
            .map { function in
                CompletionItemModel(
                    label: function,
                    insertText: "\(function)()",
                    kind: .function,
                    detail: "Function",
                    sortText: "d_\(function)",
                    priority: 65
                )
            }
    }
    
    /// Create snippet completions
    open func createSnippetCompletions(filter: String) -> [CompletionItemModel] {
        snippets
            .filter { snippet in
                filter.isEmpty || snippet.label.localizedCaseInsensitiveContains(filter)
            }
            .map { snippet in
                CompletionItemModel(
                    label: snippet.label,
                    insertText: snippet.insertText,
                    kind: .snippet,
                    detail: snippet.description,
                    sortText: "e_\(snippet.label)",
                    priority: 90,
                    snippetSupport: true
                )
            }
    }
    
    /// Create member completions (override for language-specific behavior)
    open func createMemberCompletions(for _: String?, filter _: String) -> [CompletionItemModel] {
        // Default: no member completions
        // Subclasses should override for language-specific member access
        []
    }
    
    /// Create parameter completions (override for language-specific behavior)
    open func createParameterCompletions(filter: String) -> [CompletionItemModel] {
        // Default: suggest types for parameters
        createTypeCompletions(filter: filter)
    }
}

// MARK: - Supporting Types

/// Result of context analysis
public struct ContextAnalysisResult {
    let type: CompletionContextType
    let filter: String
    let targetType: String?
    
    init(type: CompletionContextType, filter: String, targetType: String? = nil) {
        self.type = type
        self.filter = filter
        self.targetType = targetType
    }
}

/// Type of completion context
public enum CompletionContextType {
    case keyword
    case type
    case function
    case member
    case parameter
    case general
}

/// Template for code snippets
public struct SnippetTemplate: Sendable {
    public let label: String
    public let insertText: String
    public let description: String
    
    public init(label: String, insertText: String, description: String) {
        self.label = label
        self.insertText = insertText
        self.description = description
    }
}
