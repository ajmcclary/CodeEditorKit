import Foundation

// MARK: - C/C++ Completion Provider

/// Built-in completion provider for C and C++ languages
@MainActor
public final class CCompletionProvider: BaseCompletionProvider {
    // C keywords
    private let cKeywords = [
        "auto", "break", "case", "char", "const", "continue", "default", "do",
        "double", "else", "enum", "extern", "float", "for", "goto", "if",
        "inline", "int", "long", "register", "restrict", "return", "short",
        "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
        "unsigned", "void", "volatile", "while", "_Bool", "_Complex", "_Imaginary"
    ]

    // Additional C++ keywords
    private let cppKeywords = [
        "alignas", "alignof", "and", "and_eq", "asm", "bitand", "bitor", "bool",
        "catch", "class", "compl", "concept", "const_cast", "consteval", "constexpr",
        "constinit", "co_await", "co_return", "co_yield", "decltype", "delete",
        "dynamic_cast", "explicit", "export", "false", "friend", "mutable",
        "namespace", "new", "noexcept", "not", "not_eq", "nullptr", "operator",
        "or", "or_eq", "private", "protected", "public", "reinterpret_cast",
        "requires", "static_assert", "static_cast", "template", "this", "thread_local",
        "throw", "true", "try", "typeid", "typename", "using", "virtual", "wchar_t",
        "xor", "xor_eq"
    ]

    // Standard library types
    private let stdTypes = [
        // C types
        "size_t", "ptrdiff_t", "time_t", "FILE", "NULL",
        // C++ types
        "string", "vector", "map", "unordered_map", "set", "unordered_set",
        "list", "deque", "queue", "stack", "priority_queue", "pair",
        "tuple", "array", "bitset", "unique_ptr", "shared_ptr", "weak_ptr",
        "optional", "variant", "any", "function", "thread", "mutex",
        "condition_variable", "atomic", "future", "promise"
    ]

    // Standard library headers
    private let headers = [
        // C headers
        "stdio.h", "stdlib.h", "string.h", "math.h", "time.h", "assert.h",
        "ctype.h", "errno.h", "limits.h", "locale.h", "setjmp.h", "signal.h",
        "stdarg.h", "stddef.h", "stdint.h", "stdbool.h",
        // C++ headers
        "iostream", "string", "vector", "map", "set", "algorithm", "memory",
        "utility", "functional", "thread", "mutex", "condition_variable",
        "future", "chrono", "random", "regex", "filesystem", "optional",
        "variant", "any", "type_traits", "numeric", "iterator", "ranges"
    ]

    // Preprocessor directives
    private let preprocessor = [
        "#include", "#define", "#undef", "#ifdef", "#ifndef", "#if", "#else",
        "#elif", "#endif", "#error", "#pragma", "#warning", "#line"
    ]

