import Foundation
import os.log

// MARK: - TypeScript Language Plugin

/// Sample TypeScript language plugin demonstrating the plugin architecture
@MainActor
public final class TypeScriptPlugin: LanguagePlugin, @unchecked Sendable {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.codeeditor.plugin", category: "TypeScriptPlugin")
    
    // MARK: - LanguageProvider Implementation
    
    public let identifier = "typescript"
    public let displayName = "TypeScript"
    public let fileExtensions = ["ts", "tsx", "d.ts"]
    
    nonisolated public var documentationURL: URL? {
        URL(string: "https://www.typescriptlang.org/docs/")
    }
    
    public func createHighlighter() -> any SyntaxHighlighter {
        let rules: [RegexSyntaxHighlighter.HighlightRule] = [
            // Comments
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "//.*$", tokenType: .comment, priority: 10),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "/\\*[\\s\\S]*?\\*/", tokenType: .comment, priority: 10),
            
            // Strings
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string, priority: 9),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string, priority: 9),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "`(?:[^`\\\\]|\\\\.)*`", tokenType: .string, priority: 9),
            
            // Numbers
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b\\d+\\.?\\d*\\b", tokenType: .number, priority: 8),
            
            // TypeScript/JavaScript keywords
            try? RegexSyntaxHighlighter.HighlightRule(
                pattern: "\\b(abstract|any|as|asserts|async|await|boolean|break|case|catch|class|const|constructor|continue|debugger|declare|default|delete|do|else|enum|export|extends|false|finally|for|from|function|get|if|implements|import|in|infer|instanceof|interface|is|keyof|let|module|namespace|never|new|null|number|object|of|package|private|protected|public|readonly|require|return|set|static|string|super|switch|symbol|this|throw|true|try|type|typeof|undefined|unique|unknown|var|void|while|with|yield)\\b",
                tokenType: .keyword,
                priority: 7
            ),
            
            // Types
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b[A-Z][a-zA-Z0-9_]*\\b", tokenType: .type, priority: 6),
            
            // Functions
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b\\w+(?=\\s*\\()", tokenType: .function, priority: 5)
        ].compactMap { $0 }
        
        let definition = RegexSyntaxHighlighter.LanguageDefinition(
            name: displayName,
            fileExtensions: fileExtensions,
            rules: rules
        )
        
        return RegexSyntaxHighlighter(customLanguage: definition)
    }
    
    nonisolated public func completionKeywords() -> [String] {
        [
            "abstract", "any", "as", "asserts", "async", "await", "boolean",
            "break", "case", "catch", "class", "const", "constructor", "continue",
            "debugger", "declare", "default", "delete", "do", "else", "enum",
            "export", "extends", "false", "finally", "for", "from", "function",
            "get", "if", "implements", "import", "in", "infer", "instanceof",
            "interface", "is", "keyof", "let", "module", "namespace", "never",
            "new", "null", "number", "object", "of", "package", "private",
            "protected", "public", "readonly", "require", "return", "set",
            "static", "string", "super", "switch", "symbol", "this", "throw",
            "true", "try", "type", "typeof", "undefined", "unique", "unknown",
            "var", "void", "while", "with", "yield"
        ]
    }
    
    // MARK: - LanguagePlugin Implementation
    
    public let pluginVersion = "1.0.0"
    public let requiredEditorVersion = "1.0.0"
    public let author = "CodeEditor Team"
    public let description = "TypeScript language support with syntax highlighting, completion, and formatting"
    public let license = "MIT"
    
    public var capabilities: PluginCapabilities {
        PluginCapabilities(
            syntaxHighlighting: true,
            codeCompletion: true,
            codeFormatting: true,
            linting: false, // Would require TypeScript compiler
            documentationLookup: false,
            symbolNavigation: false,
            languageServer: true, // Could integrate with TypeScript language server
            incrementalParsing: false,
            smartIndentation: true,
            bracketMatching: true,
            folding: false,
            rename: false,
            goToDefinition: false,
            findReferences: false
        )
    }
    
    public var languageServerConfig: LanguageServerConfig? {
        // Configuration for TypeScript language server
        LanguageServerConfig(
            serverPath: "typescript-language-server",
            arguments: ["--stdio"],
            workingDirectory: nil,
            environmentVariables: [:],
            initializationOptions: [:],
            documentSelector: [
                DocumentFilter(language: "typescript", scheme: "file", pattern: "**/*.ts"),
                DocumentFilter(language: "typescriptreact", scheme: "file", pattern: "**/*.tsx")
            ],
            capabilities: LSPCapabilities()
        )
    }
    
    // MARK: - Feature Providers
    
    public func createCompletionProvider() -> (any CompletionProvider)? {
        TypeScriptPluginCompletionProvider()
    }
    
    public func createFormatter() -> (any CodeFormatter)? {
        TypeScriptFormatter()
    }
    
    public func createLinter() -> (any CodeLinter)? {
        // Could implement TSLint or ESLint integration
        nil
    }
    
    public func createDocumentationProvider() -> (any DocumentationProvider)? {
        // Could implement TypeScript documentation lookup
        nil
    }
    
    public func createSymbolProvider() -> (any SymbolProvider)? {
        // Could implement TypeScript symbol navigation
        nil
    }
    
    public func createIndentationProvider() -> (any IndentationProvider)? {
        TypeScriptIndentationProvider()
    }
    
    public func createLSPClient() -> (any LSPClientProtocol)? {
        // Could implement TypeScript LSP client
        nil
    }
    
    // MARK: - Lifecycle
    
    public func activate() async throws {
        // Initialize TypeScript-specific resources
        logger.debug("TypeScript plugin activated")
    }
    
    public func deactivate() async {
        // Clean up TypeScript-specific resources
        logger.debug("TypeScript plugin deactivated")
    }
    
    nonisolated public func validateCompatibility(editorVersion: String) -> PluginValidationResult {
        if PluginUtilities.versionMeetsRequirement(editorVersion, minimum: requiredEditorVersion) {
            return .compatible
        } else {
            return .incompatible(reason: "Requires editor version \(requiredEditorVersion) or later")
        }
    }
}

