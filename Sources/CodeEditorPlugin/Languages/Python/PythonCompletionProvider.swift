import Foundation

// MARK: - Python Completion Provider

/// Built-in completion provider for Python language
@MainActor
public final class PythonCompletionProvider: CompletionProvider, @unchecked Sendable {
    public let id = "python-builtin"
    public let supportedLanguages: [Language] = [.python]
    public let triggerCharacters = [".", "(", "[", " ", ":"]
    public let supportsSnippets = true
    
    // Python language elements
    private let keywords = [
        "def", "class", "if", "elif", "else", "for", "while", "try", "except",
        "finally", "with", "as", "import", "from", "return", "yield", "break",
        "continue", "pass", "global", "nonlocal", "lambda", "and", "or", "not",
        "in", "is", "del", "async", "await", "assert", "raise", "match", "case"
    ]
    
    private let builtinTypes = [
        "int", "float", "str", "bool", "list", "tuple", "dict", "set", "frozenset",
        "bytes", "bytearray", "memoryview", "range", "complex", "type", "object",
        "property", "staticmethod", "classmethod", "super"
    ]
    
    private let builtinFunctions = [
        "print", "input", "len", "range", "enumerate", "zip", "map", "filter",
        "sorted", "reversed", "sum", "min", "max", "any", "all", "abs", "round",
        "pow", "divmod", "isinstance", "issubclass", "hasattr", "getattr", "setattr",
        "delattr", "open", "format", "chr", "ord", "bin", "hex", "oct", "eval",
        "exec", "compile", "globals", "locals", "vars", "dir", "help", "id",
        "hash", "iter", "next", "callable", "repr", "ascii", "breakpoint"
    ]
    
    private let literals = [
        "True", "False", "None", "self", "__name__", "__main__", "__file__",
        "__doc__", "__dict__", "__class__", "__init__", "__new__", "__del__",
        "__str__", "__repr__", "__eq__", "__ne__", "__lt__", "__le__", "__gt__",
        "__ge__", "__hash__", "__bool__", "__len__", "__getitem__", "__setitem__",
        "__delitem__", "__iter__", "__next__", "__contains__", "__add__", "__sub__",
        "__mul__", "__truediv__", "__floordiv__", "__mod__", "__pow__", "__and__",
        "__or__", "__xor__", "__lshift__", "__rshift__", "__neg__", "__pos__",
        "__abs__", "__invert__", "__enter__", "__exit__", "__call__"
    ]
    
    private let snippets: [SnippetTemplate] = [
        SnippetTemplate(
            label: "def",
            insertText: "def ${1:function_name}(${2:parameters}):\n    ${3:pass}",
            description: "Function definition"
        ),
        SnippetTemplate(
            label: "class",
            insertText: "class ${1:ClassName}:\n    def __init__(self${2:, parameters}):\n        ${3:pass}",
            description: "Class definition with __init__"
        ),
        SnippetTemplate(
            label: "if",
            insertText: "if ${1:condition}:\n    ${2:pass}",
            description: "If statement"
        ),
        SnippetTemplate(
            label: "ifelse",
            insertText: "if ${1:condition}:\n    ${2:pass}\nelse:\n    ${3:pass}",
            description: "If-else statement"
        ),
        SnippetTemplate(
            label: "for",
            insertText: "for ${1:item} in ${2:iterable}:\n    ${3:pass}",
            description: "For loop"
        ),
        SnippetTemplate(
            label: "while",
            insertText: "while ${1:condition}:\n    ${2:pass}",
            description: "While loop"
        ),
        SnippetTemplate(
            label: "try",
            insertText: "try:\n    ${1:pass}\nexcept ${2:Exception} as ${3:e}:\n    ${4:pass}",
            description: "Try-except block"
        ),
        SnippetTemplate(
            label: "tryfinally",
            insertText: "try:\n    ${1:pass}\nexcept ${2:Exception} as ${3:e}:\n    ${4:pass}\nfinally:\n    ${5:pass}",
            description: "Try-except-finally block"
        ),
        SnippetTemplate(
            label: "with",
            insertText: "with ${1:expression} as ${2:variable}:\n    ${3:pass}",
            description: "With statement"
        ),
        SnippetTemplate(
            label: "lambda",
            insertText: "lambda ${1:arguments}: ${2:expression}",
            description: "Lambda function"
        ),
        SnippetTemplate(
            label: "list comprehension",
            insertText: "[${1:expression} for ${2:item} in ${3:iterable}]",
            description: "List comprehension"
        ),
        SnippetTemplate(
            label: "dict comprehension",
            insertText: "{${1:key}: ${2:value} for ${3:item} in ${4:iterable}}",
            description: "Dictionary comprehension"
        ),
        SnippetTemplate(
            label: "async def",
            insertText: "async def ${1:function_name}(${2:parameters}):\n    ${3:await expression}",
            description: "Async function definition"
        ),
        SnippetTemplate(
            label: "decorator",
            insertText: "@${1:decorator}\ndef ${2:function_name}(${3:parameters}):\n    ${4:pass}",
            description: "Function with decorator"
        ),
        SnippetTemplate(
            label: "property",
            insertText: "@property\ndef ${1:property_name}(self):\n    return self._${1:property_name}",
            description: "Property decorator"
        ),
        SnippetTemplate(
            label: "main",
            insertText: "if __name__ == \"__main__\":\n    ${1:main()}",
            description: "Main guard"
        )
    ]
    
