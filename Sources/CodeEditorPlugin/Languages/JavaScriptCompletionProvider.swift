import Foundation

// MARK: - JavaScript Completion Provider

/// Built-in completion provider for JavaScript language
@MainActor
public final class JavaScriptCompletionProvider: BaseCompletionProvider {
    // MARK: - Language Elements

    override public var keywords: [String] {
        [
            "const", "let", "var", "function", "class", "if", "else", "for", "while",
            "do", "switch", "case", "default", "break", "continue", "return", "try",
            "catch", "finally", "throw", "async", "await", "import", "export", "from",
            "as", "typeof", "instanceof", "new", "this", "super", "static", "extends",
            "constructor", "get", "set", "of", "in", "delete", "void", "yield",
            "debugger", "with"
        ]
    }

    override public var types: [String] {
        [
            "Object", "Array", "String", "Number", "Boolean", "Function", "Symbol",
            "Date", "RegExp", "Error", "Math", "JSON", "console", "Promise", "Map",
            "Set", "WeakMap", "WeakSet", "Proxy", "Reflect", "Intl", "BigInt",
            "ArrayBuffer", "SharedArrayBuffer", "DataView", "Float32Array", "Float64Array",
            "Int8Array", "Int16Array", "Int32Array", "Uint8Array", "Uint16Array",
            "Uint32Array", "Uint8ClampedArray"
        ]
    }

    override public var functions: [String] {
        [
            "parseInt", "parseFloat", "isNaN", "isFinite", "encodeURI", "decodeURI",
            "encodeURIComponent", "decodeURIComponent", "eval", "setTimeout", "clearTimeout",
            "setInterval", "clearInterval", "setImmediate", "clearImmediate", "requestAnimationFrame",
            "cancelAnimationFrame", "fetch", "alert", "confirm", "prompt"
        ]
    }

    override public var literals: [String] {
        [
            "true", "false", "null", "undefined", "NaN", "Infinity", "globalThis",
            "window", "document", "location", "navigator", "history"
        ]
    }

    // Common modules for import completions
    private let commonModules = [
        "react", "vue", "angular", "express", "lodash", "axios", "moment",
        "jquery", "typescript", "webpack", "babel", "eslint", "jest", "mocha",
        "chai", "sinon", "nodemon", "dotenv", "cors", "bcrypt", "jsonwebtoken",
        "mongoose", "sequelize", "graphql", "apollo", "redux", "mobx", "rxjs"
    ]

    override public var snippets: [SnippetTemplate] {
        [
        SnippetTemplate(
            label: "function",
            insertText: "function ${1:name}(${2:params}) {\n    ${3:// body}\n}",
            description: "Function declaration"
        ),
        SnippetTemplate(
            label: "arrow",
            insertText: "const ${1:name} = (${2:params}) => {\n    ${3:// body}\n}",
            description: "Arrow function"
        ),
        SnippetTemplate(
            label: "class",
            insertText: "class ${1:ClassName} {\n    constructor(${2:params}) {\n        ${3:// constructor}\n    }\n}",
            description: "Class declaration"
        ),
        SnippetTemplate(
            label: "if",
            insertText: "if (${1:condition}) {\n    ${2:// body}\n}",
            description: "If statement"
        ),
        SnippetTemplate(
            label: "ifelse",
            insertText: "if (${1:condition}) {\n    ${2:// if body}\n} else {\n    ${3:// else body}\n}",
            description: "If-else statement"
        ),
        SnippetTemplate(
            label: "for",
            insertText: "for (let ${1:i} = 0; ${1:i} < ${2:array}.length; ${1:i}++) {\n    ${3:// body}\n}",
            description: "For loop"
        ),
        SnippetTemplate(
            label: "forof",
            insertText: "for (const ${1:item} of ${2:array}) {\n    ${3:// body}\n}",
            description: "For-of loop"
        ),
        SnippetTemplate(
            label: "forin",
            insertText: "for (const ${1:key} in ${2:object}) {\n    ${3:// body}\n}",
            description: "For-in loop"
        ),
        SnippetTemplate(
            label: "while",
            insertText: "while (${1:condition}) {\n    ${2:// body}\n}",
            description: "While loop"
        ),
        SnippetTemplate(
            label: "try",
            insertText: "try {\n    ${1:// try body}\n} catch (${2:error}) {\n    ${3:// catch body}\n}",
            description: "Try-catch block"
        ),
        SnippetTemplate(
            label: "promise",
            insertText: "new Promise((resolve, reject) => {\n    ${1:// async operation}\n})",
            description: "Promise constructor"
        ),
        SnippetTemplate(
            label: "async",
            insertText: "async function ${1:name}(${2:params}) {\n    ${3:// async body}\n}",
            description: "Async function"
        ),
        SnippetTemplate(
            label: "await",
            insertText: "await ${1:promise}",
            description: "Await expression"
        ),
        SnippetTemplate(
            label: "import",
            insertText: "import ${1:{ name }} from '${2:module}'",
            description: "Import statement"
        ),
        SnippetTemplate(
            label: "export",
            insertText: "export ${1:const} ${2:name} = ${3:value}",
            description: "Export statement"
        ),
        SnippetTemplate(
            label: "console.log",
            insertText: "console.log(${1:message})",
            description: "Console log"
        ),
        SnippetTemplate(
            label: "fetch",
            insertText: "fetch('${1:url}')\n    .then(response => response.json())\n    .then(data => {\n        ${2:// handle data}\n    })\n    .catch(error => {\n        ${3:// handle error}\n    })",
            description: "Fetch API call"
        ),
        SnippetTemplate(
            label: "fetchAsync",
            insertText: "try {\n    const response = await fetch('${1:url}');\n    const data = await response.json();\n    ${2:// handle data}\n} catch (error) {\n    ${3:// handle error}\n}",
            description: "Async fetch call"
        )
        ]
    }

