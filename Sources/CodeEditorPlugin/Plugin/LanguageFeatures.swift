import Foundation

// MARK: - LanguageFeatures Namespace

public enum LanguageFeatures {
    // MARK: - Symbol Types
    
    /// Document symbol
    public struct DocumentSymbol: Identifiable, Equatable, Sendable {
        public let id: String
        public let name: String
        public let detail: String?
        public let kind: LanguageSymbolKind
        public let range: NSRange
        public let selectionRange: NSRange
        public let children: [Self]
        
        public init(
            name: String,
            kind: LanguageSymbolKind,
            range: NSRange,
            selectionRange: NSRange,
            id: String = UUID().uuidString,
            detail: String? = nil,
            children: [Self] = []
        ) {
            self.id = id
            self.name = name
            self.detail = detail
            self.kind = kind
            self.range = range
            self.selectionRange = selectionRange
            self.children = children
        }
    }
    
    /// Workspace symbol
    public struct WorkspaceSymbol: Identifiable, Equatable, Sendable {
        public let id: String
        public let name: String
        public let kind: LanguageSymbolKind
        public let location: SymbolLocation
        public let containerName: String?
        
        public init(
            name: String,
            kind: LanguageSymbolKind,
            location: SymbolLocation,
            id: String = UUID().uuidString,
            containerName: String? = nil
        ) {
            self.id = id
            self.name = name
            self.kind = kind
            self.location = location
            self.containerName = containerName
        }
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.kind == rhs.kind &&
            lhs.location == rhs.location &&
            lhs.containerName == rhs.containerName
        }
    }
    
    /// Symbol location
    public struct SymbolLocation: Equatable, Sendable {
        public let filePath: String
        public let range: NSRange
        
        public init(filePath: String, range: NSRange) {
            self.filePath = filePath
            self.range = range
        }
    }
}

// MARK: - Code Formatter Protocol

/// Protocol for code formatting
@MainActor
public protocol CodeFormatter: Sendable {
    /// Unique identifier for the formatter
    var id: String { get }
    
    /// Supported languages
    var supportedLanguages: [Language] { get }
    
    /// Format the entire document
    func format(source: String, options: FormattingOptions) async throws -> String
    
    /// Format a specific range
    func formatRange(source: String, range: NSRange, options: FormattingOptions) async throws -> String
    
    /// Check if range formatting is supported
    var supportsRangeFormatting: Bool { get }
    
    /// Get default formatting options for this formatter
    func defaultOptions() -> FormattingOptions
}

// MARK: - Formatting Options

/// Options for code formatting
public struct FormattingOptions: Equatable, Codable, Sendable {
    public var tabSize: Int = 4
    public var insertSpaces: Bool = true
    public var trimTrailingWhitespace: Bool = true
    public var insertFinalNewline: Bool = true
    public var trimFinalNewlines: Bool = true
    public var maxLineLength: Int?
    public var indentStyle: IndentStyle = .spaces
    public var bracketStyle: BracketStyle = .sameLineFunction
    
    public init() {}
}

/// Indentation style
public enum IndentStyle: String, CaseIterable, Codable, Sendable {
    case spaces
    case tabs
    case mixed
}

/// Bracket placement style
public enum BracketStyle: String, CaseIterable, Codable, Sendable {
    case sameLineFunction = "same_line_function"
    case nextLineFunction = "next_line_function"
    case sameLineControl = "same_line_control"
    case nextLineControl = "next_line_control"
}

// MARK: - Code Linter Protocol

/// Protocol for code linting
@MainActor
public protocol CodeLinter: Sendable {
    /// Unique identifier for the linter
    var id: String { get }
    
    /// Supported languages
    var supportedLanguages: [Language] { get }
    
    /// Lint the source code
    func lint(source: String, filePath: String?) async throws -> [LintIssue]
    
    /// Check if incremental linting is supported
    var supportsIncrementalLinting: Bool { get }
    
    /// Perform incremental linting
    func lintIncremental(source: String, changeRange: NSRange, filePath: String?) async throws -> [LintIssue]
    
    /// Get available lint rules
    func availableRules() -> [LintRule]
    
    /// Configure lint rules
    func configure(rules: [String: Any]) throws
}

// MARK: - Lint Issue

/// Represents a linting issue
public struct LintIssue: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let range: NSRange
    public let severity: LintSeverity
    public let message: String
    public let ruleId: String?
    public let source: String?
    public let fixes: [LintFix]
    
    public init(
        range: NSRange,
        severity: LintSeverity,
        message: String,
        id: String = UUID().uuidString,
        ruleId: String? = nil,
        source: String? = nil,
        fixes: [LintFix] = []
    ) {
        self.id = id
        self.range = range
        self.severity = severity
        self.message = message
        self.ruleId = ruleId
        self.source = source
        self.fixes = fixes
    }
}

/// Severity levels for lint issues
public enum LintSeverity: String, CaseIterable, Codable, Sendable {
    case error
    case warning
    case info
    case hint
}

/// Automatic fix for a lint issue
public struct LintFix: Equatable, Codable, Sendable {
    public let title: String
    public let description: String?
    public let textEdits: [TextEdit]
    
    public init(title: String, description: String? = nil, textEdits: [TextEdit] = []) {
        self.title = title
        self.description = description
        self.textEdits = textEdits
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title &&
               lhs.description == rhs.description &&
               lhs.textEdits == rhs.textEdits
    }
}