// MARK: - TypeScript Completion Provider

@MainActor
private final class TypeScriptPluginCompletionProvider: CompletionProvider, @unchecked Sendable {
    let id = "typescript-plugin-completion"
    let supportedLanguages: [Language] = [
        .typescript
    ]
    let triggerCharacters = [".", "(", "[", "<", " ", ":", ","]
    
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        var completions: [CompletionItemModel] = []
        
        // Basic TypeScript completions
        let keywords = [
            "interface", "type", "class", "enum", "namespace", "module",
            "export", "import", "from", "as", "declare", "abstract",
            "readonly", "public", "private", "protected", "static"
        ]
        
        for keyword in keywords {
            completions.append(CompletionItemModel(
                label: keyword,
                insertText: keyword,
                kind: .keyword,
                detail: "TypeScript keyword",
                documentation: "TypeScript language keyword"
            ))
        }
        
        // Built-in types
        let builtInTypes = [
            "string", "number", "boolean", "object", "undefined", "null",
            "any", "unknown", "never", "void", "Array", "Promise", "Date"
        ]
        
        for type in builtInTypes {
            completions.append(CompletionItemModel(
                label: type,
                insertText: type,
                kind: .class,
                detail: "Built-in type",
                documentation: "TypeScript built-in type"
            ))
        }
        
        return CompletionResult(
            items: completions,
            context: context,
            isIncomplete: false,
            processingTime: 0
        )
    }
}

// MARK: - TypeScript Formatter

@MainActor
private final class TypeScriptFormatter: CodeFormatter, @unchecked Sendable {
    let id = "typescript-formatter"
    let supportedLanguages: [Language] = [
        .typescript
    ]
    let supportsRangeFormatting = true
    
    func format(source: String, options: FormattingOptions) async throws -> String {
        // Simple TypeScript formatting (in a real implementation, this would use Prettier or similar)
        formatTypeScript(source: source, options: options)
    }
    