    // MARK: - Initialization

    public init() {
        super.init(
            id: "javascript-builtin",
            supportedLanguages: [.javascript],
            triggerCharacters: [".", "(", "[", "{", " ", ":"],
            supportsSnippets: true
        )
    }

    // MARK: - CompletionProvider Implementation

    override public func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()

        // Analyze context to determine what kind of completions to provide
        let analysisResult = analyzeJavaScriptContext(context)
        var items: [CompletionItemModel] = []

        // Add appropriate completions based on context
        switch analysisResult.type {
        case .import:
            items.append(contentsOf: createImportCompletions(filter: analysisResult.filter))

        case .keyword:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))

        case .type:
            items.append(contentsOf: createObjectCompletions(filter: analysisResult.filter))

        case .member:
            items.append(contentsOf: createMemberCompletions(for: analysisResult.targetType, filter: analysisResult.filter))

        case .general:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createGlobalFunctionCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createObjectCompletions(filter: analysisResult.filter))
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

    private func analyzeJavaScriptContext(_ context: CompletionContextModel) -> JavaScriptContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = String(context.text.prefix(context.cursorPosition))

        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)

        // Check for import/require statements
        if lineText.hasPrefix("import ") || lineText.contains("from '") || lineText.contains("require(") {
            return JavaScriptContextAnalysisResult(type: .import, filter: filter)
        }

        // Check for member access
        if beforeCursor.hasSuffix(".") {
            let targetType = extractTargetType(from: beforeCursor)
            return JavaScriptContextAnalysisResult(type: .member, filter: "", targetType: targetType)
        }

        // Check for function definition
        if lineText.contains("function ") && lineText.contains("(") && !lineText.contains(")") {
            return JavaScriptContextAnalysisResult(type: .parameter, filter: filter)
        }

        // Check for object property context
        if beforeCursor.hasSuffix(":") || lineText.contains("new ") {
            return JavaScriptContextAnalysisResult(type: .type, filter: filter)
        }

        return JavaScriptContextAnalysisResult(type: .general, filter: filter)
    }

    override public func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$")).inverted)
        return components.last ?? ""
    }

    override public func extractTargetType(from text: String) -> String? {
        CompletionParsingHelpers.extractTargetForDotNotation(from: text)
    }

    // MARK: - Completion Creation Methods

    override public func createKeywordCompletions(filter: String) -> [CompletionItemModel] {
        keywords
            .filter { keyword in
                filter.isEmpty || keyword.localizedCaseInsensitiveContains(filter)
            }
            .map { keyword in
                CompletionItemModel(
                    label: keyword,
                    insertText: keyword,
                    kind: .keyword,
                    detail: "JavaScript keyword",
                    priority: 80,
                    preselect: keyword == filter
                )
            }
    }

    private func createObjectCompletions(filter: String) -> [CompletionItemModel] {
        types
            .filter { object in
                filter.isEmpty || object.localizedCaseInsensitiveContains(filter)
            }
            .map { object in
                CompletionItemModel(
                    label: object,
                    insertText: object,
                    kind: .class,
                    detail: "JavaScript built-in object",
                    priority: 70
                )
            }
    }

    private func createGlobalFunctionCompletions(filter: String) -> [CompletionItemModel] {
        functions
            .filter { function in
                filter.isEmpty || function.localizedCaseInsensitiveContains(filter)
            }
            .map { function in
                CompletionItemModel(
                    label: function,
                    insertText: "\(function)($0)",
                    kind: .function,
                    detail: "JavaScript global function",
                    priority: 75
                )
            }
    }

    override public func createLiteralCompletions(filter: String) -> [CompletionItemModel] {
        literals
            .filter { literal in
                filter.isEmpty || literal.localizedCaseInsensitiveContains(filter)
            }
            .map { literal in
                CompletionItemModel(
                    label: literal,
                    insertText: literal,
                    kind: .value,
                    detail: "JavaScript literal/global",
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
                    detail: "JavaScript module",
                    priority: 85
                )
            }
    }

    override public func createSnippetCompletions(filter: String) -> [CompletionItemModel] {
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

    /// Delegate to JavaScriptMemberCompletions for type-specific member suggestions
    private let jsMemberCompletions = JavaScriptMemberCompletions()

    override public func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel] {
        jsMemberCompletions.createMemberCompletions(for: targetType, filter: filter)
    }

    override public func createParameterCompletions(filter: String) -> [CompletionItemModel] {
        let commonParameters = ["event", "error", "data", "result", "callback", "options", "config", "request", "response", "next", "done", "resolve", "reject"]

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

// MARK: - Supporting Types

private struct JavaScriptContextAnalysisResult {
    enum CompletionType {
        case keyword
        case type
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