    override public var snippets: [SnippetTemplate] {
        [
        // C snippets
        SnippetTemplate(
            label: "main",
            insertText: "int main(int argc, char *argv[]) {\n    ${1:// code}\n    return 0;\n}",
            description: "Main function"
        ),
        SnippetTemplate(
            label: "func",
            insertText: "${1:void} ${2:function_name}(${3:parameters}) {\n    ${4:// body}\n}",
            description: "Function declaration"
        ),
        SnippetTemplate(
            label: "struct",
            insertText: "typedef struct {\n    ${1:// members}\n} ${2:StructName};",
            description: "Struct declaration"
        ),
        SnippetTemplate(
            label: "enum",
            insertText: "typedef enum {\n    ${1:VALUE1},\n    ${2:VALUE2}\n} ${3:EnumName};",
            description: "Enum declaration"
        ),
        SnippetTemplate(
            label: "if",
            insertText: "if (${1:condition}) {\n    ${2:// body}\n}",
            description: "If statement"
        ),
        SnippetTemplate(
            label: "for",
            insertText: "for (${1:int i = 0}; ${2:i < n}; ${3:i++}) {\n    ${4:// body}\n}",
            description: "For loop"
        ),
        SnippetTemplate(
            label: "while",
            insertText: "while (${1:condition}) {\n    ${2:// body}\n}",
            description: "While loop"
        ),
        SnippetTemplate(
            label: "switch",
            insertText: "switch (${1:expression}) {\n    case ${2:value1}:\n        ${3:// code}\n        break;\n    default:\n        ${4:// default code}\n        break;\n}",
            description: "Switch statement"
        ),
        SnippetTemplate(
            label: "malloc",
            insertText: "${1:type} *${2:ptr} = (${1:type} *)malloc(${3:size} * sizeof(${1:type}));",
            description: "Dynamic memory allocation"
        ),
        SnippetTemplate(
            label: "include",
            insertText: "#include <${1:header}>",
            description: "Include header"
        ),
        SnippetTemplate(
            label: "include local",
            insertText: "#include \"${1:header}\"",
            description: "Include local header"
        ),
        SnippetTemplate(
            label: "define",
            insertText: "#define ${1:MACRO} ${2:value}",
            description: "Define macro"
        ),
        // C++ specific snippets
        SnippetTemplate(
            label: "class",
            insertText: "class ${1:ClassName} {\npublic:\n    ${2:// public members}\nprivate:\n    ${3:// private members}\n};",
            description: "Class declaration"
        ),
        SnippetTemplate(
            label: "template",
            insertText: "template<${1:typename T}>\n${2:void} ${3:function}(${4:T param}) {\n    ${5:// body}\n}",
            description: "Template function"
        ),
        SnippetTemplate(
            label: "namespace",
            insertText: "namespace ${1:name} {\n    ${2:// content}\n}",
            description: "Namespace declaration"
        ),
        SnippetTemplate(
            label: "try",
            insertText: "try {\n    ${1:// code}\n} catch (${2:const std::exception& e}) {\n    ${3:// handle exception}\n}",
            description: "Try-catch block"
        ),
        SnippetTemplate(
            label: "lambda",
            insertText: "[${1:capture}](${2:params}) ${3:-> return_type} {\n    ${4:// body}\n}",
            description: "Lambda expression"
        ),
        SnippetTemplate(
            label: "unique_ptr",
            insertText: "std::unique_ptr<${1:Type}> ${2:ptr} = std::make_unique<${1:Type}>(${3:args});",
            description: "Unique pointer"
        ),
        SnippetTemplate(
            label: "shared_ptr",
            insertText: "std::shared_ptr<${1:Type}> ${2:ptr} = std::make_shared<${1:Type}>(${3:args});",
            description: "Shared pointer"
        ),
        SnippetTemplate(
            label: "vector",
            insertText: "std::vector<${1:Type}> ${2:vec};",
            description: "Vector declaration"
        )
        ]
    }

    private let isCpp: Bool

    public init() {
        self.isCpp = false // Will be determined by context
        super.init(
            id: "c-cpp-builtin",
            supportedLanguages: [.c, .cpp],
            triggerCharacters: [".", "->", "::", "(", "<", " ", "#"],
            supportsSnippets: true
        )
    }

    // MARK: - CompletionProvider Implementation

    override public func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()

        // Determine if we're in C++ mode
        let isCurrentlyCpp = context.language == .cpp

        // Analyze context to determine what kind of completions to provide
        let analysisResult = analyzeCContext(context)
        var items: [CompletionItemModel] = []

        // Add appropriate completions based on context
        switch analysisResult.type {
        case .preprocessor:
            items.append(contentsOf: createPreprocessorCompletions(filter: analysisResult.filter))

        case .include:
            items.append(contentsOf: createIncludeCompletions(filter: analysisResult.filter, isCpp: isCurrentlyCpp))

        case .keyword:
            items.append(contentsOf: createCKeywordCompletions(filter: analysisResult.filter, isCpp: isCurrentlyCpp))

        case .type:
            items.append(contentsOf: createCTypeCompletions(filter: analysisResult.filter, isCpp: isCurrentlyCpp))

        case .member:
            items.append(contentsOf: createMemberCompletions(for: analysisResult.targetType, filter: analysisResult.filter, isCpp: isCurrentlyCpp))

        case .namespace:
            items.append(contentsOf: createNamespaceCompletions(filter: analysisResult.filter))

        case .general:
            items.append(contentsOf: createCKeywordCompletions(filter: analysisResult.filter, isCpp: isCurrentlyCpp))
            items.append(contentsOf: createCTypeCompletions(filter: analysisResult.filter, isCpp: isCurrentlyCpp))
            if supportsSnippets {
                items.append(contentsOf: createCSnippetCompletions(filter: analysisResult.filter, isCpp: isCurrentlyCpp))
            }
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

    private func analyzeCContext(_ context: CompletionContextModel) -> CContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = String(context.text.prefix(context.cursorPosition))

        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)

