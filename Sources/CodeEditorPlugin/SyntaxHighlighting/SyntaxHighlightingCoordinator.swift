import Foundation

// SwiftSyntax is not compatible with Mac Catalyst
import SwiftParser
import SwiftSyntax

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - HighlightingTaskManager

/// Actor for managing highlighting tasks with thread safety
private actor HighlightingTaskManager {
    private var currentTask: Task<[HighlightedToken], Never>?

    func setCurrentTask(_ task: Task<[HighlightedToken], Never>?) {
        currentTask?.cancel()
        currentTask = task
    }

    func cancelCurrent() {
        currentTask?.cancel()
        currentTask = nil
    }
}

// MARK: - SyntaxHighlightingCoordinator

/// Coordinates between SwiftSyntax and regex-based highlighting for different languages.
///
/// `@unchecked Sendable` rationale (Swift 6 strict concurrency):
/// - All stored properties beyond `taskManager` are immutable references to
///   value-semantic helpers (`SwiftSyntaxHighlighter`, `RegexSyntaxHighlighter`,
///   `FastJSONTokenizer`, `PerformanceMonitor`, `HighlightingStrategyExecutor`).
/// - Cancellation/active-task state lives inside the private
///   `HighlightingTaskManager` actor (declared above) — every mutation crosses
///   that actor boundary via `await taskManager.cancelCurrent()` /
///   `setCurrentTask(_:)`. The actor is the synchronization mechanism.
/// - Why not synthesized: the type is publicly subclassable in spirit (final
///   class with reference semantics) and Swift cannot prove the actor-only
///   discipline statically. The convention is enforced by the API: callers
///   never reach into mutable state directly.
public final class SyntaxHighlightingCoordinator: @unchecked Sendable {
    // MARK: - Properties

    private let swiftHighlighter: SwiftSyntaxHighlighter
    private let regexHighlighter: RegexSyntaxHighlighter
    private let fastJSONTokenizer: FastJSONTokenizer
    private let performanceMonitor: PerformanceMonitor
    private let strategyExecutor: HighlightingStrategyExecutor

    // Use an actor for managing mutable state
    private let taskManager = HighlightingTaskManager()

    // MARK: - Initialization

    public init(performanceMonitor: PerformanceMonitor? = nil) {
        swiftHighlighter = SwiftSyntaxHighlighter()
        regexHighlighter = RegexSyntaxHighlighter()
        fastJSONTokenizer = FastJSONTokenizer()
        self.performanceMonitor = performanceMonitor ?? PerformanceMonitor()

        // Initialize strategy executor with highlighters
        self.strategyExecutor = HighlightingStrategyExecutor(
            swiftHighlighter: swiftHighlighter,
            regexHighlighter: regexHighlighter,
            fastJSONTokenizer: fastJSONTokenizer
        )
    }

    // MARK: - Public Methods

    /// Detect language from file extension
    public func detectLanguage(from fileExtension: String) -> Language {
        Language(fileExtension: fileExtension) ?? .plainText
    }

    /// Highlight source code synchronously
    public func highlight(source: String, language: Language) -> [HighlightedToken] {
        strategyExecutor.highlight(source: source, language: language)
    }

    /// Highlight source code asynchronously with cancellation support
    public func highlightAsync(source: String, language: Language) async -> [HighlightedToken] {
        // Cancel any existing highlighting task
        await taskManager.cancelCurrent()

        // Capture the executor for use in the task
        let executor = strategyExecutor

        // Create new task for highlighting
        let task = Task<[HighlightedToken], Never> {
            executor.highlight(source: source, language: language)
        }

        await taskManager.setCurrentTask(task)
        return await task.value
    }

    /// Apply highlighting to an attributed string using adaptive colors with progressive rendering
    @MainActor
    public func applyHighlighting(
        to attributedString: NSMutableAttributedString,
        tokens: [HighlightedToken],
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        // Remove existing syntax highlighting
        let range = NSRange(location: 0, length: attributedString.length)
        attributedString.removeAttribute(.foregroundColor, range: range)

        // Apply new highlighting with adaptive colors in batches for responsiveness
        let batchSize = 100
        let totalTokens = tokens.count

        for (index, token) in tokens.enumerated() {
            // Check for cancellation periodically
            if index.isMultiple(of: batchSize) {
                try Task.checkCancellation()
                await Task.yield()
                progressHandler?(Double(index) / Double(totalTokens))
            }

            guard token.range.location + token.range.length <= attributedString.length else {
                continue
            }

            // Use adaptive color system that works with macOS 26 Liquid Glass design
            attributedString.addAttribute(.foregroundColor, value: token.type.color, range: token.range)
        }

        progressHandler?(1.0)
    }

