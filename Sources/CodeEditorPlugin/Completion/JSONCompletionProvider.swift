import Foundation

// MARK: - JSON Completion Provider

/// Built-in completion provider for JSON language
@MainActor
public final class JSONCompletionProvider: CompletionProvider, @unchecked Sendable {
    public let id = "json-builtin"
    public let supportedLanguages: [Language] = [.json]
    public let triggerCharacters = ["\"", ":", ",", "[", "{", " "]
    public let supportsSnippets = true
    
    // JSON keywords and values
    private let keywords = ["true", "false", "null"]
    
    // Common JSON schema properties
    private let schemaProperties = [
        "$schema", "$id", "$ref", "$defs", "definitions", "title", "description",
        "type", "properties", "items", "required", "additionalProperties",
        "patternProperties", "dependencies", "enum", "const", "allOf", "anyOf",
        "oneOf", "not", "format", "default", "examples", "minimum", "maximum",
        "exclusiveMinimum", "exclusiveMaximum", "multipleOf", "minLength",
        "maxLength", "pattern", "minItems", "maxItems", "uniqueItems",
        "minProperties", "maxProperties", "if", "then", "else"
    ]
    
    // Common JSON types
    private let types = ["object", "array", "string", "number", "integer", "boolean", "null"]
    
    // Common formats
    private let formats = [
        "date-time", "date", "time", "duration", "email", "hostname",
        "ipv4", "ipv6", "uri", "uri-reference", "uuid", "regex",
        "json-pointer", "relative-json-pointer"
    ]
    
    // Common package.json properties
    private let packageJsonProperties = [
        "name", "version", "description", "main", "scripts", "keywords",
        "author", "license", "dependencies", "devDependencies",
        "peerDependencies", "optionalDependencies", "engines", "repository",
        "bugs", "homepage", "private", "type", "module", "browser",
        "bin", "files", "directories", "publishConfig", "workspaces",
        "exports", "imports", "funding"
    ]
    
    // Common tsconfig.json properties
    private let tsconfigProperties = [
        "compilerOptions", "include", "exclude", "files", "extends",
        "references", "typeAcquisition", "watchOptions", "buildOptions"
    ]
    
    // Common compiler options for tsconfig.json
    private let compilerOptions = [
        "target", "module", "lib", "jsx", "outDir", "rootDir", "strict",
        "esModuleInterop", "skipLibCheck", "forceConsistentCasingInFileNames",
        "resolveJsonModule", "allowJs", "checkJs", "declaration", "sourceMap",
        "removeComments", "noEmit", "importHelpers", "downlevelIteration",
        "isolatedModules", "allowSyntheticDefaultImports", "experimentalDecorators",
        "emitDecoratorMetadata", "moduleResolution", "baseUrl", "paths",
        "typeRoots", "types", "allowUmdGlobalAccess", "noImplicitAny",
        "strictNullChecks", "strictFunctionTypes", "strictBindCallApply",
        "strictPropertyInitialization", "noImplicitThis", "alwaysStrict"
    ]
    
    // Common ESLint configuration properties
    private let eslintProperties = [
        "env", "extends", "parser", "parserOptions", "plugins", "rules",
        "settings", "overrides", "globals", "ignorePatterns", "root"
    ]
    
