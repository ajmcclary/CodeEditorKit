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
        // Use SharedContextAnalyzer for standardized context analysis
        SharedContextAnalyzer.analyzeContext(context, for: .python).toContextAnalysisResult()
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

    override public func extractTargetType(from text: String) -> String? {
        CompletionParsingHelpers.extractTargetForDotNotation(from: text)
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

    /// Delegate to PythonMemberCompletions for type-specific member suggestions
    private let memberCompletions = PythonMemberCompletions()

    override public func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel] {
        memberCompletions.createMemberCompletions(for: targetType, filter: filter)
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
}
