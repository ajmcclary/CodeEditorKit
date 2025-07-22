import Foundation

/// Public API protocol for plugin development
///
/// This protocol defines the stable API surface that plugins can rely on.
/// All breaking changes will follow semantic versioning.
@available(macOS 13.0, iOS 16.0, *)
@MainActor
public protocol PluginAPI {
    /// Current API version
    var apiVersion: String { get }
    
    /// Language management APIs
    var languages: LanguageAPI { get }
    
    /// Completion APIs
    var completion: CompletionAPI { get }
    
    /// Command APIs
    var commands: CommandAPI { get }
    
    /// Theme APIs
    var themes: ThemeAPI { get }
    
    /// Editor APIs
    var editor: EditorAPI { get }
    
    /// File system APIs (sandboxed)
    var fileSystem: FileSystemAPI { get }
    
    /// Diagnostic APIs
    var diagnostics: DiagnosticAPI { get }
}

// MARK: - Language API

/// API for language-related functionality
@available(macOS 13.0, iOS 16.0, *)
@MainActor
public protocol LanguageAPI {
    /// Register a syntax highlighter
    func registerHighlighter(_ highlighter: any SyntaxHighlighter, for language: Language) async throws
    
    /// Unregister a syntax highlighter
    func unregisterHighlighter(for language: Language) async throws
    
    /// Get available languages
    func availableLanguages() async -> [Language]
    
    /// Register a language configuration
    func registerLanguageConfiguration(_ config: LanguageConfiguration, for language: Language) async throws
}

/// Language configuration
@available(macOS 13.0, iOS 16.0, *)
public struct LanguageConfiguration: Sendable {
    /// Comment configuration
    public let comments: CommentConfiguration?
    
    /// Bracket pairs
    public let brackets: [BracketPair]
    
    /// Auto-closing pairs
    public let autoClosingPairs: [AutoClosingPair]
    
    /// Surrounding pairs
    public let surroundingPairs: [SurroundingPair]
    
    /// Folding configuration
    public let folding: FoldingConfiguration?
    
    /// Indentation rules
    public let indentationRules: IndentationRules?
    
    public init(
        comments: CommentConfiguration? = nil,
        brackets: [BracketPair] = [],
        autoClosingPairs: [AutoClosingPair] = [],
        surroundingPairs: [SurroundingPair] = [],
        folding: FoldingConfiguration? = nil,
        indentationRules: IndentationRules? = nil
    ) {
        self.comments = comments
        self.brackets = brackets
        self.autoClosingPairs = autoClosingPairs
        self.surroundingPairs = surroundingPairs
        self.folding = folding
        self.indentationRules = indentationRules
    }
}

// MARK: - Completion API

/// API for code completion functionality
@available(macOS 13.0, iOS 16.0, *)
@MainActor
public protocol CompletionAPI {
    /// Register a completion provider
    func registerProvider(_ provider: any CompletionProvider, for language: Language) async
    
    /// Unregister a completion provider
    func unregisterProvider(for language: Language) async
    
    /// Trigger completion at current position
    func triggerCompletion() async
}

// MARK: - Command API

/// API for command functionality
@available(macOS 13.0, iOS 16.0, *)
@MainActor
public protocol CommandAPI {
    /// Register a command
    func register(_ command: PluginCommand, handler: @escaping () async throws -> Void) async throws
    
    /// Unregister a command
    func unregister(commandId: String) async
    
    /// Execute a command
    func execute(commandId: String) async throws
    
    /// Get all registered commands
    func availableCommands() async -> [PluginCommand]
}

// MARK: - Theme API

/// Represents an editor theme
@available(macOS 13.0, iOS 16.0, *)
public struct EditorTheme: Sendable {
    public let identifier: String
    public let name: String
    public let isDark: Bool
    public let colors: ThemeColors
    
    public init(identifier: String, name: String, isDark: Bool, colors: ThemeColors) {
        self.identifier = identifier
        self.name = name
        self.isDark = isDark
        self.colors = colors
    }
}