        // Check for preprocessor directives
        if lineText.hasPrefix("#") {
            if lineText.hasPrefix("#include") {
                return CContextAnalysisResult(type: .include, filter: filter)
            }
            return CContextAnalysisResult(type: .preprocessor, filter: filter)
        }

        // Check for namespace context (C++ only)
        if beforeCursor.hasSuffix("::") {
            let targetNamespace = extractTargetNamespace(from: beforeCursor)
            return CContextAnalysisResult(type: .namespace, filter: "", targetType: targetNamespace)
        }

        // Check for member access
        if beforeCursor.hasSuffix(".") || beforeCursor.hasSuffix("->") {
            let targetType = extractTargetType(from: beforeCursor)
            return CContextAnalysisResult(type: .member, filter: "", targetType: targetType)
        }

        // Check for type context
        if lineText.contains(" ") && !lineText.contains("=") && !lineText.contains("(") {
            // Likely a variable declaration
            return CContextAnalysisResult(type: .type, filter: filter)
        }

        return CContextAnalysisResult(type: .general, filter: filter)
    }

    override public func extractTargetType(from text: String) -> String? {
        CompletionParsingHelpers.extractTargetForDotOrArrowNotation(from: text)
    }

    private func extractTargetNamespace(from text: String) -> String? {
        // Extract the namespace before ::
        let pattern = #"([\w:]+)::\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }

    // MARK: - Completion Creation Methods

    private func createCKeywordCompletions(filter: String, isCpp: Bool) -> [CompletionItemModel] {
        var keywords = cKeywords
        if isCpp {
            keywords += cppKeywords
        }

        return keywords
            .filter { keyword in
                filter.isEmpty || keyword.localizedCaseInsensitiveContains(filter)
            }
            .map { keyword in
                CompletionItemModel(
                    label: keyword,
                    insertText: keyword,
                    kind: .keyword,
                    detail: isCpp ? "C++ keyword" : "C keyword",
                    priority: 80,
                    preselect: keyword == filter
                )
            }
    }

    private func createCTypeCompletions(filter: String, isCpp: Bool) -> [CompletionItemModel] {
        var types = ["int", "char", "float", "double", "void", "long", "short", "unsigned", "signed"]

        if isCpp {
            types += stdTypes
        } else {
            types += ["size_t", "ptrdiff_t", "time_t", "FILE", "NULL"]
        }

        return types
            .filter { type in
                filter.isEmpty || type.localizedCaseInsensitiveContains(filter)
            }
            .map { type in
                let isTemplate = isCpp && ["vector", "map", "unordered_map", "set", "unordered_set", "list", "deque", "queue", "stack", "priority_queue", "pair", "tuple", "array", "unique_ptr", "shared_ptr", "weak_ptr", "optional", "variant"].contains(type)

                return CompletionItemModel(
                    label: type,
                    insertText: isTemplate ? "std::\(type)<$0>" : type,
                    kind: .class,
                    detail: isCpp ? "C++ type" : "C type",
                    priority: 70
                )
            }
    }

    private func createPreprocessorCompletions(filter: String) -> [CompletionItemModel] {
        preprocessor
            .filter { directive in
                filter.isEmpty || directive.localizedCaseInsensitiveContains(filter)
            }
            .map { directive in
                CompletionItemModel(
                    label: directive,
                    insertText: directive + " ",
                    kind: .keyword,
                    detail: "Preprocessor directive",
                    priority: 85
                )
            }
    }

    private func createIncludeCompletions(filter: String, isCpp: Bool) -> [CompletionItemModel] {
        let relevantHeaders = isCpp ? headers.filter { !$0.hasSuffix(".h") || $0 == "math.h" || $0 == "stdio.h" } : headers.filter { $0.hasSuffix(".h") }

        return relevantHeaders
            .filter { header in
                filter.isEmpty || header.localizedCaseInsensitiveContains(filter)
            }
            .map { header in
                let isSystemHeader = !header.contains("/")
                let insertText = isSystemHeader ? "<\(header)>" : "\"\(header)\""

                return CompletionItemModel(
                    label: header,
                    insertText: insertText,
                    kind: .file,
                    detail: isCpp ? "C++ header" : "C header",
                    priority: 85
                )
            }
    }

    private func createCSnippetCompletions(filter: String, isCpp: Bool) -> [CompletionItemModel] {
        let relevantSnippets = isCpp ? snippets : snippets.filter { snippet in
            !["class", "template", "namespace", "try", "lambda", "unique_ptr", "shared_ptr", "vector"].contains(snippet.label)
        }

        return relevantSnippets
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

    private func createMemberCompletions(for targetType: String?, filter: String, isCpp: Bool) -> [CompletionItemModel] {
        guard let targetType else { return [] }

        // Provide common member completions based on type
        if isCpp {
            switch targetType.lowercased() {
            case "string":
                return createStringMemberCompletions(filter: filter)

            case "vector":
                return createVectorMemberCompletions(filter: filter)

            case "map", "unordered_map":
                return createMapMemberCompletions(filter: filter)

            default:
                return createCommonMemberCompletions(filter: filter)
            }
        } else {
            // C struct member suggestions would go here
            return createCommonMemberCompletions(filter: filter)
        }
    }

    private func createNamespaceCompletions(filter: String) -> [CompletionItemModel] {
        let stdMembers = ["cout", "cin", "cerr", "endl", "string", "vector", "map", "set", "sort", "find", "copy", "move", "forward", "make_unique", "make_shared"]

        return stdMembers
            .filter { member in
                filter.isEmpty || member.localizedCaseInsensitiveContains(filter)
            }
            .map { member in
                CompletionItemModel(
                    label: member,
                    insertText: member,
                    kind: .variable,
                    detail: "std namespace member",
                    priority: 85
                )
            }
    }

    // MARK: - Type-Specific Members

    private func createStringMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("length()", "method", "Get string length"),
            ("size()", "method", "Get string size"),
            ("empty()", "method", "Check if empty"),
            ("clear()", "method", "Clear string"),
            ("append()", "method", "Append to string"),
            ("push_back()", "method", "Add character"),
            ("pop_back()", "method", "Remove last character"),
            ("at()", "method", "Access character"),
            ("front()", "method", "First character"),
            ("back()", "method", "Last character"),
            ("c_str()", "method", "Get C string"),
            ("data()", "method", "Get data pointer"),
            ("find()", "method", "Find substring"),
            ("substr()", "method", "Get substring"),
            ("compare()", "method", "Compare strings")
        ]

        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }

    private func createVectorMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("size()", "method", "Get vector size"),
            ("empty()", "method", "Check if empty"),
            ("clear()", "method", "Clear vector"),
            ("push_back()", "method", "Add element"),
            ("pop_back()", "method", "Remove last element"),
            ("front()", "method", "First element"),
            ("back()", "method", "Last element"),
            ("at()", "method", "Access element"),
            ("data()", "method", "Get data pointer"),
            ("begin()", "method", "Begin iterator"),
            ("end()", "method", "End iterator"),
            ("reserve()", "method", "Reserve capacity"),
            ("resize()", "method", "Resize vector"),
            ("capacity()", "method", "Get capacity"),
            ("shrink_to_fit()", "method", "Shrink capacity")
        ]

        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }

    private func createMapMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("size()", "method", "Get map size"),
            ("empty()", "method", "Check if empty"),
            ("clear()", "method", "Clear map"),
            ("insert()", "method", "Insert element"),
            ("erase()", "method", "Erase element"),
            ("find()", "method", "Find element"),
            ("count()", "method", "Count elements"),
            ("at()", "method", "Access element"),
            ("begin()", "method", "Begin iterator"),
            ("end()", "method", "End iterator"),
            ("contains()", "method", "Check if contains key"),
            ("emplace()", "method", "Construct and insert")
        ]

        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }

    private func createCommonMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("size()", "method", "Get size"),
            ("empty()", "method", "Check if empty"),
            ("clear()", "method", "Clear contents"),
            ("begin()", "method", "Begin iterator"),
            ("end()", "method", "End iterator")
        ]

        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
}

// MARK: - Supporting Types

extension CCompletionProvider {
    enum CCompletionType {
        case keyword
        case type
        case preprocessor
        case include
        case member
        case namespace
        case general
    }

    struct CContextAnalysisResult {
        let type: CCompletionType
        let filter: String
        let targetType: String?

        init(type: CCompletionType, filter: String, targetType: String? = nil) {
            self.type = type
            self.filter = filter
            self.targetType = targetType
        }
    }
}