    private let snippets: [SnippetTemplate] = [
        SnippetTemplate(
            label: "object",
            insertText: "{\n    \"${1:key}\": ${2:\"value\"}\n}",
            description: "JSON object"
        ),
        SnippetTemplate(
            label: "array",
            insertText: "[\n    ${1:\"item\"}\n]",
            description: "JSON array"
        ),
        SnippetTemplate(
            label: "property",
            insertText: "\"${1:key}\": ${2:\"value\"}",
            description: "Object property"
        ),
        SnippetTemplate(
            label: "package.json",
            insertText: """
{
    "name": "${1:package-name}",
    "version": "${2:1.0.0}",
    "description": "${3:Package description}",
    "main": "${4:index.js}",
    "scripts": {
        "test": "${5:echo \\"Error: no test specified\\" && exit 1}"
    },
    "keywords": [],
    "author": "${6:}",
    "license": "${7:ISC}",
    "dependencies": {},
    "devDependencies": {}
}
""",
            description: "package.json template"
        ),
        SnippetTemplate(
            label: "tsconfig.json",
            insertText: """
{
    "compilerOptions": {
        "target": "${1:es2020}",
        "module": "${2:commonjs}",
        "strict": ${3:true},
        "esModuleInterop": ${4:true},
        "skipLibCheck": ${5:true},
        "forceConsistentCasingInFileNames": ${6:true},
        "outDir": "${7:./dist}",
        "rootDir": "${8:./src}"
    },
    "include": ["${9:src/**/*}"],
    "exclude": ["${10:node_modules}", "${11:dist}"]
}
""",
            description: "tsconfig.json template"
        ),
        SnippetTemplate(
            label: "eslintrc",
            insertText: """
{
    "env": {
        "${1:browser}": ${2:true},
        "${3:es2021}": ${4:true}
    },
    "extends": "${5:eslint:recommended}",
    "parserOptions": {
        "ecmaVersion": ${6:12},
        "sourceType": "${7:module}"
    },
    "rules": {
        ${8:}
    }
}
""",
            description: "ESLint configuration"
        ),
        SnippetTemplate(
            label: "schema",
            insertText: """
{
    "\\$schema": "http://json-schema.org/draft-07/schema#",
    "\\$id": "${1:https://example.com/schema.json}",
    "title": "${2:Schema Title}",
    "description": "${3:Schema description}",
    "type": "${4:object}",
    "properties": {
        ${5:}
    }
}
""",
            description: "JSON Schema template"
        ),
        SnippetTemplate(
            label: "vscode-settings",
            insertText: """
{
    "editor.fontSize": ${1:14},
    "editor.tabSize": ${2:4},
    "editor.wordWrap": "${3:on}",
    "files.autoSave": "${4:afterDelay}",
    ${5:}
}
""",
            description: "VS Code settings"
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
        case .key:
            items.append(contentsOf: createKeyCompletions(for: analysisResult.fileType, parentKey: analysisResult.parentKey, filter: analysisResult.filter))
            
        case .value:
            items.append(contentsOf: createValueCompletions(for: analysisResult.key, fileType: analysisResult.fileType, filter: analysisResult.filter))
            
        case .keyword:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            
        case .schema:
            items.append(contentsOf: createSchemaCompletions(filter: analysisResult.filter))
            
        case .general:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            if supportsSnippets {
                items.append(contentsOf: createSnippetCompletions(filter: analysisResult.filter))
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
    
    private func analyzeContext(_ context: CompletionContextModel) -> ContextAnalysisResult {
        let beforeCursor = String(context.text.prefix(context.cursorPosition))
        let fileType = detectFileType(from: context.text)
        
        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)
        
        // Check if we're in a key position
        if isInKeyPosition(beforeCursor) {
            let parentKey = findParentKey(in: beforeCursor)
            return ContextAnalysisResult(type: .key, filter: filter, fileType: fileType, parentKey: parentKey)
        }
        
        // Check if we're in a value position
        if let currentKey = getCurrentKey(from: beforeCursor) {
            // Check for schema context
            if currentKey.hasPrefix("$") || schemaProperties.contains(currentKey) {
                return ContextAnalysisResult(type: .schema, filter: filter, fileType: fileType, key: currentKey)
            }
            
            return ContextAnalysisResult(type: .value, filter: filter, fileType: fileType, key: currentKey)
        }
        
        // Check if we're typing a keyword
        if !isInString(beforeCursor) {
            return ContextAnalysisResult(type: .keyword, filter: filter, fileType: fileType)
        }
        
        return ContextAnalysisResult(type: .general, filter: filter, fileType: fileType)
    }
    
    private func extractCurrentWord(from text: String) -> String {
        // Handle quoted strings
        if let lastQuote = text.lastIndex(of: "\"") {
            let afterQuote = String(text[text.index(after: lastQuote)...])
            if !afterQuote.contains("\"") {
                return afterQuote
            }
        }
        
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-$")).inverted)
        return components.last ?? ""
    }
    
    private func detectFileType(from text: String) -> JSONFileType {
        // Try to detect from content
        // Note: In a real implementation, we might get fileName from a different context
        if text.contains("\"name\"") && text.contains("\"version\"") && text.contains("\"dependencies\"") {
            return .packageJson
        } else if text.contains("\"compilerOptions\"") {
            return .tsconfig
        } else if text.contains("\"$schema\"") {
            return .schema
        }
        
        return .generic
    }
    
    private func isInKeyPosition(_ text: String) -> Bool {
        // Remove strings to avoid false positives
        let cleanedText = removeStrings(from: text)
        
        // Check if we're after { or , but before :
        let lastComma = cleanedText.lastIndex(of: ",") ?? cleanedText.startIndex
        let lastBrace = cleanedText.lastIndex(of: "{") ?? cleanedText.startIndex
        let lastColon = cleanedText.lastIndex(of: ":") ?? cleanedText.startIndex
        
        let lastDelimiter = max(lastComma, lastBrace)
        
        return lastDelimiter > lastColon
    }
    
    private func isInString(_ text: String) -> Bool {
        var quoteCount = 0
        var escaped = false
        
        for char in text {
            if char == "\\" {
                escaped.toggle()
            } else {
                if char == "\"" && !escaped {
                    quoteCount += 1
                }
                escaped = false
            }
        }
        
        return quoteCount % 2 == 1
    }
    
    private func removeStrings(from text: String) -> String {
        var result = ""
        var inString = false
        var escaped = false
        
        for char in text {
            if char == "\\" {
                escaped.toggle()
                if !inString {
                    result.append(char)
                }
            } else {
                if char == "\"" && !escaped {
                    inString.toggle()
                    result.append(char)
                } else if !inString {
                    result.append(char)
                }
                escaped = false
            }
        }
        
        return result
    }
    
    private func getCurrentKey(from text: String) -> String? {
        // Find the most recent key before a colon
        let pattern = #"\"([^\"]+)\"\s*:\s*[^,}\]]*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let range = Range(match.range(at: 1), in: text)!
            return String(text[range])
        }
        return nil
    }
    
    private func findParentKey(in text: String) -> String? {
        // Simplified parent key detection - find the key of the current object
        var braceLevel = 0
        let lastKey: String? = nil
        
        let lines = text.components(separatedBy: .newlines)
        for line in lines.reversed() {
            // Count braces
            braceLevel += line.filter { $0 == "}" }.count
            braceLevel -= line.filter { $0 == "{" }.count
            
            if braceLevel < 0 {
                // We're inside an object, find its key
                if let keyMatch = line.range(of: #"\"([^\"]+)\"\s*:\s*\{"#, options: .regularExpression) {
                    let keyPart = line[keyMatch]
                    if let startQuote = keyPart.firstIndex(of: "\""),
                       let endQuote = keyPart.lastIndex(of: "\""),
                       startQuote != endQuote {
                        let startIndex = keyPart.index(after: startQuote)
                        let endIndex = keyPart.index(before: endQuote)
                        return String(keyPart[startIndex...endIndex])
                    }
                }
                break
            }
        }
        
        return lastKey
    }
    
    // MARK: - Completion Creation Methods
    
    private func createKeyCompletions(for fileType: JSONFileType, parentKey: String?, filter: String) -> [CompletionItemModel] {
        var keys: [String] = []
        
        switch fileType {
        case .packageJson:
            if parentKey == "scripts" {
                keys = ["start", "test", "build", "dev", "lint", "format", "watch", "serve", "deploy"]
            } else {
                keys = packageJsonProperties
            }
            
        case .tsconfig:
            if parentKey == "compilerOptions" {
                keys = compilerOptions
            } else {
                keys = tsconfigProperties
            }
            
        case .eslint:
            keys = eslintProperties
            
        case .schema:
            keys = schemaProperties
            
        case .generic:
            // No specific keys for generic JSON
            break
        }
        
        return keys
            .filter { key in
                filter.isEmpty || key.localizedCaseInsensitiveContains(filter)
            }
            .map { key in
                CompletionItemModel(
                    label: key,
                    insertText: "\"\(key)\": $0",
                    kind: .property,
                    detail: "JSON property",
                    priority: 80
                )
            }
    }
    
    private func createValueCompletions(for key: String?, fileType: JSONFileType, filter: String) -> [CompletionItemModel] {
        guard let key else { return [] }
        
        var items: [CompletionItemModel] = []
        
        // Add boolean values for boolean properties
        if isBooleanProperty(key, fileType: fileType) {
            items.append(contentsOf: ["true", "false"]
                .filter { value in
                    filter.isEmpty || value.localizedCaseInsensitiveContains(filter)
                }
                .map { value in
                    CompletionItemModel(
                        label: value,
                        insertText: value,
                        kind: .keyword,
                        detail: "Boolean value",
                        priority: 90
                    )
                })
        }
        
        // Add specific values based on key
        switch key {
        case "type" where fileType == .schema:
            items.append(contentsOf: createTypeCompletions(filter: filter))
            
        case "format" where fileType == .schema:
            items.append(contentsOf: createFormatCompletions(filter: filter))
            
        case "target" where fileType == .tsconfig:
            items.append(contentsOf: createTargetCompletions(filter: filter))
            
        case "module" where fileType == .tsconfig:
            items.append(contentsOf: createModuleCompletions(filter: filter))
            
        case "license" where fileType == .packageJson:
            items.append(contentsOf: createLicenseCompletions(filter: filter))
            
        default:
            break
        }
        
        // Always add null option
        if filter.isEmpty || "null".localizedCaseInsensitiveContains(filter) {
            items.append(CompletionItemModel(
                label: "null",
                insertText: "null",
                kind: .keyword,
                detail: "Null value",
                priority: 70
            ))
        }
        
        return items
    }
    
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
                    detail: "JSON value",
                    priority: 85
                )
            }
    }
    
    private func createSchemaCompletions(filter: String) -> [CompletionItemModel] {
        // Return schema-specific completions
        var items: [CompletionItemModel] = []
        
        // Add schema properties
        items.append(contentsOf: schemaProperties
            .filter { prop in
                filter.isEmpty || prop.localizedCaseInsensitiveContains(filter)
            }
            .map { prop in
                CompletionItemModel(
                    label: prop,
                    insertText: "\"\(prop)\"",
                    kind: .property,
                    detail: "Schema property",
                    priority: 80
                )
            })
        
        return items
    }
    
    private func createTypeCompletions(filter: String) -> [CompletionItemModel] {
        types
            .filter { type in
                filter.isEmpty || type.localizedCaseInsensitiveContains(filter)
            }
            .map { type in
                CompletionItemModel(
                    label: type,
                    insertText: "\"\(type)\"",
                    kind: .value,
                    detail: "JSON type",
                    priority: 85
                )
            }
    }
    
    private func createFormatCompletions(filter: String) -> [CompletionItemModel] {
        formats
            .filter { format in
                filter.isEmpty || format.localizedCaseInsensitiveContains(filter)
            }
            .map { format in
                CompletionItemModel(
                    label: format,
                    insertText: "\"\(format)\"",
                    kind: .value,
                    detail: "Format type",
                    priority: 85
                )
            }
    }
    
    private func createTargetCompletions(filter: String) -> [CompletionItemModel] {
        let targets = ["ES3", "ES5", "ES6", "ES2015", "ES2016", "ES2017", "ES2018", "ES2019", "ES2020", "ES2021", "ES2022", "ESNext"]
        
        return targets
            .filter { target in
                filter.isEmpty || target.localizedCaseInsensitiveContains(filter)
            }
            .map { target in
                CompletionItemModel(
                    label: target,
                    insertText: "\"\(target)\"",
                    kind: .value,
                    detail: "ECMAScript target",
                    priority: 85
                )
            }
    }
    
    private func createModuleCompletions(filter: String) -> [CompletionItemModel] {
        let modules = ["none", "commonjs", "amd", "system", "umd", "es6", "es2015", "es2020", "esnext"]
        
        return modules
            .filter { module in
                filter.isEmpty || module.localizedCaseInsensitiveContains(filter)
            }
            .map { module in
                CompletionItemModel(
                    label: module,
                    insertText: "\"\(module)\"",
                    kind: .value,
                    detail: "Module system",
                    priority: 85
                )
            }
    }
    
    private func createLicenseCompletions(filter: String) -> [CompletionItemModel] {
        let licenses = ["MIT", "ISC", "BSD-3-Clause", "BSD-2-Clause", "Apache-2.0", "GPL-3.0", "LGPL-3.0", "MPL-2.0", "UNLICENSED"]
        
        return licenses
            .filter { license in
                filter.isEmpty || license.localizedCaseInsensitiveContains(filter)
            }
            .map { license in
                CompletionItemModel(
                    label: license,
                    insertText: "\"\(license)\"",
                    kind: .value,
                    detail: "License type",
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
    
    private func isBooleanProperty(_ key: String, fileType _: JSONFileType) -> Bool {
        let booleanProperties: Set<String> = [
            // package.json
            "private", "preferGlobal", "flat",
            // tsconfig.json compiler options
            "strict", "esModuleInterop", "skipLibCheck", "forceConsistentCasingInFileNames",
            "resolveJsonModule", "allowJs", "checkJs", "declaration", "sourceMap",
            "removeComments", "noEmit", "importHelpers", "downlevelIteration",
            "isolatedModules", "allowSyntheticDefaultImports", "experimentalDecorators",
            "emitDecoratorMetadata", "allowUmdGlobalAccess", "noImplicitAny",
            "strictNullChecks", "strictFunctionTypes", "strictBindCallApply",
            "strictPropertyInitialization", "noImplicitThis", "alwaysStrict",
            // JSON Schema
            "additionalProperties", "uniqueItems", "required",
            // ESLint
            "root"
        ]
        
        return booleanProperties.contains(key)
    }
}

// MARK: - Supporting Types

private struct ContextAnalysisResult {
    enum CompletionType {
        case key
        case value
        case keyword
        case schema
        case general
    }
    
    let type: CompletionType
    let filter: String
    let fileType: JSONFileType
    let key: String?
    let parentKey: String?
    
    init(type: CompletionType, filter: String, fileType: JSONFileType, key: String? = nil, parentKey: String? = nil) {
        self.type = type
        self.filter = filter
        self.fileType = fileType
        self.key = key
        self.parentKey = parentKey
    }
}

private enum JSONFileType {
    case packageJson
    case tsconfig
    case eslint
    case schema
    case generic
}

private struct SnippetTemplate {
    let label: String
    let insertText: String
    let description: String
}