    /// Get all supported file extensions
    public var supportedFileExtensions: [String] {
        var extensions: [String] = []
        for language in Language.allCases {
            extensions.append(contentsOf: language.fileExtensions)
        }
        return Array(Set(extensions)).sorted()
    }

    /// Cancel any in-progress highlighting
    public func cancelHighlighting() async {
        await taskManager.cancelCurrent()
    }

    deinit {
        // Note: Cannot perform async cleanup in deinit
        // The task manager will clean up its own resources
    }
}

// MARK: - Language

/// Represents the programming languages supported by the code editor.
///
/// The Language enum defines all supported languages for syntax highlighting,
/// code completion, and other language-specific features. Each language has
/// associated file extensions and display names.
///
/// ## Supported Languages
///
/// The editor supports 17+ programming languages grouped by category:
///
/// ### Web Development
/// - `.html` - HTML markup
/// - `.css` - CSS stylesheets  
/// - `.javascript` - JavaScript (.js, .mjs, .cjs)
/// - `.typescript` - TypeScript (.ts, .tsx)
///
/// ### Systems Programming
/// - `.swift` - Swift (with AST-based highlighting)
/// - `.rust` - Rust (.rs)
/// - `.c` - C language (.c, .h)
/// - `.cpp` - C++ (.cpp, .cc, .cxx, .hpp)
/// - `.go` - Go (.go)
///
/// ### Scripting Languages
/// - `.python` - Python (.py, .pyw)
/// - `.ruby` - Ruby (.rb)
/// - `.php` - PHP (.php)
/// - `.shell` - Shell scripts (.sh, .bash, .zsh)
///
/// ### Data & Configuration
/// - `.json` - JSON (.json)
/// - `.yaml` - YAML (.yml, .yaml)
/// - `.xml` - XML (.xml)
/// - `.sql` - SQL (.sql)
///
/// ### Documentation
/// - `.markdown` - Markdown (.md, .markdown)
/// - `.plainText` - Plain text (no highlighting)
///
/// ## Example
///
/// ```swift
/// // Set language directly
/// editor.language = .swift
///
/// // Get display name
/// let name = Language.python.name  // "Python"
///
/// // Check file extensions
/// let extensions = Language.javascript.fileExtensions  // ["js", "mjs", "cjs"]
///
/// // Detect from file extension
/// if let language = Language(fileExtension: "py") {
///     editor.language = language  // .python
/// }
/// ```
///
/// - SeeAlso: `CodeEditorView.language`, `CodeEditorView.setLanguage(fileExtension:)`
public enum Language: String, CaseIterable, Equatable, Hashable, Sendable {
    case swift
    case javascript
    case typescript
    case python
    case go
    case rust
    case c // swiftlint:disable:this identifier_name
    case cpp
    case java
    case html
    case css
    case json
    case markdown
    case yaml
    case xml
    case sql
    case ruby
    case php
    case shell
    case dockerfile
    case toml
    case lua
    case csharp
    case kotlin
    case dart
    case plainText = "plaintext"

    /// The human-readable display name for the language.
    ///
    /// Use this property to show language names in UI elements like
    /// language selectors or status bars.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let languages = Language.allCases.map { $0.name }
    /// // ["Swift", "JavaScript", "TypeScript", ...]
    /// ```
    public var name: String {
        LanguageDescriptor.descriptor(for: self)?.displayName ?? rawValue.capitalized
    }

    /// The file extensions associated with this language.
    ///
    /// Returns an array of common file extensions (without dots) that are
    /// typically used for files of this language type.
    ///
    /// ## Example
    ///
    /// ```swift
    /// Language.python.fileExtensions    // ["py", "pyw"]
    /// Language.cpp.fileExtensions       // ["cpp", "cc", "cxx", "hpp", "h", "hh"]
    /// ```
    public var fileExtensions: [String] {
        LanguageDescriptor.descriptor(for: self)?.fileExtensions ?? []
    }

    /// The Language Server Protocol identifier for the language.
    ///
    /// This identifier is used when communicating with Language Server Protocol (LSP) servers.
    /// It follows the standard LSP language identifiers as defined in the specification.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let language = Language.swift
    /// let lspId = language.lspIdentifier // "swift"
    /// 
    /// // Use with LSP client
    /// lspClient.initialize(languageId: language.lspIdentifier)
    /// ```
    ///
    /// - SeeAlso: [LSP Specification - Text Document Item](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocumentItem)
    public var lspIdentifier: String {
        LanguageDescriptor.descriptor(for: self)?.lspIdentifier ?? rawValue
    }