    func formatRange(source: String, range: NSRange, options: FormattingOptions) async throws -> String {
        guard let swiftRange = Range(range, in: source) else {
            return source
        }
        let substring = String(source[swiftRange])
        return formatTypeScript(source: substring, options: options)
    }
    
    func defaultOptions() -> FormattingOptions {
        var options = FormattingOptions()
        options.tabSize = 2
        options.insertSpaces = true
        options.trimTrailingWhitespace = true
        options.insertFinalNewline = true
        return options
    }
    
    private func formatTypeScript(source: String, options: FormattingOptions) -> String {
        // Basic formatting - in practice would use TypeScript formatter
        var lines = source.components(separatedBy: .newlines)
        var indentLevel = 0
        let indentString = options.insertSpaces ? String(repeating: " ", count: options.tabSize) : "\t"
        
        for index in 0..<lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            
            // Decrease indent for closing braces
            if line.hasPrefix("}") || line.hasPrefix("]") || line.hasPrefix(")") {
                indentLevel = max(0, indentLevel - 1)
            }
            
            // Apply indentation
            if !line.isEmpty {
                lines[index] = String(repeating: indentString, count: indentLevel) + line
            }
            
            // Increase indent for opening braces
            if line.hasSuffix("{") || line.hasSuffix("[") || line.hasSuffix("(") {
                indentLevel += 1
            }
        }
        
        var formatted = lines.joined(separator: "\n")
        
        // Trim trailing whitespace if requested
        if options.trimTrailingWhitespace {
            formatted = formatted.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
        }
        
        // Add final newline if requested
        if options.insertFinalNewline && !formatted.hasSuffix("\n") {
            formatted += "\n"
        }
        
        return formatted
    }
}

// MARK: - TypeScript Indentation Provider

@MainActor
private final class TypeScriptIndentationProvider: IndentationProvider, @unchecked Sendable {
    let id = "typescript-indentation"
    let supportedLanguages: [Language] = [
        .typescript
    ]
    let supportsAutomaticIndentation = true
    
    func indentationForNewLine(after lineText: String, in _: String, at _: Int) -> Int {
        let trimmedLine = lineText.trimmingCharacters(in: .whitespaces)
        let currentIndent = lineText.count - lineText.trimmingCharacters(in: .leadingWhitespace).count
        
        // Increase indentation after opening braces
        if trimmedLine.hasSuffix("{") || trimmedLine.hasSuffix("[") || trimmedLine.hasSuffix("(") {
            return currentIndent + 2 // TypeScript commonly uses 2 spaces
        }
        
        // Maintain current indentation for most cases
        return currentIndent
    }
    
    func indentationForLine(at lineNumber: Int, in source: String) -> Int {
        let lines = source.components(separatedBy: .newlines)
        guard lineNumber < lines.count else { return 0 }
        
        let line = lines[lineNumber]
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // Calculate base indentation from previous lines
        var indentLevel = 0
        for index in 0..<lineNumber {
            let prevLine = lines[index].trimmingCharacters(in: .whitespaces)
            if prevLine.hasSuffix("{") || prevLine.hasSuffix("[") || prevLine.hasSuffix("(") {
                indentLevel += 1
            }
            if prevLine.hasPrefix("}") || prevLine.hasPrefix("]") || prevLine.hasPrefix(")") {
                indentLevel = max(0, indentLevel - 1)
            }
        }
        
        // Decrease indent for closing braces on current line
        if trimmedLine.hasPrefix("}") || trimmedLine.hasPrefix("]") || trimmedLine.hasPrefix(")") {
            indentLevel = max(0, indentLevel - 1)
        }
        
        return indentLevel * 2 // TypeScript commonly uses 2 spaces
    }
}

// MARK: - String Extension

extension String {
    var trimmingCharacters: String {
        trimmingCharacters(in: .whitespaces)
    }
    
    var trimmingLeadingWhitespace: String {
        trimmingCharacters(in: .leadingWhitespace)
    }
}

extension CharacterSet {
    static let leadingWhitespace = CharacterSet(charactersIn: " \t")
}
