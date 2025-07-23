import Foundation

// MARK: - TypeScript Completion Provider

/// Built-in completion provider for TypeScript language
@MainActor
public final class TypeScriptCompletionProvider: BaseCompletionProvider {
    // TypeScript extends JavaScript, so include JS keywords plus TS-specific ones
    override public var keywords: [String] {
        [
        // JavaScript keywords
        "const", "let", "var", "function", "class", "if", "else", "for", "while",
        "do", "switch", "case", "default", "break", "continue", "return", "try",
        "catch", "finally", "throw", "async", "await", "import", "export", "from",
        "as", "typeof", "instanceof", "new", "this", "super", "static", "extends",
        "constructor", "get", "set", "of", "in", "delete", "void", "yield",
        "debugger", "with",
        // TypeScript-specific keywords
        "interface", "type", "enum", "namespace", "module", "declare", "abstract",
        "implements", "private", "protected", "public", "readonly", "override",
        "keyof", "infer", "is", "asserts", "any", "unknown", "never", "object",
        "string", "number", "boolean", "symbol", "bigint", "undefined", "null"
        ]
    }

    override public var types: [String] {
        [
        // Primitive types
        "string", "number", "boolean", "symbol", "bigint", "any", "unknown",
        "never", "void", "undefined", "null", "object",
        // Utility types
        "Partial", "Required", "Readonly", "Record", "Pick", "Omit", "Exclude",
        "Extract", "NonNullable", "Parameters", "ConstructorParameters",
        "ReturnType", "InstanceType", "ThisParameterType", "OmitThisParameter",
        "ThisType", "Uppercase", "Lowercase", "Capitalize", "Uncapitalize",
        // Common built-in types
        "Array", "Promise", "Map", "Set", "WeakMap", "WeakSet", "Date", "RegExp",
        "Error", "Function", "Object", "String", "Number", "Boolean", "Symbol"
        ]
    }

    private let decorators = [
        "@Component", "@Injectable", "@Directive", "@Pipe", "@NgModule",
        "@Input", "@Output", "@ViewChild", "@ContentChild", "@HostListener",
        "@HostBinding", "@Optional", "@Self", "@SkipSelf", "@Host",
        "@deprecated", "@experimental", "@sealed", "@override", "@readonly"
    ]

    override public var snippets: [SnippetTemplate] {
        [
        SnippetTemplate(
            label: "interface",
            insertText: "interface ${1:InterfaceName} {\n    ${2:property}: ${3:type};\n}",
            description: "Interface declaration"
        ),
        SnippetTemplate(
            label: "type",
            insertText: "type ${1:TypeName} = ${2:type};",
            description: "Type alias"
        ),
        SnippetTemplate(
            label: "enum",
            insertText: "enum ${1:EnumName} {\n    ${2:Value1},\n    ${3:Value2}\n}",
            description: "Enum declaration"
        ),
        SnippetTemplate(
            label: "class",
            insertText: "class ${1:ClassName} {\n    constructor(${2:params}) {\n        ${3:// constructor}\n    }\n}",
            description: "Class declaration"
        ),
        SnippetTemplate(
            label: "abstract class",
            insertText: "abstract class ${1:AbstractClassName} {\n    abstract ${2:methodName}(${3:params}): ${4:returnType};\n}",
            description: "Abstract class declaration"
        ),
        SnippetTemplate(
            label: "function",
            insertText: "function ${1:name}(${2:params}: ${3:type}): ${4:returnType} {\n    ${5:// body}\n}",
            description: "Function with types"
        ),
        SnippetTemplate(
            label: "arrow",
            insertText: "const ${1:name} = (${2:params}: ${3:type}): ${4:returnType} => {\n    ${5:// body}\n}",
            description: "Arrow function with types"
        ),
        SnippetTemplate(
            label: "generic function",
            insertText: "function ${1:name}<${2:T}>(${3:param}: ${2:T}): ${4:returnType} {\n    ${5:// body}\n}",
            description: "Generic function"
        ),
        SnippetTemplate(
            label: "generic interface",
            insertText: "interface ${1:InterfaceName}<${2:T}> {\n    ${3:property}: ${2:T};\n}",
            description: "Generic interface"
        ),
        SnippetTemplate(
            label: "namespace",
            insertText: "namespace ${1:NamespaceName} {\n    ${2:// exports}\n}",
            description: "Namespace declaration"
        ),
        SnippetTemplate(
            label: "module",
            insertText: "module ${1:ModuleName} {\n    ${2:// exports}\n}",
            description: "Module declaration"
        ),
        SnippetTemplate(
            label: "type guard",
            insertText: "function ${1:isType}(${2:value}: ${3:any}): ${2:value} is ${4:Type} {\n    ${5:// type guard logic}\n}",
            description: "Type guard function"
        ),
        SnippetTemplate(
            label: "async function",
            insertText: "async function ${1:name}(${2:params}: ${3:type}): Promise<${4:returnType}> {\n    ${5:// async body}\n}",
            description: "Async function with types"
        ),
        SnippetTemplate(
            label: "import type",
            insertText: "import type { ${1:TypeName} } from '${2:module}';",
            description: "Type-only import"
        ),
        SnippetTemplate(
            label: "export interface",
            insertText: "export interface ${1:InterfaceName} {\n    ${2:property}: ${3:type};\n}",
            description: "Export interface"
        ),
        SnippetTemplate(
            label: "mapped type",
            insertText: "type ${1:MappedType} = {\n    [K in keyof ${2:Type}]: ${3:ValueType};\n}",
            description: "Mapped type"
        ),
        SnippetTemplate(
            label: "conditional type",
            insertText: "type ${1:ConditionalType} = ${2:T} extends ${3:U} ? ${4:TrueType} : ${5:FalseType};",
            description: "Conditional type"
        )
        ]
    }