    // Common module imports
    private let commonModules = [
        "os", "sys", "time", "datetime", "json", "re", "math", "random",
        "collections", "itertools", "functools", "pathlib", "typing",
        "dataclasses", "enum", "asyncio", "threading", "multiprocessing",
        "subprocess", "logging", "argparse", "configparser", "csv",
        "sqlite3", "urllib", "requests", "numpy", "pandas", "matplotlib"
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
        case .import:
            items.append(contentsOf: createImportCompletions(filter: analysisResult.filter))
            
        case .keyword:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            
        case .type:
            items.append(contentsOf: createTypeCompletions(filter: analysisResult.filter))
            
        case .member:
            items.append(contentsOf: createMemberCompletions(for: analysisResult.targetType, filter: analysisResult.filter))
            
        case .general:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createBuiltinFunctionCompletions(filter: analysisResult.filter))
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
            context: context,
            isIncomplete: false,
            processingTime: processingTime
        )
    }
    
    // MARK: - Context Analysis
    
    private func analyzeContext(_ context: CompletionContextModel) -> ContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = String(context.text.prefix(context.cursorPosition))
        
        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)
        
        // Check for import statements
        if lineText.hasPrefix("import ") || lineText.hasPrefix("from ") {
            return ContextAnalysisResult(type: .import, filter: filter)
        }
        
        // Check for member access
        if beforeCursor.hasSuffix(".") {
            let targetType = extractTargetType(from: beforeCursor)
            return ContextAnalysisResult(type: .member, filter: "", targetType: targetType)
        }
        
        // Check for function definition
        if lineText.contains("def ") && lineText.contains("(") && !lineText.contains("):") {
            return ContextAnalysisResult(type: .parameter, filter: filter)
        }
        
        // Check for type hints
        if lineText.contains(": ") && !lineText.contains("=") {
            return ContextAnalysisResult(type: .type, filter: filter)
        }
        
        return ContextAnalysisResult(type: .general, filter: filter)
    }
    
    private func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted)
        return components.last ?? ""
    }
    
    private func extractTargetType(from text: String) -> String? {
        // Simple heuristic to extract the object before the dot
        let pattern = #"(\w+)\s*\.\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let range = Range(match.range(at: 1), in: text)!
            return String(text[range])
        }
        return nil
    }
    
    // MARK: - Completion Creation Methods
    
    private func createKeywordCompletions(filter: String) -> [CompletionItemModel] {
        keywords
            .filter { keyword in
                filter.isEmpty || keyword.localizedCaseInsensitiveContains(filter)
            }
            .map { keyword in
                CompletionItemModel(
                    label: keyword,
                    insertText: keyword,
                    kind: .keyword,
                    detail: "Python keyword",
                    priority: 80,
                    preselect: keyword == filter
                )
            }
    }
    
    private func createTypeCompletions(filter: String) -> [CompletionItemModel] {
        builtinTypes
            .filter { type in
                filter.isEmpty || type.localizedCaseInsensitiveContains(filter)
            }
            .map { type in
                CompletionItemModel(
                    label: type,
                    insertText: type,
                    kind: .class,
                    detail: "Python built-in type",
                    priority: 70
                )
            }
    }
    
    private func createBuiltinFunctionCompletions(filter: String) -> [CompletionItemModel] {
        builtinFunctions
            .filter { function in
                filter.isEmpty || function.localizedCaseInsensitiveContains(filter)
            }
            .map { function in
                CompletionItemModel(
                    label: function,
                    insertText: "\(function)($0)",
                    kind: .function,
                    detail: "Python built-in function",
                    priority: 75
                )
            }
    }
    
    private func createLiteralCompletions(filter: String) -> [CompletionItemModel] {
        literals
            .filter { literal in
                filter.isEmpty || literal.localizedCaseInsensitiveContains(filter)
            }
            .map { literal in
                let kind: CompletionItemKind = literal.hasPrefix("__") ? .method : .value
                return CompletionItemModel(
                    label: literal,
                    insertText: literal,
                    kind: kind,
                    detail: literal.hasPrefix("__") ? "Python magic method" : "Python literal",
                    priority: 60
                )
            }
    }
    
    private func createImportCompletions(filter: String) -> [CompletionItemModel] {
        commonModules
            .filter { module in
                filter.isEmpty || module.localizedCaseInsensitiveContains(filter)
            }
            .map { module in
                CompletionItemModel(
                    label: module,
                    insertText: module,
                    kind: .module,
                    detail: "Python module",
                    priority: 85
                )
            }
    }
    
    private func createSnippetCompletions(filter: String) -> [CompletionItemModel] {
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
                    priority: 90,
                    snippetSupport: true
                )
            }
    }
    
    private func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel] {
        guard let targetType else { return [] }
        
        // Provide common member completions based on type
        switch targetType.lowercased() {
        case "str", "string":
            return createStringMemberCompletions(filter: filter)
            
        case "list":
            return createListMemberCompletions(filter: filter)
            
        case "dict", "dictionary":
            return createDictMemberCompletions(filter: filter)
            
        case "set":
            return createSetMemberCompletions(filter: filter)
            
        default:
            return createCommonMemberCompletions(filter: filter)
        }
    }
    
    private func createParameterCompletions(filter: String) -> [CompletionItemModel] {
        let commonParameters = ["self", "cls", "args", "kwargs", "key", "value", "index", "item", "data", "result", "error", "callback"]
        
        return commonParameters
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
    
    // MARK: - Type-Specific Members
    
    private func createStringMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("upper()", "method", "Return uppercase string"),
            ("lower()", "method", "Return lowercase string"),
            ("capitalize()", "method", "Return capitalized string"),
            ("title()", "method", "Return title cased string"),
            ("strip()", "method", "Remove leading and trailing whitespace"),
            ("split()", "method", "Split string into list"),
            ("join()", "method", "Join iterable into string"),
            ("replace()", "method", "Replace substring"),
            ("find()", "method", "Find substring position"),
            ("startswith()", "method", "Check if starts with substring"),
            ("endswith()", "method", "Check if ends with substring"),
            ("format()", "method", "Format string"),
            ("encode()", "method", "Encode string to bytes"),
            ("isdigit()", "method", "Check if all characters are digits"),
            ("isalpha()", "method", "Check if all characters are alphabetic")
        ]
        
        return members
            .filter { name, _, _ in
                filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
            }
            .map { name, type, description in
                CompletionItemModel(
                    label: name,
                    insertText: name,
                    kind: type == "method" ? .method : .property,
                    detail: description,
                    priority: 85
                )
            }
    }
    
    private func createListMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("append()", "method", "Add element to end"),
            ("extend()", "method", "Extend list by appending elements"),
            ("insert()", "method", "Insert element at index"),
            ("remove()", "method", "Remove first occurrence of value"),
            ("pop()", "method", "Remove and return element"),
            ("clear()", "method", "Remove all elements"),
            ("index()", "method", "Return index of first occurrence"),
            ("count()", "method", "Count occurrences of value"),
            ("sort()", "method", "Sort list in place"),
            ("reverse()", "method", "Reverse list in place"),
            ("copy()", "method", "Return shallow copy")
        ]
        
        return members
            .filter { name, _, _ in
                filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
            }
            .map { name, type, description in
                CompletionItemModel(
                    label: name,
                    insertText: name,
                    kind: type == "method" ? .method : .property,
                    detail: description,
                    priority: 85
                )
            }
    }
    
    private func createDictMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("get()", "method", "Get value for key with default"),
            ("keys()", "method", "Return dict keys"),
            ("values()", "method", "Return dict values"),
            ("items()", "method", "Return dict items"),
            ("update()", "method", "Update dict with key-value pairs"),
            ("pop()", "method", "Remove and return value for key"),
            ("popitem()", "method", "Remove and return last item"),
            ("clear()", "method", "Remove all items"),
            ("copy()", "method", "Return shallow copy"),
            ("setdefault()", "method", "Set default value for key")
        ]
        
        return members
            .filter { name, _, _ in
                filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
            }
            .map { name, type, description in
                CompletionItemModel(
                    label: name,
                    insertText: name,
                    kind: type == "method" ? .method : .property,
                    detail: description,
                    priority: 85
                )
            }
    }
    
    private func createSetMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("add()", "method", "Add element to set"),
            ("remove()", "method", "Remove element (raises error if not found)"),
            ("discard()", "method", "Remove element (no error if not found)"),
            ("pop()", "method", "Remove and return arbitrary element"),
            ("clear()", "method", "Remove all elements"),
            ("union()", "method", "Return union of sets"),
            ("intersection()", "method", "Return intersection of sets"),
            ("difference()", "method", "Return difference of sets"),
            ("symmetric_difference()", "method", "Return symmetric difference"),
            ("issubset()", "method", "Check if subset"),
            ("issuperset()", "method", "Check if superset"),
            ("copy()", "method", "Return shallow copy")
        ]
        
        return members
            .filter { name, _, _ in
                filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
            }
            .map { name, type, description in
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
            ("__str__()", "method", "String representation"),
            ("__repr__()", "method", "Developer representation"),
            ("__len__()", "method", "Length of object"),
            ("__class__", "property", "Class of instance"),
            ("__dict__", "property", "Instance dictionary"),
            ("__doc__", "property", "Documentation string")
        ]
        
        return members
            .filter { name, _, _ in
                filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
            }
            .map { name, type, description in
                CompletionItemModel(
                    label: name,
                    insertText: name,
                    kind: type == "method" ? .method : .property,
                    detail: description,
                    priority: 40
                )
            }
    }
}

// MARK: - Supporting Types

private struct ContextAnalysisResult {
    enum CompletionType {
        case keyword    // Keywords like def, class, etc.
        case type      // Type names
        case member    // Member access after dot
        case general   // General context
        case parameter // Function parameters
        case `import`  // Import statements
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
