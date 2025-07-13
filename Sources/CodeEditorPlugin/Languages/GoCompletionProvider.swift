import Foundation

// MARK: - Go Completion Provider

/// Built-in completion provider for Go language
@MainActor
public final class GoCompletionProvider: CompletionProvider {
    public let id = "go-builtin"
    public let supportedLanguages: [Language] = [.go]
    public let triggerCharacters = [".", "(", "[", " ", ":"]
    public let supportsSnippets = true
    
    // Go language elements
    private let keywords = [
        "break", "case", "chan", "const", "continue", "default", "defer", "else",
        "fallthrough", "for", "func", "go", "goto", "if", "import", "interface",
        "map", "package", "range", "return", "select", "struct", "switch", "type",
        "var"
    ]
    
    private let builtinTypes = [
        "bool", "byte", "complex64", "complex128", "error", "float32", "float64",
        "int", "int8", "int16", "int32", "int64", "rune", "string", "uint",
        "uint8", "uint16", "uint32", "uint64", "uintptr"
    ]
    
    private let builtinFunctions = [
        "append", "cap", "close", "complex", "copy", "delete", "imag", "len",
        "make", "new", "panic", "print", "println", "real", "recover"
    ]
    
    private let constants = [
        "true", "false", "nil", "iota"
    ]
    
    private let commonPackages = [
        "fmt", "io", "os", "strings", "strconv", "time", "errors", "sync",
        "context", "net/http", "encoding/json", "database/sql", "log",
        "regexp", "sort", "math", "bytes", "bufio", "crypto", "path",
        "filepath", "testing", "flag", "runtime"
    ]
    
    private let snippets: [SnippetTemplate] = [
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
            
        case .function:
            items.append(contentsOf: createFunctionCompletions(filter: analysisResult.filter))
            
        case .member:
            items.append(contentsOf: createMemberCompletions(for: analysisResult.targetType, filter: analysisResult.filter))
            
        case .general:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createBuiltinFunctionCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createTypeCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createConstantCompletions(filter: analysisResult.filter))
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
    