    /// Initialize from file extension
    public init?(fileExtension: String) {
        let lowercased = fileExtension.lowercased()
        for language in Self.allCases where language.fileExtensions.contains(lowercased) {
            self = language
            return
        }
        return nil
    }
}

// MARK: - Language Extensions

extension Language {
    /// Unique identifier for the language (used by plugin system)
    public var identifier: String {
        rawValue
    }

    /// Get language from identifier
    public init?(identifier: String) {
        self.init(rawValue: identifier)
    }
}

// MARK: - TokenType

/// The type of syntax token identified by the highlighter.
///
/// `TokenType` categorizes code elements for appropriate syntax coloring.
/// Each type has an associated color that adapts to the current theme and
/// platform appearance (light/dark mode).
///
/// ## Token Categories
///
/// ### Code Structure
/// - ``keyword`` - Language keywords (if, for, while, class, etc.)
/// - ``operator`` - Mathematical and logical operators (+, -, &&, ||, etc.)
/// - ``punctuation`` - Structural punctuation (., ,, ;, {, }, etc.)
///
/// ### Identifiers
/// - ``identifier`` - Variable and constant names
/// - ``type`` - Type names and type declarations
/// - ``function`` - Function and method names
/// - ``property`` - Property and field names
///
/// ### Literals
/// - ``string`` - String literals and character literals
/// - ``number`` - Numeric literals (integers, floats, hex, etc.)
///
/// ### Documentation
/// - ``comment`` - Single-line and multi-line comments
///
/// ### Special
/// - ``preprocessor`` - Preprocessor directives (#if, #define, import, etc.)
/// - ``whitespace`` - Spaces, tabs, and newlines (typically not visible)
/// - ``unknown`` - Unrecognized tokens
///
/// ## Platform-Specific Colors
///
/// Colors automatically adapt to the current platform and appearance:
///
/// ```swift
/// let keywordColor = TokenType.keyword.adaptiveColor
/// // Returns appropriate color for current platform and dark/light mode
/// ```
///
/// - Note: On macOS, colors integrate with the system's source code
///         appearance preferences when available.
///
/// - SeeAlso: ``HighlightedToken``, ``Theme``, ``TokenName``
public enum TokenType: String, CaseIterable, Sendable {
    /// Language keywords (if, for, while, class, struct, func, etc.)
    case keyword

    /// Variable, constant, and other identifier names
    case identifier

    /// String literals, including interpolated strings
    case string

    /// Numeric literals (integers, floats, hex, binary, etc.)
    case number

    /// Comments, both single-line (//) and multi-line (/* */)
    case comment

    /// Type names and type annotations
    case type

    /// Function and method names at declaration or call sites
    case function

    /// Property, field, and member names
    case property

    /// Operators (+, -, *, /, ==, &&, ||, etc.)
    case `operator`

    /// Punctuation marks (., ,, ;, :, {, }, [, ], etc.)
    case punctuation

    /// Whitespace characters (spaces, tabs, newlines)
    case whitespace

    /// Preprocessor directives and compiler annotations
    case preprocessor

    /// Tokens that don't match any other category
    case unknown

    /// Cross-platform adaptive color property.
    ///
    /// Returns a color that automatically adapts to the current platform
    /// and appearance settings (light/dark mode). On macOS, integrates
    /// with system source code appearance preferences when available.
    ///
    /// ```swift
    /// let color = TokenType.keyword.adaptiveColor
    /// textStorage.addAttribute(.foregroundColor, value: color, range: range)
    /// ```
    ///
    /// - Important: Always use this property instead of hardcoded colors
    ///              to ensure proper appearance across platforms.
    @MainActor public var adaptiveColor: PlatformColor {
        #if canImport(AppKit)
        AdaptiveColorSystem.syntaxColor(for: self)
        #else
        defaultColor
        #endif
    }

    /// Legacy color property - use adaptiveColor for macOS compatibility.
    ///
    /// This property is maintained for backward compatibility but
    /// `adaptiveColor` should be preferred for new code.
    ///
    /// - SeeAlso: ``adaptiveColor``
    @MainActor public var color: PlatformColor {
        adaptiveColor
    }