    public init() {
        super.init(
            id: "typescript-builtin",
            supportedLanguages: [.typescript],
            triggerCharacters: [".", "(", "[", "{", " ", ":", "<", ">"],
            supportsSnippets: true
        )
    }

    // MARK: - CompletionProvider Implementation

    override public func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()

        // Analyze context to determine what kind of completions to provide
        let analysisResult = analyzeTypeScriptContext(context)
        var items: [CompletionItemModel] = []

        // Add appropriate completions based on context
        switch analysisResult.type {
        case .type:
            items.append(contentsOf: createTSTypeCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createTypeCompletions(filter: analysisResult.filter))

        case .decorator:
            items.append(contentsOf: createDecoratorCompletions(filter: analysisResult.filter))

        case .import:
            items.append(contentsOf: createImportCompletions(filter: analysisResult.filter))

        case .keyword:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))

        case .member:
            items.append(contentsOf: createMemberCompletions(for: analysisResult.targetType, filter: analysisResult.filter))

        case .generic:
            items.append(contentsOf: createGenericCompletions(filter: analysisResult.filter))

        case .general:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createTypeCompletions(filter: analysisResult.filter))
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

    private func analyzeTypeScriptContext(_ context: CompletionContextModel) -> TypeScriptContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = String(context.text.prefix(context.cursorPosition))

        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)

        // Check for decorator context
        if lineText.hasPrefix("@") || beforeCursor.hasSuffix("@") {
            return TypeScriptContextAnalysisResult(type: .decorator, filter: filter)
        }

        // Check for type context
        if lineText.contains(": ") || lineText.contains("extends ") || lineText.contains("implements ") {
            return TypeScriptContextAnalysisResult(type: .type, filter: filter)
        }

        // Check for generic context
        if beforeCursor.hasSuffix("<") || (beforeCursor.contains("<") && !beforeCursor.contains(">")) {
            return TypeScriptContextAnalysisResult(type: .generic, filter: filter)
        }

        // Check for import/require statements
        if lineText.hasPrefix("import ") || lineText.contains("from '") || lineText.contains("require(") {
            return TypeScriptContextAnalysisResult(type: .import, filter: filter)
        }

        // Check for member access
        if beforeCursor.hasSuffix(".") {
            let targetType = extractTargetType(from: beforeCursor)
            return TypeScriptContextAnalysisResult(type: .member, filter: "", targetType: targetType)
        }

        // Check for function definition
        if lineText.contains("function ") && lineText.contains("(") && !lineText.contains(")") {
            return TypeScriptContextAnalysisResult(type: .parameter, filter: filter)
        }

        return TypeScriptContextAnalysisResult(type: .general, filter: filter)
    }

    override public func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$")).inverted)
        return components.last ?? ""
    }

    override public func extractTargetType(from text: String) -> String? {
        // Extract the object before the dot
        let pattern = #"([\w$]+)\s*\.\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }

    // MARK: - Completion Creation Methods

    override public func createTypeCompletions(filter: String) -> [CompletionItemModel] {
        types
            .filter { type in
                filter.isEmpty || type.localizedCaseInsensitiveContains(filter)
            }
            .map { type in
                // Determine if it's a utility type (starts with uppercase)
                let isUtilityType = type.first?.isUppercase ?? false
                return CompletionItemModel(
                    label: type,
                    insertText: isUtilityType ? "\(type)<$0>" : type,
                    kind: .interface,
                    detail: isUtilityType ? "TypeScript utility type" : "TypeScript type",
                    priority: 75
                )
            }
    }

    private func createTSTypeCompletions(filter: String) -> [CompletionItemModel] {
        // Additional common types not in builtinTypes
        let additionalTypes = ["HTMLElement", "Document", "Window", "Event", "MouseEvent", "KeyboardEvent", "FormData", "Response", "Request"]

        return additionalTypes
            .filter { type in
                filter.isEmpty || type.localizedCaseInsensitiveContains(filter)
            }
            .map { type in
                CompletionItemModel(
                    label: type,
                    insertText: type,
                    kind: .interface,
                    detail: "DOM/Web API type",
                    priority: 70
                )
            }
    }

    private func createDecoratorCompletions(filter: String) -> [CompletionItemModel] {
        decorators
            .filter { decorator in
                let decoratorName = decorator.dropFirst() // Remove @
                return filter.isEmpty || decoratorName.localizedCaseInsensitiveContains(filter)
            }
            .map { decorator in
                CompletionItemModel(
                    label: decorator,
                    insertText: decorator,
                    kind: .method,
                    detail: "TypeScript decorator",
                    priority: 85
                )
            }
    }

    private func createImportCompletions(filter: String) -> [CompletionItemModel] {
        // Common TypeScript/JavaScript modules and type definitions
        let modules = [
            "@types/node", "@types/react", "@types/express", "@types/jest",
            "react", "react-dom", "vue", "angular", "express", "axios",
            "rxjs", "lodash", "moment", "date-fns", "zod", "yup"
        ]

        return modules
            .filter { module in
                filter.isEmpty || module.localizedCaseInsensitiveContains(filter)
            }
            .map { module in
                CompletionItemModel(
                    label: module,
                    insertText: module,
                    kind: .module,
                    detail: module.hasPrefix("@types/") ? "Type definitions" : "JavaScript module",
                    priority: 85
                )
            }
    }

    private func createGenericCompletions(filter: String) -> [CompletionItemModel] {
        // Common generic type parameters
        let generics = ["T", "K", "V", "E", "TKey", "TValue", "TResult", "TError", "TData"]

        return generics
            .filter { generic in
                filter.isEmpty || generic.localizedCaseInsensitiveContains(filter)
            }
            .map { generic in
                CompletionItemModel(
                    label: generic,
                    insertText: generic,
                    kind: .typeParameter,
                    detail: "Generic type parameter",
                    priority: 70
                )
            }
    }

    // MARK: - Member Completions Override

    override public func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel] {
        guard let targetType else { return [] }

        // Provide TypeScript-aware member completions
        switch targetType.lowercased() {
        case "array":
            return createArrayMemberCompletions(filter: filter)

        case "promise":
            return createPromiseMemberCompletions(filter: filter)

        case "string":
            return createStringMemberCompletions(filter: filter)

        case "object":
            return createObjectMemberCompletions(filter: filter)

        default:
            // For unknown types, provide common members
            return createCommonMemberCompletions(filter: filter)
        }
    }

    // MARK: - Parameter Completions Override

    override public func createParameterCompletions(filter: String) -> [CompletionItemModel] {
        let commonParameters = [
            "event: Event", "error: Error", "data: any", "result: T",
            "callback: () => void", "options: Options", "config: Config",
            "request: Request", "response: Response", "next: NextFunction"
        ]

        return commonParameters
            .filter { param in
                let paramName = param.split(separator: ":").first ?? ""
                return filter.isEmpty || paramName.localizedCaseInsensitiveContains(filter)
            }
            .map { param in
                CompletionItemModel(
                    label: param,
                    insertText: param,
                    kind: .variable,
                    detail: "Typed parameter suggestion",
                    priority: 55
                )
            }
    }

    // MARK: - Type-Specific Members (TypeScript-aware)

    private func createArrayMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("length", "property", "number"),
            ("push(...items: T[]): number", "method", "Add elements to end"),
            ("pop(): T | undefined", "method", "Remove last element"),
            ("map<U>(fn: (value: T) => U): U[]", "method", "Transform elements"),
            ("filter(fn: (value: T) => boolean): T[]", "method", "Filter elements"),
            ("reduce<U>(fn: (acc: U, value: T) => U, initial: U): U", "method", "Reduce to value"),
            ("forEach(fn: (value: T) => void): void", "method", "Iterate elements"),
            ("find(fn: (value: T) => boolean): T | undefined", "method", "Find element"),
            ("includes(value: T): boolean", "method", "Check if includes"),
            ("some(fn: (value: T) => boolean): boolean", "method", "Test any element"),
            ("every(fn: (value: T) => boolean): boolean", "method", "Test all elements")
        ]

        return members
            .filter { name, _, _ in
                let memberName = name.split(separator: "(").first ?? ""
                return filter.isEmpty || memberName.localizedCaseInsensitiveContains(filter)
            }
            .map { name, type, description in
                CompletionItemModel(
                    label: name,
                    insertText: type == "property" ? name : String(name.split(separator: "(").first ?? "") + "($0)",
                    kind: type == "method" ? .method : .property,
                    detail: description,
                    priority: 85
                )
            }
    }

    private func createPromiseMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("then<U>(fn: (value: T) => U): Promise<U>", "method", "Handle resolved value"),
            ("catch(fn: (error: any) => T): Promise<T>", "method", "Handle rejection"),
            ("finally(fn: () => void): Promise<T>", "method", "Execute after settlement")
        ]

        return members
            .filter { name, _, _ in
                let memberName = name.split(separator: "(").first ?? ""
                return filter.isEmpty || memberName.localizedCaseInsensitiveContains(filter)
            }
            .map { name, _, description in
                let memberName = String(name.split(separator: "(").first ?? "")
                return CompletionItemModel(
                    label: name,
                    insertText: "\(memberName)($0)",
                    kind: .method,
                    detail: description,
                    priority: 85
                )
            }
    }

    private func createStringMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("length", "property", "number"),
            ("charAt(index: number): string", "method", "Character at index"),
            ("includes(search: string): boolean", "method", "Check if contains"),
            ("indexOf(search: string): number", "method", "Find index"),
            ("slice(start: number, end?: number): string", "method", "Extract section"),
            ("split(separator: string | RegExp): string[]", "method", "Split into array"),
            ("toLowerCase(): string", "method", "Convert to lowercase"),
            ("toUpperCase(): string", "method", "Convert to uppercase"),
            ("trim(): string", "method", "Remove whitespace"),
            ("replace(search: string | RegExp, replace: string): string", "method", "Replace text")
        ]

        return members
            .filter { name, _, _ in
                let memberName = name.split(separator: "(").first ?? ""
                return filter.isEmpty || memberName.localizedCaseInsensitiveContains(filter)
            }
            .map { name, type, description in
                let memberName = String(name.split(separator: "(").first ?? "")
                return CompletionItemModel(
                    label: name,
                    insertText: type == "property" ? name : "\(memberName)($0)",
                    kind: type == "method" ? .method : .property,
                    detail: description,
                    priority: 85
                )
            }
    }

    private func createObjectMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("Object.keys(obj: T): string[]", "method", "Get object keys"),
            ("Object.values(obj: T): T[keyof T][]", "method", "Get object values"),
            ("Object.entries(obj: T): [string, T[keyof T]][]", "method", "Get entries"),
            ("Object.assign<T>(target: T, ...sources: any[]): T", "method", "Copy properties"),
            ("Object.freeze<T>(obj: T): Readonly<T>", "method", "Freeze object")
        ]

        return members
            .filter { name, _, _ in
                filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
            }
            .map { name, _, description in
                let parts = name.split(separator: "(")
                let methodName = String(parts.first ?? "")
                return CompletionItemModel(
                    label: name,
                    insertText: "\(methodName)($0)",
                    kind: .method,
                    detail: description,
                    priority: 85
                )
            }
    }

    private func createCommonMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("toString(): string", "method", "Convert to string"),
            ("valueOf(): T", "method", "Primitive value"),
            ("constructor", "property", "Constructor function")
        ]

        return members
            .filter { name, _, _ in
                let memberName = name.split(separator: "(").first ?? ""
                return filter.isEmpty || memberName.localizedCaseInsensitiveContains(filter)
            }
            .map { name, type, description in
                let memberName = String(name.split(separator: "(").first ?? "")
                return CompletionItemModel(
                    label: name,
                    insertText: type == "property" ? name : "\(memberName)($0)",
                    kind: type == "method" ? .method : .property,
                    detail: description,
                    priority: 40
                )
            }
    }
}

// MARK: - Supporting Types

private struct TypeScriptContextAnalysisResult {
    enum CompletionType {
        case keyword
        case type
        case member
        case general
        case parameter
        case `import`
        case decorator
        case generic
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
