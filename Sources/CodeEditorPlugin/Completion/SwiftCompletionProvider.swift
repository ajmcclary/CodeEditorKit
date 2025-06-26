import Foundation

// MARK: - Swift Completion Provider

/// Built-in completion provider for Swift language
@MainActor
public final class SwiftCompletionProvider: CompletionProvider, @unchecked Sendable {
    public let id = "swift-builtin"
    public let supportedLanguages: [Language] = [.swift]
    public let triggerCharacters = [".", "(", "[", "<", " "]
    public let supportsSnippets = true
    
    // Swift language elements
    private let keywords = [
        "func", "var", "let", "class", "struct", "enum", "protocol", "extension",
        "import", "if", "else", "for", "while", "do", "switch", "case", "default",
        "break", "continue", "return", "throw", "try", "catch", "guard", "defer",
        "public", "private", "internal", "fileprivate", "open", "static", "final",
        "override", "mutating", "nonmutating", "convenience", "required", "lazy",
        "weak", "unowned", "inout", "async", "await", "actor", "nonisolated"
    ]
    
    private let types = [
        "String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set",
        "Optional", "Result", "Data", "URL", "Date", "UUID", "NSString", "NSArray",
        "NSMutableArray", "NSMutableDictionary", "NSObject", "Any", "AnyObject"
    ]
    
    private let literals = [
        "true", "false", "nil", "self", "super", "Self"
    ]
    
    private let snippets: [SnippetTemplate] = [
        SnippetTemplate(
            label: "func",
            insertText: "func ${1:name}(${2:parameters}) ${3:-> ReturnType }{{\n    ${4:// implementation}\n}}",
            description: "Function declaration"
        ),
        SnippetTemplate(
            label: "class",
            insertText: "class ${1:ClassName} {\n    ${2:// implementation}\n}",
            description: "Class declaration"
        ),
        SnippetTemplate(
            label: "struct",
            insertText: "struct ${1:StructName} {\n    ${2:// implementation}\n}",
            description: "Struct declaration"
        ),
        SnippetTemplate(
            label: "enum",
            insertText: "enum ${1:EnumName} {\n    case ${2:caseName}\n}",
            description: "Enum declaration"
        ),
        SnippetTemplate(
            label: "protocol",
            insertText: "protocol ${1:ProtocolName} {\n    ${2:// requirements}\n}",
            description: "Protocol declaration"
        ),
        SnippetTemplate(
            label: "extension",
            insertText: "extension ${1:TypeName} {\n    ${2:// implementation}\n}",
            description: "Extension declaration"
        ),
        SnippetTemplate(
            label: "if",
            insertText: "if ${1:condition} {\n    ${2:// code}\n}",
            description: "If statement"
        ),
        SnippetTemplate(
            label: "guard",
            insertText: "guard ${1:condition} else {\n    ${2:return}\n}",
            description: "Guard statement"
        ),
        SnippetTemplate(
            label: "for",
            insertText: "for ${1:item} in ${2:collection} {\n    ${3:// code}\n}",
            description: "For-in loop"
        ),
        SnippetTemplate(
            label: "while",
            insertText: "while ${1:condition} {\n    ${2:// code}\n}",
            description: "While loop"
        ),
        SnippetTemplate(
            label: "switch",
            insertText: "switch ${1:value} {\ncase ${2:pattern}:\n    ${3:// code}\ndefault:\n    ${4:// code}\n}",
            description: "Switch statement"
        ),
        SnippetTemplate(
            label: "do-catch",
            insertText: "do {\n    ${1:try statement}\n} catch {\n    ${2:// handle error}\n}",
            description: "Do-catch block"
        ),
        SnippetTemplate(
            label: "async func",
            insertText: "func ${1:name}(${2:parameters}) async ${3:throws }${4:-> ReturnType }{{\n    ${5:// implementation}\n}}",
            description: "Async function declaration"
        ),
        SnippetTemplate(
            label: "actor",
            insertText: "actor ${1:ActorName} {\n    ${2:// implementation}\n}",
            description: "Actor declaration"
        )
    ]
    