    #if canImport(UIKit)
    /// Default colors for iOS
    @MainActor public var defaultColor: PlatformColor {
        switch self {
        case .keyword: return .systemPurple
        case .identifier: return .label
        case .string: return .systemRed
        case .number: return .systemBlue
        case .comment: return .systemGreen
        case .type: return .systemTeal
        case .function: return .systemIndigo
        case .property: return .systemOrange
        case .operator: return .systemBrown
        case .punctuation: return .secondaryLabel
        case .whitespace: return .clear
        case .preprocessor: return .systemPink
        case .unknown: return .label
        }
    }
    #endif

    /// Convert from color to closest token type
    static func fromColor(_ color: PlatformColor, scheme: SyntaxColorScheme) -> Self {
        // Compare with scheme colors to find best match
        if color == scheme.keyword { return .keyword }
        if color == scheme.string { return .string }
        if color == scheme.number { return .number }
        if color == scheme.comment { return .comment }
        if color == scheme.type { return .type }
        if color == scheme.function { return .function }
        if color == scheme.property { return .property }
        if color == scheme.operator { return .operator }
        if color == scheme.punctuation { return .punctuation }
        if color == scheme.preprocessor { return .preprocessor }
        if color == scheme.error { return .unknown }
        return .identifier // Default
    }

    /// Convert from SwiftSyntax token type
    init(fromSwiftType swiftType: SwiftTokenType) {
        switch swiftType {
        case .keyword: self = .keyword
        case .identifier: self = .identifier
        case .string: self = .string
        case .number: self = .number
        case .comment: self = .comment
        case .type: self = .type
        case .function: self = .function
        case .property: self = .property
        case .operator: self = .operator
        case .punctuation: self = .punctuation
        case .whitespace: self = .whitespace
        case .unknown: self = .unknown
        }
    }

    /// Convert from regex highlighter token type
    init(fromRegexType regexType: RegexSyntaxHighlighter.RegexTokenType) {
        switch regexType {
        case .keyword: self = .keyword
        case .identifier: self = .identifier
        case .string: self = .string
        case .number: self = .number
        case .comment: self = .comment
        case .type: self = .type
        case .function: self = .function
        case .property: self = .property
        case .operator: self = .operator
        case .punctuation: self = .punctuation
        case .whitespace: self = .whitespace
        case .preprocessor: self = .preprocessor
        case .unknown: self = .unknown
        }
    }
}

// MARK: - HighlightedToken

/// Represents a syntax-highlighted token in source code.
///
/// A `HighlightedToken` contains the location, type, and text content of a
/// syntactically significant element in code (keyword, string, identifier, etc.).
/// These tokens are produced by syntax highlighters and used to apply colors
/// and styles to source code in the editor.
///
/// ## Overview
///
/// Tokens are the fundamental units of syntax highlighting. Each token represents
/// a contiguous range of text that should be styled consistently based on its
/// syntactic role in the code.
///
/// ## Creating Tokens
///
/// Tokens are typically created by syntax highlighters, not directly by users:
///
/// ```swift
/// // Example from a syntax highlighter
/// let token = HighlightedToken(
///     range: NSRange(location: 0, length: 4),
///     type: .keyword,
///     text: "func"
/// )
/// ```
///
/// ## Using Tokens
///
/// ```swift
/// // Apply highlighting to text storage
/// for token in highlightedTokens {
///     textStorage.addAttribute(
///         .foregroundColor,
///         value: token.type.adaptiveColor,
///         range: token.range
///     )
/// }
/// ```
///
/// ## Performance Considerations
///
/// Tokens are designed to be lightweight and efficient:
/// - They're value types for efficient copying
/// - They're `Sendable` for use across actor boundaries
/// - Range calculations are cached in the token
///
/// - SeeAlso: ``TokenType``, ``SyntaxHighlightingCoordinator``, ``Theme``
public struct HighlightedToken: Sendable {
    /// The range of the token in the source text.
    ///
    /// This range is relative to the highlighter input and uses UTF-16
    /// `NSRange` offsets for compatibility with `NSTextStorage`.
    public let range: NSRange

    /// The syntactic type of the token.
    ///
    /// Determines how the token should be colored and styled.
    public let type: TokenType

    /// The actual text content of the token.
    ///
    /// This is the substring of the source code that this token represents.
    /// Useful for debugging and for highlighters that need to examine
    /// token content for sub-categorization.
    public let text: String

    /// Creates a new highlighted token.
    ///
    /// - Parameters:
    ///   - range: The range of the token in the source text
    ///   - type: The syntactic type of the token
    ///   - text: The text content of the token
    public init(range: NSRange, type: TokenType, text: String) {
        self.range = range
        self.type = type
        self.text = text
    }
}
