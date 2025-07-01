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
        let ext = fileExtension.lowercased()

        if ext == "swift" {
            return .swift
        }

        if let languageDefinition = regexHighlighter.languageDefinition(for: ext) {
            return .regex(languageDefinition)
        }

        return .plainText
    }

    /// Highlight source code synchronously
    public func highlight(source: String, language: Language) -> [HighlightedToken] {
        switch language {
        case .swift:
            return swiftHighlighter.highlight(source: source)

        case let .regex(definition):
            return regexHighlighter.highlight(source: source, language: definition)

        case .plainText:
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

            case let .regex(definition):
                return regexHL.highlight(source: source, language: definition)

            case .plainText:
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
        var extensions = ["swift"]

        // Add regex-based language extensions
        for language in regexHighlighter.supportedLanguages.values {
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

public enum Language: Equatable, Hashable, Sendable {
    case swift
    case regex(RegexSyntaxHighlighter.LanguageDefinition)
    case plainText

    public var name: String {
        switch self {
        case .swift:
            "Swift"

        case let .regex(definition):
            definition.name

        case .plainText:
            "Plain Text"
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.swift, .swift),
             (.plainText, .plainText):
            true

        case let (.regex(lhsDef), .regex(rhsDef)):
            lhsDef.name == rhsDef.name

        default:
            false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .swift:
            hasher.combine("swift")

        case .plainText:
            hasher.combine("plainText")

        case .regex(let definition):
            hasher.combine("regex")
            hasher.combine(definition.name)
        }
    }
    
    /// Unique identifier for the language (used by plugin system)
    public var identifier: String {
        switch self {
        case .swift:
            return "swift"

        case .regex(let definition):
            return definition.name.lowercased().replacingOccurrences(of: " ", with: "-")

        case .plainText:
            return "plaintext"
        }
    }
    
    /// Create a language instance from identifier and name (used by plugin system)
    public init(name: String, identifier: String) {
        switch identifier {
        case "swift":
            self = .swift

        case "plaintext":
            self = .plainText

        default:
            // For unknown languages, create a basic regex language definition
            let definition = RegexSyntaxHighlighter.LanguageDefinition(
                name: name,
                fileExtensions: [identifier],
                rules: []
            )
            self = .regex(definition)
        }
    }
    
    // MARK: - Commonly Used Languages
    
    /// Python language definition
    public static var python: Self {
        // Create language definition directly using the static helper
        let rules: [RegexSyntaxHighlighter.HighlightRule] = [
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "#.*$", tokenType: .comment, priority: 10),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string, priority: 9),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string, priority: 9),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b\\d+\\.?\\d*\\b", tokenType: .number, priority: 8),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b(def|class|if|elif|else|for|while|try|except|finally|with|as|import|from|return|yield|break|continue|pass|global|nonlocal|lambda|and|or|not|in|is|True|False|None)\\b", tokenType: .keyword, priority: 7)
        ].compactMap { $0 }
        
        let definition = RegexSyntaxHighlighter.LanguageDefinition(
            name: "Python",
            fileExtensions: ["py", "pyw"],
            rules: rules
        )
        return .regex(definition)
    }
    
    public static var javascript: Self {
        let rules: [RegexSyntaxHighlighter.HighlightRule] = [
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "//.*$", tokenType: .comment, priority: 10),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "/\\*[\\s\\S]*?\\*/", tokenType: .comment, priority: 10),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string, priority: 9),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string, priority: 9),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "`(?:[^`\\\\]|\\\\.)*`", tokenType: .string, priority: 9),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b\\d+\\.?\\d*\\b", tokenType: .number, priority: 8),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b(const|let|var|function|class|if|else|for|while|do|switch|case|default|break|continue|return|try|catch|finally|throw|async|await|import|export|from|as|typeof|instanceof)\\b", tokenType: .keyword, priority: 7)
        ].compactMap { $0 }
        
        let definition = RegexSyntaxHighlighter.LanguageDefinition(
            name: "JavaScript",
            fileExtensions: ["js", "jsx", "mjs"],
            rules: rules
        )
        return .regex(definition)
    }
    
    public static var json: Self {
        let rules: [RegexSyntaxHighlighter.HighlightRule] = [
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string, priority: 9),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b\\d+\\.?\\d*\\b", tokenType: .number, priority: 8),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b(true|false|null)\\b", tokenType: .keyword, priority: 7),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "[{}\\[\\],:]", tokenType: .punctuation, priority: 6)
        ].compactMap { $0 }
        
        let definition = RegexSyntaxHighlighter.LanguageDefinition(
            name: "JSON",
            fileExtensions: ["json", "jsonc"],
            rules: rules
        )
        return .regex(definition)
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

// MARK: - Extension for RegexSyntaxHighlighter

extension RegexSyntaxHighlighter {
    var supportedLanguages: [String: LanguageDefinition] {
        supportedLanguagesMap
    }
}