/// Theme color definitions
@available(macOS 13.0, iOS 16.0, *)
public struct ThemeColors: Sendable {
    public let background: String // Hex color
    public let foreground: String
    public let keyword: String
    public let string: String
    public let comment: String
    public let type: String
    public let function: String
    public let variable: String
    public let number: String
    public let `operator`: String
    public let punctuation: String
    public let selection: String
    public let lineNumber: String
    public let currentLine: String
    
    public init(
        background: String,
        foreground: String,
        keyword: String,
        string: String,
        comment: String,
        type: String,
        function: String,
        variable: String,
        number: String,
        operator: String,
        punctuation: String,
        selection: String,
        lineNumber: String,
        currentLine: String
    ) {
        self.background = background
        self.foreground = foreground
        self.keyword = keyword
        self.string = string
        self.comment = comment
        self.type = type
        self.function = function
        self.variable = variable
        self.number = number
        self.`operator` = `operator`
        self.punctuation = punctuation
        self.selection = selection
        self.lineNumber = lineNumber
        self.currentLine = currentLine
    }
}

/// API for theme functionality
@available(macOS 13.0, iOS 16.0, *)
@MainActor
public protocol ThemeAPI {
    /// Register a theme
    func register(_ theme: EditorTheme) async throws
    
    /// Unregister a theme
    func unregister(themeId: String) async
    
    /// Get available themes
    func availableThemes() async -> [EditorTheme]
    
    /// Get current theme
    func currentTheme() async -> EditorTheme
    
    /// Set current theme
    func setTheme(_ themeId: String) async throws
}

// MARK: - Editor API

/// API for editor functionality
@available(macOS 13.0, iOS 16.0, *)
@MainActor
public protocol EditorAPI {
    /// Get current text
    func getText() async -> String
    
    /// Set text (with undo support)
    func setText(_ text: String) async throws
    
    /// Get selected text
    func getSelectedText() async -> String?
    
    /// Get selection range
    func getSelection() async -> NSRange
    
    /// Set selection range
    func setSelection(_ range: NSRange) async
    
    /// Insert text at current position
    func insertText(_ text: String) async
    
    /// Replace text in range
    func replaceText(in range: NSRange, with text: String) async
    
    /// Get current language
    func getLanguage() async -> Language
    
    /// Set language
    func setLanguage(_ language: Language) async throws
    
    /// Get cursor position
    func getCursorPosition() async -> CursorPosition
    
    /// Set cursor position
    func setCursorPosition(_ position: CursorPosition) async
}

/// Cursor position information
@available(macOS 13.0, iOS 16.0, *)
public struct CursorPosition: Sendable {
    public let line: Int
    public let column: Int
    public let offset: Int
    
    public init(line: Int, column: Int, offset: Int) {
        self.line = line
        self.column = column
        self.offset = offset
    }
}

// MARK: - File System API

/// API for sandboxed file system access
@available(macOS 13.0, iOS 16.0, *)
@MainActor
public protocol FileSystemAPI {
    /// Read file from plugin workspace
    func readFile(_ path: String) async throws -> Data
    
    /// Write file to plugin workspace
    func writeFile(_ path: String, data: Data) async throws
    
    /// Delete file from plugin workspace
    func deleteFile(_ path: String) async throws
    
    /// List files in plugin workspace
    func listFiles(in directory: String?) async throws -> [String]
    
    /// Check if file exists
    func fileExists(_ path: String) async -> Bool
    
    /// Get workspace URL
    var workspaceURL: URL { get }
}

// MARK: - Diagnostic API

/// API for diagnostic functionality
@available(macOS 13.0, iOS 16.0, *)
@MainActor
public protocol DiagnosticAPI {
    /// Report diagnostics
    func report(_ diagnostics: [PluginAPIDiagnostic]) async
    
    /// Clear diagnostics
    func clear() async
    
    /// Get current diagnostics
    func current() async -> [PluginAPIDiagnostic]
}

