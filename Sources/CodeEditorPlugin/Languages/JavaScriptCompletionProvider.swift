import Foundation

// MARK: - JavaScript Completion Provider

/// Built-in completion provider for JavaScript language
@MainActor
public final class JavaScriptCompletionProvider: CompletionProvider {
    public let id = "javascript-builtin"
    public let supportedLanguages: [Language] = [.javascript]
    public let triggerCharacters = [".", "(", "[", "{", " ", ":"]
    public let supportsSnippets = true
    
    // JavaScript language elements
    private let keywords = [
        "const", "let", "var", "function", "class", "if", "else", "for", "while",
        "do", "switch", "case", "default", "break", "continue", "return", "try",
        "catch", "finally", "throw", "async", "await", "import", "export", "from",
        "as", "typeof", "instanceof", "new", "this", "super", "static", "extends",
        "constructor", "get", "set", "of", "in", "delete", "void", "yield",
        "debugger", "with"
    ]
    
    private let builtinObjects = [
        "Object", "Array", "String", "Number", "Boolean", "Function", "Symbol",
        "Date", "RegExp", "Error", "Math", "JSON", "console", "Promise", "Map",
        "Set", "WeakMap", "WeakSet", "Proxy", "Reflect", "Intl", "BigInt",
        "ArrayBuffer", "SharedArrayBuffer", "DataView", "Float32Array", "Float64Array",
        "Int8Array", "Int16Array", "Int32Array", "Uint8Array", "Uint16Array",
        "Uint32Array", "Uint8ClampedArray"
    ]
    
    private let globalFunctions = [
        "parseInt", "parseFloat", "isNaN", "isFinite", "encodeURI", "decodeURI",
        "encodeURIComponent", "decodeURIComponent", "eval", "setTimeout", "clearTimeout",
        "setInterval", "clearInterval", "setImmediate", "clearImmediate", "requestAnimationFrame",
        "cancelAnimationFrame", "fetch", "alert", "confirm", "prompt"
    ]
    
    private let literals = [
        "true", "false", "null", "undefined", "NaN", "Infinity", "globalThis",
        "window", "document", "location", "navigator", "history"
    ]
    
    private let commonModules = [
        "react", "vue", "angular", "express", "lodash", "axios", "moment",
        "jquery", "typescript", "webpack", "babel", "eslint", "jest", "mocha",
        "chai", "sinon", "nodemon", "dotenv", "cors", "bcrypt", "jsonwebtoken",
        "mongoose", "sequelize", "graphql", "apollo", "redux", "mobx", "rxjs"
    ]
    
    private let snippets: [SnippetTemplate] = [
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
    
    private func analyzeContext(_ context: CompletionContextModel) -> ContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = String(context.text.prefix(context.cursorPosition))
        
        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)
        
        // Check for import/require statements
        if lineText.hasPrefix("import ") || lineText.contains("from '") || lineText.contains("require(") {
            return ContextAnalysisResult(type: .import, filter: filter)
        }
        
        // Check for member access
        if beforeCursor.hasSuffix(".") {
            let targetType = extractTargetType(from: beforeCursor)
            return ContextAnalysisResult(type: .member, filter: "", targetType: targetType)
        }
        
        // Check for function definition
        if lineText.contains("function ") && lineText.contains("(") && !lineText.contains(")") {
            return ContextAnalysisResult(type: .parameter, filter: filter)
        }
        
        // Check for object property context
        if beforeCursor.hasSuffix(":") || lineText.contains("new ") {
            return ContextAnalysisResult(type: .type, filter: filter)
        }
        
