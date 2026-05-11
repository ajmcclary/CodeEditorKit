import Foundation

// MARK: - Go Completion Provider

/// Built-in completion provider for Go language
@MainActor
final class GoCompletionProvider: BaseCompletionProvider {
    // MARK: - Language Elements

    override var keywords: [String] {
        [
            "break", "case", "chan", "const", "continue", "default", "defer", "else",
            "fallthrough", "for", "func", "go", "goto", "if", "import", "interface",
            "map", "package", "range", "return", "select", "struct", "switch", "type",
            "var"
        ]
    }

    override var types: [String] {
        [
            "bool", "byte", "complex64", "complex128", "error", "float32", "float64",
            "int", "int8", "int16", "int32", "int64", "rune", "string", "uint",
            "uint8", "uint16", "uint32", "uint64", "uintptr"
        ]
    }

    override var functions: [String] {
        [
            "append", "cap", "close", "complex", "copy", "delete", "imag", "len",
            "make", "new", "panic", "print", "println", "real", "recover"
        ]
    }

    override var literals: [String] {
        ["true", "false", "nil", "iota"]
    }

    // Common packages for import completions
    private let commonPackages = [
        "fmt", "io", "os", "strings", "strconv", "time", "errors", "sync",
        "context", "net/http", "encoding/json", "database/sql", "log",
        "regexp", "sort", "math", "bytes", "bufio", "crypto", "path",
        "filepath", "testing", "flag", "runtime"
    ]

    override var snippets: [SnippetTemplate] {
        [
        SnippetTemplate(
            label: "func",
            insertText: "func ${1:name}(${2:params}) ${3:returnType} {\n    ${4:// body}\n}",
            description: "Function declaration"
        ),
        SnippetTemplate(
            label: "method",
            insertText: "func (${1:receiver} ${2:Type}) ${3:methodName}(${4:params}) ${5:returnType} {\n    ${6:// body}\n}",
            description: "Method declaration"
        ),
        SnippetTemplate(
            label: "struct",
            insertText: "type ${1:Name} struct {\n    ${2:field} ${3:type}\n}",
            description: "Struct declaration"
        ),
        SnippetTemplate(
            label: "interface",
            insertText: "type ${1:Name} interface {\n    ${2:Method}(${3:params}) ${4:returnType}\n}",
            description: "Interface declaration"
        ),
        SnippetTemplate(
            label: "if",
            insertText: "if ${1:condition} {\n    ${2:// body}\n}",
            description: "If statement"
        ),
        SnippetTemplate(
            label: "iferr",
            insertText: "if err != nil {\n    ${1:return err}\n}",
            description: "Error check"
        ),
        SnippetTemplate(
            label: "for",
            insertText: "for ${1:i} := ${2:0}; ${1:i} < ${3:n}; ${1:i}++ {\n    ${4:// body}\n}",
            description: "For loop"
        ),
        SnippetTemplate(
            label: "forrange",
            insertText: "for ${1:index}, ${2:value} := range ${3:slice} {\n    ${4:// body}\n}",
            description: "For range loop"
        ),
        SnippetTemplate(
            label: "switch",
            insertText: "switch ${1:value} {\ncase ${2:case1}:\n    ${3:// body}\ndefault:\n    ${4:// default}\n}",
            description: "Switch statement"
        ),
        SnippetTemplate(
            label: "select",
            insertText: "select {\ncase ${1:msg} := <-${2:channel}:\n    ${3:// handle msg}\ndefault:\n    ${4:// default}\n}",
            description: "Select statement"
        ),
        SnippetTemplate(
            label: "goroutine",
            insertText: "go func() {\n    ${1:// concurrent code}\n}()",
            description: "Goroutine"
        ),
        SnippetTemplate(
            label: "defer",
            insertText: "defer ${1:func()}",
            description: "Defer statement"
        ),
        SnippetTemplate(
            label: "test",
            insertText: "func Test${1:Name}(t *testing.T) {\n    ${2:// test body}\n}",
            description: "Test function"
        ),
        SnippetTemplate(
            label: "benchmark",
            insertText: "func Benchmark${1:Name}(b *testing.B) {\n    for i := 0; i < b.N; i++ {\n        ${2:// benchmark code}\n    }\n}",
            description: "Benchmark function"
        ),
        SnippetTemplate(
            label: "main",
            insertText: "package main\n\nfunc main() {\n    ${1:// main code}\n}",
            description: "Main function"
        ),
        SnippetTemplate(
            label: "init",
            insertText: "func init() {\n    ${1:// initialization}\n}",
            description: "Init function"
        )
        ]
    }