/// Diagnostic information
@available(macOS 13.0, iOS 16.0, *)
public struct PluginAPIDiagnostic: Sendable {
    public let range: NSRange
    public let severity: PluginAPIDiagnosticSeverity
    public let message: String
    public let code: String?
    public let source: String?
    public let relatedInformation: [PluginAPIDiagnosticRelatedInformation]
    
    public init(
        range: NSRange,
        severity: PluginAPIDiagnosticSeverity,
        message: String,
        code: String? = nil,
        source: String? = nil,
        relatedInformation: [PluginAPIDiagnosticRelatedInformation] = []
    ) {
        self.range = range
        self.severity = severity
        self.message = message
        self.code = code
        self.source = source
        self.relatedInformation = relatedInformation
    }
}

/// Diagnostic severity levels
@available(macOS 13.0, iOS 16.0, *)
public enum PluginAPIDiagnosticSeverity: Int, Sendable {
    case error = 1
    case warning = 2
    case information = 3
    case hint = 4
}

/// Related diagnostic information
@available(macOS 13.0, iOS 16.0, *)
public struct PluginAPIDiagnosticRelatedInformation: Sendable {
    public let location: DiagnosticLocation
    public let message: String
    
    public init(location: DiagnosticLocation, message: String) {
        self.location = location
        self.message = message
    }
}

/// Diagnostic location
@available(macOS 13.0, iOS 16.0, *)
public struct DiagnosticLocation: Sendable {
    public let uri: String
    public let range: NSRange
    
    public init(uri: String, range: NSRange) {
        self.uri = uri
        self.range = range
    }
}

// MARK: - Configuration Types

/// Comment configuration
@available(macOS 13.0, iOS 16.0, *)
public struct CommentConfiguration: Sendable {
    public let lineComment: String?
    public let blockComment: (start: String, end: String)?
    
    public init(lineComment: String? = nil, blockComment: (start: String, end: String)? = nil) {
        self.lineComment = lineComment
        self.blockComment = blockComment
    }
}

/// Bracket pair
@available(macOS 13.0, iOS 16.0, *)
public struct BracketPair: Sendable {
    public let open: String
    public let close: String
    
    public init(open: String, close: String) {
        self.open = open
        self.close = close
    }
}

/// Auto-closing pair
@available(macOS 13.0, iOS 16.0, *)
public struct AutoClosingPair: Sendable {
    public let open: String
    public let close: String
    public let notIn: [String]
    
    public init(open: String, close: String, notIn: [String] = []) {
        self.open = open
        self.close = close
        self.notIn = notIn
    }
}

/// Surrounding pair
@available(macOS 13.0, iOS 16.0, *)
public struct SurroundingPair: Sendable {
    public let open: String
    public let close: String
    
    public init(open: String, close: String) {
        self.open = open
        self.close = close
    }
}

/// Folding configuration
@available(macOS 13.0, iOS 16.0, *)
public struct FoldingConfiguration: Sendable {
    public let offSide: Bool
    public let markers: FoldingMarkers?
    
    public init(offSide: Bool = false, markers: FoldingMarkers? = nil) {
        self.offSide = offSide
        self.markers = markers
    }
}

/// Folding markers
@available(macOS 13.0, iOS 16.0, *)
public struct FoldingMarkers: Sendable {
    public let start: String
    public let end: String
    
    public init(start: String, end: String) {
        self.start = start
        self.end = end
    }
}

/// Indentation rules
@available(macOS 13.0, iOS 16.0, *)
public struct IndentationRules: Sendable {
    public let increaseIndentPattern: String
    public let decreaseIndentPattern: String
    public let indentNextLinePattern: String?
    public let unindentedLinePattern: String?
    
    public init(
        increaseIndentPattern: String,
        decreaseIndentPattern: String,
        indentNextLinePattern: String? = nil,
        unindentedLinePattern: String? = nil
    ) {
        self.increaseIndentPattern = increaseIndentPattern
        self.decreaseIndentPattern = decreaseIndentPattern
        self.indentNextLinePattern = indentNextLinePattern
        self.unindentedLinePattern = unindentedLinePattern
    }
}
