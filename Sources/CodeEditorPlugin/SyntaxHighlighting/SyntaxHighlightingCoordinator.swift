import Foundation
import SwiftParser
import SwiftSyntax

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
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

/// Coordinates between SwiftSyntax and regex-based highlighting for different languages
/// Thread-safe implementation with proper cancellation support
public final class SyntaxHighlightingCoordinator {
    // MARK: - Properties

    private let swiftHighlighter: SwiftSyntaxHighlighter
    private let regexHighlighter: RegexSyntaxHighlighter
    private let performanceMonitor = PerformanceMonitor.shared
    
    // Use an actor for managing mutable state
    private let taskManager = HighlightingTaskManager()

    // MARK: - Initialization

    public init() {
        swiftHighlighter = SwiftSyntaxHighlighter()
        regexHighlighter = RegexSyntaxHighlighter()
    }

    // MARK: - Public Methods

    /// Detect language from file extension
    public func detectLanguage(from fileExtension: String) -> Language {
        Language(fileExtension: fileExtension) ?? .plainText
    }

    /// Highlight source code synchronously
    public func highlight(source: String, language: Language) -> [HighlightedToken] {
        switch language {
        case .swift:
            return swiftHighlighter.highlight(source: source)
            
        case .plainText:
            return []
            
        default:
            // Use regex highlighter for all other languages
            if let languageDefinition = regexHighlighter.languageDefinition(for: language) {
                return regexHighlighter.highlight(source: source, language: languageDefinition)
            }
            return []
        }
    }
    
    /// Highlight source code asynchronously with cancellation support
    public func highlightAsync(source: String, language: Language) async -> [HighlightedToken] {
        // Cancel any existing highlighting task
        await taskManager.cancelCurrent()
        
        // Capture highlighters explicitly
        let swiftHL = swiftHighlighter
        let regexHL = regexHighlighter
        
        // Create new task for highlighting
        let task = Task<[HighlightedToken], Never> {
            // Perform highlighting directly without performance monitoring in async context
            switch language {
            case .swift:
                return swiftHL.highlight(source: source)
                
            case .plainText:
                return []
                
            default:
                // Use regex highlighter for all other languages
                if let languageDefinition = regexHL.languageDefinition(for: language) {
                    return regexHL.highlight(source: source, language: languageDefinition)
                }
                return []
            }
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
    ) async {
        // Remove existing syntax highlighting
        let range = NSRange(location: 0, length: attributedString.length)
        attributedString.removeAttribute(.foregroundColor, range: range)
        
        // Apply new highlighting with adaptive colors in batches for responsiveness
        let batchSize = 100
        let totalTokens = tokens.count
        
        for (index, token) in tokens.enumerated() {
            // Check for cancellation periodically
            if index.isMultiple(of: batchSize) {
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
    case plainText = "plaintext"
    
    public var name: String {
        switch self {
        case .swift: "Swift"
        case .javascript: "JavaScript"
        case .typescript: "TypeScript"
        case .python: "Python"
        case .go: "Go"
        case .rust: "Rust"
        case .c: "C"
        case .cpp: "C++"
        case .java: "Java"
        case .html: "HTML"
        case .css: "CSS"
        case .json: "JSON"
        case .markdown: "Markdown"
        case .yaml: "YAML"
        case .xml: "XML"
        case .sql: "SQL"
        case .ruby: "Ruby"
        case .php: "PHP"
        case .shell: "Shell"
        case .plainText: "Plain Text"
        }
    }
    
    public var fileExtensions: [String] {
        switch self {
        case .swift: ["swift"]
        case .javascript: ["js", "jsx", "mjs"]
        case .typescript: ["ts", "tsx"]
        case .python: ["py", "pyw"]
        case .go: ["go"]
        case .rust: ["rs"]
        case .c: ["c", "h"]
        case .cpp: ["cpp", "cc", "cxx", "hpp", "hh", "hxx"]
        case .java: ["java"]
        case .html: ["html", "htm", "xhtml"]
        case .css: ["css", "scss", "sass", "less"]
        case .json: ["json", "jsonc"]
        case .markdown: ["md", "markdown", "mdown", "mkd"]
        case .yaml: ["yaml", "yml"]
        case .xml: ["xml", "xsl", "xslt", "svg"]
        case .sql: ["sql"]
        case .ruby: ["rb", "rbw"]
        case .php: ["php", "phtml", "php3", "php4", "php5"]
        case .shell: ["sh", "bash", "zsh", "fish"]
        case .plainText: ["txt", "text", "log"]
        }
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

public enum TokenType: String, CaseIterable, Sendable {
    case keyword
    case identifier
    case string
    case number
    case comment
    case type
    case function
    case property
    case `operator`
    case punctuation
    case whitespace
    case preprocessor
    case unknown

    /// Cross-platform adaptive color property
    @MainActor public var adaptiveColor: PlatformColor {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        AdaptiveColorSystem.syntaxColor(for: self)
        #else
        defaultColor
        #endif
    }
    
    /// Legacy color property - use adaptiveColor for macOS 26 compatibility
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

    /// Convert from SwiftSyntax token type
    init(fromSwiftType swiftType: SwiftSyntaxHighlighter.TokenType) {
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

public struct HighlightedToken: Sendable {
    public let range: NSRange
    public let type: TokenType
    public let text: String

    public init(range: NSRange, type: TokenType, text: String) {
        self.range = range
        self.type = type
        self.text = text
    }
}