/// Lint rule definition
public struct LintRule: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let category: String
    public let defaultSeverity: LintSeverity
    public let configurable: Bool
    
    public init(
        id: String,
        name: String,
        description: String,
        category: String,
        defaultSeverity: LintSeverity,
        configurable: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.defaultSeverity = defaultSeverity
        self.configurable = configurable
    }
}

// MARK: - Documentation Provider Protocol

/// Protocol for providing documentation lookup
@MainActor
public protocol DocumentationProvider: Sendable {
    /// Unique identifier for the provider
    var id: String { get }
    
    /// Supported languages
    var supportedLanguages: [Language] { get }
    
    /// Get documentation for a symbol at the given position
    func documentation(at position: Int, in source: String) async throws -> DocumentationResult?
    
    /// Search documentation by query
    func searchDocumentation(query: String) async throws -> [DocumentationItem]
    
    /// Check if hover documentation is supported
    var supportsHoverDocumentation: Bool { get }
}

// MARK: - Documentation Types

/// Documentation lookup result
public struct DocumentationResult: Equatable, Sendable {
    public let content: String
    public let format: DocumentationFormat
    public let language: String?
    public let url: URL?
    public let examples: [CodeExample]
    
    public init(
        content: String,
        format: DocumentationFormat = .markdown,
        language: String? = nil,
        url: URL? = nil,
        examples: [CodeExample] = []
    ) {
        self.content = content
        self.format = format
        self.language = language
        self.url = url
        self.examples = examples
    }
}

/// Documentation format
public enum DocumentationFormat: String, CaseIterable, Codable, Sendable {
    case plainText = "plaintext"
    case markdown
    case html
}

/// Documentation item for search results
public struct DocumentationItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let category: String
    public let url: URL?
    public let score: Double
    
    public init(
        title: String,
        summary: String,
        category: String,
        id: String = UUID().uuidString,
        url: URL? = nil,
        score: Double = 0.0
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.category = category
        self.url = url
        self.score = score
    }
}

/// Code example in documentation
public struct CodeExample: Equatable, Sendable {
    public let title: String?
    public let code: String
    public let language: String
    public let description: String?
    
    public init(code: String, language: String, title: String? = nil, description: String? = nil) {
        self.title = title
        self.code = code
        self.language = language
        self.description = description
    }
}

// MARK: - Symbol Provider Protocol

/// Protocol for symbol navigation and search
@MainActor
public protocol SymbolProvider: Sendable {
    /// Unique identifier for the provider
    var id: String { get }
    
    /// Supported languages
    var supportedLanguages: [Language] { get }
    
    /// Get symbols in the document
    func documentSymbols(in source: String) async throws -> [LanguageFeatures.DocumentSymbol]
    
    /// Get workspace symbols matching query
    func workspaceSymbols(query: String) async throws -> [LanguageFeatures.WorkspaceSymbol]
    
    /// Find definition of symbol at position
    func definition(at position: Int, in source: String) async throws -> [LanguageFeatures.SymbolLocation]
    
    /// Find references to symbol at position
    func references(at position: Int, in source: String, includeDeclaration: Bool) async throws -> [LanguageFeatures.SymbolLocation]
    
    /// Find implementations of symbol at position
    func implementations(at position: Int, in source: String) async throws -> [LanguageFeatures.SymbolLocation]
}

/// Language feature symbol kinds
public enum LanguageSymbolKind: String, CaseIterable, Codable, Sendable {
    case file = "file"
    case module = "module"
    case namespace = "namespace"
    case package = "package"
    case `class` = "class"
    case method = "method"
    case property = "property"
    case field = "field"
    case constructor = "constructor"
    case `enum` = "enum"
    case interface = "interface"
    case function = "function"
    case variable = "variable"
    case constant = "constant"
    case string = "string"
    case number = "number"
    case boolean = "boolean"
    case array = "array"
    case object = "object"
    case key = "key"
    case null = "null"
    case enumMember = "enumMember"
    case `struct` = "struct"
    case event = "event"
    case `operator` = "operator"
    case typeParameter = "typeParameter"
}

// MARK: - Indentation Provider Protocol

/// Protocol for smart indentation
@MainActor
public protocol IndentationProvider: Sendable {
    /// Unique identifier for the provider
    var id: String { get }
    
    /// Supported languages
    var supportedLanguages: [Language] { get }
    
    /// Calculate indentation for a new line
    func indentationForNewLine(after lineText: String, in source: String, at position: Int) -> Int
    
    /// Calculate indentation for existing line
    func indentationForLine(at lineNumber: Int, in source: String) -> Int
    
    /// Check if automatic indentation adjustment is supported
    var supportsAutomaticIndentation: Bool { get }
}

// MARK: - LSP Client Protocol

/// Protocol for Language Server Protocol clients
@MainActor
public protocol LSPClientProtocol: Sendable {
    /// Unique identifier for the client
    var id: String { get }
    
    /// Supported languages
    var supportedLanguages: [Language] { get }
    
    /// Start the language server
    func start() async throws
    
    /// Stop the language server
    func stop() async
    
    /// Check if server is running
    var isRunning: Bool { get }
    
    /// Send a request to the language server
    func sendRequest<T: Codable>(_ request: LSPRequest) async throws -> T
    
    /// Send a notification to the language server
    func sendNotification(_ notification: LSPNotification) async throws
}

// Note: LSP types are now defined in LSP/LSPTypes.swift