    public init() {}
    
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
            
        case .member:
            items.append(contentsOf: createMemberCompletions(for: analysisResult.targetType, filter: analysisResult.filter))
            
        case .general:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createTypeCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createLiteralCompletions(filter: analysisResult.filter))
            if supportsSnippets {
                items.append(contentsOf: createSnippetCompletions(filter: analysisResult.filter))
            }
            
        case .parameter:
            items.append(contentsOf: createParameterCompletions(filter: analysisResult.filter))
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return CompletionResult(
            items: items,
            isIncomplete: false,
            context: context,
            processingTime: processingTime
        )
    }
    
    // MARK: - Context Analysis
    
    private func analyzeContext(_ context: CompletionContextModel) -> ContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = String(context.text.prefix(context.cursorPosition))
        
        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)
        
        // Determine completion type based on context
        if lineText.contains("func ") && !lineText.contains("{") {
            return ContextAnalysisResult(type: .parameter, filter: filter)
        }
        
        if beforeCursor.hasSuffix(".") {
            let targetType = extractTargetType(from: beforeCursor)
            return ContextAnalysisResult(type: .member, filter: "", targetType: targetType)
        }
        
        if lineText.hasPrefix("import ") || lineText.contains(": ") {
            return ContextAnalysisResult(type: .type, filter: filter)
        }
        
        return ContextAnalysisResult(type: .general, filter: filter)
    }
    
    private func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return components.last ?? ""
    }
    
    private func extractTargetType(from text: String) -> String? {
        // Simple heuristic to extract the type before the dot
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        if let lastWord = words.last?.dropLast() { // Remove the dot
            return String(lastWord)
        }
        return nil
    }
    
    // MARK: - Completion Creation Methods
    
    private func createKeywordCompletions(filter: String) -> [CompletionItemModel] {
        keywords.filter { keyword in
            filter.isEmpty || keyword.localizedCaseInsensitiveContains(filter)
        }.map { keyword in
            CompletionItemModel(
                label: keyword,
                insertText: keyword,
                kind: .keyword,
                detail: "Swift keyword",
                priority: 80,
                preselect: keyword == filter
            )
        }
    }
    
    private func createTypeCompletions(filter: String) -> [CompletionItemModel] {
        types.filter { type in
            filter.isEmpty || type.localizedCaseInsensitiveContains(filter)
        }.map { type in
            CompletionItemModel(
                label: type,
                insertText: type,
                kind: determineTypeKind(type),
                detail: "Swift type",
                priority: 70
            )
        }
    }
    
    private func createLiteralCompletions(filter: String) -> [CompletionItemModel] {
        literals.filter { literal in
            filter.isEmpty || literal.localizedCaseInsensitiveContains(filter)
        }.map { literal in
            CompletionItemModel(
                label: literal,
                insertText: literal,
                kind: .value,
                detail: "Swift literal",
                priority: 60
            )
        }
    }
    
    private func createSnippetCompletions(filter: String) -> [CompletionItemModel] {
        snippets.filter { snippet in
            filter.isEmpty || snippet.label.localizedCaseInsensitiveContains(filter)
        }.map { snippet in
            CompletionItemModel(
                label: snippet.label,
                insertText: snippet.insertText,
                kind: .snippet,
                detail: snippet.description,
                priority: 90,
                snippetSupport: true
            )
        }
    }
    
    private func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel] {
        guard let targetType else { return [] }
        
        // Provide common member completions based on type
        switch targetType.lowercased() {
        case "string":
            return createStringMemberCompletions(filter: filter)

        case "array":
            return createArrayMemberCompletions(filter: filter)

        case "dictionary":
            return createDictionaryMemberCompletions(filter: filter)

        default:
            return createCommonMemberCompletions(filter: filter)
        }
    }
    
    private func createParameterCompletions(filter: String) -> [CompletionItemModel] {
        let commonParameters = ["completion", "handler", "delegate", "error", "result", "value", "index"]
        
        return commonParameters.filter { param in
            filter.isEmpty || param.localizedCaseInsensitiveContains(filter)
        }.map { param in
            CompletionItemModel(
                label: param,
                insertText: param,
                kind: .variable,
                detail: "Parameter suggestion",
                priority: 50
            )
        }
    }
    
    // MARK: - Type-Specific Members
    
    private func createStringMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("count", "property", "Number of characters"),
            ("isEmpty", "property", "Whether string is empty"),
            ("uppercased()", "method", "Returns uppercased string"),
            ("lowercased()", "method", "Returns lowercased string"),
            ("contains(_:)", "method", "Check if contains substring"),
            ("hasPrefix(_:)", "method", "Check if has prefix"),
            ("hasSuffix(_:)", "method", "Check if has suffix"),
            ("replacingOccurrences(of:with:)", "method", "Replace occurrences")
        ]
        
        return members.filter { name, _, _ in
            filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
        }.map { name, type, description in
            CompletionItemModel(
                label: name,
                insertText: name,
                kind: type == "method" ? .method : .property,
                detail: description,
                priority: 85
            )
        }
    }
    
    private func createArrayMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("count", "property", "Number of elements"),
            ("isEmpty", "property", "Whether array is empty"),
            ("first", "property", "First element (optional)"),
            ("last", "property", "Last element (optional)"),
            ("append(_:)", "method", "Add element to end"),
            ("insert(_:at:)", "method", "Insert element at index"),
            ("remove(at:)", "method", "Remove element at index"),
            ("filter(_:)", "method", "Filter elements"),
            ("map(_:)", "method", "Transform elements"),
            ("forEach(_:)", "method", "Iterate over elements")
        ]
        
        return members.filter { name, _, _ in
            filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
        }.map { name, type, description in
            CompletionItemModel(
                label: name,
                insertText: name,
                kind: type == "method" ? .method : .property,
                detail: description,
                priority: 85
            )
        }
    }
    
    private func createDictionaryMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("count", "property", "Number of key-value pairs"),
            ("isEmpty", "property", "Whether dictionary is empty"),
            ("keys", "property", "Collection of keys"),
            ("values", "property", "Collection of values"),
            ("updateValue(_:forKey:)", "method", "Update value for key"),
            ("removeValue(forKey:)", "method", "Remove value for key"),
            ("filter(_:)", "method", "Filter key-value pairs"),
            ("map(_:)", "method", "Transform key-value pairs")
        ]
        
        return members.filter { name, _, _ in
            filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
        }.map { name, type, description in
            CompletionItemModel(
                label: name,
                insertText: name,
                kind: type == "method" ? .method : .property,
                detail: description,
                priority: 85
            )
        }
    }
    
    private func createCommonMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("description", "property", "String representation"),
            ("debugDescription", "property", "Debug string representation"),
            ("hashValue", "property", "Hash value for Hashable types")
        ]
        
        return members.filter { name, _, _ in
            filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
        }.map { name, type, description in
            CompletionItemModel(
                label: name,
                insertText: name,
                kind: type == "method" ? .method : .property,
                detail: description,
                priority: 40
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func determineTypeKind(_ typeName: String) -> CompletionItemKind {
        switch typeName {
        case "String", "Int", "Double", "Float", "Bool":
            return .struct

        case "Array", "Dictionary", "Set", "Optional", "Result":
            return .struct

        case let name where name.hasPrefix("NS"):
            return .class

        default:
            return .class
        }
    }
}

// MARK: - Supporting Types

private struct ContextAnalysisResult {
    enum CompletionType {
        case keyword    // Keywords like func, var, etc.
        case type      // Type names and imports
        case member    // Member access after dot
        case general   // General context
        case parameter // Function parameters
    }
    
    let type: CompletionType
    let filter: String
    let targetType: String?
    
    init(type: CompletionType, filter: String, targetType: String? = nil) {
        self.type = type
        self.filter = filter
        self.targetType = targetType
    }
}

private struct SnippetTemplate {
    let label: String
    let insertText: String
    let description: String
}