        return ContextAnalysisResult(type: .general, filter: filter)
    }
    
    private func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$")).inverted)
        return components.last ?? ""
    }
    
    private func extractTargetType(from text: String) -> String? {
        // Extract the object before the dot
        let pattern = #"([\w$]+)\s*\.\s*$"#
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
                    detail: "JavaScript keyword",
                    priority: 80,
                    preselect: keyword == filter
                )
            }
    }
    
    private func createObjectCompletions(filter: String) -> [CompletionItemModel] {
        builtinObjects
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
        globalFunctions
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
    
    private func createLiteralCompletions(filter: String) -> [CompletionItemModel] {
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
        case "console":
            return createConsoleMemberCompletions(filter: filter)
            
        case "array":
            return createArrayMemberCompletions(filter: filter)
            
        case "string":
            return createStringMemberCompletions(filter: filter)
            
        case "object":
            return createObjectMemberCompletions(filter: filter)
            
        case "promise":
            return createPromiseMemberCompletions(filter: filter)
            
        case "math":
            return createMathMemberCompletions(filter: filter)
            
        default:
            return createCommonMemberCompletions(filter: filter)
        }
    }
    
    private func createParameterCompletions(filter: String) -> [CompletionItemModel] {
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
    
    // MARK: - Type-Specific Members
    
    private func createConsoleMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("log()", "method", "Log message to console"),
            ("error()", "method", "Log error message"),
            ("warn()", "method", "Log warning message"),
            ("info()", "method", "Log info message"),
            ("debug()", "method", "Log debug message"),
            ("table()", "method", "Display data as table"),
            ("time()", "method", "Start timer"),
            ("timeEnd()", "method", "End timer and log time"),
            ("clear()", "method", "Clear console"),
            ("group()", "method", "Create inline group"),
            ("groupEnd()", "method", "End inline group"),
            ("assert()", "method", "Assert condition")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createArrayMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("length", "property", "Number of elements"),
            ("push()", "method", "Add elements to end"),
            ("pop()", "method", "Remove last element"),
            ("shift()", "method", "Remove first element"),
            ("unshift()", "method", "Add elements to beginning"),
            ("slice()", "method", "Extract section of array"),
            ("splice()", "method", "Add/remove elements"),
            ("concat()", "method", "Merge arrays"),
            ("join()", "method", "Join elements into string"),
            ("reverse()", "method", "Reverse array in place"),
            ("sort()", "method", "Sort array in place"),
            ("filter()", "method", "Filter elements"),
            ("map()", "method", "Transform elements"),
            ("reduce()", "method", "Reduce to single value"),
            ("forEach()", "method", "Execute function for each element"),
            ("find()", "method", "Find first matching element"),
            ("findIndex()", "method", "Find first matching index"),
            ("includes()", "method", "Check if includes value"),
            ("indexOf()", "method", "Find index of value"),
            ("every()", "method", "Test if all elements pass"),
            ("some()", "method", "Test if any element passes")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createStringMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("length", "property", "Number of characters"),
            ("charAt()", "method", "Character at index"),
            ("charCodeAt()", "method", "Unicode of character"),
            ("concat()", "method", "Concatenate strings"),
            ("includes()", "method", "Check if contains substring"),
            ("indexOf()", "method", "Find index of substring"),
            ("lastIndexOf()", "method", "Find last index of substring"),
            ("match()", "method", "Match against regex"),
            ("replace()", "method", "Replace substring"),
            ("search()", "method", "Search for match"),
            ("slice()", "method", "Extract section"),
            ("split()", "method", "Split into array"),
            ("substring()", "method", "Extract substring"),
            ("toLowerCase()", "method", "Convert to lowercase"),
            ("toUpperCase()", "method", "Convert to uppercase"),
            ("trim()", "method", "Remove whitespace"),
            ("trimStart()", "method", "Remove leading whitespace"),
            ("trimEnd()", "method", "Remove trailing whitespace"),
            ("padStart()", "method", "Pad start of string"),
            ("padEnd()", "method", "Pad end of string"),
            ("repeat()", "method", "Repeat string")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createObjectMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("assign()", "method", "Copy properties"),
            ("create()", "method", "Create new object"),
            ("defineProperty()", "method", "Define property"),
            ("defineProperties()", "method", "Define properties"),
            ("entries()", "method", "Get [key, value] pairs"),
            ("freeze()", "method", "Freeze object"),
            ("fromEntries()", "method", "Create from entries"),
            ("getOwnPropertyDescriptor()", "method", "Get property descriptor"),
            ("getOwnPropertyNames()", "method", "Get property names"),
            ("getPrototypeOf()", "method", "Get prototype"),
            ("hasOwnProperty()", "method", "Check own property"),
            ("is()", "method", "Check if same value"),
            ("isExtensible()", "method", "Check if extensible"),
            ("isFrozen()", "method", "Check if frozen"),
            ("isSealed()", "method", "Check if sealed"),
            ("keys()", "method", "Get keys"),
            ("seal()", "method", "Seal object"),
            ("values()", "method", "Get values")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createPromiseMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("then()", "method", "Handle resolved value"),
            ("catch()", "method", "Handle rejection"),
            ("finally()", "method", "Execute after settlement"),
            ("all()", "method", "Wait for all promises"),
            ("allSettled()", "method", "Wait for all settlements"),
            ("any()", "method", "First fulfilled promise"),
            ("race()", "method", "First settled promise"),
            ("reject()", "method", "Create rejected promise"),
            ("resolve()", "method", "Create resolved promise")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createMathMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("PI", "property", "Pi constant"),
            ("E", "property", "Euler's constant"),
            ("abs()", "method", "Absolute value"),
            ("ceil()", "method", "Round up"),
            ("floor()", "method", "Round down"),
            ("round()", "method", "Round to nearest"),
            ("max()", "method", "Maximum value"),
            ("min()", "method", "Minimum value"),
            ("pow()", "method", "Power"),
            ("sqrt()", "method", "Square root"),
            ("random()", "method", "Random number"),
            ("sin()", "method", "Sine"),
            ("cos()", "method", "Cosine"),
            ("tan()", "method", "Tangent"),
            ("log()", "method", "Natural logarithm")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createCommonMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("toString()", "method", "Convert to string"),
            ("valueOf()", "method", "Primitive value"),
            ("constructor", "property", "Constructor function"),
            ("hasOwnProperty()", "method", "Check own property")
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
                    kind: type == "method" ? .method : .property,
                    detail: description,
                    priority: 85
                )
            }
    }
}

// MARK: - Supporting Types

private struct ContextAnalysisResult {
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

private struct SnippetTemplate {
    let label: String
    let insertText: String
    let description: String
}