    private func analyzeContext(_ context: CompletionContextModel) -> GoContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = String(context.text.prefix(context.cursorPosition))
        
        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)
        
        // Check for import statements
        if lineText.hasPrefix("import ") {
            return GoContextAnalysisResult(type: .import, filter: filter)
        }
        
        // Check for type context
        if lineText.contains("var ") && lineText.contains(" ") && !lineText.contains("=") {
            return GoContextAnalysisResult(type: .type, filter: filter)
        }
        
        // Check for member access
        if beforeCursor.hasSuffix(".") {
            let targetType = extractTargetType(from: beforeCursor)
            return GoContextAnalysisResult(type: .member, filter: "", targetType: targetType)
        }
        
        // Check for function definition
        if lineText.contains("func ") && lineText.contains("(") && !lineText.contains(")") {
            return GoContextAnalysisResult(type: .parameter, filter: filter)
        }
        
        // Check for function call context
        if beforeCursor.hasSuffix("(") {
            return GoContextAnalysisResult(type: .function, filter: filter)
        }
        
        return GoContextAnalysisResult(type: .general, filter: filter)
    }
    
    private func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted)
        return components.last ?? ""
    }
    
    private func extractTargetType(from text: String) -> String? {
        // Extract the object before the dot
        let pattern = #"(\w+)\s*\.\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
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
                    detail: "Go keyword",
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
                    kind: .struct,
                    detail: "Go built-in type",
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
                    detail: "Go built-in function",
                    priority: 75
                )
            }
    }
    
    private func createConstantCompletions(filter: String) -> [CompletionItemModel] {
        constants
            .filter { constant in
                filter.isEmpty || constant.localizedCaseInsensitiveContains(filter)
            }
            .map { constant in
                CompletionItemModel(
                    label: constant,
                    insertText: constant,
                    kind: .constant,
                    detail: "Go constant",
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
        case "fmt":
            return createFmtPackageCompletions(filter: filter)
            
        case "strings":
            return createStringsPackageCompletions(filter: filter)
            
        case "time":
            return createTimePackageCompletions(filter: filter)
            
        case "http":
            return createHttpPackageCompletions(filter: filter)
            
        default:
            return createCommonMemberCompletions(filter: filter)
        }
    }
    
    private func createParameterCompletions(filter: String) -> [CompletionItemModel] {
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
    
    private func createFunctionCompletions(filter: String) -> [CompletionItemModel] {
        // Common function patterns
        let patterns = [
            ("error", "Handle error"),
            ("context.Context", "Context parameter"),
            ("string, error", "String with error"),
            ("[]byte, error", "Bytes with error"),
            ("int, error", "Int with error"),
            ("bool", "Boolean return")
        ]
        
        return patterns
            .filter { pattern, _ in
                filter.isEmpty || pattern.localizedCaseInsensitiveContains(filter)
            }
            .map { pattern, description in
                CompletionItemModel(
                    label: pattern,
                    insertText: pattern,
                    kind: .typeParameter,
                    detail: description,
                    priority: 60
                )
            }
    }
    
    // MARK: - Package-Specific Members
    
    private func createFmtPackageCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("Println()", "method", "Print with newline"),
            ("Printf()", "method", "Formatted print"),
            ("Sprintf()", "method", "Format string"),
            ("Print()", "method", "Print values"),
            ("Errorf()", "method", "Format error"),
            ("Fprintf()", "method", "Format to writer"),
            ("Scan()", "method", "Scan input"),
            ("Scanf()", "method", "Scan formatted"),
            ("Fscanf()", "method", "Scan from reader")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createStringsPackageCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("Contains()", "method", "Check substring"),
            ("HasPrefix()", "method", "Check prefix"),
            ("HasSuffix()", "method", "Check suffix"),
            ("Join()", "method", "Join strings"),
            ("Split()", "method", "Split string"),
            ("ToLower()", "method", "Convert to lowercase"),
            ("ToUpper()", "method", "Convert to uppercase"),
            ("Trim()", "method", "Trim whitespace"),
            ("Replace()", "method", "Replace substring"),
            ("Fields()", "method", "Split into fields")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createTimePackageCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("Now()", "method", "Current time"),
            ("Sleep()", "method", "Sleep duration"),
            ("Since()", "method", "Time since"),
            ("Until()", "method", "Time until"),
            ("Parse()", "method", "Parse time"),
            ("Duration", "type", "Duration type"),
            ("Time", "type", "Time type"),
            ("Second", "constant", "Second duration"),
            ("Minute", "constant", "Minute duration"),
            ("Hour", "constant", "Hour duration")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createHttpPackageCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("Get()", "method", "HTTP GET request"),
            ("Post()", "method", "HTTP POST request"),
            ("ListenAndServe()", "method", "Start HTTP server"),
            ("HandleFunc()", "method", "Register handler"),
            ("NewRequest()", "method", "Create request"),
            ("StatusOK", "constant", "200 status"),
            ("StatusNotFound", "constant", "404 status"),
            ("MethodGet", "constant", "GET method"),
            ("MethodPost", "constant", "POST method")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createCommonMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("String()", "method", "String representation"),
            ("Error()", "method", "Error string"),
            ("Close()", "method", "Close resource"),
            ("Read()", "method", "Read data"),
            ("Write()", "method", "Write data")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createMemberItems(from members: [(String, String, String)], filter: String) -> [CompletionItemModel] {
        members
            .filter { name, _, _ in
                filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
            }
            .map { name, type, description in
                CompletionItemModel(
                    label: name,
                    insertText: name,
                    kind: type == "method" ? .method : (type == "type" ? .struct : (type == "constant" ? .constant : .property)),
                    detail: description,
                    priority: 85
                )
            }
    }
}

// MARK: - Supporting Types

private struct GoContextAnalysisResult {
    enum CompletionType {
        case keyword
        case type
        case function
        case member
        case general
        case parameter
        case `import`
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
