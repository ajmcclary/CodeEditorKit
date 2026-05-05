import Foundation

/// Public API protocol for plugin development
///
/// This protocol defines the stable API surface that plugins can rely on.
/// All breaking changes will follow semantic versioning.
@available(macOS 13.0, iOS 16.0, *)
@MainActor
protocol PluginAPI {
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
protocol LanguageAPI {
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
struct LanguageConfiguration: Sendable {
    /// Comment configuration
    let comments: CommentConfiguration?

    /// Bracket pairs
    let brackets: [BracketPair]

    /// Auto-closing pairs
    let autoClosingPairs: [AutoClosingPair]

    /// Surrounding pairs
    let surroundingPairs: [SurroundingPair]

    /// Folding configuration
    let folding: FoldingConfiguration?

    /// Indentation rules
    let indentationRules: IndentationRules?

    init(
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
protocol CompletionAPI {
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
protocol CommandAPI {
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

/// API for theme functionality. Sub-project 2 of the design system
/// migration consolidated three formerly-separate theme-shaped types
/// (`Theme.Colors`/`Theme.Fonts`, `CodeEditorSwiftUITheme`, and the old
/// `EditorTheme`/`ThemeColors`) into the single `Theme` value type. This
/// API now takes/returns `Theme` directly.
@available(macOS 13.0, iOS 16.0, *)
@MainActor
protocol ThemeAPI {
    /// Register a theme.
    func register(_ theme: Theme) async throws

    /// Unregister a theme by id.
    func unregister(themeId: String) async

    /// Get all registered themes.
    func availableThemes() async -> [Theme]

    /// Get the current theme. Defaults to `Theme.lcarsDark` if none has
    /// been explicitly set.
    func currentTheme() async -> Theme

    /// Set the current theme by id.
    func setTheme(_ themeId: String) async throws
}

// MARK: - Editor API

/// API for editor functionality
@available(macOS 13.0, iOS 16.0, *)
@MainActor
protocol EditorAPI {
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
struct CursorPosition: Sendable {
    let line: Int
    let column: Int
    let offset: Int
}

// MARK: - File System API

/// API for sandboxed file system access
@available(macOS 13.0, iOS 16.0, *)
@MainActor
protocol FileSystemAPI {
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
protocol DiagnosticAPI {
    /// Report diagnostics
    func report(_ diagnostics: [PluginAPIDiagnostic]) async

    /// Clear diagnostics
    func clear() async

    /// Get current diagnostics
    func current() async -> [PluginAPIDiagnostic]
}

/// Diagnostic information
@available(macOS 13.0, iOS 16.0, *)
struct PluginAPIDiagnostic: Sendable {
    let range: NSRange
    let severity: PluginAPIDiagnosticSeverity
    let message: String
    let code: String?
    let source: String?
    let relatedInformation: [PluginAPIDiagnosticRelatedInformation]

    init(
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
enum PluginAPIDiagnosticSeverity: Int, Sendable {
    case error = 1
    case warning = 2
    case information = 3
    case hint = 4
}

/// Related diagnostic information
@available(macOS 13.0, iOS 16.0, *)
struct PluginAPIDiagnosticRelatedInformation: Sendable {
    let location: DiagnosticLocation
    let message: String
}

/// Diagnostic location
@available(macOS 13.0, iOS 16.0, *)
struct DiagnosticLocation: Sendable {
    let uri: String
    let range: NSRange
}

// MARK: - Configuration Types

/// Comment configuration
@available(macOS 13.0, iOS 16.0, *)
struct CommentConfiguration: Sendable {
    let lineComment: String?
    let blockComment: (start: String, end: String)?
}

/// Bracket pair
@available(macOS 13.0, iOS 16.0, *)
struct BracketPair: Sendable {
    let open: String
    let close: String
}

/// Auto-closing pair
@available(macOS 13.0, iOS 16.0, *)
struct AutoClosingPair: Sendable {
    let open: String
    let close: String
    let notIn: [String]

    init(open: String, close: String, notIn: [String] = []) {
        self.open = open
        self.close = close
        self.notIn = notIn
    }
}

/// Surrounding pair
@available(macOS 13.0, iOS 16.0, *)
struct SurroundingPair: Sendable {
    let open: String
    let close: String
}

/// Folding configuration
@available(macOS 13.0, iOS 16.0, *)
struct FoldingConfiguration: Sendable {
    let offSide: Bool
    let markers: FoldingMarkers?

    init(offSide: Bool = false, markers: FoldingMarkers? = nil) {
        self.offSide = offSide
        self.markers = markers
    }
}

/// Folding markers
@available(macOS 13.0, iOS 16.0, *)
struct FoldingMarkers: Sendable {
    let start: String
    let end: String
}

/// Indentation rules
@available(macOS 13.0, iOS 16.0, *)
struct IndentationRules: Sendable {
    let increaseIndentPattern: String
    let decreaseIndentPattern: String
    let indentNextLinePattern: String?
    let unindentedLinePattern: String?

    init(
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
