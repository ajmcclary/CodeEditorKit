import Foundation

// MARK: - LanguageDetectionService

/// Service responsible for language detection and management
/// Separates language detection logic from UI implementation
@MainActor
public final class LanguageDetectionService {
    // MARK: - Properties
    
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "LanguageDetectionService")
    
    // Cache for language detection results
    private var extensionCache: [String: Language] = [:]
    private var contentCache: [Int: Language] = [:]  // Hash -> Language
    
    // MARK: - Initialization
    
    public init() {
        // Preload common extensions into cache
        preloadCommonExtensions()
    }
    
    // MARK: - Public Methods
    
    /// Detects language from file extension
    public func detectLanguage(fromExtension extension: String) -> Language {
        let normalizedExtension = `extension`.lowercased()
        
        // Check cache first
        if let cached = extensionCache[normalizedExtension] {
            return cached
        }
        
        // Detect language
        let language = Language(fileExtension: normalizedExtension) ?? .plainText
        
        // Cache the result
        extensionCache[normalizedExtension] = language
        
        logger.debug("Detected language \(language.name) for extension .\(normalizedExtension)")
        return language
    }
    
    /// Detects language from file path
    public func detectLanguage(fromPath path: String) -> Language {
        let url = URL(fileURLWithPath: path)
        let fileExtension = url.pathExtension
        
        guard !fileExtension.isEmpty else {
            // Check for special filenames
            let filename = url.lastPathComponent
            return detectLanguage(fromFilename: filename)
        }
        
        return detectLanguage(fromExtension: fileExtension)
    }
    
    /// Detects language from filename (for special cases like Dockerfile, Makefile)
    public func detectLanguage(fromFilename filename: String) -> Language {
        let lowercasedFilename = filename.lowercased()
        
        switch lowercasedFilename {
        case "dockerfile":
            return .shell

        case "makefile", "gnumakefile":
            return .shell

        case "rakefile":
            return .ruby

        case "gemfile":
            return .ruby

        case "podfile":
            return .ruby

        case "package.json":
            return .json

        case "tsconfig.json":
            return .json

        case ".gitignore", ".dockerignore":
            return .plainText

        case "readme", "license", "changelog":
            return .markdown

        default:
            return .plainText
        }
    }
    
    /// Detects language from content analysis (heuristic)
    public func detectLanguage(fromContent content: String) -> Language? {
        // Quick return for empty content
        guard !content.isEmpty else { return nil }
        
        // Check cache
        let contentHash = content.hashValue
        if let cached = contentCache[contentHash] {
            return cached
        }
        
        // Limit content analysis to first 1000 characters for performance
        let sampleContent = String(content.prefix(1_000))
        
        // Try to detect by shebang
        if let shebangLanguage = detectLanguageFromShebang(sampleContent) {
            contentCache[contentHash] = shebangLanguage
            return shebangLanguage
        }
        
        // Try to detect by content patterns
        if let patternLanguage = detectLanguageFromPatterns(sampleContent) {
            contentCache[contentHash] = patternLanguage
            return patternLanguage
        }
        
        return nil
    }
    
    /// Gets all supported file extensions
    public func getAllSupportedExtensions() -> Set<String> {
        var extensions = Set<String>()
        for language in Language.allCases {
            extensions.formUnion(language.fileExtensions)
        }
        return extensions
    }
    
    /// Checks if a file extension is supported
    public func isExtensionSupported(_ extension: String) -> Bool {
        detectLanguage(fromExtension: `extension`) != .plainText
    }
    
    /// Gets language display information
    public func getLanguageInfo(for language: Language) -> LanguageInfo {
        LanguageInfo(
            identifier: language.rawValue,
            displayName: language.name,
            fileExtensions: language.fileExtensions,
            primaryExtension: language.fileExtensions.first ?? ""
        )
    }
    
    /// Validates language change
    public func validateLanguageChange(from oldLanguage: Language, to newLanguage: Language) -> LanguageChangeValidation {
        if oldLanguage == newLanguage {
            return .noChange
        }
        
        // Check if switching between similar languages
        let similarGroups: [[Language]] = [
            [.javascript, .typescript],
            [.c, .cpp],
            [.html, .xml],
            [.yaml, .json]
        ]
        
        for group in similarGroups {
            if group.contains(oldLanguage) && group.contains(newLanguage) {
                return .similar
            }
        }
        
        return .different
    }
    
    // MARK: - Cache Management
    
    /// Clears all language detection caches
    public func clearCache() {
        extensionCache.removeAll()
        contentCache.removeAll()
        logger.debug("Language detection cache cleared")
    }
    
    /// Clears content-based detection cache
    public func clearContentCache() {
        contentCache.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func preloadCommonExtensions() {
        let commonExtensions = [
            "swift", "js", "ts", "py", "go", "rs", "c", "cpp", "java",
            "html", "css", "json", "md", "yml", "xml", "sql", "rb", "php", "sh"
        ]
        
        for ext in commonExtensions {
            _ = detectLanguage(fromExtension: ext)
        }
    }
    
    private func detectLanguageFromShebang(_ content: String) -> Language? {
        guard content.hasPrefix("#!") else { return nil }
        
        let firstLine = content.split(separator: "\n", maxSplits: 1).first ?? ""
        let shebang = String(firstLine).lowercased()
        
        if shebang.contains("python") {
            return .python
        } else if shebang.contains("ruby") {
            return .ruby
        } else if shebang.contains("bash") || shebang.contains("sh") {
            return .shell
        } else if shebang.contains("node") || shebang.contains("javascript") {
            return .javascript
        } else if shebang.contains("php") {
            return .php
        }
        
        return nil
    }
    
    private func detectLanguageFromPatterns(_ content: String) -> Language? {
        // Swift patterns
        if content.contains("import Foundation") || content.contains("import UIKit") ||
           content.contains("func ") && content.contains("->") {
            return .swift
        }
        
        // Python patterns
        if content.contains("import ") && content.contains("from ") ||
           content.contains("def ") && content.contains(":") {
            return .python
        }
        
        // JavaScript patterns
        if content.contains("const ") || content.contains("let ") ||
           content.contains("function ") || content.contains("=>") {
            return .javascript
        }
        
        // HTML patterns
        if content.contains("<!DOCTYPE") || content.contains("<html") ||
           content.contains("<body") || content.contains("<head") {
            return .html
        }
        
        // JSON patterns
        if (content.hasPrefix("{") && content.contains(":")) ||
           (content.hasPrefix("[") && content.contains("{")) {
            return .json
        }
        
        return nil
    }
}

// MARK: - Supporting Types

public struct LanguageInfo {
    public let identifier: String
    public let displayName: String
    public let fileExtensions: [String]
    public let primaryExtension: String
}

public enum LanguageChangeValidation {
    case noChange
    case similar    // Languages in the same family
    case different  // Completely different languages
}