    init() {
        super.init(
            id: "go-builtin",
            supportedLanguages: [.go],
            triggerCharacters: [".", "(", " ", ":"],
            supportsSnippets: true
        )
    }

    // MARK: - Context Analysis Override

    override func analyzeContext(_ context: CompletionContextModel) -> ContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = context.textBeforeCursor

        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)

        // Check for import statements - treat as function context
        if lineText.hasPrefix("import ") {
            return ContextAnalysisResult(type: .function, filter: filter)
        }

        // Check for type context
        if lineText.contains("var ") && lineText.contains(" ") && !lineText.contains("=") {
            return ContextAnalysisResult(type: .type, filter: filter)
        }

        // Check for member access
        if beforeCursor.hasSuffix(".") {
            let targetType = extractTargetType(from: beforeCursor)
            return ContextAnalysisResult(type: .member, filter: "", targetType: targetType)
        }

        // Check for function definition
        if lineText.contains("func ") && lineText.contains("(") && !lineText.contains(")") {
            return ContextAnalysisResult(type: .parameter, filter: filter)
        }

        // Check for function call context
        if beforeCursor.hasSuffix("(") {
            return ContextAnalysisResult(type: .function, filter: filter)
        }

        return ContextAnalysisResult(type: .general, filter: filter)
    }

    override func extractTargetType(from text: String) -> String? {
        CompletionParsingHelpers.extractTargetForDotNotation(from: text)
    }

    // MARK: - Function Completions Override

    override func createFunctionCompletions(filter: String) -> [CompletionItemModel] {
        // Check if we're in import context
        if filter.contains("import") {
            return createImportCompletions(filter: filter)
        }

        // Otherwise return Go built-in functions
        return createBuiltinFunctionCompletions(filter: filter)
    }

    private func createBuiltinFunctionCompletions(filter: String) -> [CompletionItemModel] {
        functions
            .filter { function in
                filter.isEmpty || function.localizedCaseInsensitiveContains(filter)
            }
            .map { function in
                CompletionItemModel(
                    label: function,
                    insertText: "\(function)($0)",
                    kind: .function,
                    detail: "Go built-in function",
                    priority: 75
                )
            }
    }

    override func createLiteralCompletions(filter: String) -> [CompletionItemModel] {
        literals
            .filter { constant in
                filter.isEmpty || constant.localizedCaseInsensitiveContains(filter)
            }
            .map { constant in
                CompletionItemModel(
                    label: constant,
                    insertText: constant,
                    kind: .value,
                    detail: "Go literal",
                    priority: 65
                )
            }
    }

    private func createImportCompletions(filter: String) -> [CompletionItemModel] {
        commonPackages
            .filter { pkg in
                filter.isEmpty || pkg.localizedCaseInsensitiveContains(filter)
            }
            .map { pkg in
                CompletionItemModel(
                    label: pkg,
                    insertText: "\"\(pkg)\"",
                    kind: .module,
                    detail: "Go package",
                    priority: 85
                )
            }
    }

    // MARK: - Member Completions Override

    /// Delegate to GoMemberCompletions for type-specific member suggestions
    private let goMemberCompletions = GoMemberCompletions()

    override func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel] {
        goMemberCompletions.createMemberCompletions(for: targetType, filter: filter)
    }

    // MARK: - Parameter Completions Override

    override func createParameterCompletions(filter: String) -> [CompletionItemModel] {
        let commonParameters = ["ctx context.Context", "err error", "w http.ResponseWriter", "r *http.Request", "data []byte", "id string", "name string", "value interface{}"]

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
}
