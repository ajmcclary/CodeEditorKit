import Foundation

// MARK: - Python Completion Provider

/// Built-in completion provider for Python language
@MainActor
public final class PythonCompletionProvider: BaseCompletionProvider {
    // MARK: - Language Elements

    override public var keywords: [String] {
        [
            "def", "class", "if", "elif", "else", "for", "while", "try", "except",
            "finally", "with", "as", "import", "from", "return", "yield", "break",
            "continue", "pass", "global", "nonlocal", "lambda", "and", "or", "not",
            "in", "is", "del", "async", "await", "assert", "raise", "match", "case"
        ]
    }

    override public var types: [String] {
        [
            "int", "float", "str", "bool", "list", "tuple", "dict", "set", "frozenset",
            "bytes", "bytearray", "memoryview", "range", "complex", "type", "object",
            "property", "staticmethod", "classmethod", "super"
        ]
    }

    override public var functions: [String] {
        [
            "print", "input", "len", "range", "enumerate", "zip", "map", "filter",
            "sorted", "reversed", "sum", "min", "max", "any", "all", "abs", "round",
            "pow", "divmod", "isinstance", "issubclass", "hasattr", "getattr", "setattr",
            "delattr", "open", "format", "chr", "ord", "bin", "hex", "oct", "eval",
            "exec", "compile", "globals", "locals", "vars", "dir", "help", "id",
            "hash", "iter", "next", "callable", "repr", "ascii", "breakpoint"
        ]
    }

    override public var literals: [String] {
        [
            "True", "False", "None", "self", "__name__", "__main__", "__file__",
            "__doc__", "__dict__", "__class__", "__init__", "__new__", "__del__",
            "__str__", "__repr__", "__eq__", "__ne__", "__lt__", "__le__", "__gt__",
            "__ge__", "__hash__", "__bool__", "__len__", "__getitem__", "__setitem__",
            "__delitem__", "__iter__", "__next__", "__contains__", "__add__", "__sub__",
            "__mul__", "__truediv__", "__floordiv__", "__mod__", "__pow__", "__and__",
            "__or__", "__xor__", "__lshift__", "__rshift__", "__neg__", "__pos__",
            "__abs__", "__invert__", "__enter__", "__exit__", "__call__"
        ]
    }

    override public var snippets: [SnippetTemplate] {
        [
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
    }

    // Common module imports
    private let commonModules = [
        "os", "sys", "time", "datetime", "json", "re", "math", "random",
        "collections", "itertools", "functools", "pathlib", "typing",
        "dataclasses", "enum", "asyncio", "threading", "multiprocessing",
        "subprocess", "logging", "argparse", "configparser", "csv",
        "sqlite3", "urllib", "requests", "numpy", "pandas", "matplotlib"
    ]

    // MARK: - Initialization

    public init() {
        super.init(
            id: "python-builtin",
            supportedLanguages: [.python],
            triggerCharacters: [".", "(", "[", " ", ":"],
            supportsSnippets: true
        )
    }

    // MARK: - Context Analysis Override

    override public func analyzeContext(_ context: CompletionContextModel) -> ContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = String(context.text.prefix(context.cursorPosition))

        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)

        // Check for import statements - treat as keyword context
        if lineText.hasPrefix("import ") || lineText.hasPrefix("from ") {
            // We'll handle imports in createFunctionCompletions by including modules
            return ContextAnalysisResult(type: .function, filter: filter)
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

    // MARK: - Override Function Completions

    override public func createFunctionCompletions(filter: String) -> [CompletionItemModel] {
        let lineText = extractCurrentWord(from: filter) // This is a simplification

        // Check if we're in an import context
        if lineText.contains("import") || lineText.contains("from") {
            return createImportCompletions(filter: filter)
        }

        // Otherwise return Python built-in functions
        return createBuiltinFunctionCompletions(filter: filter)
    }

    override public func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted)
        return components.last ?? ""
    }

    override public func extractTargetType(from text: String) -> String? {
        // Simple heuristic to extract the object before the dot
        let pattern = #"(\w+)\s*\.\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }

    // MARK: - Python-Specific Completion Methods

    private func createBuiltinFunctionCompletions(filter: String) -> [CompletionItemModel] {
        functions
            .filter { function in
                filter.isEmpty || function.localizedCaseInsensitiveContains(filter)
            }
            .map { function in
                CompletionItemModel(
                    label: function,
                    insertText: "\(function)()",
                    kind: .function,
                    detail: "Python built-in function",
                    sortText: "d_\(function)",
                    priority: 75
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
                    sortText: "a_\(module)",
                    priority: 85
                )
            }
    }

    // MARK: - Member Completions Override

    override public func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel] {
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

    // MARK: - Parameter Completions Override

    override public func createParameterCompletions(filter: String) -> [CompletionItemModel] {
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
                    sortText: "f_\(param)",
                    priority: 50
                )
            }
    }

    // MARK: - Type-Specific Members

    private func createStringMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members: [(name: String, type: String, description: String)] = [
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

        return filteredMemberCompletions(from: members, filter: filter)
    }

    private func createListMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members: [(name: String, type: String, description: String)] = [
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

        return filteredMemberCompletions(from: members, filter: filter)
    }

    private func createDictMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members: [(name: String, type: String, description: String)] = [
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

        return filteredMemberCompletions(from: members, filter: filter)
    }

    private func createSetMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members: [(name: String, type: String, description: String)] = [
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

        return filteredMemberCompletions(from: members, filter: filter)
    }

    private func createCommonMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members: [(name: String, type: String, description: String)] = [
            ("__str__()", "method", "String representation"),
            ("__repr__()", "method", "Developer representation"),
            ("__len__()", "method", "Length of object"),
            ("__class__", "property", "Class of instance"),
            ("__dict__", "property", "Instance dictionary"),
            ("__doc__", "property", "Documentation string")
        ]

        return filteredMemberCompletions(from: members, filter: filter, sortPrefix: "c_", priority: 40)
    }
}
